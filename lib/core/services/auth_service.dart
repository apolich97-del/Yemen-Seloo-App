import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'customer_accounting_service.dart';

DateTime? _parseAuthDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v);
  try {
    return (v as dynamic).toDate() as DateTime;
  } catch (_) {
    return null;
  }
}

/// مستخدم التطبيق + دوره + بيانات قاعدة عملاء يمن سيلو.
class AppUser {
  final String uid;
  final String? email;
  final String? phone;
  final String firstName;
  final String lastName;
  final String role; // customer | manager | support | shipping | courier | accounting
  final List<String> addressesCount;
  final String customerCode;
  final String city;
  final String district;
  final String addressLine;
  final String preferredCurrency;
  final String staffNotes;
  final String customerTier;
  final double? deferredCreditLimitSar;
  final DateTime? lastOrderAt;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    this.email,
    this.phone,
    this.firstName = '',
    this.lastName = '',
    this.role = 'customer',
    this.addressesCount = const [],
    this.customerCode = '',
    this.city = '',
    this.district = '',
    this.addressLine = '',
    this.preferredCurrency = 'south',
    this.staffNotes = '',
    this.customerTier = 'normal',
    this.deferredCreditLimitSar,
    this.lastOrderAt,
    this.createdAt,
  });

  String get displayName =>
      [firstName, lastName].where((e) => e.trim().isNotEmpty).join(' ').trim();

  String get effectiveCode =>
      customerCode.isNotEmpty
          ? customerCode
          : 'YS-C-${uid.substring(0, uid.length >= 4 ? 4 : uid.length).toUpperCase()}';

  String get fullAddressAr =>
      [city, district, addressLine].where((e) => e.trim().isNotEmpty).join(' — ');

  CustomerTier get tier => CustomerTierX.fromKey(customerTier);

  double get effectiveCreditLimitSar =>
      deferredCreditLimitSar ?? tier.defaultCreditLimitSar;

  bool get hasCompleteCustomerProfile =>
      firstName.trim().isNotEmpty &&
      (phone ?? '').replaceAll(RegExp(r'\D'), '').length >= 9 &&
      city.trim().isNotEmpty &&
      district.trim().isNotEmpty &&
      addressLine.trim().isNotEmpty;

  /// واتساب يحتاج الرقم بصيغة دولية بلا رموز.
  String get whatsappNumber {
    var p = (phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    if (p.startsWith('+')) p = p.substring(1);
    if (p.startsWith('00')) p = p.substring(2);
    return p;
  }

  bool get isStaff => role != 'customer';

  AppUser copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? city,
    String? district,
    String? addressLine,
    String? preferredCurrency,
    String? staffNotes,
    String? customerTier,
    double? deferredCreditLimitSar,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        phone: phone ?? this.phone,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        role: role,
        addressesCount: addressesCount,
        customerCode: customerCode,
        city: city ?? this.city,
        district: district ?? this.district,
        addressLine: addressLine ?? this.addressLine,
        preferredCurrency: preferredCurrency ?? this.preferredCurrency,
        staffNotes: staffNotes ?? this.staffNotes,
        customerTier: customerTier ?? this.customerTier,
        deferredCreditLimitSar: deferredCreditLimitSar ?? this.deferredCreditLimitSar,
        lastOrderAt: lastOrderAt,
        createdAt: createdAt,
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

  /// حسابات المدير الرئيسي — فقط هذان الحسابان يملكان توزيع الأدوار
  /// وتعديل وحذف الطلبات.
  static const Set<String> mainManagerEmails = <String>{
    'apolich97@gmail.com',
    'abode212k@gmail.com',
  };

  /// المدير الرئيسي فقط (وليس الحسابات المشتركة أو باقي الموظفين).
  bool get isMainManager {
    final email = (user.value?.email ?? _auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    final r = role;
    return mainManagerEmails.contains(email) &&
        (r == 'manager' || r == 'owner');
  }

  /// من يملك تعديل بيانات الطلب وحذفه: المدير الرئيسي والمحاسب.
  bool get canEditOrders => isMainManager || role == 'accounting';

  /// الأدوار القابلة للتوزيع من المدير الرئيسي.
  static const Set<String> staffRoles = <String>{
    'manager',
    'marketer',
    'accounting',
    'shipping',
    'support',
    'courier',
  };

  /// إضافة موظف أو تحديث دوره في سجل الفريق.
  Future<void> upsertStaff({
    required String name,
    required String email,
    required String role,
  }) async {
    final key = email.trim().toLowerCase();
    await FirebaseFirestore.instance.collection('staff_invites').doc(key).set({
      'name': name.trim(),
      'email': key,
      'role': role,
      'active': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'addedBy': user.value?.email ?? '',
    }, SetOptions(merge: true));

    // إن كان الحساب موجوداً مسبقاً في users نحدّث دوره فوراً.
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: key)
        .limit(5)
        .get();
    for (final d in snap.docs) {
      await d.reference.set({'role': role, 'email': key}, SetOptions(merge: true));
    }
    if (snap.docs.isEmpty && email.trim() != key) {
      final snapRaw = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(5)
          .get();
      for (final d in snapRaw.docs) {
        await d.reference.set({'role': role, 'email': key}, SetOptions(merge: true));
      }
    }
  }

  /// إزالة الموظف: حذف السجل وإعادة دوره إلى عميل.
  Future<void> removeStaff(String email) async {
    final key = email.trim().toLowerCase();
    if (mainManagerEmails.contains(key)) {
      throw 'لا يمكن إزالة مدير رئيسي';
    }
    final db = FirebaseFirestore.instance;
    await db.collection('staff_invites').doc(key).delete();
    final snap =
        await db.collection('users').where('email', isEqualTo: key).limit(5).get();
    for (final d in snap.docs) {
      await d.reference.set({'role': 'customer'}, SetOptions(merge: true));
    }
  }

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

      // الدور قد يُضبط في users/{uid}.role من لوحة Firebase
      final docRole = (d['role'] as String?) ?? '';
      if (claimRole is! String || claimRole.isEmpty) {
        if (docRole.isNotEmpty && docRole != 'customer') role = docRole;
      }

      // بريد الفريق يفتح لوحة الإدارة حتى لو لم يُضبط claim الدور بعد
      // (نفس القائمة المعتمدة في firestore.rules).
      final email = (u.email ?? '').toLowerCase().trim();
      if (role == 'customer' && mainManagerEmails.contains(email)) {
        role = 'manager';
      }

      // ربط ديناميكي: دور الموظف من سجل الفريق staff_invites/{email}
      if (email.isNotEmpty) {
        try {
          var inv = await FirebaseFirestore.instance
              .collection('staff_invites')
              .doc(email)
              .get();
          if (!inv.exists) {
            final qInv = await FirebaseFirestore.instance
                .collection('staff_invites')
                .where('email', isEqualTo: email)
                .limit(1)
                .get();
            if (qInv.docs.isNotEmpty) inv = qInv.docs.first;
          }
          final invRole = (inv.data()?['role'] ?? '') as String;
          if (inv.data() != null &&
              (inv.data()?['active'] ?? true) == true &&
              staffRoles.contains(invRole)) {
            role = invRole;
            // تثبيت الدور في users/{uid} حتى تُقرأ به قواعد Firestore.
            try {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(u.uid)
                  .set({'role': invRole}, SetOptions(merge: true));
            } catch (_) {}
          }
        } catch (_) {
          // تعذّر القراءة (قواعد/شبكة) — يبقى العميل عميلاً.
        }
      }
      final rawPhone = ((d['phone'] as String?) ?? '').trim();
      final resolvedPhone = rawPhone.isNotEmpty ? rawPhone : (u.phoneNumber ?? '');
      final rawCode = ((d['customerCode'] as String?) ?? '').trim();
      final resolvedCode = rawCode.isNotEmpty
          ? rawCode
          : 'YS-C-${u.uid.substring(0, u.uid.length >= 4 ? 4 : u.uid.length).toUpperCase()}';
      user.value = AppUser(
        uid: u.uid,
        email: u.email ?? (d['email'] as String?),
        phone: resolvedPhone,
        firstName: (d['firstName'] ?? '') as String,
        lastName: (d['lastName'] ?? '') as String,
        role: role,
        customerCode: resolvedCode,
        city: (d['city'] ?? '') as String,
        district: (d['district'] ?? '') as String,
        addressLine: (d['addressLine'] ?? '') as String,
        preferredCurrency: (d['preferredCurrency'] ?? 'south') as String,
        staffNotes: (d['staffNotes'] ?? '') as String,
        customerTier: (d['customerTier'] ?? 'normal') as String,
        deferredCreditLimitSar:
            (d['deferredCreditLimitSar'] as num?)?.toDouble(),
        lastOrderAt: _parseAuthDate(d['lastOrderAt']),
        createdAt: _parseAuthDate(d['createdAt']),
      );
    } catch (e) {
      debugPrint('refreshProfile: $e');
    }
  }

  String _codeFor(String uid) =>
      'YS-C-${uid.substring(0, uid.length >= 4 ? 4 : uid.length).toUpperCase()}';

  Future<void> saveProfile({
    required String firstName,
    required String lastName,
    String? phone,
    String? city,
    String? district,
    String? addressLine,
    String? preferredCurrency,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw 'غير مسجل الدخول';
    final docRef = _db.collection('users').doc(u.uid);
    final payload = <String, dynamic>{
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'phone': (phone ?? '').trim(),
      'customerCode': user.value?.customerCode.isNotEmpty == true
          ? user.value!.customerCode
          : _codeFor(u.uid),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (city != null) payload['city'] = city.trim();
    if (district != null) payload['district'] = district.trim();
    if (addressLine != null) payload['addressLine'] = addressLine.trim();
    if (preferredCurrency != null) {
      payload['preferredCurrency'] = preferredCurrency.trim();
    }
    await docRef.set(payload, SetOptions(merge: true));
    await refreshProfile();
  }

  /// مزامنة بيانات التسجيل الإلزامية في قاعدة عملاء يمن سيلو + إنشاء عنوان افتراضي عند عدم وجود عنوان.
  Future<void> syncCustomerRegistration({
    required String firstName,
    required String lastName,
    required String phone,
    required String city,
    required String district,
    required String addressLine,
  }) async {
    final u = _auth.currentUser;
    if (u == null) return;
    final cleanFirst = firstName.trim();
    final cleanLast = lastName.trim();
    final cleanPhone = phone.trim();
    final cleanCity = city.trim();
    final cleanDistrict = district.trim();
    final cleanLine = addressLine.trim();

    final ref = _db.collection('users').doc(u.uid);
    final existing = await ref.get();
    final data = existing.data() ?? <String, dynamic>{};

    final resolvedCode = ((data['customerCode'] as String?) ?? '').isNotEmpty
        ? data['customerCode']
        : _codeFor(u.uid);

    await ref.set({
      'firstName': cleanFirst,
      'lastName': cleanLast,
      'phone': cleanPhone,
      'city': cleanCity,
      'district': cleanDistrict,
      'addressLine': cleanLine,
      'email': (u.email ?? (data['email'] ?? '')).toString().trim().toLowerCase(),
      'customerCode': resolvedCode,
      if (!existing.exists || data['createdAt'] == null)
        'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // إنشاء عنوان افتراضي للعميل إن لم يكن لديه عنوان محفوظ
    try {
      final addrCol = ref.collection('addresses');
      final addrSnap = await addrCol.limit(1).get();
      if (addrSnap.docs.isEmpty && cleanCity.isNotEmpty) {
        final fullName = '$cleanFirst $cleanLast'.trim();
        await addrCol.add({
          'label': 'المنزل',
          'city': cleanCity,
          'district': cleanDistrict,
          'line': cleanLine,
          'phone': cleanPhone,
          'receiverName': fullName.isEmpty ? 'العميل' : fullName,
          'isDefault': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}

    await refreshProfile();
  }

  /// تحديث فئة العميل والحد الائتماني الآجل (من لوحة العملاء للإدارة).
  Future<void> updateCustomerCreditSettings({
    required String targetUid,
    required CustomerTier tier,
    required double creditLimitSar,
  }) async {
    await _db.collection('users').doc(targetUid).set({
      'customerTier': tier.key,
      'deferredCreditLimitSar': creditLimitSar < 0 ? 0.0 : creditLimitSar,
      'notesUpdatedAt': FieldValue.serverTimestamp(),
      'notesUpdatedBy': user.value?.displayName.isNotEmpty == true
          ? user.value!.displayName
          : (user.value?.email ?? 'staff'),
    }, SetOptions(merge: true));
  }

  Future<void> updateCustomerStaffNotes({
    required String targetUid,
    required String notes,
  }) async {
    await _db.collection('users').doc(targetUid).set({
      'staffNotes': notes.trim(),
      'notesUpdatedAt': FieldValue.serverTimestamp(),
      'notesUpdatedBy': user.value?.displayName.isNotEmpty == true
          ? user.value!.displayName
          : (user.value?.email ?? 'staff'),
    }, SetOptions(merge: true));
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
        'email': account.email.trim().toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await refreshProfile();
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
