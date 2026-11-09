import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/payment_accounts.dart';
import '../../core/controllers/payment_controller.dart';
import '../../core/models/currency.dart';
import '../../core/theme/app_theme.dart';

/// المرحلة 2 — «الدفع»: اختيار الحساب وإثبات الحوالة.
class PaymentScreen extends GetView<PaymentController> {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الدفع')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _notice(),
          const SizedBox(height: 12),
          SectionCard(
            title: 'طرق الدفع المتاحة',
            child: Obx(() => Column(
                  children: controller.accounts
                      .map((a) => _accountTile(a))
                      .toList(growable: false),
                )),
          ),
          const SizedBox(height: 12),
          Obx(() {
            final a = controller.selected.value;
            if (a == null) return const SizedBox.shrink();
            return _accountDetails(a);
          }),
          const SizedBox(height: 12),
          Obx(() {
            final t = controller.transfer.value;
            return SectionCard(
              title: 'بيانات الحوالة',
              trailing: TextButton(
                onPressed: controller.selected.value == null ? null : _openTransferSheet,
                child: Text(t == null ? 'إدخال البيانات' : 'تعديل'),
              ),
              child: t == null
                  ? const Text(
                      'لم تُدخل بيانات الحوالة بعد — سيُطلب منك اسم المرسل ورقم العملية.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    )
                  : Column(
                      children: [
                        MoneyRow(label: 'اسم المرسل', value: t.senderName),
                        MoneyRow(label: 'رقم العملية', value: t.refNo),
                        if (t.note.isNotEmpty) MoneyRow(label: 'ملاحظة', value: t.note),
                        if (t.proofUrl.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Icon(Icons.attach_file, size: 16, color: AppColors.success),
                                SizedBox(width: 4),
                                Text('تم إرفاق صورة الحوالة',
                                    style: TextStyle(fontSize: 12, color: AppColors.success)),
                              ],
                            ),
                          ),
                      ],
                    ),
            );
          }),
          const SizedBox(height: 100),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Obx(() => ElevatedButton(
                onPressed: controller.canConfirm ? controller.confirmPayment : null,
                child: controller.busy.value
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('تأكيد الدفع · ${controller.totalLabel}'),
              )),
        ),
      ),
    );
  }

  Widget _notice() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accent.withValues(alpha: .4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'الدفع يتم بتحويل يدوي: حوّل المبلغ إلى أحد الحسابات أدناه، ثم أدخل بيانات الحوالة '
                '(اسم المرسل ورقم العملية). تراجع المحاسبة الحوالة وتُفعّل الطلب بعد التأكيد — '
                'عادةً خلال ساعات العمل.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.7,
                  color: AppColors.ink.withValues(alpha: .85),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _accountTile(PaymentAccount a) {
    return Obx(() {
      final active = controller.selected.value?.id == a.id;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => controller.select(a),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? AppColors.primary : const Color(0xFFE6EAE8),
                width: active ? 1.6 : 1,
              ),
              color: active ? AppColors.primary.withValues(alpha: .05) : Colors.white,
            ),
            child: Row(
              children: [
                Icon(
                  active ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 20,
                  color: active ? AppColors.primary : AppColors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.titleAr,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(
                        '${a.bankAr} · ${a.primaryNumber}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                if (active)
                  TextButton(
                    onPressed: () => controller.copyNumber(a.primaryNumber),
                    child: const Text('نسخ', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _accountDetails(PaymentAccount a) {
    return SectionCard(
      title: 'تفاصيل الحساب',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...a.numbers.map((n) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        n,
                        style: const TextStyle(
                          fontSize: 16,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => controller.copyNumber(n),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                    ),
                  ],
                ),
              )),
          Text(a.noteAr, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('المبلغ المطلوب: ${formatMoney(controller.payload.estimate.totalLocal, controller.currency)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openTransferSheet,
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('إدخال بيانات الحوالة'),
          ),
        ],
      ),
    );
  }

  void _openTransferSheet() {
    Get.bottomSheet(
      _TransferSheet(controller: controller),
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }
}

/// نافذة «بيانات الحوالة»: المبلغ، اسم المرسل، رقم العملية، ملاحظة + إرسال.
class _TransferSheet extends StatelessWidget {
  final PaymentController controller;
  const _TransferSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE3E0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('بيانات الحوالة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('تأكد من مطابقة المبلغ ورقم العملية — تُراجع المحاسبة كل حوالة.',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
            const SizedBox(height: 16),
            TextField(
              controller: controller.amountCtrl,
              enabled: false,
              decoration: InputDecoration(
                labelText: 'المبلغ المحوّل',
                suffixText: controller.currency.shortAr,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.senderCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'اسم المرسل',
                hintText: 'الاسم كما يظهر في الحوالة',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.refCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'رقم العملية',
                hintText: 'رقم الحوالة / المرجع',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظة (اختياري)',
                hintText: 'اسم الفرع أو وقت التحويل',
              ),
            ),
            const SizedBox(height: 12),
            Obx(() => OutlinedButton.icon(
                  onPressed: controller.uploading.value ? null : controller.pickProof,
                  icon: controller.uploading.value
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('إرفاق صورة الحوالة (اختياري)'),
                )),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: controller.saveTransfer,
              child: const Text('إرسال'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
