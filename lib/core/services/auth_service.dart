import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// مستخدم التطبيق + دوره (يُقرأ من custom claims ويُخزّن في users/{uid}).
class AppUser {
  final String uid;
  final String? email;
  final String? phone;
  final String firstName;
  final String lastName;
  final String role; // customer | manager | support | shipping | courier | accounting
  final List<String> addressesCount;

  const AppUser({
    required this.uid,
    this.email,
    this.phone,
    this.firstName = '',
    this.lastName = '',
    this.role = 'customer',
    this.addressesCount = const [],
  });

  String get displayName =>
      [firstName, lastName].where((e) => e.trim().isNotEmpty).join(' ').trim();

  /// واتساب يحتاج الرقم بصيغة دولية بلا رموز.
  String get whatsappNumber {
    var p = (phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    if (p.startsWith('+')) p = p.substring(1);
    if (p.startsWith('00')) p = p.substring(2);
    return p;
  }

  bool get isStaff => role != 'customer';

  AppUser copyWith({String? firstName, String? lastName, String? phone}) => AppUser(
        uid: uid,
        email: email,
        phone: phone ?? this.phone,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        role: role,
        addressesCount: addressesCount,
      );
}

class AuthService extends GetxService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _fn = FirebaseFunctions.instanceFor(region: 'europe-west1');

  final Rxn<AppUser> user = Rxn<AppUser>();
  final RxBool loading = false.obs;
  final RxString error = ''.obs;

  bool get isSignedIn => _auth.currentUser != null;
  String? get uid => _auth.currentUser?.uid;
  String get role => user.value?.role ?? 'customer';
  bool get isStaff => role != 'customer';

  @override
  void onInit() {
    super.onInit();
    _auth.authStateChanges().listen(_onAuthChanged);
    ever(user, (_) {});
  }

  Future<void> _onAuthChanged(User? u) async {
    if (u == null) {
      user.value = null;
      return;
    }
    user.value = AppUser(uid: u.uid, email: u.email, phone: u.phoneNumber);
    await refreshProfile();
  }

  Future<void> refreshProfile() async {
    final u = _auth.currentUser;
    if (u == null) return;
    try {
      final snap = await _db.collection('users').doc(u.uid).get();
      final d = snap.data() ?? <String, dynamic>{};
      // الدور الرسمي يأتي من claims (لا يمكن للعميل تعديله بنفسه).
      String role = 'customer';
      final token = await u.getIdTokenResult(true);
      final claimRole = token.claims?['role'];
      if (claimRole is String && claimRole.isNotEmpty) role = claimRole;
      user.value = AppUser(
        uid: u.uid,
        email: u.email,
        phone: u.phoneNumber ?? (d['phone'] as String?),
        firstName: (d['firstName'] ?? '') as String,
        lastName: (d['lastName'] ?? '') as String,
        role: role,
      );
    } catch (e) {
      debugPrint('refreshProfile: $e');
    }
  }

  Future<void> saveProfile({required String firstName, required String lastName, String? phone}) async {
    final u = _auth.currentUser;
    if (u == null) throw 'غير مسجل الدخول';
    await _db.collection('users').doc(u.uid).set({
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await refreshProfile();
  }

  Future<void> signInWithGoogle() async {
    loading.value = true;
    error.value = '';
    try {
      final g = GoogleSignIn(scopes: const ['email', 'profile']);
      final account = await g.signIn();
      if (account == null) return;
      final auth = await account.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      await _auth.signInWithCredential(cred);
      await _db.collection('users').doc(_auth.currentUser!.uid).set({
        'firstName': account.displayName?.split(' ').first ?? '',
        'lastName': account.displayName?.split(' ').skip(1).join(' ') ?? '',
        'email': account.email,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      error.value = _ar(e.code);
    } catch (e) {
      error.value = 'تعذر تسجيل الدخول بجوجل';
    } finally {
      loading.value = false;
    }
  }

  /// 1) إرسال رمز عبر Firebase Phone Auth (رسالة SMS من جوجل).
  Future<String?> sendSmsOtp(String e164Phone) async {
    loading.value = true;
    error.value = '';
    try {
      final completer = Completer<String?>();
      await _auth.verifyPhoneNumber(
        phoneNumber: e164Phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (c) async => await _auth.signInWithCredential(c),
        verificationFailed: (e) {
          error.value = _ar(e.code);
          if (!completer.isCompleted) completer.completeError(e);
        },
        codeSent: (verificationId, _) {
          if (!completer.isCompleted) completer.complete(verificationId);
        },
        codeAutoRetrievalTimeout: (_) {},
      );
      return await completer.future;
    } catch (_) {
      return null;
    } finally {
      loading.value = false;
    }
  }

  Future<bool> confirmSmsOtp(String verificationId, String code) async {
    loading.value = true;
    try {
      await _auth.signInWithCredential(
        PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code),
      );
      await refreshProfile();
      return true;
    } on FirebaseAuthException catch (e) {
      error.value = 'رمز غير صحيح (${_ar(e.code)})';
      return false;
    } finally {
      loading.value = false;
    }
  }

  /// 2) واتساب OTP — Firebase لا يرسل واتساب.
  /// السيرفر يرسل الرمز عبر مزود (Twilio/Meta) ثم يُصدر customToken.
  /// هكذا لا نحتاج كلمة سر في التطبيق.
  Future<bool> requestWhatsAppOtp(String e164Phone) async {
    loading.value = true;
    error.value = '';
    try {
      final res = await _fn.httpsCallable('whatsappOtpRequest').call({'phone': e164Phone});
      return (res.data['sent'] as bool?) ?? false;
    } on FirebaseFunctionsException catch (e) {
      error.value = e.message ?? 'تعذر إرسال رمز واتساب';
      return false;
    } finally {
      loading.value = false;
    }
  }

  Future<bool> confirmWhatsAppOtp(String e164Phone, String code) async {
    loading.value = true;
    error.value = '';
    try {
      final res = await _fn
          .httpsCallable('whatsappOtpVerify')
          .call({'phone': e164Phone, 'code': code});
      final token = res.data['customToken'] as String?;
      if (token == null || token.isEmpty) {
        error.value = 'تعذر إنشاء جلسة الدخول';
        return false;
      }
      await _auth.signInWithCustomToken(token);
      await _db.collection('users').doc(_auth.currentUser!.uid).set({
        'phone': e164Phone,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await refreshProfile();
      return true;
    } on FirebaseFunctionsException catch (e) {
      error.value = e.message ?? 'رمز غير صحيح';
      return false;
    } finally {
      loading.value = false;
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
    user.value = null;
  }

  String _ar(String code) => switch (code) {
        'invalid-phone-number' => 'رقم الهاتف غير صحيح',
        'too-many-requests' => 'محاولات كثيرة، حاول لاحقاً',
        'invalid-verification-code' => 'الرمز غير صحيح',
        'quota-exceeded' => 'تم تجاوز الحد المسموح للإرسال',
        'network-request-failed' => 'تحقق من الاتصال بالإنترنت',
        _ => 'تعذر إكمال العملية',
      };
}
