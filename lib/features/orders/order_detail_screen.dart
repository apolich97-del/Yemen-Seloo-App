import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/models/currency.dart';
import '../../core/models/order.dart';
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
      appBar: AppBar(title: const Text('تفاصيل الطلب')),
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
              _header(o),
              const SizedBox(height: 12),
              _timeline(o),
              const SizedBox(height: 12),
              _items(o),
              const SizedBox(height: 12),
              _payment(o),
              if (o.proofImageUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                _proof(o),
              ],
              const SizedBox(height: 12),
              _totals(o),
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
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            if (o.trackingNo.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('رقم التتبع: ${o.trackingNo}${o.courierName.isEmpty ? '' : ' · ${o.courierName}'}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 6),
            Text(o.address.fullAr,
                style: const TextStyle(fontSize: 12, height: 1.6, color: AppColors.muted)),
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
                      color: done ? AppColors.primary : Colors.white,
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
                        color: done ? AppColors.ink : AppColors.muted,
                      ),
                    ),
                    if (at != null)
                      Text(
                        '${at.day}/${at.month} · ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
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
                        child: const Icon(Icons.image_outlined, size: 18, color: AppColors.muted),
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
                            style: const TextStyle(fontSize: 11, color: AppColors.muted),
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

  Widget _payment(Order o) {
    final p = o.payment;
    if (p.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'بيانات الحوالة',
      child: Column(
        children: [
          MoneyRow(label: 'اسم المرسل', value: p.senderName),
          MoneyRow(label: 'رقم العملية', value: p.refNo),
          MoneyRow(label: 'الحساب المستلم', value: p.accountNumber),
          MoneyRow(
            label: 'حالة التأكيد',
            value: p.confirmedAt == null ? 'بانتظار مراجعة المحاسبة' : 'مؤكدة',
            free: p.confirmedAt != null,
          ),
        ],
      ),
    );
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
