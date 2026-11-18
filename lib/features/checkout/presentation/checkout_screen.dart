import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/controllers/checkout_controller.dart';
import '../../../core/models/currency.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/cart_share.dart';
import '../../guide/interactive_guide.dart';
import '../../../core/services/order_documents.dart';
import '../../../core/services/settings_service.dart';
import '../../cart/presentation/cart_share_card.dart';
import '../../../core/theme/app_theme.dart';

/// المرحلة 1 — «ملخص الطلب / إكمال الطلب»
class CheckoutScreen extends GetView<CheckoutController> {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', height: 26),
            const SizedBox(width: 8),
            const Text('ملخص الطلب'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 18),
          onPressed: Get.back,
        ),
        actions: [
          IconButton(
            tooltip: 'ملخص PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () async {
              if (controller.lines.isEmpty) return;
              try {
                final f = await CartPdf.build(
                  lines: controller.lines,
                  addressAr: controller.address.value?.fullAr ?? '',
                  totalLabel:
                      'الإجمالي: ${formatMoney(controller.estimate.value?.totalLocal ?? 0, controller.currency.value)}',
                  currencyNote: controller.currency.value.key,
                );
                await Share.shareXFiles([XFile(f.path)],
                    text: 'ملخص السلة — يمن سيلو');
              } catch (e) {
                Get.snackbar('تعذر إنشاء PDF', '$e');
              }
            },
          ),
        ],
      ),
      body: Obx(() {
        if (controller.lines.isEmpty) {
          return const Center(child: Text('السلة فارغة'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _brandStrip(),
            const SizedBox(height: 12),
            _addressCard(context),
            const SizedBox(height: 12),
            _orderDetailsCard(context),
            const SizedBox(height: 12),
            _currencyCard(context),
            const SizedBox(height: 12),
            _planCard(context),
            const SizedBox(height: 12),
            _summaryCard(context),
            const SizedBox(height: 12),
            Obx(() => CartShareCard(
                  url: controller.lines.isEmpty
                      ? ''
                      : CartShare.buildFromLines(controller.lines),
                )),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('متابعة الدفع',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  /// شريط هوية يمن سيلو أعلى الملخص.
  Widget _brandStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset('assets/images/logo.png', height: 30),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('يمن سيلو',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
                SizedBox(height: 2),
                Text('وسيطك الموثوق للتسوق العالمي',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5)),
              ],
            ),
          ),
          const Icon(Icons.verified_user_outlined, color: Colors.white70, size: 18),
        ],
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

  /// اختيار خطة السداد: كاش أو طلب آجل 50%.
  /// إرشاد مرة واحدة لبطاقة الطلب الآجل.
  void _guideDeferred() {
    if (!Get.isRegistered<InteractiveGuideController>()) return;
    Get.find<InteractiveGuideController>().showIfFirst(
      'action_deferred',
      title: 'الطلب الآجل 50%',
      body: 'إن بلغت قيمة المنتجات الحد الأدنى، يمكنك دفع النصف الآن والنصف عند الاستلام.',
      steps: <String>[
        'اختر «طلب آجل — السداد بالنصف».',
        'حوّل الدفعة الأولى فقط من شاشة الدفع.',
        'تابع المتبقي في بطاقة الرصيد داخل تفاصيل الطلب.',
      ],
    );
  }

  Widget _planCard(BuildContext context) {
    if (!Get.isRegistered<SettingsService>()) return const SizedBox.shrink();
    final sf = Get.find<SettingsService>().settings.value;
    return Obx(() {
      final est = controller.estimate.value;
      if (est == null) return const SizedBox.shrink();
      final eligible = sf.deferredEnabled &&
          est.subtotalSar >= sf.deferredThresholdSar;
      final pct = sf.deferredUpfrontPercent.toStringAsFixed(0);
      final upfront = roundMoney(est.totalLocal * (sf.deferredUpfrontPercent / 100),
          est.currency);

      Widget option({
        required String value,
        required String title,
        required String subtitle,
        required bool enabled,
      }) {
        final selected = controller.paymentPlan.value == value;
        return GestureDetector(
          onTap: enabled
              ? () {
                  controller.paymentPlan.value = value;
                  if (value == 'half_deferred') _guideDeferred();
                }
              : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withOpacity(.08) : T.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? AppColors.primary : T.border,
                  width: selected ? 1.6 : 1),
            ),
            child: Row(
              children: [
                Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 18,
                    color: enabled
                        ? (selected ? AppColors.primary : AppColors.muted)
                        : const Color(0xFFCFC7E0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: enabled
                                  ? AppColors.ink
                                  : const Color(0xFFA9A2BC))),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }

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
            const Text('طريقة السداد',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark)),
            const SizedBox(height: 10),
            option(
              value: 'full',
              title: 'دفع كامل (كاش 100%)',
              subtitle: 'تحويل ${formatMoney(est.totalLocal, est.currency)} الآن',
              enabled: true,
            ),
            option(
              value: 'half_deferred',
              title: 'طلب آجل — السداد بالنصف $pct%',
              subtitle: eligible
                  ? 'المطلوب الآن ${formatMoney(upfront, est.currency)} · '
                      'المتبقي ${formatMoney(est.totalLocal - upfront, est.currency)}'
                  : 'غير متاح: قيمة السلة أقل من الحد الأدنى '
                      '${formatMoney(sf.deferredThresholdSar * (est.currency == AppCurrency.sar ? 1 : est.rate), est.currency)}',
              enabled: eligible,
            ),
          ],
        ),
      );
    });
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
              label: 'رسوم الخدمة',
              value: formatMoney(e.localOf(e.serviceFeeSar), c),
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
