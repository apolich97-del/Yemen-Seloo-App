import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

/// تسجيل الدخول مع التسجيل لمرة واحدة فقط لكل حساب Google في قاعدة بيانات عملاء يمن سيلو.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController(text: '+967');
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _addressLine = TextEditingController();
  final _code = TextEditingController();
  final _auth = Get.find<AuthService>();

  String? _verificationId;
  bool _whatsapp = false;
  bool _codeSent = false;
  bool _needsOnboarding = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _prefillFromUser(_auth.user.value);
  }

  void _prefillFromUser(AppUser? u) {
    if (u == null) return;
    if (u.firstName.trim().isNotEmpty) _firstName.text = u.firstName;
    if (u.lastName.trim().isNotEmpty) _lastName.text = u.lastName;
    if ((u.phone ?? '').trim().isNotEmpty) _phone.text = u.phone!;
    if (u.city.trim().isNotEmpty) _city.text = u.city;
    if (u.district.trim().isNotEmpty) _district.text = u.district;
    if (u.addressLine.trim().isNotEmpty) _addressLine.text = u.addressLine;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _city.dispose();
    _district.dispose();
    _addressLine.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _e164 {
    var p = _phone.text.replaceAll(RegExp(r'[^0-9+]'), '');
    if (!p.startsWith('+')) p = '+$p';
    return p;
  }

  String get _digitsOnly => _phone.text.replaceAll(RegExp(r'\D'), '');

  bool _validateRegistration() {
    final first = _firstName.text.trim();
    final last = _lastName.text.trim();
    final phoneDigits = _digitsOnly;
    final city = _city.text.trim();
    final line = _addressLine.text.trim();

    String? err;
    if (first.isEmpty) {
      err = 'الاسم الأول مطلوب لحفظ بياناتك في قاعدة العملاء';
    } else if (last.isEmpty) {
      err = 'الاسم الأخير مطلوب لحفظ بياناتك في قاعدة العملاء';
    } else if (phoneDigits.length < 9) {
      err = 'أدخل رقم هاتف / واتساب صحيحاً (9 أرقام على الأقل)';
    } else if (city.isEmpty) {
      err = 'المحافظة / المدينة مطلوبة لتجهيز عنوان الطلبات';
    } else if (line.isEmpty) {
      err = 'العنوان التفصيلي مطلوب (الشارع / أقرب معلم)';
    }
    setState(() => _formError = err);
    if (err != null) {
      Get.snackbar('بيانات مطلوبة', err);
      return false;
    }
    return true;
  }

  Future<void> _syncCustomerProfile() async {
    await _auth.syncCustomerRegistration(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      phone: _e164,
      city: _city.text.trim(),
      district: _district.text.trim(),
      addressLine: _addressLine.text.trim(),
    );
  }

  Future<void> _handleSignedInAccount() async {
    await _auth.refreshProfile();
    final u = _auth.user.value;
    if (u != null && (u.hasCompleteCustomerProfile || u.isStaff)) {
      Get.offAllNamed('/orders');
      if (u.isStaff) {
        Get.toNamed('/admin');
      }
      return;
    }
    // أول مرة لهذا الحساب فقط: نُعبّئ الاسم من Google إن وُجد ونفتح نموذج التسجيل لمرة واحدة
    _prefillFromUser(u);
    final fbUser = FirebaseAuth.instance.currentUser;
    final display = (fbUser?.displayName ?? '').trim();
    if (display.isNotEmpty && _firstName.text.trim().isEmpty) {
      final parts = display.split(RegExp(r'\\s+'));
      _firstName.text = parts.first;
      if (parts.length > 1 && _lastName.text.trim().isEmpty) {
        _lastName.text = parts.sublist(1).join(' ');
      }
    }
    if (mounted) {
      setState(() {
        _needsOnboarding = true;
        _formError = null;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    if (!_validateRegistration()) return;
    await _syncCustomerProfile();
    Get.offAllNamed('/orders');
  }

  Future<void> _send() async {
    if (_e164.replaceAll('+', '').length < 10) {
      Get.snackbar('رقم غير صحيح', 'أدخل الرقم بالصيغة الدولية مثال +9677xxxxxxxx');
      return;
    }
    if (_whatsapp) {
      final ok = await _auth.requestWhatsAppOtp(_e164);
      if (!ok) {
        Get.snackbar('تعذر الإرسال', _auth.error.value);
        return;
      }
      setState(() => _codeSent = true);
    } else {
      final id = await _auth.sendSmsOtp(_e164);
      if (id == null) {
        Get.snackbar('تعذر الإرسال', _auth.error.value);
        return;
      }
      _verificationId = id;
      setState(() => _codeSent = true);
    }
    Get.snackbar('تم الإرسال', _whatsapp ? 'وصلك رمز على واتساب' : 'وصلك رمز عبر رسالة نصية');
  }

  Future<void> _verify() async {
    if (_code.text.trim().length < 4) return;
    final ok = _whatsapp
        ? await _auth.confirmWhatsAppOtp(_e164, _code.text.trim())
        : await _auth.confirmSmsOtp(_verificationId!, _code.text.trim());
    if (ok) {
      await _handleSignedInAccount();
    } else {
      Get.snackbar('فشل التحقق', _auth.error.value);
    }
  }

  Future<void> _loginGoogle() async {
    await _auth.signInWithGoogle();
    if (_auth.isSignedIn) {
      await _handleSignedInAccount();
    } else if (_auth.error.value.isNotEmpty) {
      Get.snackbar('تعذر الدخول', _auth.error.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_needsOnboarding
            ? 'إكمال بيانات العميل (مرة واحدة)'
            : 'تسجيل الدخول'),
      ),
      body: Obx(() {
        final busy = _auth.loading.value;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: T.primary.withOpacity(.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(Icons.shopping_bag_outlined,
                    size: 36, color: T.primary),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text('يمن سيلو',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: T.text)),
            ),
            Center(
              child: Text(
                _needsOnboarding
                    ? 'سجّل بيانات التوصيل لمرة واحدة فقط لهذا الحساب'
                    : 'دخول سريع بحساب Google أو برقم الهاتف',
                style: TextStyle(fontSize: 12, color: T.muted),
              ),
            ),
            const SizedBox(height: 20),
            if (!_needsOnboarding) ...[
              ElevatedButton.icon(
                onPressed: busy ? null : _loginGoogle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: Text(
                  busy ? 'جارٍ تسجيل الدخول…' : 'تسجيل الدخول بحساب Google',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'إن كنت مسجّلاً من قبل بهذا الحساب ستدخل مباشرة بدون إعادة كتابة البيانات.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.5, color: T.muted),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('أو الدخول برقم الهاتف / واتساب',
                        style: TextStyle(fontSize: 11, color: T.muted)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف / واتساب',
                  hintText: '+9677xxxxxxxx',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: false,
                      groupValue: _whatsapp,
                      onChanged: (v) => setState(() {
                        _whatsapp = v ?? false;
                        _codeSent = false;
                      }),
                      title: const Text('رسالة SMS', style: TextStyle(fontSize: 12.5)),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: true,
                      groupValue: _whatsapp,
                      onChanged: (v) => setState(() {
                        _whatsapp = v ?? false;
                        _codeSent = false;
                      }),
                      title: const Text('واتساب', style: TextStyle(fontSize: 12.5)),
                    ),
                  ),
                ],
              ),
              if (_codeSent) ...[
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                      labelText: 'رمز التحقق', hintText: '6 أرقام'),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton(
                onPressed: busy ? null : (_codeSent ? _verify : _send),
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_codeSent ? 'تحقق ودخول' : 'إرسال رمز التحقق'),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: T.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: T.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.badge_outlined, size: 18, color: T.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('بيانات العميل — تُطلب مرة واحدة فقط *',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: T.text)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تُحفظ تلقائياً لهذا الحساب ولن يُطلب منك إدخالها مجدداً عند تسجيل الخروج والعودة.',
                      style: TextStyle(fontSize: 11, height: 1.5, color: T.muted),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstName,
                            decoration: const InputDecoration(
                              labelText: 'الاسم الأول *',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _lastName,
                            decoration: const InputDecoration(
                              labelText: 'الاسم الأخير *',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف / واتساب *',
                        hintText: '+9677xxxxxxxx',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _city,
                            decoration: const InputDecoration(
                              labelText: 'المحافظة / المدينة *',
                              hintText: 'صنعاء / عدن / تعز...',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _district,
                            decoration: const InputDecoration(
                              labelText: 'المديرية / الحي (اختياري)',
                              hintText: 'اختياري',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _addressLine,
                      decoration: const InputDecoration(
                        labelText: 'العنوان التفصيلي *',
                        hintText: 'الشارع، المبنى، أو أقرب معلم للتوصيل',
                        isDense: true,
                      ),
                    ),
                    if (_formError != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: T.danger.withOpacity(.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: T.danger.withOpacity(.3)),
                        ),
                        child: Text(
                          _formError!,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: T.danger),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: busy ? null : _completeOnboarding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text('حفظ البيانات والدخول',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await _auth.signOut();
                  if (mounted) setState(() => _needsOnboarding = false);
                },
                child: const Text('التبديل لحساب Google آخر'),
              ),
            ],
          ],
        );
      }),
    );
  }
}
