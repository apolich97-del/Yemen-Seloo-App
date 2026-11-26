import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/controllers/checkout_controller.dart';
import '../../../core/models/currency.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/cart_share.dart';
import '../../guide/interactive_guide.dart';
import '../../../core/services/order_documents.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/settings_service.dart';
import '../../cart/presentation/cart_share_card.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/wallet_service.dart';

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
            const SizedBox(height: 10),
            _alertsBanner(context),
            _addressCard(context),
            const SizedBox(height: 12),
            _shippingCard(context),
            const SizedBox(height: 12),
            _orderDetailsCard(context),
            const SizedBox(height: 12),
            _currencyCard(context),
            const SizedBox(height: 12),
            _planCard(context),
            const SizedBox(height: 12),
            _walletCard(context),
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
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: T.primary),
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

  Widget _alertsBanner(BuildContext context) {
    if (!Get.isRegistered<NotificationService>()) return const SizedBox.shrink();
    final ns = Get.find<NotificationService>();
    return Obx(() {
      final list = ns.checkoutAlerts;
      if (list.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          children: list.map((a) {
            final c = a.severity == 'urgent'
                ? T.danger
                : (a.severity == 'info' ? T.info : T.warning);
            final acked = controller.acknowledgedAlertIds.contains(a.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.withOpacity(.11),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.withOpacity(.48)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        a.severity == 'urgent'
                            ? Icons.error_outline
                            : Icons.campaign_outlined,
                        size: 18,
                        color: c,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(a.title,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: T.text)),
                      ),
                      if (a.createdByRole.isNotEmpty)
                        Text(a.createdByRole,
                            style: TextStyle(fontSize: 10, color: T.muted)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(a.message,
                      style: TextStyle(fontSize: 11.5, height: 1.5, color: T.text)),
                  if (a.requiresAck) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => controller.toggleAlertAck(a.id),
                      child: Row(
                        children: [
                          Checkbox(
                            value: acked,
                            onChanged: (_) => controller.toggleAlertAck(a.id),
                            visualDensity: VisualDensity.compact,
                            activeColor: c,
                          ),
                          Expanded(
                            child: Text('قرأت التنبيه وأوافق على المتابعة',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: T.text)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      );
    });
  }

  void _pickSavedAddress(BuildContext context) {
    final list = controller.savedAddresses;
    Get.bottomSheet(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: T.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('اختر عنوان التوصيل',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: T.text)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Get.back();
                      controller.editAddress();
                    },
                    icon: const Icon(Icons.add, size: 17),
                    label: const Text('جديد / تعديل'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                Text('لا توجد عناوين محفوظة بعد', style: TextStyle(fontSize: 12, color: T.muted))
              else
                ...list.map((a) {
                  final on = controller.address.value?.id == a.id;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(on ? Icons.radio_button_checked : Icons.location_on_outlined,
                        color: on ? T.primary : T.muted),
                    title: Text('${a.label} — ${a.city}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: T.text)),
                    subtitle: Text('${a.fullAr} · ${a.phone}',
                        style: TextStyle(fontSize: 11, color: T.muted)),
                    onTap: () {
                      controller.selectAddress(a);
                      Get.back();
                    },
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addressCard(BuildContext context) {
    return SectionCard(
      title: 'عنوان التوصيل',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.savedAddresses.length > 1)
            TextButton(
              onPressed: () => _pickSavedAddress(context),
              child: const Text('تغيير'),
            ),
          TextButton.icon(
            onPressed: controller.editAddress,
            icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
            label: const Text('تعديل'),
          ),
        ],
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

  Widget _shippingCard(BuildContext context) {
    final c = controller;
    Widget opt(String key, String title, IconData icon) => Obx(() {
          final on = c.shippingMode.value == key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => c.shippingMode.value = key,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: on ? T.primary.withOpacity(.08) : T.soft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: on ? T.primary : T.border,
                      width: on ? 1.4 : 1),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 17, color: on ? T.primary : T.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: on ? T.primary : T.text)),
                    ),
                    Icon(on ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 16, color: on ? T.primary : T.muted),
                  ],
                ),
              ),
            ),
          );
        });

    Widget textField(TextEditingController ctrl, String label) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
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
          Row(children: [
            Icon(Icons.local_shipping_outlined, size: 18, color: T.primary),
            const SizedBox(width: 8),
            Text('طريقة التوصيل',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: T.text)),
          ]),
          const SizedBox(height: 10),
          opt('home', 'توصيل محلي للمنزل (داخل المدينة)', Icons.home_outlined),
          opt('governorate', 'شحن للمحافظات عبر مكتب نقل', Icons.warehouse_outlined),
          opt('driver', 'سائق خاص بالعميل', Icons.person_pin_circle_outlined),
          Obx(() {
            switch (c.shippingMode.value) {
              case 'governorate':
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: TextField(
                        onChanged: (v) => c.shippingGovernorate.value = v,
                        decoration: InputDecoration(
                          labelText: 'المحافظة',
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: TextField(
                        onChanged: (v) => c.shippingOffice.value = v,
                        decoration: InputDecoration(
                          labelText: 'اسم مكتب النقل المفضل (اختياري)',
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    Obx(() => CheckboxListTile(
                          value: c.shippingOfficeChoice.value == 'seloo',
                          onChanged: (v) => c.shippingOfficeChoice.value =
                              v == true ? 'seloo' : 'preferred',
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text('يمن سيلو يختار أنسب مكتب',
                              style: TextStyle(fontSize: 11, color: T.text)),
                        )),
                    textField(c.receiverNameCtrl, 'اسم المستلم'),
                    textField(c.receiverPhoneCtrl, 'رقم المستلم'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: T.warning.withOpacity(.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: T.warning.withOpacity(.35)),
                      ),
                      child: Text(
                        'رسوم نقل المحافظات تُحدَّد بالاتفاق مع يمن سيلو ومكتب الشحن، ولا تُدفع مسبقاً.',
                        style: TextStyle(
                            fontSize: 10.5, height: 1.5, color: T.text),
                      ),
                    ),
                  ],
                );
              case 'driver':
                return Column(
                  children: [
                    textField(c.driverNameCtrl, 'اسم السائق'),
                    textField(c.driverPhoneCtrl, 'رقم هاتف السائق'),
                    textField(c.meetPointCtrl, 'نقطة الالتقاء'),
                  ],
                );
              default:
                return const SizedBox.shrink();
            }
          }),
        ],
      ),
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
          if (controller.lines.any((l) => l.isNonRefundable)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: T.warning.withOpacity(.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: T.warning.withOpacity(.45)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 17, color: T.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'تنبيه: طلبك يحتوي على قطع غير قابلة للاسترداد أو الاستبدال بعد الشراء (${controller.lines.where((l) => l.isNonRefundable).length} قطعة).',
                      style: TextStyle(fontSize: 10.5, height: 1.45, fontWeight: FontWeight.w700, color: T.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                  color: active ? T.primary : T.text,
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
    return Obx(() {
      final sf = Get.find<SettingsService>().settings.value;
      final est = controller.estimate.value;
      if (est == null) return const SizedBox.shrink();
      final restriction = controller.deferredRestrictionReason(est, sf);
      final eligible = restriction == null;
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
                                  ? T.text
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
            Text('طريقة السداد',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: T.primary)),
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
                  ? 'الدفعة الأولى ${formatMoney(upfront, est.currency)} · المتبقي ${formatMoney(est.totalLocal - upfront, est.currency)} (متاح لك: ${controller.availableDeferredCreditSar.toStringAsFixed(0)} ر.س)'
                  : restriction,
              enabled: eligible,
            ),
            if (controller.paymentPlan.value == 'half_deferred' && eligible) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'خيار الآجل عبر استمارة واتساب الإجبارية:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: T.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'يمكنك متابعة دفع الدفعة الأولى الآن، أو تأكيد الطلب الآجل فوراً والانتقال لاستمارة تأكيد الطلب عبر واتساب.',
                      style: TextStyle(fontSize: 10.5, color: T.muted, height: 1.5),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: controller.busy.value
                          ? null
                          : controller.confirmDeferredWithoutDeposit,
                      icon: const Icon(Icons.chat_outlined, size: 17),
                      label: const Text('تأكيد طلب آجل + استمارة واتساب',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ],
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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: T.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (c != AppCurrency.sar)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  c == AppCurrency.usd
                      ? 'سعر الصرف: 1 USD = ${e.matrix.sar > 0 ? (e.matrix.sar / (e.matrix.usd > 0 ? e.matrix.usd : 1)).toStringAsFixed(2) : "3.75"} ر.س'
                      : 'سعر الصرف: 1 ر.س = ${e.rate.toStringAsFixed(0)} ${c.shortAr}',
                  style: TextStyle(fontSize: 11, color: T.muted),
                ),
              ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: T.soft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: T.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('المقارنة بجميع العملات (سعودي / دولار ← شمال / جنوب)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: T.primary)),
                  const SizedBox(height: 5),
                  MoneyRow(label: 'سعودي (SAR)', value: '${e.matrix.sar.toStringAsFixed(2)} ر.س'),
                  MoneyRow(label: 'دولار (USD)', value: '${e.matrix.usd.toStringAsFixed(2)} USD'),
                  MoneyRow(label: 'شمال × السعودي (${e.matrix.rateNorth.toStringAsFixed(0)})', value: '${e.matrix.northFromSar.toStringAsFixed(0)} ر.ي'),
                  MoneyRow(label: 'شمال × الدولار (${e.matrix.usdRateNorth.toStringAsFixed(0)})', value: '${e.matrix.northFromUsd.toStringAsFixed(0)} ر.ي'),
                  MoneyRow(label: 'جنوب × السعودي (${e.matrix.rateSouth.toStringAsFixed(0)})', value: '${e.matrix.southFromSar.toStringAsFixed(0)} ر.ي'),
                  MoneyRow(label: 'جنوب × الدولار (${e.matrix.usdRateSouth.toStringAsFixed(0)})', value: '${e.matrix.southFromUsd.toStringAsFixed(0)} ر.ي'),
                  if (controller.paymentPlan.value == 'half_deferred')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'ملاحظة الآجل: المتبقي يُثبّت بسعر صرف يوم إنشاء الطلب.',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: T.warning),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  /// الخصم من رصيد المحفظة (كلياً أو جزئياً).
  Widget _walletCard(BuildContext context) {
    final controller = Get.find<CheckoutController>();
    final wallet = Get.put(WalletService(), permanent: false);
    final amount = TextEditingController();
    return StreamBuilder<Map<String, dynamic>?>(
      stream: wallet.watch(),
      builder: (context, snap) {
        final bal = ((snap.data?['balanceSar'] as num?) ?? 0).toDouble();
        if (bal <= 0) return const SizedBox.shrink();
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
              Row(children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 18, color: T.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('الخصم من رصيد المحفظة',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: T.text)),
                ),
                Text('${bal.toStringAsFixed(2)} ر.س',
                    style: TextStyle(fontSize: 11, color: T.muted)),
              ]),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final x = double.tryParse(v.trim()) ?? 0;
                      controller.walletUseSar.value =
                          x > bal ? bal : (x < 0 ? 0 : x);
                    },
                    decoration: const InputDecoration(
                        labelText: 'المبلغ المخصوم (اختياري)',
                        isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    amount.text = bal.toStringAsFixed(2);
                    controller.walletUseSar.value = bal;
                  },
                  child: const Text('الكل', style: TextStyle(fontSize: 11)),
                ),
              ]),
            ],
          ),
        );
      },
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
