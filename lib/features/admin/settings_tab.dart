import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/models/app_settings.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/app_theme.dart';
import 'role_guard.dart';

/// الإعدادات: أسعار الصرف (140 / 413)، رسوم الشحن والتوصيل، بيانات الدعم، الكوبونات.
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _settings = Get.find<SettingsService>();
  final _db = FirebaseFirestore.instance;

  final _rateNorth = TextEditingController();
  final _rateSouth = TextEditingController();
  final _shipping = TextEditingController();
  final _delivery = TextEditingController();
  final _freeOver = TextEditingController();
  final _serviceFee = TextEditingController();
  final _perPiece = TextEditingController();
  final _minDays = TextEditingController();
  final _maxDays = TextEditingController();
  final _whatsapp = TextEditingController();
  final _phone = TextEditingController();

  final _couponCode = TextEditingController();
  final _couponValue = TextEditingController();
  String _couponType = 'percent';

  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _rateNorth, _rateSouth, _shipping, _delivery, _freeOver,
      _whatsapp, _phone, _couponCode, _couponValue
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(AppSettings s) {
    if (_loaded) return;
    _rateNorth.text = s.rateNorth.toStringAsFixed(0);
    _rateSouth.text = s.rateSouth.toStringAsFixed(0);
    _shipping.text = s.shippingFeeSar.toStringAsFixed(2);
    _delivery.text = s.deliveryFeeSar.toStringAsFixed(2);
    _freeOver.text = s.freeShippingThresholdSar.toStringAsFixed(0);
    _serviceFee.text = s.serviceFeeSar.toStringAsFixed(2);
    _perPiece.text = s.shippingPerPieceSar.toStringAsFixed(2);
    _minDays.text = s.deliveryMinDays.toString();
    _maxDays.text = s.deliveryMaxDays.toString();
    _whatsapp.text = s.supportWhatsApp;
    _phone.text = s.supportPhone;
    _loaded = true;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final s = AppSettings(
        rateNorth: double.tryParse(_rateNorth.text) ?? 140,
        rateSouth: double.tryParse(_rateSouth.text) ?? 413,
        shippingFeeSar: double.tryParse(_shipping.text) ?? 0,
        deliveryFeeSar: double.tryParse(_delivery.text) ?? 0,
        freeShippingThresholdSar: double.tryParse(_freeOver.text) ?? 300,
        serviceFeeSar: double.tryParse(_serviceFee.text) ?? 1.22,
        shippingPerPieceSar: double.tryParse(_perPiece.text) ?? 1,
        deliveryMinDays: int.tryParse(_minDays.text) ?? 15,
        deliveryMaxDays: int.tryParse(_maxDays.text) ?? 20,
        supportWhatsApp: _whatsapp.text.trim(),
        supportPhone: _phone.text.trim(),
        companyNameAr: 'يمن سيلو',
      );
      await _db.collection('settings').doc('app').set({
        ...s.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      Get.snackbar('تم الحفظ', 'طُبّقت الأسعار الجديدة — الطلبات القديمة تحتفظ بسعر صرفها');
    } catch (e) {
      Get.snackbar('تعذر الحفظ', '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addCoupon() async {
    final code = _couponCode.text.trim().toUpperCase();
    final value = double.tryParse(_couponValue.text);
    if (code.isEmpty || value == null || value <= 0) {
      Get.snackbar('بيانات ناقصة', 'أدخل الكود وقيمة صحيحة');
      return;
    }
    await _db.collection('coupons').doc(code).set({
      'type': _couponType,
      'value': value,
      'minOrderSar': 0,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _couponCode.clear();
    _couponValue.clear();
    Get.snackbar('تم', 'أُضيف الكود $code');
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allow: ['manager'],
      child: Obx(() {
        _fill(_settings.settings.value);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: 'أسعار الصرف',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _rateNorth,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '1 ر.س ← ريال شمالي',
                            hintText: '140',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _rateSouth,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '1 ر.س ← ريال جنوبي',
                            hintText: '413',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'التسعير الداخلي بالريال السعودي. تغيير السعر يؤثر على الطلبات الجديدة فقط؛ '
                    'كل طلب يحتفظ بـ exchangeRate الخاص به عند إنشائه.',
                    style: TextStyle(fontSize: 11, height: 1.6, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'رسوم الخدمة و الشحن لكل قطعة',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _serviceFee,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'رسوم الخدمة (ر.س)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _perPiece,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'شحن القطعة (ر.س)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'تُطبَّق رسوم الخدمة على كل طلب، والشحن لكل قطعة ما دام الطلب تحت حد الشحن المجاني.',
                    style: TextStyle(fontSize: 11, height: 1.6, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'مدة التوصيل المتوقعة (أيام)',
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minDays,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'من (يوم)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _maxDays,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'إلى (يوم)'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'رسوم الشحن والتوصيل (بالريال السعودي)',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _shipping,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'رسوم الشحن'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _delivery,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'رسوم التوصيل'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _freeOver,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'شحن مجاني عند تجاوز (بالريال السعودي)',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'بيانات الدعم',
              child: Column(
                children: [
                  TextField(
                    controller: _whatsapp,
                    decoration: const InputDecoration(labelText: 'واتساب الدعم'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'هاتف الدعم'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'إضافة كوبون',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _couponCode,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(labelText: 'الكود'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _couponValue,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _couponType == 'percent' ? 'النسبة %' : 'المبلغ ر.س',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _couponType,
                    items: const [
                      DropdownMenuItem(value: 'percent', child: Text('نسبة مئوية')),
                      DropdownMenuItem(value: 'fixedSar', child: Text('مبلغ ثابت')),
                    ],
                    onChanged: (v) => setState(() => _couponType = v ?? 'percent'),
                    decoration: const InputDecoration(labelText: 'نوع الخصم'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _addCoupon,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة كود'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ الإعدادات'),
            ),
            const SizedBox(height: 24),
          ],
        );
      }),
    );
  }
}
