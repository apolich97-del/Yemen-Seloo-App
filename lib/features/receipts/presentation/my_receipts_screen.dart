import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/currency.dart';
import '../../../core/models/order.dart';
import '../../../core/models/receipt.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/order_documents.dart';
import '../../../core/services/order_service.dart';
import '../../../core/services/receipt_service.dart';
import '../../../core/theme/app_theme.dart';

/// «إيصالاتي» (واجهة إيصال الكاملة): عرض الإيصالات، رفع إيصال سداد مباشرة،
/// فلاتر الحالة، كشف الحساب، وتنزيل PDF لكل إيصال معتمد.
class MyReceiptsScreen extends StatefulWidget {
  const MyReceiptsScreen({super.key});
  @override
  State<MyReceiptsScreen> createState() => _MyReceiptsScreenState();
}

class _MyReceiptsScreenState extends State<MyReceiptsScreen> {
  String _filter = 'all'; // all | pending | approved | rejected

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<ReceiptService>();
    final auth = Get.find<AuthService>();
    final uid = auth.uid ?? '';

    return Obx(() {
      final _ = T.dark; // استجابة فورية للثيم
      return Scaffold(
        backgroundColor: T.bg,
        appBar: AppBar(
          title: const Text('إيصال — سجل الدفعات'),
          actions: [
            TextButton.icon(
              onPressed: () => Get.toNamed(AppRoutes.accountStatement),
              icon: const Icon(Icons.account_balance_outlined, size: 17),
              label: const Text('كشف الحساب',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
            ),
            const ThemeToggleButton(),
            const SizedBox(width: 6),
          ],
        ),
        body: uid.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: T.muted),
                    const SizedBox(height: 10),
                    Text('سجّل الدخول لعرض إيصالاتك ورفع إشعارات السداد',
                        style: TextStyle(color: T.text)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Get.toNamed(AppRoutes.login),
                      child: const Text('تسجيل الدخول'),
                    ),
                  ],
                ),
              )
            : StreamBuilder<List<Receipt>>(
                stream: svc.byCustomer(uid),
                builder: (context, snap) {
                  final waiting = snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData;
                  final allReceipts = snap.data ?? const <Receipt>[];
                  final approvedCount =
                      allReceipts.where((r) => r.isApproved).length;
                  final pendingCount =
                      allReceipts.where((r) => !r.isApproved && !r.isRejected).length;
                  final filtered = allReceipts.where((r) {
                    if (_filter == 'approved') return r.isApproved;
                    if (_filter == 'rejected') return r.isRejected;
                    if (_filter == 'pending') return !r.isApproved && !r.isRejected;
                    return true;
                  }).toList();

                  return ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      // ═══ بطاقة ملخص الإيصالات ═══
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: T.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: T.border),
                        ),
                        child: Row(
                          children: [
                            _stat('الإجمالي', '${allReceipts.length}', T.primary),
                            _stat('معتمدة', '$approvedCount', T.success),
                            _stat('قيد المراجعة', '$pendingCount', T.warning),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ═══ طلبات متاح لها رفع إيصال سداد مباشرة ═══
                      _OrdersNeedingReceiptCard(uid: uid),

                      // ═══ فلاتر الإيصالات ═══
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _chip('الكل', 'all'),
                            _chip('قيد المراجعة', 'pending'),
                            _chip('معتمد', 'approved'),
                            _chip('مرفوض', 'rejected'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (waiting)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 36),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (snap.hasError)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: T.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: T.border),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.info_outline, color: T.warning, size: 30),
                              const SizedBox(height: 8),
                              Text('تعذر تحميل الإيصالات — تأكد من الاتصال',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: T.text)),
                            ],
                          ),
                        )
                      else if (filtered.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: T.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: T.border),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 48, color: T.muted),
                              const SizedBox(height: 10),
                              Text('لا توجد إيصالات في هذا القسم بعد',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: T.text)),
                              const SizedBox(height: 6),
                              Text(
                                'يمكنك رفع صورة حوالة لأي طلب من الأعلى أو من صفحة تفاصيل الطلب.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 11.5, height: 1.6, color: T.muted),
                              ),
                            ],
                          ),
                        )
                      else
                        ...filtered.map((r) => _row(context, r)),
                    ],
                  );
                },
              ),
      );
    });
  }

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10.5, color: T.muted)),
          ],
        ),
      );

  Widget _chip(String label, String key) {
    final active = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: active ? Colors.white : T.text)),
        selected: active,
        selectedColor: AppColors.primary,
        backgroundColor: T.card,
        side: BorderSide(color: active ? AppColors.primary : T.border),
        onSelected: (_) => setState(() => _filter = key),
      ),
    );
  }

  Widget _row(BuildContext context, Receipt r) {
    final Color color = r.isApproved
        ? T.success
        : r.isRejected
            ? T.danger
            : T.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.receiptNo,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: T.text)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withOpacity(.14),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(r.statusAr,
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: color)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'الطلب ${r.orderNo} · ${formatMoney(r.amountLocal, AppCurrency.sar)}',
            style: TextStyle(fontSize: 11.5, color: T.muted),
          ),
          if (r.senderName.isNotEmpty)
            Text('المرسل: ${r.senderName}',
                style: TextStyle(fontSize: 11, color: T.muted)),
          if (r.refNo.isNotEmpty)
            Text('رقم العملية: ${r.refNo}',
                style: TextStyle(fontSize: 11, color: T.muted)),
          if (r.isRejected && r.rejectReason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('سبب الرفض: ${r.rejectReason}',
                  style: TextStyle(fontSize: 11, color: T.danger)),
            ),
          if (r.proofUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: r.proofUrl.startsWith('data:')
                  ? Image.memory(
                      base64Decode(
                          r.proofUrl.substring(r.proofUrl.indexOf(',') + 1)),
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    )
                  : Image.network(
                      r.proofUrl,
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
            ),
          ],
          if (r.isApproved)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  try {
                    final order =
                        await Get.find<OrderService>().fetchOrder(r.orderId);
                    if (order == null) {
                      Get.snackbar('غير متاح', 'تعذر جلب الطلب');
                      return;
                    }
                    final f =
                        await ReceiptDocuments.buildReceiptPdf(order, r);
                    await Share.shareXFiles([XFile(f.path)],
                        text: 'إيصال ${r.receiptNo} — يمن سيلو');
                  } catch (e) {
                    Get.snackbar('تعذر إنشاء PDF', '$e');
                  }
                },
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('تنزيل PDF'),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrdersNeedingReceiptCard extends StatelessWidget {
  const _OrdersNeedingReceiptCard({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: uid)
          .limit(30)
          .snapshots(),
      builder: (context, snap) {
        final all = (snap.data?.docs ?? const [])
            .map((d) => Order.fromDoc(d.id, d.data()))
            .where((o) =>
                !o.status.isTerminal &&
                (o.hasRemaining ||
                    o.isDeferred ||
                    o.status == OrderStatus.unpaid ||
                    o.status == OrderStatus.verifying))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (all.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: T.soft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: T.softBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.upload_file_outlined, size: 17, color: T.primary),
                  const SizedBox(width: 6),
                  Text('رفع إيصال سداد لطلباتك (${all.length})',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: T.text)),
                ],
              ),
              const SizedBox(height: 8),
              ...all.take(5).map((o) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: T.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: T.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.orderNo,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      color: T.text)),
                              Text(
                                '${o.status.labelAr} · المتبقي: ${formatMoney(o.remainingLocal, o.currency)}',
                                style: TextStyle(fontSize: 10.5, color: T.muted),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => Get.bottomSheet(
                            _DirectUploadReceiptSheet(order: o),
                            isScrollControlled: true,
                            backgroundColor: T.card,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20)),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.add_photo_alternate_outlined,
                              size: 15),
                          label: const Text('رفع إيصال',
                              style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }
}

class _DirectUploadReceiptSheet extends StatefulWidget {
  const _DirectUploadReceiptSheet({required this.order});
  final Order order;
  @override
  State<_DirectUploadReceiptSheet> createState() =>
      _DirectUploadReceiptSheetState();
}

class _DirectUploadReceiptSheetState extends State<_DirectUploadReceiptSheet> {
  late final TextEditingController _amount;
  final _ref = TextEditingController();
  late final TextEditingController _sender;
  final _note = TextEditingController();
  String _proof = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    final sug = o.remainingLocal > 0 ? o.remainingLocal : o.totalLocal;
    _amount = TextEditingController(
        text: sug > 0 ? sug.toStringAsFixed(2) : '');
    _sender = TextEditingController(text: o.address.receiverName);
  }

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    _sender.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 30,
        maxWidth: 800,
        maxHeight: 800);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (bytes.length > 350 * 1024) {
      Get.snackbar('الصورة كبيرة', 'اختر صورة أصغر من 350 ك.ب');
      return;
    }
    final mime =
        x.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    setState(() => _proof = 'data:$mime;base64,${base64Encode(bytes)}');
  }

  Future<void> _save() async {
    final amount =
        double.tryParse(_amount.text.replaceAll(',', '').trim()) ?? 0;
    if (amount <= 0) {
      Get.snackbar('المبلغ مطلوب', 'أدخل المبلغ الذي حوّلته');
      return;
    }
    if (_proof.isEmpty) {
      Get.snackbar('الصورة مطلوبة', 'أرفق صورة إشعار الحوالة');
      return;
    }
    setState(() => _busy = true);
    try {
      final no = await Get.find<ReceiptService>().create(
        order: widget.order,
        amountLocal: amount,
        refNo: _ref.text.trim(),
        senderName: _sender.text.trim().isEmpty
            ? widget.order.address.receiverName
            : _sender.text.trim(),
        note: _note.text.trim(),
        proofUrl: _proof,
        source: 'customer',
      );
      Get.back();
      Get.snackbar('تم الإرسال ✓',
          'أُرسل الإيصال $no للمحاسبة وسيُخصم من المتبقي بعد الاعتماد',
          duration: const Duration(seconds: 5));
    } catch (e) {
      Get.snackbar('تعذر الإرسال', '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('رفع إيصال سداد (${o.orderNo})',
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: T.text)),
                const Spacer(),
                IconButton(
                    onPressed: Get.back, icon: const Icon(Icons.close, size: 18)),
              ],
            ),
            Text('المتبقي: ${formatMoney(o.remainingLocal, o.currency)}',
                style: TextStyle(fontSize: 11.5, color: T.muted)),
            const SizedBox(height: 10),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'المبلغ المحوّل *', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ref,
              decoration: const InputDecoration(
                  labelText: 'رقم العملية / الحوالة', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sender,
              decoration:
                  const InputDecoration(labelText: 'اسم المرسل', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration:
                  const InputDecoration(labelText: 'ملاحظة (اختياري)', isDense: true),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(_proof.isEmpty
                  ? 'إرفاق صورة إشعار الحوالة *'
                  : 'تم إرفاق الصورة ✓ (تغيير)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'جارٍ الإرسال…' : 'إرسال الإيصال للمراجعة'),
            ),
          ],
        ),
      ),
    );
  }
}
