import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/currency.dart';
import '../../core/models/order.dart';
import '../../core/models/receipt.dart';
import '../../core/services/cart_share.dart';
import '../../core/services/receipt_service.dart';
import '../cart/presentation/cart_share_card.dart';
import '../../core/widgets/brand_header.dart';
import '../guide/interactive_guide.dart';
import '../../core/widgets/order_stage_bar.dart';
import '../receipts/presentation/my_receipts_screen.dart';
import '../support/presentation/support_screen.dart';
import '../../core/services/order_documents.dart';
import '../../core/services/order_service.dart';
import '../../core/theme/app_theme.dart';

/// تفاصيل الطلب: الخط الزمني + المنتجات + إثبات التسليم + تسريع الشحن.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final id = Get.arguments as String? ?? '';
    final svc = Get.find<OrderService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطلب'),
        actions: const [ThemeToggleButton(), SizedBox(width: 6)],
      ),
      body: StreamBuilder<Order?>(
        stream: svc.watchOrder(id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final o = snap.data;
          if (o == null) {
            return const Center(child: Text('الطلب غير موجود'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              BrandHeader(
                title: 'طلب ${o.orderNo}',
                subtitle: o.address.receiverName.isEmpty
                    ? 'يمن سيلو · متابعة الطلب'
                    : '${o.address.receiverName} · ${o.address.city}',
                badge: o.status.labelAr,
              ),
              const SizedBox(height: 12),
              _header(o),
              const SizedBox(height: 12),
              _timeline(o),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Get.to(() => SupportScreen(order: o)),
                  icon: const Icon(Icons.support_agent, size: 18),
                  label: const Text('اسأل الدعم عن الطلب'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Get.to(() => const MyReceiptsScreen()),
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('إيصالات السداد الخاصة بي'),
                ),
              ),
              const SizedBox(height: 12),
              CartShareCard(url: CartShare.fromOrderItems(o)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SectionCard(
                  title: 'مراحل الطلب',
                  child: OrderStageBar(status: o.status),
                ),
              ),
              _receiptsCard(o),
              _balanceCard(o),
              if (o.hasRemaining) const SizedBox(height: 12),
              _items(o),
              const SizedBox(height: 12),
              _payment(o),
              if (o.proofImageUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                _proof(o),
              ],
              const SizedBox(height: 12),
              _totals(o),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareWhatsApp(o),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('مشاركة واتساب'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _sharePdf(o),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('ملخص PDF'),
                    ),
                  ),
                ],
              ),
              if (!o.status.isTerminal) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: o.expediteRequestedAt != null
                      ? null
                      : () async {
                          try {
                            await svc.requestExpedite(id);
                            Get.snackbar('تم', 'أُرسل تنبيه تسريع الشحن للموظف');
                          } catch (e) {
                            Get.snackbar('تعذر الإرسال', '$e');
                          }
                        },
                  icon: const Icon(Icons.bolt),
                  label: Text(o.expediteRequestedAt != null
                      ? 'طلب التسريع مُرسل'
                      : 'طلب تسريع الشحن'),
                ),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _deferredBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent),
        ),
        child: const Text('آجل 50%',
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF7A5E00))),
      );

  Widget _header(Order o) {
    final c = Color(o.status.colorValue);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(o.orderNo,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                if (o.isDeferred) ...[
                  const SizedBox(width: 6),
                  _deferredBadge(),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(o.status.labelAr,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'تاريخ الطلب: ${o.createdAt.day}/${o.createdAt.month}/${o.createdAt.year}',
              style: TextStyle(fontSize: 12, color: T.muted),
            ),
            if (o.trackingNo.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('رقم التتبع: ${o.trackingNo}${o.courierName.isEmpty ? '' : ' · ${o.courierName}'}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 6),
            Text(o.address.fullAr,
                style: TextStyle(fontSize: 12, height: 1.6, color: T.muted)),
          ],
        ),
      ),
    );
  }

  Widget _timeline(Order o) {
    return SectionCard(
      title: 'حالة الطلب',
      child: Column(
        children: List.generate(kTimelineStages.length, (i) {
          final stage = kTimelineStages[i];
          final done = o.stageReached(stage);
          final event = o.timeline.where((e) => stage.reachedBy.contains(e.status)).toList();
          final at = event.isEmpty ? null : event.last.at;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? AppColors.primary : T.card,
                      border: Border.all(
                        color: done ? AppColors.primary : const Color(0xFFDCE3E0),
                        width: 2,
                      ),
                    ),
                    child: done
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : null,
                  ),
                  if (i != kTimelineStages.length - 1)
                    Container(
                      width: 2,
                      height: 34,
                      color: done ? AppColors.primary.withOpacity(.35) : const Color(0xFFEDF1EF),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.labelAr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                        color: done ? T.text : T.muted,
                      ),
                    ),
                    if (at != null)
                      Text(
                        '${at.day}/${at.month} · ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 11, color: T.muted),
                      ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _items(Order o) => SectionCard(
        title: 'المنتجات (${o.totalPieces})',
        child: Column(
          children: o.items.map((it) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      it.imageUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 52,
                        height: 52,
                        color: const Color(0xFFEDF1EF),
                        child: Icon(Icons.image_outlined, size: 18, color: T.muted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        if (it.size.isNotEmpty || it.color.isNotEmpty)
                          Text(
                            [if (it.size.isNotEmpty) 'مقاس ${it.size}',
                             if (it.color.isNotEmpty) 'لون ${it.color}'].join(' · '),
                            style: TextStyle(fontSize: 11, color: T.muted),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('× ${it.qty}', style: const TextStyle(fontSize: 12)),
                      Text(
                        formatMoney(it.lineTotalSar * o.exchangeRate, o.currency),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );

  /// بطاقة الرصيد: إجمالي الطلب / المدفوع المؤكد / المتبقي.
  Widget _balanceCard(Order o) {
    Widget cell(String label, String value, {Color? color}) => Expanded(
          child: Column(
            children: [
              Text(label, style: TextStyle(fontSize: 10.5, color: T.muted)),
              const SizedBox(height: 3),
              Text(value,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: color ?? T.text)),
            ],
          ),
        );
    return SectionCard(
      title: o.isDeferred ? 'رصيد الطلب — آجل 50%' : 'رصيد الطلب',
      child: Column(
        children: [
          Row(
            children: [
              cell('إجمالي الطلب', formatMoney(o.totalLocal, o.currency)),
              cell('المؤكد دفعه', formatMoney(o.paidTotalLocal, o.currency),
                  color: AppColors.success),
              cell('المتبقي عليك', formatMoney(o.remainingLocal, o.currency),
                  color: AppColors.danger),
            ],
          ),
          if (!o.hasRemaining) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.verified_outlined,
                    size: 16, color: AppColors.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'تم سداد كامل قيمة هذا الطلب — يمكنك تنزيل إيصالاتك من زر '
                    '«إيصالات السداد الخاصة بي».',
                    style: TextStyle(fontSize: 10.5, height: 1.5, color: T.muted),
                  ),
                ),
              ],
            ),
          ],
          if (o.hasRemaining && o.status != OrderStatus.unpaid) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  if (Get.isRegistered<InteractiveGuideController>()) {
                    Get.find<InteractiveGuideController>().showIfFirst(
                      'action_receipt',
                      title: 'رفع إيصال سداد',
                      body: 'ارفع صورة الحوالة وسيُخصم المبلغ من المتبقي بعد اعتماد المحاسبة.',
                      steps: <String>[
                        'أدخل المبلغ المحوّل واسم المرسل.',
                        'أرفق صورة إشعار الحوالة.',
                        'انتظر الاعتماد ليظهر الإيصال برقمه.',
                      ],
                    );
                  }
                  Get.bottomSheet(
                          _UploadReceiptSheet(order: o),
                  isScrollControlled: true,
                  backgroundColor: T.card,
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20))),
                        );
                },
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: const Text('رفع إيصال سداد'),
              ),
            ),
          ],
          if (o.hasRemaining && o.status == OrderStatus.outForDelivery) ...[
            const SizedBox(height: 8),
            Text(
                '⚠️ طلب آجل — تحصيل متبقٍ عند التسليم: '
                '${formatMoney(o.remainingLocal, o.currency)}',
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger)),
          ],
        ],
      ),
    );
  }

  /// إيصالات السداد الخاصة بالعميل مع حالتها.
  Widget _receiptsCard(Order o) => StreamBuilder<List<Receipt>>(
        stream: Get.find<ReceiptService>().forOrder(o.id),
        builder: (context, snap) {
          final list = snap.data ?? const <Receipt>[];
          if (list.isEmpty) return const SizedBox.shrink();
          Widget statusChip(Receipt r) {
            final color = r.isApproved
                ? AppColors.success
                : r.isRejected
                    ? AppColors.danger
                    : const Color(0xFFB26A00);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(r.statusAr,
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: color)),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SectionCard(
              title: 'إيصالات السداد (${list.length})',
              child: Column(
                children: list.map((r) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.receiptNo,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800)),
                              if (r.note.isNotEmpty)
                                Text(r.note,
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        color: T.muted)),
                            ],
                          ),
                        ),
                        Text(formatMoney(r.amountLocal, o.currency),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w900)),
                        const SizedBox(width: 6),
                        statusChip(r),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      );

  Widget _payment(Order o) {
    final p = o.payment;
    if (p.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'بيانات الحوالة',
      child: Column(
        children: [
          MoneyRow(label: 'اسم المرسل', value: p.senderName),
          if (p.refNo.isNotEmpty)
            MoneyRow(label: 'رقم العملية', value: p.refNo),
          MoneyRow(label: 'الحساب المستلم', value: p.accountNumber),
          MoneyRow(
            label: 'حالة التأكيد',
            value: p.confirmedAt == null ? 'بانتظار مراجعة المحاسبة' : 'مؤكدة',
            free: p.confirmedAt != null,
          ),
          _ProofSection(order: o, direct: p.proofUrl),
        ],
      ),
    );
  }

  /// الصورة قد تكون مخزّنة داخل Firestore (data:) أو رابطاً خارجياً.
  Widget _proofImage(String src) {
    if (src.startsWith('data:')) {
      try {
        final b64 = src.substring(src.indexOf(',') + 1);
        return Image.memory(base64Decode(b64),
            height: 220,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(
                height: 60,
                child: Center(child: Text('تعذر عرض صورة الحوالة'))));
      } catch (_) {
        return const SizedBox(
            height: 60, child: Center(child: Text('تعذر عرض صورة الحوالة')));
      }
    }
    return Image.network(src,
        height: 220,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox(
            height: 60,
            child: Center(child: Text('تعذر تحميل صورة الحوالة'))));
  }

  /// مشاركة ملخص الطلب على واتساب بقالب يمن سيلو.
  Future<void> _shareWhatsApp(Order o) async {
    final text = OrderDocuments.whatsappText(o);
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await Share.share(text);
    }
  }

  /// فاتورة PDF عربية بهوية يمن سيلو.
  Future<void> _sharePdf(Order o) async {
    try {
      final f = await OrderDocuments.buildPdf(o);
      await Share.shareXFiles([XFile(f.path)], text: 'فاتورة الطلب ${o.orderNo} — يمن سيلو');
    } catch (e) {
      Get.snackbar('تعذر إنشاء PDF', '$e');
    }
  }

  Widget _proof(Order o) => SectionCard(
        title: 'إثبات التسليم',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            o.proofImageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(
              height: 80,
              child: Center(child: Text('تعذر تحميل صورة الإثبات')),
            ),
          ),
        ),
      );

  Widget _totals(Order o) {
    return SectionCard(
      title: 'الملخص المالي',
      child: Column(
        children: [
          MoneyRow(
            label: 'المنتجات',
            value: formatMoney(o.subtotalSar * o.exchangeRate, o.currency),
          ),
          MoneyRow(
            label: 'الشحن',
            value: o.shippingFeeSar == 0
                ? 'مجاني'
                : formatMoney(o.shippingFeeSar * o.exchangeRate, o.currency),
            free: o.shippingFeeSar == 0,
          ),
          MoneyRow(
            label: 'التوصيل',
            value: formatMoney(o.deliveryFeeSar * o.exchangeRate, o.currency),
          ),
          if (o.discountSar > 0)
            MoneyRow(
              label: 'الخصم (${o.couponCode})',
              value: '- ${formatMoney(o.discountSar * o.exchangeRate, o.currency)}',
              free: true,
            ),
          const Divider(height: 20),
          MoneyRow(
            label: 'الإجمالي',
            value: formatMoney(o.totalLocal, o.currency),
            bold: true,
          ),
        ],
      ),
    );
  }
}


/// نافذة رفع إيصال سداد من العميل (يُحفظ بحالة pending للمراجعة).
class _UploadReceiptSheet extends StatefulWidget {
  const _UploadReceiptSheet({required this.order});

  final Order order;

  @override
  State<_UploadReceiptSheet> createState() => _UploadReceiptSheetState();
}

class _UploadReceiptSheetState extends State<_UploadReceiptSheet> {
  final _amount = TextEditingController();
  final _ref = TextEditingController();
  final _sender = TextEditingController();
  final _note = TextEditingController();
  String _proof = '';
  bool _busy = false;

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
        imageQuality: 25,
        maxWidth: 720,
        maxHeight: 720);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (bytes.length > 300 * 1024) {
      Get.snackbar('الصورة كبيرة', 'اختر صورة أصغر من 300 ك.ب');
      return;
    }
    final mime = x.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    setState(() => _proof = 'data:$mime;base64,${base64Encode(bytes)}');
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim()) ?? 0;
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
      Get.snackbar('تم الإرسال',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('رفع إيصال سداد',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                const Spacer(),
                IconButton(
                    onPressed: Get.back, icon: const Icon(Icons.close, size: 18)),
              ],
            ),
            Text('المتبقي عليك: ${formatMoney(o.remainingLocal, o.currency)}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger)),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ المحوّل'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _sender,
              decoration:
                  const InputDecoration(labelText: 'اسم المرسل (اختياري)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ref,
              decoration: const InputDecoration(
                  labelText: 'رقم العملية (اختياري)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(_proof.isEmpty
                  ? 'إرفاق صورة الإشعار'
                  : 'تم إرفاق صورة الإشعار ✓'),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'جارٍ الإرسال…' : 'إرسال للمحاسبة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// يعرض صورة الحوالة: من بيانات الطلب أو من آخر إيصال مرفوع.
class _ProofSection extends StatelessWidget {
  const _ProofSection({required this.order, required this.direct});

  final Order order;
  final String direct;

  Widget _image(String src) {
    try {
      if (src.startsWith('data:')) {
        return Image.memory(base64Decode(src.substring(src.indexOf(',') + 1)),
            height: 230,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(
                height: 60,
                child: Center(child: Text('تعذر عرض صورة الحوالة'))));
      }
      return Image.network(src,
          height: 230,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(
              height: 60,
              child: Center(child: Text('تعذر تحميل صورة الحوالة'))));
    } catch (_) {
      return const SizedBox(
          height: 60, child: Center(child: Text('تعذر عرض صورة الحوالة')));
    }
  }

  Widget _label(String text, Color color) => Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(text,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (direct.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('صورة الحوالة المرفقة', AppColors.success),
          const SizedBox(height: 6),
          ClipRRect(
              borderRadius: BorderRadius.circular(12), child: _image(direct)),
        ],
      );
    }
    return StreamBuilder<List<Receipt>>(
      stream: Get.find<ReceiptService>().forOrder(order.id),
      builder: (context, snap) {
        final list = snap.data ?? const <Receipt>[];
        final withProof = list.where((r) => r.proofUrl.isNotEmpty).toList();
        if (withProof.isEmpty) {
          return _label(
              snap.hasError
                  ? 'تعذر تحميل الإيصالات'
                  : 'لا توجد صورة حوالة مرفقة مع هذا الطلب',
              AppColors.danger);
        }
        final r = withProof.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label('صورة الحوالة المرفقة (${r.receiptNo})', AppColors.success),
            const SizedBox(height: 6),
            ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _image(r.proofUrl)),
          ],
        );
      },
    );
  }
}
