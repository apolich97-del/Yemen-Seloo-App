import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/models/app_settings.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/app_theme.dart';
import 'team_tab.dart';
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
  final _usdNorth = TextEditingController();
  final _defThreshold = TextEditingController();
  final _defPercent = TextEditingController();
  bool _defEnabled = true;
  final _usdSouth = TextEditingController();
  final _rateSouth = TextEditingController();
  final _shipping = TextEditingController();
  final _delivery = TextEditingController();
  final _deliveryNorth = TextEditingController();
  final _deliverySouth = TextEditingController();
  final _freeOver = TextEditingController();
  final _serviceFee = TextEditingController();
  final _perPiece = TextEditingController();
  final _minDays = TextEditingController();
  final _maxDays = TextEditingController();
  final _senderName = TextEditingController();
  final _waybillPhone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _whatsappAlt = TextEditingController();
  final _phone = TextEditingController();

  final _couponCode = TextEditingController();
  final _couponValue = TextEditingController();
  String _couponType = 'percent';

  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _rateNorth, _rateSouth, _usdNorth, _usdSouth,
      _defThreshold, _defPercent, _shipping, _delivery,
      _deliveryNorth, _deliverySouth, _freeOver,
      _serviceFee, _perPiece, _minDays, _maxDays,
      _senderName, _waybillPhone, _whatsapp, _whatsappAlt, _phone, _couponCode, _couponValue
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(AppSettings s) {
    if (_loaded) return;
    _rateNorth.text = s.rateNorth.toStringAsFixed(0);
    _usdNorth.text = s.usdRateNorth.toStringAsFixed(0);
    _defEnabled = s.deferredEnabled;
    _defThreshold.text = s.deferredThresholdSar.toStringAsFixed(0);
    _defPercent.text = s.deferredUpfrontPercent.toStringAsFixed(0);
    _usdSouth.text = s.usdRateSouth.toStringAsFixed(0);
    _rateSouth.text = s.rateSouth.toStringAsFixed(0);
    _shipping.text = s.shippingFeeSar.toStringAsFixed(2);
    _delivery.text = s.deliveryFeeSar.toStringAsFixed(2);
    _deliveryNorth.text = s.deliveryFeeNorthLocal.toStringAsFixed(0);
    _deliverySouth.text = s.deliveryFeeSouthLocal.toStringAsFixed(0);
    _freeOver.text = s.freeShippingThresholdSar.toStringAsFixed(0);
    _serviceFee.text = s.serviceFeeSar.toStringAsFixed(2);
    _perPiece.text = s.shippingPerPieceSar.toStringAsFixed(2);
    _minDays.text = s.deliveryMinDays.toString();
    _maxDays.text = s.deliveryMaxDays.toString();
    _senderName.text = s.senderName;
    _waybillPhone.text = s.waybillCompanyPhone;
    _whatsapp.text = s.supportWhatsApp;
    _whatsappAlt.text = s.alternateWhatsApp;
    _phone.text = s.supportPhone;
    _loaded = true;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final s = AppSettings(
        rateNorth: double.tryParse(_rateNorth.text) ?? 140,
        deferredEnabled: _defEnabled,
        deferredThresholdSar: double.tryParse(_defThreshold.text) ?? 150,
        deferredUpfrontPercent: double.tryParse(_defPercent.text) ?? 50,
        usdRateNorth: double.tryParse(_usdNorth.text) ?? 533,
        usdRateSouth: double.tryParse(_usdSouth.text) ?? 1570,
        rateSouth: double.tryParse(_rateSouth.text) ?? 413,
        shippingFeeSar: double.tryParse(_shipping.text) ?? 0,
        deliveryFeeSar: double.tryParse(_delivery.text) ?? 0,
        deliveryFeeNorthLocal: double.tryParse(_deliveryNorth.text) ?? 1500,
        deliveryFeeSouthLocal: double.tryParse(_deliverySouth.text) ?? 1000,
        freeShippingThresholdSar: double.tryParse(_freeOver.text) ?? 300,
        serviceFeeSar: double.tryParse(_serviceFee.text) ?? 1.22,
        shippingPerPieceSar: double.tryParse(_perPiece.text) ?? 1,
        deliveryMinDays: int.tryParse(_minDays.text) ?? 15,
        deliveryMaxDays: int.tryParse(_maxDays.text) ?? 20,
        supportWhatsApp: _whatsapp.text.trim(),
        alternateWhatsApp: _whatsappAlt.text.trim(),
        supportPhone: _phone.text.trim(),
        companyNameAr: 'يمن سيلو',
        senderName: _senderName.text.trim(),
        waybillCompanyPhone: _waybillPhone.text.trim(),
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
            if (Get.isRegistered<AuthService>() &&
                Get.find<AuthService>().isMainManager)
              SectionCard(
              title: 'الفريق والصلاحيات',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'حدّد دور كل موظف: مدير، محاسب، شحن، مندوب، أو خدمة عملاء. '
                    'يظهر لكل موظف ما يخصه فقط في لوحة الإدارة.',
                    style: TextStyle(fontSize: 11, height: 1.6, color: T.muted),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Get.to(() => const TeamTab()),
                      icon: const Icon(Icons.group_add_outlined, size: 16),
                      label: const Text('توزيع أدوار الفريق'),
                    ),
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'أسعار الصرف لجميع العملات والمناطق',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _usdNorth,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '1 دولار (\$) ← ريال شمالي',
                            hintText: '533',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _usdSouth,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '1 دولار (\$) ← ريال جنوبي',
                            hintText: '1570',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: T.soft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: T.softBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: T.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'المعامل النشط الآن: 1 ر.س = '
                                '${_rateNorth.text.isEmpty ? '—' : _rateNorth.text} شمالي · '
                                '${_rateSouth.text.isEmpty ? '—' : _rateSouth.text} جنوبي',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: T.text),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'التغيير يُطبَّق فوراً على الكتالوج والطلبات الجديدة، '
                          'وكل طلب قديم يحتفظ بسعر الصرف المسجّل عند إنشائه.',
                          style: TextStyle(
                              fontSize: 10.5, height: 1.6, color: T.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'نظام الطلبات الآجلة (الدفع بالنصف)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _defEnabled,
                    title: Text('تفعيل نظام الآجل',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: T.text)),
                    subtitle: Text('يسمح للعميل بدفع نصف القيمة وتأجيل الباقي',
                        style: TextStyle(fontSize: 10.5, color: T.muted)),
                    onChanged: (v) => setState(() => _defEnabled = v),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _defThreshold,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'حد تفعيل الطلب الآجل (ر.س)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _defPercent,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'نسبة الدفعة المقدمة (%)'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'رسوم التوصيل المحلي حسب المنطقة والعملة',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _deliveryNorth,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'توصيل الشمال (ر.ي شمال)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _deliverySouth,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'توصيل الجنوب (ر.ي جنوب)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _delivery,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'توصيل السعودية (ر.س)'),
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
                  Text(
                    'تُطبَّق رسوم الخدمة على كل طلب، والشحن لكل قطعة ما دام الطلب تحت حد الشحن المجاني.',
                    style: TextStyle(fontSize: 11, height: 1.6, color: T.muted),
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
              title: 'بوليصة شحن المحافظات',
              child: Column(
                children: [
                  TextField(
                    controller: _senderName,
                    decoration: const InputDecoration(
                      labelText: 'اسم المُرسِل المعتمد (من المدير)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _waybillPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الشركة الافتراضي على البوليصة',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'يُطبع الاسم والرقم تلقائياً في أعلى بوليصة شحن المحافظات.',
                      style: TextStyle(fontSize: 10.5, color: T.muted),
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
