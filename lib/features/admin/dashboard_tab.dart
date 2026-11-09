import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
      allow: ['manager'],
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
                  _Kpi('إجمالي الطلبات', '${docs.length}', Icons.receipt_long, AppColors.primary),
                  _Kpi('قيمة الطلبات', formatMoney(revenue, AppCurrency.sar), Icons.payments_outlined,
                      AppColors.primaryDark),
                  _Kpi('بانتظار الحوالة', '$unpaid', Icons.schedule, const Color(0xFFB26A00)),
                  _Kpi('قيد التحقق', '$verifying', Icons.fact_check_outlined, const Color(0xFFB26A00)),
                  _Kpi('قيد التجهيز', '$processing', Icons.inventory_2_outlined, const Color(0xFF1A56DB)),
                  _Kpi('تم الشحن', '$shipped', Icons.local_shipping_outlined, const Color(0xFF6B21A8)),
                  _Kpi('تم التسليم', '$delivered', Icons.check_circle_outline, AppColors.success),
                ],
              ),
              const SizedBox(height: 16),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'الأرقام تُحسب مباشرة من مجموعة orders — أي تغيير حالة من أي موظف يظهر هنا '
                    'وفي تطبيق العميل في اللحظة نفسها (Firestore realtime).',
                    style: TextStyle(fontSize: 12, height: 1.7, color: AppColors.muted),
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

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Kpi(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EAE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ],
      ),
    );
  }
}
