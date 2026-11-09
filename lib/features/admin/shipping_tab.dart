import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/models/currency.dart';
import '../../core/models/order.dart';
import '../../core/services/order_service.dart';
import '../../core/theme/app_theme.dart';
import 'role_guard.dart';

/// الشحن: الطلبات الجاهزة للشحن + تعيين المندوب + إثبات التسليم.
class ShippingTab extends StatelessWidget {
  const ShippingTab({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = Get.find<OrderService>();
    return RoleGuard(
      allow: ['shipping', 'courier'],
      child: StreamBuilder<List<Order>>(
        stream: allOrdersStream(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!
              .where((o) =>
                  o.status == OrderStatus.processing ||
                  o.status == OrderStatus.shipped ||
                  o.status == OrderStatus.outForDelivery)
              .toList();
          if (list.isEmpty) {
            return const Center(
              child: Text('لا توجد شحنات نشطة',
                  style: TextStyle(fontSize: 13, color: AppColors.muted)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final o = list[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Row(
                    children: [
                      Text(o.orderNo,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      Text(o.status.labelAr,
                          style: TextStyle(fontSize: 11, color: Color(o.status.colorValue))),
                    ],
                  ),
                  subtitle: Text(
                    '${o.address.city} · ${o.address.receiverName}\n'
                    '${o.courierName.isEmpty ? 'بلا مندوب' : o.courierName}'
                    '${o.trackingNo.isEmpty ? '' : ' · تتبع ${o.trackingNo}'}'
                    ' · ${formatMoney(o.totalLocal, o.currency)}',
                    style: const TextStyle(fontSize: 11.5, height: 1.6, color: AppColors.muted),
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 14),
                    onPressed: () => _advance(orders, o),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _advance(OrderService orders, Order o) async {
    final next = o.status.nextStatuses.where((s) => s != OrderStatus.cancelled).toList();
    if (next.isEmpty) return;
    final to = await showDialog<OrderStatus>(
      context: Get.context!,
      builder: (context) => SimpleDialog(
        title: const Text('الإجراء', style: TextStyle(fontSize: 15)),
        children: next
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(Get.context!, s),
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
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: Text(to.labelAr, style: const TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (to == OrderStatus.shipped) ...[
              TextField(
                  controller: tracking,
                  decoration: const InputDecoration(labelText: 'رقم التتبع')),
              const SizedBox(height: 8),
              TextField(
                  controller: courier,
                  decoration: const InputDecoration(labelText: 'شركة الشحن')),
            ],
            if (to == OrderStatus.outForDelivery)
              TextField(
                  controller: courier,
                  decoration: const InputDecoration(labelText: 'اسم المندوب')),
            if (to == OrderStatus.delivered)
              TextField(
                  controller: proof,
                  decoration: const InputDecoration(labelText: 'رابط صورة الإثبات')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(Get.context!, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(Get.context!, true), child: const Text('تنفيذ')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await orders.advanceStatus(
        orderId: o.id,
        to: to,
        trackingNo: tracking.text.trim(),
        courierName: courier.text.trim(),
        proofUrl: proof.text.trim(),
      );
      Get.snackbar('تم', 'تم تحديث الحالة إلى ${to.labelAr}');
    } catch (e) {
      Get.snackbar('تعذر التحديث', '$e');
    }
  }
}
