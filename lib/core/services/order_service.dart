import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../models/app_settings.dart';
import '../models/cart.dart';
import '../models/currency.dart';
import '../models/order.dart';

/// كل كتابة على الطلبات تمرّ عبر Cloud Functions:
/// submitOrder / attachPayment / confirmPayment / advanceOrderStatus / requestExpedite.
/// التطبيق يقرأ فقط (Firestore rules تمنع الكتابة المباشرة على orders).
class OrderService extends GetxService {
  final _db = FirebaseFirestore.instance;
  final _fn = FirebaseFunctions.instanceFor(region: 'europe-west1');
  final _auth = FirebaseAuth.instance;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw 'يجب تسجيل الدخول أولاً';
    return u.uid;
  }

  Future<String> submitOrder({
    required List<CartLine> lines,
    required AppCurrency currency,
    required Address address,
    String couponCode = '',
    Map<String, dynamic>? payment,
    Map<String, dynamic>? commission,
  }) async {
    try {
      final res = await _fn.httpsCallable('submitOrder').call({
        'items': lines.map((e) => e.toServer()).toList(),
        'currency': currency.key,
        'address': address.toMap(),
        'couponCode': couponCode,
        if (payment != null) 'payment': payment,
        if (commission != null) 'commission': commission,
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      return (data['orderNo'] ?? data['orderId']) as String;
    } on FirebaseFunctionsException catch (e) {
      throw _msg(e);
    }
  }

  Future<void> attachPayment({
    required String orderId,
    required Map<String, dynamic> payment,
  }) async {
    try {
      await _fn.httpsCallable('attachPayment').call({'orderId': orderId, ...payment});
    } on FirebaseFunctionsException catch (e) {
      throw _msg(e);
    }
  }

  Future<void> requestExpedite(String orderId) async {
    try {
      await _fn.httpsCallable('requestExpedite').call({'orderId': orderId});
    } on FirebaseFunctionsException catch (e) {
      throw _msg(e);
    }
  }

  Future<void> advanceStatus({
    required String orderId,
    required OrderStatus to,
    String note = '',
    String trackingNo = '',
    String courierName = '',
    String proofUrl = '',
  }) async {
    try {
      await _fn.httpsCallable('advanceOrderStatus').call({
        'orderId': orderId,
        'to': to.key,
        'note': note,
        'trackingNo': trackingNo,
        'courierName': courierName,
        'proofUrl': proofUrl,
      });
    } on FirebaseFunctionsException catch (e) {
      throw _msg(e);
    }
  }

  Future<void> confirmPayment({required String orderId, bool approve = true, String note = ''}) async {
    try {
      await _fn.httpsCallable('confirmPayment').call({
        'orderId': orderId,
        'approve': approve,
        'note': note,
      });
    } on FirebaseFunctionsException catch (e) {
      throw _msg(e);
    }
  }

  // ── قراءات ──────────────────────────────────────────────────────────────
  Stream<List<Order>> myOrders({OrderStatus? status}) {
    Query q = _db.collection('orders').where('userId', isEqualTo: _uid);
    if (status != null) q = q.where('status', isEqualTo: status.key);
    return q.orderBy('createdAt', descending: true).limit(100).snapshots().map(
          (s) => s.docs.map((d) => Order.fromDoc(d.id, d.data() as Map<String, dynamic>)).toList(),
        );
  }

  Stream<Order?> watchOrder(String id) => _db.collection('orders').doc(id).snapshots().map(
        (d) => d.exists ? Order.fromDoc(d.id, d.data() as Map<String, dynamic>) : null,
      );

  Future<Order?> fetchOrder(String id) async {
    final d = await _db.collection('orders').doc(id).get();
    return d.exists ? Order.fromDoc(d.id, d.data() as Map<String, dynamic>) : null;
  }

  /// تحقق مبدئي من الكوبون للعرض فقط — التأكيد النهائي في السيرفر.
  Future<Coupon?> lookupCoupon(String code) async {
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return null;
    final d = await _db.collection('coupons').doc(c).get();
    if (!d.exists) return null;
    return Coupon.fromMap(c, d.data() as Map<String, dynamic>);
  }

  String _msg(FirebaseFunctionsException e) => switch (e.code) {
        'unauthenticated' => 'يجب تسجيل الدخول',
        'permission-denied' => 'لا تملك صلاحية لهذا الإجراء',
        'failed-precondition' => e.message ?? 'لا يمكن تنفيذ العملية في هذه الحالة',
        'invalid-argument' => e.message ?? 'بيانات غير صحيحة',
        _ => e.message ?? 'حدث خطأ غير متوقع',
      };
}

/// كمستخدم إداري: تيار كل الطلبات (يعمل فقط لحسابات الطاقم).
Stream<List<Order>> allOrdersStream({OrderStatus? status, int limit = 200}) {
  Query q = FirebaseFirestore.instance.collection('orders');
  if (status != null) q = q.where('status', isEqualTo: status.key);
  return q.orderBy('createdAt', descending: true).limit(limit).snapshots().map(
        (s) => s.docs.map((d) => Order.fromDoc(d.id, d.data() as Map<String, dynamic>)).toList(),
      );
}
