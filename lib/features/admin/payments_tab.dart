import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/models/currency.dart';
import '../../core/models/order.dart';
import '../../core/services/order_service.dart';
import '../../core/theme/app_theme.dart';
import 'role_guard.dart';

/// مراجعة الحوالات: العميل أدخل اسم المرسل ورقم العملية ← المحاسب يؤكد أو يرفض.
class PaymentsTab extends StatelessWidget {
  const PaymentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = Get.find<OrderService>();
    return RoleGuard(
      allow: ['accounting'],
      child: StreamBuilder<List<Order>>(
        stream: allOrdersStream(status: OrderStatus.verifying),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off, size: 44, color: T.muted),
                    const SizedBox(height: 10),
                    const Text('تعذر تحميل الحوالات',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('${snap.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10.5, color: T.muted)),
                  ],
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!.where((o) => !o.payment.isEmpty).toList();
          if (list.isEmpty) {
            return Center(
              child: Text('لا توجد حوالات بانتظار المراجعة',
                  style: TextStyle(fontSize: 13, color: T.muted)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final o = list[i];
              return Card(
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
                          const Spacer(),
                          Text(formatMoney(o.totalLocal, o.currency),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryDark)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _kv('اسم المرسل', o.payment.senderName),
                      _kv('رقم العملية', o.payment.refNo),
                      _kv('الحساب المستلم', o.payment.accountNumber),
                      _kv('المبلغ المُدخل',
                          formatMoney(o.payment.amount, o.currency)),
                      if (o.payment.note.isNotEmpty) _kv('ملاحظة', o.payment.note),
                      if (o.payment.creditLocal > 0.5)
                        _kv('زيادة للعميل',
                            formatMoney(o.payment.creditLocal, o.currency)),
                      if (o.payment.proofUrl.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: o.payment.proofUrl.startsWith('data:')
                                ? Image.memory(
                                    base64Decode(o.payment.proofUrl
                                        .substring(o.payment.proofUrl.indexOf(',') + 1)),
                                    height: 140,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Text(
                                        'تعذر تحميل الصورة',
                                        style: TextStyle(
                                            fontSize: 11, color: T.muted)),
                                  )
                                : Image.network(o.payment.proofUrl,
                                    height: 140, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Text(
                                        'تعذر تحميل الصورة',
                                        style: TextStyle(
                                            fontSize: 11, color: T.muted))),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _act(orders, o, true),
                              child: const Text('تأكيد الحوالة'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                side: const BorderSide(color: AppColors.danger),
                              ),
                              onPressed: () => _act(orders, o, false),
                              child: const Text('رفض'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(k, style: TextStyle(fontSize: 11.5, color: T.muted)),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Future<void> _act(OrderService orders, Order o, bool approve) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'تأكيد الحوالة' : 'رفض الحوالة',
            style: const TextStyle(fontSize: 15)),
        content: TextField(
          controller: note,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: approve ? 'ملاحظة (اختياري)' : 'سبب الرفض',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('تنفيذ')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await orders.confirmPayment(orderId: o.id, approve: approve, note: note.text.trim());
      Get.snackbar('تم', approve ? 'تم تأكيد الحوالة وتفعيل الطلب' : 'تم رفض الحوالة');
    } catch (e) {
      Get.snackbar('تعذر التنفيذ', '$e');
    }
  }
}
