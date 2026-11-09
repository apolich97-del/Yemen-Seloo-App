import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/orders_controller.dart';
import '../../core/models/currency.dart';
import '../../core/models/order.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/app_theme.dart';

/// المرحلة 3 — «طلباتي»: شريط الحالات + بطاقات الطلبات.
class MyOrdersScreen extends GetView<OrdersController> {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsService>();
    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: Obx(() => ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: kOrderTabs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final s = kOrderTabs[i];
                    final active = controller.selectedTab.value?.key == s?.key;
                    return ChoiceChip(
                      label: Text(s == null ? 'الكل' : s.labelAr),
                      selected: active,
                      selectedColor: AppColors.primary.withValues(alpha: .12),
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        color: active ? AppColors.primaryDark : AppColors.ink,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (_) => controller.selectTab(s),
                    );
                  },
                )),
          ),
          Expanded(
            child: Obx(() {
              if (controller.loading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.error.value.isNotEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(controller.error.value,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ),
                );
              }
              if (controller.orders.isEmpty) return _empty();
              return RefreshIndicator(
                onRefresh: () async => controller.selectTab(controller.selectedTab.value),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: controller.orders.length,
                  itemBuilder: (_, i) =>
                      _orderCard(controller.orders[i], settings),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('لا توجد طلبات في هذا التبويب',
                style: TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Get.toNamed('/cart'), child: const Text('ابدأ التسوق')),
          ],
        ),
      );

  Widget _orderCard(Order o, SettingsService settings) {
    final statusColor = Color(o.status.colorValue);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => controller.open(o),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(o.orderNo,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        o.status.labelAr,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${o.createdAt.day}/${o.createdAt.month}/${o.createdAt.year} · ${o.totalPieces} قطعة',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ...o.thumbnails.take(3).map((u) => Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(u, width: 44, height: 44, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                      width: 44,
                                      height: 44,
                                      color: const Color(0xFFEDF1EF),
                                    )),
                          ),
                        )),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatMoney(o.totalLocal, o.currency),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryDark),
                        ),
                        if (o.currency != AppCurrency.sar)
                          Text(
                            '≈ ${formatMoney(o.totalSar, AppCurrency.sar)}',
                            style: const TextStyle(fontSize: 10, color: AppColors.muted),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => controller.open(o),
                        child: const Text('تفاصيل الطلب'),
                      ),
                    ),
                    if (!o.status.isTerminal &&
                        (o.status == OrderStatus.processing ||
                            o.status == OrderStatus.shipped ||
                            o.status == OrderStatus.verifying)) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: o.expediteRequestedAt != null
                              ? null
                              : () => controller.requestExpedite(o),
                          icon: const Icon(Icons.bolt, size: 16),
                          label: Text(o.expediteRequestedAt != null ? 'طُلب التسريع' : 'تسريع الشحن',
                              style: const TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
