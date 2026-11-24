import 'package:cloud_firestore/cloud_firestore.dart'
    show FirebaseFirestore, FieldValue, Timestamp;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/order.dart';
import '../../core/models/receipt.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/order_documents.dart';
import '../../core/services/order_service.dart';
import '../../core/services/receipt_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_header.dart';
import '../orders/refunds_ui.dart';

/// معاينة كاملة للطلب للمدير والموظف: البيانات، القطع، المال، الإيصالات،
/// التتبع والمراحل، مع مشاركة واتساب وPDF وصلاحيات المدير الرئيسي.
Future<void> showOrderPreview(Order o) async {
  await Get.dialog(
    Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: _OrderPreview(order: o),
      ),
    ),
  );
}

class _OrderPreview extends StatelessWidget {
  const _OrderPreview({required this.order});

  final Order order;

  bool get _canEdit {
    if (!Get.isRegistered<AuthService>()) return false;
    return Get.find<AuthService>().canEditOrders;
  }

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Container(
      decoration: BoxDecoration(
        color: T.bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: BrandHeader(
              title: 'طلب ${o.orderNo}',
              subtitle: '${o.address.receiverName} · ${o.address.city}',
              badge: o.status.labelAr,
              compact: true,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _block('بيانات العميل والعنوان', [
                  _kv('العميل', o.address.receiverName),
                  _kv('الهاتف', o.address.phone),
                  _kv('العنوان', o.address.fullAr),
                ]),
                const SizedBox(height: 10),
                _block('الحالة وسعر الصرف المثبّت', [
                  _kv('الحالة', o.status.labelAr),
                  _kv('العملة', o.currency.name.toUpperCase()),
                  _kv('سعر الصرف',
                      '1 ر.س = ${o.exchangeRate.toStringAsFixed(2)} ${o.currency.name.toUpperCase()}'),
                  _kv('تاريخ الإنشاء', _date(o.createdAt)),
                ]),
                const SizedBox(height: 10),
                _block('القطع (${o.items.length})', [
                  ...o.items.map(_item),
                ]),
                const SizedBox(height: 10),
                _block('الملخص المالي', [
                  _kv('إجمالي المنتجات', '${o.subtotalSar.toStringAsFixed(2)} ر.س'),
                  _kv('الشحن', '${o.shippingFeeSar.toStringAsFixed(2)} ر.س'),
                  _kv('التوصيل', '${o.deliveryFeeSar.toStringAsFixed(2)} ر.س'),
                  if (o.discountSar > 0)
                    _kv('الخصم', '- ${o.discountSar.toStringAsFixed(2)} ر.س'),
                  _kv('الإجمالي', '${o.totalSar.toStringAsFixed(2)} ر.س', bold: true),
                  _kv('المدفوع',
                      '${o.paidTotalLocal.toStringAsFixed(2)} ${o.currency.name.toUpperCase()}'),
                  _kv('المتبقي',
                      '${o.remainingLocal.toStringAsFixed(2)} ${o.currency.name.toUpperCase()}'),
                ]),
                const SizedBox(height: 10),
                _receipts(o),
                const SizedBox(height: 10),
                _block('التتبع والمندوب', [
                  _kv('رقم التتبع',
                      o.trackingNo.isEmpty ? 'غير مُسجّل' : o.trackingNo),
                  _kv('المندوب',
                      o.courierName.isEmpty ? 'غير مُعيَّن' : o.courierName),
                ]),
                const SizedBox(height: 10),
                _block('سجل المراحل', [
                  if (o.timeline.isEmpty)
                    Text('لا توجد مراحل مسجّلة بعد',
                        style: TextStyle(fontSize: 11, color: T.muted))
                  else
                    ...o.timeline.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.only(top: 5),
                                decoration: BoxDecoration(
                                  color: T.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${e.status.labelAr} · ${_date(e.at)}',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: T.text)),
                                    if (e.note.isNotEmpty)
                                      Text(e.note,
                                          style: TextStyle(
                                              fontSize: 10.5,
                                              height: 1.5,
                                              color: T.muted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                  if (o.proofImageUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(o.proofImageUrl,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox()),
                    ),
                  ],
                ]),
                const SizedBox(height: 14),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: T.card,
              border: Border(top: BorderSide(color: T.border)),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => shareOrderWhatsApp(o),
                        icon: const Icon(Icons.share_outlined, size: 16),
                        label: const Text('مشاركة واتساب',
                            style: TextStyle(fontSize: 11.5)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => shareOrderPdfWhatsApp(o),
                        icon: const Icon(Icons.picture_as_pdf_outlined,
                            size: 16),
                        label: const Text('PDF واتساب',
                            style: TextStyle(fontSize: 11.5)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final f = await OrderDocuments.buildShippingWaybillPdf(o);
                          await Share.shareXFiles([XFile(f.path)],
                              text: 'بوليصة الشحن ${o.orderNo}');
                        },
                        icon: const Icon(Icons.local_shipping_outlined, size: 15),
                        label: const Text('بوليصة الشحن', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final f = await OrderDocuments.buildDeliveryWaybillPdf(o);
                          await Share.shareXFiles([XFile(f.path)],
                              text: 'بوليصة التسليم ${o.orderNo}');
                        },
                        icon: const Icon(Icons.verified_outlined, size: 15),
                        label: const Text('بوليصة التسليم', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
                if (_canEdit) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => showCreateRefundDialog(o),
                      icon: const Icon(Icons.assignment_return_outlined,
                          size: 16),
                      label: const Text('إنشاء طلب استرداد',
                          style: TextStyle(fontSize: 11.5)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _editOrder(o),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('تعديل بيانات الطلب',
                              style: TextStyle(fontSize: 11.5)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _deleteOrder(o),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('حذف',
                            style: TextStyle(fontSize: 11.5)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                TextButton(onPressed: Get.back, child: const Text('إغلاق')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══ عناصر مساعدة ═══

  Widget _block(String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: T.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: T.primary)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );

  Widget _kv(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(k,
                  style: TextStyle(fontSize: 11, color: T.muted)),
            ),
            Expanded(
              child: Text(
                v.isEmpty ? '—' : v,
                style: TextStyle(
                    fontSize: bold ? 12.5 : 11.5,
                    height: 1.5,
                    fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
                    color: T.text),
              ),
            ),
          ],
        ),
      );

  Widget _item(OrderItem it) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: it.imageUrl.isEmpty
                  ? Container(
                      width: 44,
                      height: 44,
                      color: T.soft,
                      child: Icon(Icons.image_outlined,
                          size: 18, color: T.muted),
                    )
                  : Image.network(it.imageUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                            width: 44,
                            height: 44,
                            color: T.soft,
                            child: Icon(Icons.image_outlined,
                                size: 18, color: T.muted),
                          )),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: T.text)),
                  const SizedBox(height: 2),
                  Text(
                    '× ${it.qty}'
                    '${it.color.isNotEmpty ? ' · ${it.color}' : ''}'
                    '${it.size.isNotEmpty ? ' · ${it.size}' : ''}'
                    ' · ${it.lineTotalSar.toStringAsFixed(2)} ر.س',
                    style: TextStyle(fontSize: 10.5, color: T.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _receipts(Order o) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: T.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('سجل الإيصالات',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: T.primary)),
            const SizedBox(height: 8),
            if (Get.isRegistered<ReceiptService>())
              StreamBuilder<List<Receipt>>(
                stream: Get.find<ReceiptService>().forOrder(o.id),
                builder: (context, snap) {
                  final list = snap.data ?? const <Receipt>[];
                  if (list.isEmpty) {
                    return Text('لا توجد إيصالات مسجّلة',
                        style: TextStyle(fontSize: 11, color: T.muted));
                  }
                  return Column(
                    children: list
                        .map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                      r.status == 'approved'
                                          ? Icons.check_circle_outline
                                          : r.status == 'rejected'
                                              ? Icons.cancel_outlined
                                              : Icons.schedule,
                                      size: 14,
                                      color: r.status == 'approved'
                                          ? AppColors.success
                                          : T.muted),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${r.receiptNo} · ${r.amountLocal.toStringAsFixed(2)} · ${r.status == 'approved' ? 'معتمد' : r.status == 'rejected' ? 'مرفوض' : 'قيد المراجعة'}',
                                      style: TextStyle(
                                          fontSize: 10.5, color: T.text),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  );
                },
              )
            else
              Text('خدمة الإيصالات غير متاحة',
                  style: TextStyle(fontSize: 11, color: T.muted)),
          ],
        ),
      );

  // ═══ صلاحيات المدير الرئيسي ═══

  Future<void> _editOrder(Order o) async {
    final orders = Get.find<OrderService>();
    var status = o.status;
    final tracking = TextEditingController(text: o.trackingNo);
    final courier = TextEditingController(text: o.courierName);
    final paid = TextEditingController(text: o.paidTotalLocal.toStringAsFixed(2));
    final note = TextEditingController();

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('تعديل بيانات الطلب',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<OrderStatus>(
                value: status,
                isExpanded: true,
                items: OrderStatus.values
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e.labelAr,
                              style: const TextStyle(fontSize: 12)),
                        ))
                    .toList(),
                onChanged: (v) => status = v ?? status,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: tracking,
                decoration: const InputDecoration(
                    labelText: 'رقم التتبع', isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: courier,
                decoration: const InputDecoration(
                    labelText: 'المندوب', isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: paid,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'تصحيح المدفوع (بعملة العميل)', isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                    labelText: 'سبب التصحيح (يُسجَّل)', isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Get.back(result: true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final newPaid = double.tryParse(paid.text.trim());
      final ref = FirebaseFirestore.instance.collection('orders').doc(o.id);
      if (orders.isClosed) {
        throw 'خدمة الطلبات غير متاحة';
      }
      await ref.update({
        'status': status.key,
        'trackingNo': tracking.text.trim(),
        'courierName': courier.text.trim(),
        if (newPaid != null) 'paidTotalLocal': newPaid,
        if (newPaid != null) 'remainingLocal': (o.totalLocal - newPaid).clamp(0, 1e12),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await ref.collection('events').add({
        'status': status.key,
        'at': Timestamp.now(),
        'byName': 'المدير الرئيسي',
        'note': note.text.trim().isEmpty
            ? 'تصحيح بيانات الطلب'
            : note.text.trim(),
      });
      Get.back();
      Get.snackbar('تم التعديل', 'حُدّثت بيانات الطلب ${o.orderNo}');
    } catch (e) {
      Get.snackbar('تعذر التعديل', '$e');
    }
  }

  Future<void> _deleteOrder(Order o) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('حذف الطلب؟'),
        content: Text(
            'سيُحذف الطلب ${o.orderNo} وإيصالاته نهائياً. لا يمكن التراجع.',
            style: const TextStyle(fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Get.back(result: true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final db = FirebaseFirestore.instance;
      final receipts = await db
          .collection('orders')
          .doc(o.id)
          .collection('receipts')
          .get();
      for (final r in receipts.docs) {
        await r.reference.delete();
      }
      await db.collection('orders').doc(o.id).delete();
      Get.back();
      Get.snackbar('تم الحذف', 'أُزيل الطلب ${o.orderNo} وإيصالاته');
    } catch (e) {
      Get.snackbar('تعذر الحذف', '$e');
    }
  }
}

String _date(DateTime d) =>
    '${d.year}/${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// مشاركة ملخص الطلب نصياً على واتساب.
Future<void> shareOrderWhatsApp(Order o) async {
  final text = OrderDocuments.whatsappText(o);
  final phone = _waPhone(o.address.phone);
  final uri = Uri.parse(phone.isEmpty
      ? 'https://wa.me/?text=${Uri.encodeComponent(text)}'
      : 'https://wa.me/$phone?text=${Uri.encodeComponent(text)}');
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    await Share.share(text);
  }
}

/// إنشاء PDF بهوية يمن سيلو ومشاركته على واتساب.
Future<void> shareOrderPdfWhatsApp(Order o) async {
  try {
    final f = await OrderDocuments.buildPdf(o);
    await Share.shareXFiles([XFile(f.path)],
        text: 'طلب ${o.orderNo} — يمن سيلو');
    final phone = _waPhone(o.address.phone);
    if (phone.isNotEmpty) {
      final msg = 'طلبك ${o.orderNo} من يمن سيلو مرفق كملف PDF.';
      await launchUrl(
        Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}'),
        mode: LaunchMode.externalApplication,
      );
    }
  } catch (e) {
    Get.snackbar('تعذر إنشاء PDF', '$e');
  }
}

String _waPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  if (digits.startsWith('967')) return digits;
  if (digits.startsWith('0')) return '967${digits.substring(1)}';
  if (digits.length == 9) return '967$digits';
  return digits;
}
