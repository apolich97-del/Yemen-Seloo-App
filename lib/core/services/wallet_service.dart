import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

/// حركة في محفظة العميل.
class WalletMovement {
  WalletMovement(this.raw);
  final Map<String, dynamic> raw;

  String get id => (raw['id'] ?? '') as String;
  String get type => (raw['type'] ?? 'credit') as String; // credit | debit
  double get amountSar => ((raw['amountSar'] as num?) ?? 0).toDouble();
  double get amountLocal => ((raw['amountLocal'] as num?) ?? 0).toDouble();
  String get note => (raw['note'] ?? '') as String;
  DateTime? get at => (raw['at'] as Timestamp?)?.toDate();
}

/// محفظة العميل: رصيد بالريال + حركات + طلبات سحب نقدي.
class WalletService extends GetxService {
  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('wallets').doc(uid);

  Stream<Map<String, dynamic>?> watch([String? uid]) => _doc(uid ?? _uid)
      .snapshots()
      .map((d) => d.data());

  Future<double> balanceSar([String? uid]) async {
    final d = await _doc(uid ?? _uid).get();
    return ((d.data()?['balanceSar'] as num?) ?? 0).toDouble();
  }

  List<WalletMovement> movementsOf(Map<String, dynamic>? data) {
    final list = ((data?['movements'] as List?) ?? const []);
    final out = list
        .map((e) => WalletMovement(Map<String, dynamic>.from(e as Map)))
        .toList();
    out.sort((a, b) => (b.at ?? DateTime(2000)).compareTo(a.at ?? DateTime(2000)));
    return out;
  }

  /// إضافة رصيد (استرداد أو تعويض) — للفريق أو تلقائياً.
  Future<void> credit({
    required String uid,
    required double amountSar,
    required double amountLocal,
    String note = 'إضافة رصيد',
    String byName = '',
  }) async {
    if (amountSar <= 0) return;
    final ref = _doc(uid);
    final snap = await ref.get();
    final data = snap.data() ?? <String, dynamic>{};
    final cur = ((data['balanceSar'] as num?) ?? 0).toDouble();
    final moves = List<Map<String, dynamic>>.from(
        ((data['movements'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)));
    moves.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'type': 'credit',
      'amountSar': amountSar,
      'amountLocal': amountLocal,
      'note': note,
      'byName': byName,
      'at': Timestamp.now(),
    });
    await ref.set({
      'balanceSar': cur + amountSar,
      'movements': moves,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// خصم من الرصيد عند الشراء.
  Future<double> debit({
    required double amountSar,
    required double amountLocal,
    required String note,
  }) async {
    final ref = _doc(_uid);
    final snap = await ref.get();
    final data = snap.data() ?? <String, dynamic>{};
    final cur = ((data['balanceSar'] as num?) ?? 0).toDouble();
    final used = amountSar > cur ? cur : amountSar;
    if (used <= 0) return 0;
    final moves = List<Map<String, dynamic>>.from(
        ((data['movements'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)));
    moves.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'type': 'debit',
      'amountSar': used,
      'amountLocal': amountLocal,
      'note': note,
      'at': Timestamp.now(),
    });
    await ref.set({
      'balanceSar': cur - used,
      'movements': moves,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return used;
  }

  /// طلب سحب نقدي.
  Future<void> requestWithdrawal({
    required double amountSar,
    required double amountLocal,
    required String method, // bank | wallet
    required String accountName,
    required String accountNumber,
    required String holderName,
  }) async {
    await _db.collection('wallet_requests').add({
      'userId': _uid,
      'amountSar': amountSar,
      'amountLocal': amountLocal,
      'method': method,
      'accountName': accountName,
      'accountNumber': accountNumber,
      'holderName': holderName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> requests({bool mine = false}) {
    var q = _db.collection('wallet_requests').orderBy('createdAt', descending: true);
    if (mine) q = q.where('userId', isEqualTo: _uid) as Query<Map<String, dynamic>>;
    return q.snapshots();
  }

  /// إتمام السحب: خصم الرصيد وتسجيل رقم الحوالة.
  Future<void> completeRequest(String id, {String transferRefNo = ''}) async {
    final ref = _db.collection('wallet_requests').doc(id);
    final snap = await ref.get();
    final d = snap.data();
    if (d == null || d['status'] != 'pending') return;
    await debit(
      amountSar: ((d['amountSar'] as num?) ?? 0).toDouble(),
      amountLocal: ((d['amountLocal'] as num?) ?? 0).toDouble(),
      note: 'سحب نقدي — ${d['accountName']}',
    );
    await ref.update({
      'status': 'done',
      'transferRefNo': transferRefNo,
      'doneAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectRequest(String id, {String reason = ''}) =>
      _db.collection('wallet_requests').doc(id).update({
        'status': 'rejected',
        'reason': reason,
        'doneAt': FieldValue.serverTimestamp(),
      });
}
