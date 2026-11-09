import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

/// تسجيل الدخول: Google + رقم الهاتف.
/// خياران للهاتف: SMS (Firebase مباشرة) أو واتساب OTP (عبر Cloud Function).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController(text: '+967');
  final _code = TextEditingController();
  final _auth = Get.find<AuthService>();

  String? _verificationId;
  bool _whatsapp = false;
  bool _codeSent = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _e164 {
    var p = _phone.text.replaceAll(RegExp(r'[^0-9+]'), '');
    if (!p.startsWith('+')) p = '+$p';
    return p;
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
      Get.offAllNamed('/orders');
    } else {
      Get.snackbar('فشل التحقق', _auth.error.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(.1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.shopping_bag_outlined,
                  size: 38, color: AppColors.primaryDark),
            ),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text('يمن سيلو',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ),
          const Center(
            child: Text('سجّل الدخول لمتابعة طلباتك',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ),
          const SizedBox(height: 26),
          OutlinedButton.icon(
            onPressed: _auth.loading.value ? null : () async {
              await _auth.signInWithGoogle();
              if (_auth.isSignedIn) Get.offAllNamed('/orders');
            },
            icon: const Icon(Icons.g_mobiledata, size: 28),
            label: const Text('المتابعة بحساب Google'),
          ),
          const SizedBox(height: 20),
          Row(
            children: const [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('أو', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 20),
          const Text('رقم الهاتف',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(hintText: '+9677xxxxxxxx'),
          ),
          const SizedBox(height: 10),
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
              decoration: const InputDecoration(labelText: 'رمز التحقق', hintText: '6 أرقام'),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton(
            onPressed: _auth.loading.value ? null : (_codeSent ? _verify : _send),
            child: _auth.loading.value
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_codeSent ? 'تحقق ودخول' : 'إرسال الرمز'),
          ),
          const SizedBox(height: 14),
          Text(
            'ملاحظة: دخول الهاتف عبر Firebase يرسل رسالة SMS فقط. خيار «واتساب» يمرّ عبر مزوّد '
            'مراسلة (Twilio/Meta) في Cloud Function ثم يُصدر customToken للدخول.',
            style: TextStyle(fontSize: 10.5, height: 1.7, color: AppColors.muted.withOpacity(.9)),
          ),
        ],
      ),
    );
  }
}
