import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../models/cart.dart';
import '../models/currency.dart';
import '../models/order.dart';
import 'pricing_service.dart';

/// كتابة مباشرة في Firestore (بلا Cloud Functions). القواعد تمنع تعديل
/// الإجمالي أو الكتابة في طلبات الغير، والطاقم فقط يغيّر الحالة.
class OrderService extends GetxService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw 'يجب تسجيل الدخول أولاً';
    return u.uid;
  }

  String get _email => _auth.currentUser?.email ?? '';

  String _no(String id) {
    final d = DateTime.now();
    String t(int v) => v.toString().padLeft(2, '0');
    final c = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return 'YS${t(d.year % 100)}${t(d.month)}${t(d.day)}-${c.substring(c.length - 4)}';
  }

  Future<String> submitOrder({
    required List<CartLine> lines,
    required AppCurrency currency,
    required Address address,
    String couponCode = '',
    Map<String, dynamic>? payment,
    Map<String, dynamic>? commission,
    PriceEstimate? estimate,
  }) async {
    if (lines.isEmpty) throw 'السلة فارغة';
    if (estimate == null) throw 'أعد فتح شاشة الملخص لحساب الإجمالي';
    final e = estimate;
    final ref = _db.collection('orders').doc();
    final st = payment != null ? 'verifying' : 'unpaid';
    final pieces = lines.fold<int>(0, (s, l) => s + l.qty);
    final perPiece = (commission?['perPieceSar'] as num?)?.toDouble() ?? 0;

    await ref.set({
      'orderNo': _no(ref.id),
      'userId': _uid,
      'customerEmail': _email,
      'customerName': address.receiverName,
      'customerPhone': address.phone,
      'currency': currency.key,
      'exchangeRate': e.rate,
      'items': lines.map((l) => {
            'goodsId': l.goodsId,
            'sku': l.variantKey,
            'title': l.titleAr,
            'imageUrl': l.imageUrl,
            'color': l.color,
            'size': l.size,
            'qty': l.qty,
            'unitPriceSar': l.unitPriceSar,
            'productUrl': '',
          }).toList(),
      'deliveryMinDays': 15,
      'deliveryMaxDays': 20,
      'subtotalSar': e.subtotalSar,
      'shippingFeeSar': e.shippingFeeSar,
      'serviceFeeSar': e.serviceFeeSar,
      'deliveryFeeSar': e.deliveryFeeSar,
      'discountSar': e.discountSar,
      'totalSar': e.totalSar,
      'totalLocal': e.totalLocal,
      'couponCode': e.couponCode.isEmpty ? couponCode : e.couponCode,
      'address': address.toMap(),
      'status': st,
      'payment': payment,
      'commission': commission == null ? null : {
            'perPieceSar': perPiece,
            'approved': commission['approved'] ?? false,
            'totalSar': perPiece * pieces,
            'totalLocal': perPiece * pieces * e.rate,
          },
      'timeline': [{
        'status': st,
        'at': Timestamp.now(),
        'byName': 'العميل',
        'note': payment != null ? 'تم رفع بيانات الحوالة' : 'تم إنشاء الطلب',
      }],
      'revision': 1,
      'editingLocked': payment != null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }
  Future<void> attachPayment({
    required String orderId,
    required Map<String, dynamic> payment,
  }) async {
    final r = _db.collection('orders').doc(orderId);
    await r.update({
      'payment': payment,
      'status': 'verifying',
      'editingLocked': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await r.collection('events').add({
      'status': 'verifying',
      'at': Timestamp.now(),
      'byName': 'العميل',
      'note': 'تم رفع بيانات الحوالة',
    });
  }

  Future<void> requestExpedite(String orderId) async {
    await _db.collection('orders').doc(orderId).update({
      'expediteRequestedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> advanceStatus({
    required String orderId,
    required OrderStatus to,
    String note = '',
    String trackingNo = '',
    String courierName = '',
    String proofUrl = '',
  }) async {
    final r = _db.collection('orders').doc(orderId);
    await r.update({
      'status': to.key,
      if (trackingNo.isNotEmpty) 'trackingNo': trackingNo,
      if (courierName.isNotEmpty) 'courierName': courierName,
      if (proofUrl.isNotEmpty) 'proofImageUrl': proofUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await r.collection('events').add({
      'status': to.key,
      'at': Timestamp.now(),
      'byName': _email,
      'note': note,
    });
  }

  Future<void> confirmPayment({
    required String orderId,
    bool approve = true,
    String note = '',
  }) async {
    await advanceStatus(
      orderId: orderId,
      to: approve ? OrderStatus.processing : OrderStatus.cancelled,
      note: note.isEmpty
          ? (approve ? 'تم التحقق من الحوالة' : 'الحوالة غير مطابقة')
          : note,
    );
  }

  Future<Map<String, dynamic>> updateOrderDraft({
    required String orderId,
    required List<CartLine> lines,
    required AppCurrency currency,
    String couponCode = '',
    String note = '',
  }) async =>
      throw 'تعديل الطلب بعد الإرسال غير متاح';

  Future<Map<String, dynamic>> approveDraftOrder(String orderId) async =>
      throw 'اعتماد المسودة غير متاح';

  Stream<List<Order>> myOrders({OrderStatus? status}) {
    Query q = _db.collection('orders').where('userId', isEqualTo: _uid);
    if (status != null) q = q.where('status', isEqualTo: status.key);
    return q.orderBy('createdAt', descending: true).limit(100).snapshots().map(
          (s) => s.docs
              .map((d) => Order.fromDoc(d.id, d.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  Stream<Order?> watchOrder(String id) =>
      _db.collection('orders').doc(id).snapshots().map((d) =>
          d.exists ? Order.fromDoc(d.id, d.data() as Map<String, dynamic>) : null);

  Future<Order?> fetchOrder(String id) async {
    final d = await _db.collection('orders').doc(id).get();
    return d.exists ? Order.fromDoc(d.id, d.data() as Map<String, dynamic>) : null;
  }

  Future<Coupon?> lookupCoupon(String code) async {
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return null;
    final d = await _db.collection('coupons').doc(c).get();
    if (!d.exists) return null;
    return Coupon.fromMap(c, d.data() as Map<String, dynamic>);
  }
}

Stream<List<Order>> allOrdersStream({OrderStatus? status, int limit = 200}) {
  Query q = FirebaseFirestore.instance.collection('orders');
  if (status != null) q = q.where('status', isEqualTo: status.key);
  return q.orderBy('createdAt', descending: true).limit(limit).snapshots().map(
        (s) => s.docs
            .map((d) => Order.fromDoc(d.id, d.data() as Map<String, dynamic>))
            .toList(),
      );
}
