import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/models/currency.dart';
import '../../core/models/order.dart';
import '../../core/services/order_service.dart';
import '../../core/theme/app_theme.dart';
import 'role_guard.dart';

/// إدارة الطلبات: تغيير الحالة + رقم التتبع + تعيين المندوب.
class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  OrderStatus? _filter;
  final _orders = Get.find<OrderService>();

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allow: ['support', 'shipping', 'courier'],
      child: Column(
        children: [
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
                final list = snap.data!;
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
        selectedColor: AppColors.primary.withValues(alpha: .12),
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
                  Text(o.orderNo,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Color(o.status.colorValue).withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(o.status.labelAr,
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(o.status.colorValue))),
                  ),
                  const Spacer(),
                  Text(formatMoney(o.totalLocal, o.currency),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${o.address.city} · ${o.address.receiverName} · ${o.address.phone} · ${o.totalPieces} قطعة',
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
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
            if (to == OrderStatus.outForDelivery)
              TextField(
                controller: courier,
                decoration: const InputDecoration(labelText: 'اسم المندوب'),
              ),
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
