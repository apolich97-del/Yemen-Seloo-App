import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/order.dart';
import '../../core/models/refund.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/refund_service.dart';
import '../../core/theme/app_theme.dart';

/// بطاقة استردادات الطلب: للعميل وللفريق، مع بيانات الحساب والإثبات والسند.
class RefundsSection extends StatelessWidget {
  const RefundsSection({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final svc = Get.put(RefundService(), permanent: false);
    final isStaff = Get.isRegistered<AuthService>() &&
        Get.find<AuthService>().isStaff;
    return StreamBuilder<List<RefundRecord>>(
      stream: svc.forOrder(order.id),
      builder: (context, snap) {
        final list = snap.data ?? const <RefundRecord>[];
        if (list.isEmpty && !isStaff) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(top: 12),
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
                  Icon(Icons.assignment_return_outlined,
                      size: 16, color: T.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('الاستردادات (${list.length})',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: T.primary)),
                  ),
                  if (isStaff)
                    TextButton.icon(
                      onPressed: () => showCreateRefundDialog(order),
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('إنشاء طلب استرداد',
                          style: TextStyle(fontSize: 10.5)),
                    ),
                ],
              ),
              if (list.isEmpty)
                Text('لا توجد استردادات',
                    style: TextStyle(fontSize: 11, color: T.muted)),
              ...list.map((r) => _card(context, svc, r, isStaff)),
            ],
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context, RefundService svc, RefundRecord r,
      bool isStaff) {
    final cur = r.currency;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: T.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.refundRefNo,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: T.text)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (r.isCompleted
                          ? AppColors.success
                          : r.status == 'cancelled'
                              ? AppColors.danger
                              : AppColors.accent)
                      .withOpacity(.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(r.statusAr,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: T.text)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${r.amountSar.toStringAsFixed(2)} ر.س · '
            '${r.amountLocal.toStringAsFixed(2)} $cur · ${r.methodAr}',
            style: TextStyle(fontSize: 10.5, color: T.muted),
          ),
          Text(
            'السبب: ${r.reasonNote.isEmpty ? r.reasonAr : '${r.reasonAr} — ${r.reasonNote}'}',
            style: TextStyle(fontSize: 10.5, color: T.muted),
          ),
          if (r.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                r.items
                    .map((e) =>
                        '${e['title'] ?? ''} × ${e['qty'] ?? 1}'
                        '${(e['color'] ?? '') == '' ? '' : ' · ${e['color']}'}'
                        '${(e['size'] ?? '') == '' ? '' : ' · ${e['size']}'}')
                    .join('\n'),
                style: TextStyle(fontSize: 10, height: 1.5, color: T.text),
              ),
            ),
          if (r.bankOrWalletName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'الحساب: ${r.bankOrWalletName} · ${r.payoutAccountNumber} · ${r.payoutAccountHolder}',
                style: TextStyle(fontSize: 10, color: T.muted),
              ),
            ),
          if (r.transferProofUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  base64Decode(
                      r.transferProofUrl.substring(
                          r.transferProofUrl.indexOf(',') + 1)),
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (r.awaitingAccount && !isStaff)
                ActionChip(
                  backgroundColor: T.card,
                  side: BorderSide(color: T.border),
                  label: Text('إدخال بيانات الحساب',
                      style: TextStyle(fontSize: 10.5, color: T.primary)),
                  onPressed: () => _accountDialog(svc, r),
                ),
              if (isStaff &&
                  r.status == 'ready_to_transfer' &&
                  r.settlementMethod == 'bank_transfer')
                ActionChip(
                  backgroundColor: T.card,
                  side: BorderSide(color: T.border),
                  label: Text('إتمام الاسترداد',
                      style: TextStyle(fontSize: 10.5, color: T.primary)),
                  onPressed: () => _completeDialog(svc, r),
                ),
              if (isStaff && r.isCompleted)
                ActionChip(
                  backgroundColor: T.card,
                  side: BorderSide(color: T.border),
                  label: Text('سند PDF',
                      style: TextStyle(fontSize: 10.5, color: T.primary)),
                  onPressed: () => _sharePdf(svc, r, whatsapp: false),
                ),
              if (isStaff && r.isCompleted)
                ActionChip(
                  backgroundColor: T.card,
                  side: BorderSide(color: T.border),
                  label: Text('واتساب',
                      style: TextStyle(fontSize: 10.5, color: T.primary)),
                  onPressed: () => _sharePdf(svc, r, whatsapp: true),
                ),
              if (!isStaff && r.isCompleted) ...[
                ActionChip(
                  backgroundColor: T.card,
                  side: BorderSide(color: T.border),
                  label: Text('تحميل سند الاسترداد',
                      style: TextStyle(fontSize: 10.5, color: T.primary)),
                  onPressed: () => _sharePdf(svc, r, whatsapp: false),
                ),
                ActionChip(
                  backgroundColor: T.card,
                  side: BorderSide(color: T.border),
                  label: Text('مشاركة واتساب',
                      style: TextStyle(fontSize: 10.5, color: T.primary)),
                  onPressed: () => _sharePdf(svc, r, whatsapp: true),
                ),
              ],
              if (isStaff &&
                  Get.isRegistered<AuthService>() &&
                  Get.find<AuthService>().isMainManager &&
                  !r.isCompleted) ...[
                ActionChip(
                  backgroundColor: T.card,
                  side: BorderSide(color: T.border),
                  label: Text('إلغاء السجل',
                      style:
                          TextStyle(fontSize: 10.5, color: AppColors.danger)),
                  onPressed: () async {
                    await svc.cancelOrDelete(
                        orderId: order.id, refundId: r.id, delete: false);
                    Get.snackbar('تم', 'أُلغي سجل الاسترداد');
                  },
                ),
                ActionChip(
                  backgroundColor: T.card,
                  side: BorderSide(color: T.border),
                  label: Text('حذف السجل',
                      style:
                          TextStyle(fontSize: 10.5, color: AppColors.danger)),
                  onPressed: () async {
                    await svc.cancelOrDelete(
                        orderId: order.id, refundId: r.id, delete: true);
                    Get.snackbar('تم الحذف', 'حُذف سجل الاسترداد');
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _accountDialog(RefundService svc, RefundRecord r) async {
    final bank = TextEditingController(text: r.bankOrWalletName);
    final acc = TextEditingController(text: r.payoutAccountNumber);
    final holder = TextEditingController(text: r.payoutAccountHolder);
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('بيانات حساب الاسترداد',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: RefundRecord.wallets.contains(r.bankOrWalletName)
                    ? r.bankOrWalletName
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'البنك أو المحفظة', isDense: true),
                items: RefundRecord.wallets
                    .map((w) => DropdownMenuItem(
                        value: w,
                        child: Text(w,
                            style:
                                TextStyle(fontSize: 12, color: T.text))))
                    .toList(),
                onChanged: (v) => bank.text = v ?? bank.text,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bank,
                decoration: const InputDecoration(
                    labelText: 'أو اكتب الاسم يدوياً', isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: acc,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                    labelText: 'رقم الحساب / المحفظة', isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: holder,
                decoration: const InputDecoration(
                    labelText: 'اسم المستلم', isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Get.back(result: true),
              child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true) return;
    if (bank.text.trim().isEmpty || acc.text.trim().isEmpty) {
      Get.snackbar('بيانات ناقصة', 'أدخل البنك ورقم الحساب');
      return;
    }
    await svc.setPayoutAccount(
      orderId: order.id,
      refundId: r.id,
      bank: bank.text.trim(),
      accountNumber: acc.text.trim(),
      holder: holder.text.trim(),
    );
    Get.snackbar('تم الحفظ', 'بيانات الحساب أُرسلت للمحاسبة');
  }

  Future<void> _completeDialog(RefundService svc, RefundRecord r) async {
    final ref = TextEditingController();
    String proof = '';
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('إتمام الاسترداد',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        content: StatefulBuilder(
          builder: (context, setLocal) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ref,
                  decoration: const InputDecoration(
                      labelText: 'رقم مرجع التحويل', isDense: true),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final x = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 40,
                        maxWidth: 900);
                    if (x == null) return;
                    final bytes = await x.readAsBytes();
                    final mime = x.path.toLowerCase().endsWith('.png')
                        ? 'image/png'
                        : 'image/jpeg';
                    setLocal(() =>
                        proof = 'data:$mime;base64,${base64Encode(bytes)}');
                  },
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: Text(proof.isEmpty ? 'رفع صورة الإثبات' : 'تم اختيار صورة',
                      style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Get.back(result: true),
              child: const Text('اعتماد')),
        ],
      ),
    );
    if (ok != true) return;
    final name =
        Get.find<AuthService>().user.value?.displayName ?? 'المحاسبة';
    await svc.complete(
      orderId: order.id,
      refundId: r.id,
      transferRefNo: ref.text.trim(),
      proofUrl: proof,
      byName: name.isEmpty ? 'المحاسبة' : name,
    );
    Get.snackbar('تم', 'اعتُمد الاسترداد ${r.refundRefNo}');
  }

  Future<void> _sharePdf(RefundService svc, RefundRecord r,
      {required bool whatsapp}) async {
    try {
      final f = await svc.buildPdf(order, r);
      if (whatsapp) {
        await Share.shareXFiles([XFile(f.path)],
            text: 'سند استرداد ${r.refundRefNo} — يمن سيلو');
        final digits = order.address.phone.replaceAll(RegExp(r'[^0-9]'), '');
        final phone = digits.startsWith('967')
            ? digits
            : digits.startsWith('0')
                ? '967${digits.substring(1)}'
                : digits.length == 9
                    ? '967$digits'
                    : digits;
        if (phone.isNotEmpty) {
          await launchUrl(
            Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent('سند استرداد ${r.refundRefNo} من يمن سيلو')}'),
            mode: LaunchMode.externalApplication,
          );
        }
      } else {
        await Share.shareXFiles([XFile(f.path)],
            text: 'سند استرداد ${r.refundRefNo} — يمن سيلو');
      }
    } catch (e) {
      Get.snackbar('تعذر إنشاء السند', '$e');
    }
  }
}

/// نافذة إنشاء طلب استرداد للفريق.
Future<void> showCreateRefundDialog(Order order) async {
  final svc = Get.put(RefundService(), permanent: false);
  final selected = <int, int>{};
  var reason = 'out_of_stock';
  var method = 'deduct_remaining';
  final note = TextEditingController();

  double total() {
    var sum = 0.0;
    selected.forEach((i, qty) {
      sum += order.items[i].unitPriceSar * qty;
    });
    return sum;
  }

  final ok = await Get.dialog<bool>(
    AlertDialog(
      title: const Text('إنشاء طلب استرداد',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 460,
        child: StatefulBuilder(
          builder: (context, setLocal) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('اختر القطع والكميات',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: T.text)),
                const SizedBox(height: 6),
                ...List.generate(order.items.length, (i) {
                  final it = order.items[i];
                  final qty = selected[i] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${it.title} · ${it.unitPriceSar.toStringAsFixed(2)} ر.س',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(fontSize: 10.5, color: T.text),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              size: 16),
                          onPressed: qty <= 0
                              ? null
                              : () => setLocal(() {
                                    if (qty - 1 <= 0) {
                                      selected.remove(i);
                                    } else {
                                      selected[i] = qty - 1;
                                    }
                                  }),
                        ),
                        Text('$qty',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: T.text)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline,
                              size: 16),
                          onPressed: qty >= it.qty
                              ? null
                              : () => setLocal(
                                  () => selected[i] = qty + 1),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: reason,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'سبب الاسترداد', isDense: true),
                  items: const [
                    DropdownMenuItem(
                        value: 'out_of_stock', child: Text('نفاد الكمية')),
                    DropdownMenuItem(
                        value: 'shipping_unavailable',
                        child: Text('تعذر الشحن')),
                    DropdownMenuItem(
                        value: 'damaged', child: Text('منتج تالف')),
                    DropdownMenuItem(
                        value: 'other', child: Text('سبب آخر')),
                  ],
                  onChanged: (v) => setLocal(() => reason = v ?? reason),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(
                      labelText: 'ملاحظة على السبب (اختياري)',
                      isDense: true),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: method,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'طريقة التسوية', isDense: true),
                  items: const [
                    DropdownMenuItem(
                        value: 'deduct_remaining',
                        child: Text('خصم من المبلغ المتبقي (آجل 50%)')),
                    DropdownMenuItem(
                        value: 'bank_transfer',
                        child: Text('تحويل لحساب العميل')),
                  ],
                  onChanged: (v) => setLocal(() => method = v ?? method),
                ),
                const SizedBox(height: 10),
                Text(
                  'المبلغ: ${total().toStringAsFixed(2)} ر.س · '
                  '${(total() * order.exchangeRate).toStringAsFixed(2)} '
                  '${order.currency.name.toUpperCase()}',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: T.primary),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('إلغاء')),
        ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('إنشاء')),
      ],
    ),
  );
  if (ok != true) return;
  if (selected.isEmpty) {
    Get.snackbar('لم تُختر قطع', 'اختر قطعة واحدة على الأقل');
    return;
  }
  final items = selected.entries.map((e) {
    final it = order.items[e.key];
    return <String, dynamic>{
      'goodsId': it.goodsId,
      'title': it.title,
      'imageUrl': it.imageUrl,
      'color': it.color,
      'size': it.size,
      'qty': e.value,
      'unitPriceSar': it.unitPriceSar,
      'lineLocal': it.unitPriceSar * e.value * order.exchangeRate,
    };
  }).toList();

  final name =
      Get.find<AuthService>().user.value?.displayName ?? 'الفريق';
  try {
    await svc.create(
      order: order,
      items: items,
      amountSar: total(),
      reason: reason,
      reasonNote: note.text.trim(),
      settlementMethod: method,
      byName: name.isEmpty ? 'الفريق' : name,
    );
    Get.snackbar('تم الإنشاء', 'أُنشئ سجل استرداد جديد');
  } catch (e) {
    Get.snackbar('تعذر الإنشاء', '$e');
  }
}
