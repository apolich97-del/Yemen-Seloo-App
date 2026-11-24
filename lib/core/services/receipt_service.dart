import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:get/get.dart';

import '../models/order.dart';
import '../models/receipt.dart';

/// نظام «إيصال»: كل تحديث للأرصدة يمر عبر معاملة ذرّية.
class ReceiptService extends GetxService {
  final _db = FirebaseFirestore.instance;

  /// عدّاد ذري لرقم الإيصال RCP-0001.
  Future<String> _nextNo(Transaction tx) async {
    final ref = _db.collection('counters').doc('receipts');
    final snap = await tx.get(ref);
    final n = ((snap.data()?['value'] as num?)?.toInt() ?? 0) + 1;
    tx.set(ref, {'value': n}, SetOptions(merge: true));
    return 'RCP-${n.toString().padLeft(4, '0')}';
  }

  /// إيصالات طلب معيّن (للعميل والطاقم).
  Stream<List<Receipt>> forOrder(String orderId) => _db
      .collection('orders')
      .doc(orderId)
      .collection('receipts')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs
          .map((d) => Receipt.fromDoc(d.id, d.data()))
          .toList());

  /// كل إيصالات عميل معيّن — يدعم collectionGroup مع احتياطي من الطلبات عند عدم توفر الفهرس.
  Stream<List<Receipt>> byCustomer(String uid) => _resilientReceiptsStream(
        primary: _db
            .collectionGroup('receipts')
            .where('customerId', isEqualTo: uid)
            .limit(100)
            .snapshots(),
        fallbackOrders: _db
            .collection('orders')
            .where('userId', isEqualTo: uid)
            .limit(40)
            .snapshots(),
      );

  /// آخر الإيصالات بانتظار المراجعة (لوحة المحاسبة).
  Stream<List<Receipt>> pending() => _resilientReceiptsStream(
        primary: _db
            .collectionGroup('receipts')
            .where('status', isEqualTo: 'pending')
            .limit(100)
            .snapshots(),
        fallbackOrders: _db.collection('orders').limit(50).snapshots(),
        statusFilter: 'pending',
      );

  /// آخر الإيصالات المعتمدة.
  Stream<List<Receipt>> approved() => _resilientReceiptsStream(
        primary: _db
            .collectionGroup('receipts')
            .where('status', isEqualTo: 'approved')
            .limit(100)
            .snapshots(),
        fallbackOrders: _db.collection('orders').limit(50).snapshots(),
        statusFilter: 'approved',
      );

  Stream<List<Receipt>> _resilientReceiptsStream({
    required Stream<QuerySnapshot<Map<String, dynamic>>> primary,
    required Stream<QuerySnapshot<Map<String, dynamic>>> fallbackOrders,
    String? statusFilter,
  }) {
    late StreamController<List<Receipt>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? primarySub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? fallbackSub;
    var switchedToFallback = false;

    void startFallback() {
      if (switchedToFallback || controller.isClosed) return;
      switchedToFallback = true;
      fallbackSub = fallbackOrders.listen(
        (ordersSnap) async {
          try {
            final results = await Future.wait(
              ordersSnap.docs.take(30).map((orderDoc) async {
                try {
                  Query<Map<String, dynamic>> q =
                      orderDoc.reference.collection('receipts');
                  if (statusFilter != null) {
                    q = q.where('status', isEqualTo: statusFilter);
                  }
                  final snap = await q.limit(20).get();
                  return snap.docs
                      .map((d) => Receipt.fromDoc(d.id, d.data()))
                      .toList();
                } catch (_) {
                  return const <Receipt>[];
                }
              }),
            );
            final merged = results.expand((e) => e).toList()
              ..sort((a, b) => (b.createdAt ?? DateTime(2000))
                  .compareTo(a.createdAt ?? DateTime(2000)));
            if (!controller.isClosed) controller.add(merged);
          } catch (_) {
            if (!controller.isClosed) controller.add(const <Receipt>[]);
          }
        },
        onError: (_) {
          if (!controller.isClosed) controller.add(const <Receipt>[]);
        },
      );
    }

    controller = StreamController<List<Receipt>>(
      onListen: () {
        primarySub = primary.listen(
          (snap) {
            final list = snap.docs
                .map((d) => Receipt.fromDoc(d.id, d.data()))
                .toList()
              ..sort((a, b) => (b.createdAt ?? DateTime(2000))
                  .compareTo(a.createdAt ?? DateTime(2000)));
            if (!controller.isClosed) controller.add(list);
          },
          onError: (_) => startFallback(),
        );
      },
      onCancel: () async {
        await primarySub?.cancel();
        await fallbackSub?.cancel();
      },
    );
    return controller.stream;
  }

  /// إنشاء إيصال (مصدره العميل أو الإدارة).
  Future<String> create({
    required Order order,
    required double amountLocal,
    required String refNo,
    required String senderName,
    required String note,
    required String proofUrl,
    required String source,
    Map<String, dynamic>? verification,
  }) async {
    final receiptRef =
        _db.collection('orders').doc(order.id).collection('receipts').doc();
    late String no;
    await _db.runTransaction((tx) async {
      no = await _nextNo(tx);
      tx.set(receiptRef, {
        'receiptNo': no,
        'orderId': order.id,
        'orderNo': order.orderNo,
        'customerId': order.userId,
        'status': source == 'admin' ? 'approved' : 'pending',
        'source': source,
        'amountLocal': amountLocal,
        'amountSar': amountLocal / (order.exchangeRate == 0 ? 1 : order.exchangeRate),
        'refNo': refNo,
        'senderName': senderName,
        'note': note,
        'proofUrl': proofUrl,
        'verification': verification ?? <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return no;
  }

  /// يجد إيصالاً برقمه داخل طلب.
  Future<Receipt?> byReceiptNo(String orderId, String receiptNo) async {
    final snap = await _db
        .collection('orders')
        .doc(orderId)
        .collection('receipts')
        .where('receiptNo', isEqualTo: receiptNo)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return Receipt.fromDoc(d.id, d.data());
  }

  /// اعتماد إيصال: خصم المبلغ من المتبقي وتحديث الأرصدة والإيصال.
  Future<void> approve({
    required Order order,
    required Receipt receipt,
    String reviewer = '',
    bool markPaidNow = false,
  }) async {
    final orderRef = _db.collection('orders').doc(order.id);
    final receiptRef = orderRef.collection('receipts').doc(receipt.id);

    await _db.runTransaction((tx) async {
      final orderSnap = await tx.get(orderRef);
      final data = orderSnap.data() ?? <String, dynamic>{};
      final total = (data['totalLocal'] as num?)?.toDouble() ?? order.totalLocal;
      final paid = (data['paidTotalLocal'] as num?)?.toDouble() ?? 0;
      final paidNow = paid + (markPaidNow ? order.upfrontDueLocal : 0) + receipt.amountLocal;
      final remaining = total - paidNow;
      final payment = Map<String, dynamic>.from(
          (data['payment'] as Map<String, dynamic>?) ?? <String, dynamic>{});
      if (remaining < 0) {
        payment['creditLocal'] =
            (((payment['creditLocal'] as num?)?.toDouble() ?? 0) - remaining);
      }

      tx.update(orderRef, {
        'paidTotalLocal': paidNow,
        'remainingLocal': remaining < 0 ? 0.0 : remaining,
        'payment': payment,
        if ((data['status'] as String?) == 'unpaid' ||
            (data['status'] as String?) == 'verifying')
          'status': 'processing',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.update(receiptRef, {
        'status': 'approved',
        'remainingAfterLocal': remaining < 0 ? 0.0 : remaining,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': reviewer,
      });
    });
  }

  /// رفض إيصال دون تعديل الأرصدة.
  Future<void> reject({
    required Order order,
    required Receipt receipt,
    required String reason,
    String reviewer = '',
  }) =>
      _db
          .collection('orders')
          .doc(order.id)
          .collection('receipts')
          .doc(receipt.id)
          .update({
        'status': 'rejected',
        'rejectReason': reason,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': reviewer,
      });
}
