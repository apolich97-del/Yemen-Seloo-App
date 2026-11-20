import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'admin_shell.dart';

import '../../core/models/currency.dart';
import '../../core/models/order.dart';
import '../../core/theme/app_theme.dart';
import 'role_guard.dart';

/// إحصائيات لحظية مباشرة من Firestore (تُحدَّث تلقائياً).
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('orders');
    return RoleGuard(
      allow: ['manager', 'marketer'],
      child: StreamBuilder<QuerySnapshot>(
        stream: col.snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? const [];
          double revenue = 0;
          var unpaid = 0, verifying = 0, processing = 0, shipped = 0, delivered = 0;
          for (final d in docs) {
            final o = Order.fromDoc(d.id, d.data() as Map<String, dynamic>);
            revenue += o.totalSar;
            switch (o.status) {
              case OrderStatus.unpaid:
                unpaid++;
              case OrderStatus.verifying:
                verifying++;
              case OrderStatus.processing:
                processing++;
              case OrderStatus.shipped:
              case OrderStatus.outForDelivery:
                shipped++;
              case OrderStatus.delivered:
                delivered++;
              case OrderStatus.cancelled:
                break;
            }
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Kpi('إجمالي الطلبات', '${docs.length}', Icons.receipt_long, AppColors.primary,
                      onTap: () => adminGo('الطلبات')),
                  _Kpi('قيمة الطلبات', formatMoney(revenue, AppCurrency.sar), Icons.payments_outlined,
                      AppColors.primaryDark),
                  _Kpi('بانتظار الحوالة', '$unpaid', Icons.schedule, const Color(0xFFB26A00)),
                  _Kpi('قيد التحقق', '$verifying', Icons.fact_check_outlined, const Color(0xFFB26A00),
                      onTap: () => adminGo('المدفوعات')),
                  _Kpi('قيد التجهيز', '$processing', Icons.inventory_2_outlined, const Color(0xFF1A56DB)),
                  _Kpi('تم الشحن', '$shipped', Icons.local_shipping_outlined, const Color(0xFF6B21A8),
                      onTap: () => adminGo('الشحن')),
                  _Kpi('تم التسليم', '$delivered', Icons.check_circle_outline, AppColors.success),
                ],
              ),
              const SizedBox(height: 16),
              _salesReport(docs),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'الأرقام تُحسب مباشرة من مجموعة orders — أي تغيير حالة من أي موظف يظهر هنا '
                    'وفي تطبيق العميل في اللحظة نفسها (Firestore realtime).',
                    style: TextStyle(fontSize: 12, height: 1.7, color: T.muted),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// تقرير مبيعات: اليوم / الأسبوع / الشهر + المحصّل والمتبقي الآجل.
Widget _salesReport(List<QueryDocumentSnapshot> docs) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekAgo = today.subtract(const Duration(days: 7));
  final monthAgo = DateTime(now.year, now.month, 1);

  double sumSar(Iterable<Order> list) => list.fold(0.0, (a, o) => a + o.totalSar);
  double collected(Iterable<Order> list) => list.fold(
      0.0,
      (a, o) =>
          a + (o.exchangeRate == 0 ? 0 : o.paidTotalLocal / o.exchangeRate));
  double outstanding(Iterable<Order> list) => list.fold(
      0.0,
      (a, o) =>
          a + (o.exchangeRate == 0 ? 0 : o.remainingLocal / o.exchangeRate));

  final orders = docs
      .map((d) => Order.fromDoc(d.id, d.data() as Map<String, dynamic>))
      .where((o) => o.status != OrderStatus.cancelled)
      .toList();

  final todayOrders =
      orders.where((o) => !o.createdAt.isBefore(today)).toList();
  final weekOrders = orders.where((o) => !o.createdAt.isBefore(weekAgo)).toList();
  final monthOrders =
      orders.where((o) => !o.createdAt.isBefore(monthAgo)).toList();

  Widget row(String label, int count, double sales) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
                width: 70,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800))),
            Text('$count طلب',
                style: TextStyle(fontSize: 11.5, color: T.muted)),
            const Spacer(),
            Text(formatMoney(sales, AppCurrency.sar),
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w900)),
          ],
        ),
      );

  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: T.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: T.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('تقرير المبيعات',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark)),
        const SizedBox(height: 6),
        row('اليوم', todayOrders.length, sumSar(todayOrders)),
        row('الأسبوع', weekOrders.length, sumSar(weekOrders)),
        row('الشهر', monthOrders.length, sumSar(monthOrders)),
        const Divider(height: 18),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('المحصّل المؤكد',
                      style: TextStyle(fontSize: 10.5, color: T.muted)),
                  Text(formatMoney(collected(orders), AppCurrency.sar),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.success)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('متبقٍ على العملاء (آجل)',
                      style: TextStyle(fontSize: 10.5, color: T.muted)),
                  Text(formatMoney(outstanding(orders), AppCurrency.sar),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.danger)),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// ينتقل إلى تبويب داخل لوحة الإدارة بالاسم.
void adminGo(String label) {
  if (!Get.isRegistered<AdminNav>()) return;
  const order = [
    'لوحة المعلومات',
    'الطلبات',
    'المدفوعات',
    'إيصال',
    'دعم العملاء',
    'الشحن',
    'الإعدادات',
  ];
  if (order.contains(label)) Get.find<AdminNav>().goTo(label);
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _Kpi(this.label, this.value, this.icon, this.color, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11.5, color: T.muted)),
        ],
      ),
      ),
    );
  }
}
