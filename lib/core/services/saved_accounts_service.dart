import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class SavedAccountEntry {
  final String uid;
  final String email;
  final String name;
  final String phone;
  final String role;
  final int lastActiveMs;

  const SavedAccountEntry({
    required this.uid,
    required this.email,
    required this.name,
    this.phone = '',
    this.role = 'customer',
    required this.lastActiveMs,
  });

  factory SavedAccountEntry.fromMap(Map<String, dynamic> m) => SavedAccountEntry(
        uid: (m['uid'] ?? '').toString(),
        email: (m['email'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        phone: (m['phone'] ?? '').toString(),
        role: (m['role'] ?? 'customer').toString(),
        lastActiveMs: (m['lastActiveMs'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'name': name,
        'phone': phone,
        'role': role,
        'lastActiveMs': lastActiveMs,
      };
}

/// يحفظ الحسابات المسجلة على الجهاز لسهولة العرض والتنقل بينها بدون إعادة تسجيل البيانات.
class SavedAccountsService extends GetxService {
  final _box = GetStorage();
  static const _kKey = 'seloo_saved_accounts_v1';
  final RxList<SavedAccountEntry> accounts = <SavedAccountEntry>[].obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    try {
      final raw = _box.read(_kKey);
      if (raw is List) {
        final list = raw
            .whereType<Map>()
            .map((e) => SavedAccountEntry.fromMap(Map<String, dynamic>.from(e)))
            .where((e) => e.uid.isNotEmpty)
            .toList()
          ..sort((a, b) => b.lastActiveMs.compareTo(a.lastActiveMs));
        accounts.assignAll(list);
      }
    } catch (_) {}
  }

  void record({
    required String uid,
    required String email,
    required String name,
    required String phone,
    required String role,
  }) {
    if (uid.trim().isEmpty) return;
    final entry = SavedAccountEntry(
      uid: uid,
      email: email.trim(),
      name: name.trim().isNotEmpty ? name.trim() : (email.trim().isNotEmpty ? email.trim() : 'حساب عميل'),
      phone: phone.trim(),
      role: role.isEmpty ? 'customer' : role,
      lastActiveMs: DateTime.now().millisecondsSinceEpoch,
    );
    final next = accounts.where((e) => e.uid != uid).toList();
    next.insert(0, entry);
    if (next.length > 12) next.removeRange(12, next.length);
    accounts.assignAll(next);
    try {
      _box.write(_kKey, next.map((e) => e.toMap()).toList());
    } catch (_) {}
  }

  void removeAccount(String uid) {
    final next = accounts.where((e) => e.uid != uid).toList();
    accounts.assignAll(next);
    try {
      _box.write(_kKey, next.map((e) => e.toMap()).toList());
    } catch (_) {}
  }
}
