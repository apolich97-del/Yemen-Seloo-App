import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/controllers/checkout_controller.dart';
import '../../../core/models/currency.dart';
import '../../../core/theme/app_theme.dart';

/// المرحلة 1 — «ملخص الطلب / إكمال الطلب»
class CheckoutScreen extends GetView<CheckoutController> {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ملخص الطلب'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 18),
          onPressed: Get.back,
        ),
      ),
      body: Obx(() {
        if (controller.lines.isEmpty) {
          return const Center(child: Text('السلة فارغة'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _addressCard(context),
            const SizedBox(height: 12),
            _orderDetailsCard(context),
            const SizedBox(height: 12),
            _currencyCard(context),
            const SizedBox(height: 12),
            _summaryCard(context),
            const SizedBox(height: 12),
            _couponCard(context),
            const SizedBox(height: 90),
          ].map((w) => w).toList(),
        );
      }),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Obx(() {
            final est = controller.estimate.value;
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('الإجمالي النهائي',
                          style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      Text(
                        est == null
                            ? '—'
                            : formatMoney(est.totalLocal, est.currency),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: controller.busy.value
                        ? null
                        : controller.continueToPayment,
                    child: const Text('متابعة الدفع'),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _addressCard(BuildContext context) {
    return SectionCard(
      title: 'عنوان التوصيل',
      trailing: TextButton.icon(
        onPressed: controller.editAddress,
        icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
        label: const Text('تعديل'),
      ),
      child: Obx(() {
        if (controller.loadingAddress.value) {
          return const LinearProgressIndicator(minHeight: 2);
        }
        final a = controller.address.value;
        if (a == null) {
          return Row(
            children: [
              const Icon(Icons.location_off_outlined, color: AppColors.danger),
              const SizedBox(width: 8),
              const Expanded(child: Text('لم تُضف عنواناً بعد — اضغط «تعديل» لإضافة عنوان')),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(a.label,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 6),
            Text(a.fullAr, style: const TextStyle(fontSize: 13, height: 1.6)),
            const SizedBox(height: 4),
            Text('${a.receiverName} · ${a.phone}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        );
      }),
    );
  }

  Widget _orderDetailsCard(BuildContext context) {
    return SectionCard(
      title: 'تفاصيل الطلب',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: controller.thumbnails.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  controller.thumbnails[i],
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 64,
                    height: 64,
                    color: const Color(0xFFEDF1EF),
                    child: const Icon(Icons.image_not_supported_outlined,
                        color: AppColors.muted),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.muted),
              const SizedBox(width: 6),
              Text('عدد القطع: ${controller.pieces}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              const Icon(Icons.schedule, size: 18, color: AppColors.muted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  controller.expectedDeliveryAr,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _currencyCard(BuildContext context) {
    return SectionCard(
      title: 'عملة الدفع',
      child: Obx(() => Wrap(
            spacing: 8,
            children: AppCurrency.values.map((c) {
              final active = controller.currency.value == c;
              return ChoiceChip(
                label: Text(c.labelAr),
                selected: active,
                selectedColor: AppColors.primary.withOpacity(.12),
                labelStyle: TextStyle(
                  color: active ? AppColors.primaryDark : AppColors.ink,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
                onSelected: (_) => controller.setCurrency(c),
              );
            }).toList(),
          )),
    );
  }

  Widget _summaryCard(BuildContext context) {
    return SectionCard(
      title: 'الملخص المالي',
      child: Obx(() {
        final e = controller.estimate.value;
        if (e == null) return const SizedBox.shrink();
        final c = e.currency;
        return Column(
          children: [
            MoneyRow(
              label: 'إجمالي المبلغ الأساسي',
              value: formatMoney(e.localOf(e.subtotalSar), c),
            ),
            MoneyRow(
              label: 'رسوم الشحن',
              value: e.shippingIsFree ? 'مجاني' : formatMoney(e.localOf(e.shippingFeeSar), c),
              free: e.shippingIsFree,
            ),
            MoneyRow(
              label: 'رسوم التوصيل',
              value: formatMoney(e.deliveryLocal, c),
            ),
            if (e.discountSar > 0)
              MoneyRow(
                label: 'الخصم (${e.couponCode})',
                value: '- ${formatMoney(e.localOf(e.discountSar), c)}',
                free: true,
              ),
            const Divider(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('الإجمالي النهائي',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text(
                    formatMoney(e.totalLocal, c),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
            if (c != AppCurrency.sar)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'سعر الصرف: 1 ر.س = ${e.rate.toStringAsFixed(0)} ${c.shortAr}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _couponCard(BuildContext context) {
    return SectionCard(
      title: 'كود الخصم',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.couponCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'أدخل كود القسيمة'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 96,
                height: 48,
                child: OutlinedButton(
                  onPressed: controller.busy.value ? null : controller.applyCoupon,
                  child: const Text('تطبيق'),
                ),
              ),
            ],
          ),
          Obx(() {
            if (controller.couponMessage.value.isEmpty) return const SizedBox.shrink();
            final ok = controller.couponAccepted.value;
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(ok ? Icons.check_circle : Icons.error_outline,
                      size: 16, color: ok ? AppColors.success : AppColors.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      controller.couponMessage.value,
                      style: TextStyle(
                        fontSize: 12,
                        color: ok ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ),
                  if (ok)
                    TextButton(
                      onPressed: controller.removeCoupon,
                      child: const Text('إزالة', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
