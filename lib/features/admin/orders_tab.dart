import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/models/currency.dart';
import '../../core/models/order.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/order_service.dart';
import '../../core/theme/app_theme.dart';
import 'order_preview_sheet.dart';
import '../orders/order_detail_screen.dart';
import 'role_guard.dart';

/// إدارة الطلبات: تغيير الحالة + رقم التتبع + تعيين المندوب.
class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  OrderStatus? _filter;
  String _query = '';
  final _orders = Get.find<OrderService>();

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allow: ['support', 'shipping', 'courier', 'accounting', 'marketer'],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'ابحث برقم الطلب أو الهاتف',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _chip('الكل', null),
                ...OrderStatus.values.map((s) => _chip(s.labelAr, s)),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Order>>(
              stream: allOrdersStream(status: _filter),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var list = snap.data!;
                if (_query.isNotEmpty) {
                  final q = _query.toLowerCase();
                  list = list
                      .where((o) =>
                          o.orderNo.toLowerCase().contains(q) ||
                          o.address.phone.contains(q) ||
                          o.address.receiverName.contains(q))
                      .toList();
                }
                if (list.isEmpty) {
                  return const Center(child: Text('لا توجد طلبات'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _row(list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, OrderStatus? s) {
    final active = _filter == s;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        selectedColor: AppColors.primary.withOpacity(.12),
        onSelected: (_) => setState(() => _filter = s),
      ),
    );
  }

  Widget _row(Order o) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Get.to(() => const OrderDetailScreen(), arguments: o.id),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              o.orderNo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: T.text),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.open_in_new, size: 13, color: T.primary),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'معاينة الطلب كاملة',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.visibility_outlined, size: 17, color: T.primary),
                    onPressed: () => showOrderPreview(o),
                  ),
                  IconButton(
                    tooltip: 'تعديل سريع',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    onPressed: () => _openEditor(o),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Color(o.status.colorValue).withOpacity(.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(o.status.labelAr,
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(o.status.colorValue))),
                  ),
                  if (o.isDeferred) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.accent),
                      ),
                      child: Text('آجل 50%',
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: T.dark ? T.accent : const Color(0xFF7A5E00))),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    formatMoney(o.totalLocal, o.currency),
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        color: T.primary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${o.address.city} · ${o.address.receiverName} · ${o.address.phone} · ${o.totalPieces} قطعة',
                style: TextStyle(fontSize: 11.5, color: T.muted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateStatus(o),
                      child: const Text('تحديث الحالة', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _assignCourier(o),
                      child: const Text('تعيين مندوب', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Future<void> _updateStatus(Order o) async {
    final next = o.status.nextStatuses;
    if (next.isEmpty) {
      Get.snackbar('لا انتقال متاح', 'حالة الطلب نهائية: ${o.status.labelAr}');
      return;
    }
    final to = await showDialog<OrderStatus>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('الحالة الجديدة', style: TextStyle(fontSize: 15)),
        children: next
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, s),
                  child: Text(s.labelAr),
                ))
            .toList(),
      ),
    );
    if (to == null) return;
    final tracking = TextEditingController(text: o.trackingNo);
    final courier = TextEditingController(text: o.courierName);
    final proof = TextEditingController(text: o.proofImageUrl);
    final courierPhone = TextEditingController();
    final collected = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('تأكيد: ${to.labelAr}', style: const TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (to == OrderStatus.shipped) ...[
              TextField(
                controller: tracking,
                decoration: const InputDecoration(labelText: 'رقم التتبع'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: courier,
                decoration: const InputDecoration(labelText: 'شركة الشحن'),
              ),
            ],
            if (to == OrderStatus.outForDelivery) ...[
              TextField(
                controller: courier,
                decoration: const InputDecoration(labelText: 'اسم المندوب'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: courierPhone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration:
                    const InputDecoration(labelText: 'رقم جوال المندوب'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: collected,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'مبلغ التحصيل (بالعملة المحلية)'),
              ),
            ],
            if (to == OrderStatus.delivered)
              TextField(
                controller: proof,
                decoration: const InputDecoration(labelText: 'رابط صورة إثبات التسليم'),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _orders.advanceStatus(
        orderId: o.id,
        to: to,
        trackingNo: tracking.text.trim(),
        courierName: courier.text.trim(),
        proofUrl: proof.text.trim(),
        courierPhone: courierPhone.text.trim(),
        collectedLocal: double.tryParse(collected.text.trim()),
      );
      Get.snackbar('تم التحديث', 'الطلب الآن: ${to.labelAr} — أُرسل إشعار للعميل');
    } catch (e) {
      Get.snackbar('تعذر التحديث', '$e');
    }
  }

  Future<void> _assignCourier(Order o) async {
    final ctrl = TextEditingController(text: o.courierName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعيين مندوب', style: TextStyle(fontSize: 15)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'اسم/رقم المندوب'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true) return;
    // تعيين المندوب لا يغيّر الحالة — يُسجَّل في الحقل courierName.
    try {
      await _orders.advanceStatus(
        orderId: o.id,
        to: o.status,
        note: 'تعيين مندوب',
        courierName: ctrl.text.trim(),
      );
      Get.snackbar('تم', 'تم تعيين المندوب');
    } catch (e) {
      Get.snackbar('تعذر الحفظ', '$e');
    }
  }
}


/// محرّر الطلب للموظف: الحالة، التتبع، المندوب، وملاحظة تُسجَّل في سجل الطلب.
extension _StaffOrderEditor on _OrdersTabState {
  Future<void> _openEditor(Order o) async {
    final orders = Get.find<OrderService>();
    var status = o.status;
    final tracking = TextEditingController(text: o.trackingNo);
    final courier = TextEditingController(text: o.courierName);
    final note = TextEditingController();

    await Get.dialog(
      AlertDialog(
        title: Text('الطلب ${o.orderNo}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${o.address.receiverName} · ${o.address.phone}\n'
                  '${o.address.fullAr}',
                  style: TextStyle(fontSize: 11, height: 1.5, color: T.text)),
              const SizedBox(height: 6),
              Text(
                  '${o.items.length} منتج · إجمالي ${o.totalSar.toStringAsFixed(2)} ر.س · '
                  'مدفوع ${o.paidTotalLocal.toStringAsFixed(2)} · متبقٍ ${o.remainingLocal.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 11, color: T.muted)),
              const Divider(height: 16),
              // معاينة المنتجات كاملة
              ...o.items.map((it) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: T.muted)),
                        Expanded(
                          child: Text(
                            '${it.title.length > 60 ? '${it.title.substring(0, 60)}…' : it.title}'
                            ' × ${it.qty}'
                            '${it.color.isNotEmpty ? ' · ${it.color}' : ''}'
                            '${it.size.isNotEmpty ? ' · ${it.size}' : ''}',
                            style: TextStyle(fontSize: 10.5, height: 1.5, color: T.text),
                          ),
                        ),
                      ],
                    ),
                  )),
              const Divider(height: 16),
              const Divider(height: 18),
              const Text('الحالة',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
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
                    labelText: 'اسم المندوب', isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                    labelText: 'ملاحظة داخلية (تُسجَّل في سجل الطلب)',
                    isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          if (Get.find<AuthService>().role == 'manager')
            TextButton(
              onPressed: () async {
                final ok = await Get.dialog<bool>(
                  AlertDialog(
                    title: const Text('حذف الطلب؟'),
                    content: Text('سيُحذف الطلب ${o.orderNo} نهائياً. لا يمكن التراجع.',
                        style: const TextStyle(fontSize: 12)),
                    actions: [
                      TextButton(
                          onPressed: () => Get.back(result: false),
                          child: const Text('إلغاء')),
                      ElevatedButton(
                          onPressed: () => Get.back(result: true),
                          child: const Text('حذف')),
                    ],
                  ),
                );
                if (ok != true) return;
                try {
                  await FirebaseFirestore.instance
                      .collection('orders')
                      .doc(o.id)
                      .delete();
                  Get.back();
                  Get.snackbar('تم الحذف', 'أُزيل الطلب ${o.orderNo}');
                } catch (e) {
                  Get.snackbar('تعذر الحذف', '$e');
                }
              },
              child: const Text('حذف الطلب',
                  style: TextStyle(color: AppColors.danger)),
            ),
          TextButton(onPressed: Get.back, child: const Text('إغلاق')),
          ElevatedButton(
            onPressed: () async {
              try {
                await orders.advanceStatus(
                  orderId: o.id,
                  to: status,
                  note: note.text.trim(),
                  trackingNo: tracking.text.trim(),
                  courierName: courier.text.trim(),
                );
                Get.back();
                Get.snackbar('تم التحديث', 'حُفظت حالة الطلب ${o.orderNo}');
              } catch (e) {
                Get.snackbar('تعذر الحفظ', '$e');
              }
            },
            child: const Text('حفظ التعديل'),
          ),
        ],
      ),
    );
  }
}
