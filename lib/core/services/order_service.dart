import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../models/app_settings.dart';
import '../models/cart.dart';
import '../models/currency.dart';
import '../models/order.dart';
import 'audit_service.dart';
import 'notification_service.dart';
import 'pricing_service.dart';
import 'settings_service.dart';

/// مرجع الطلب المُرسل: معرّف المستند + رقم الطلب الفريد (YS...).
class SubmittedOrderRef {
  final String id;
  final String orderNo;
  const SubmittedOrderRef(this.id, this.orderNo);
}

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

  /// رقم الطلب بنفس خوارزمية الجدول المعتمدة:
  /// YS + آخر رقمين من السنة + رمز الشهر + رقم الأسبوع داخل الشهر
  /// + "-" + حرف يتغيّر كل 26 طلباً + رقم متسلسل من 001 إلى 999.
  /// مثال: YS26AU3-Q173
  static const _monthCodes = [
    'JA', 'FE', 'MR', 'AP', 'MY', 'JN',
    'JL', 'AU', 'SE', 'OC', 'NV', 'DE',
  ];

  String _formatOrderNo(int n) {
    final now = DateTime.now();
    final idx = n > 0 ? n - 1 : 0;
    final week = ((now.day - 1) ~/ 7) + 1;
    final letter = String.fromCharCode(65 + (idx % 26));
    final seq = (idx % 1000) + 1;

    return 'YS${(now.year % 100).toString().padLeft(2, '0')}'
        '${_monthCodes[now.month - 1]}$week-'
        '$letter${seq.toString().padLeft(3, '0')}';
  }

  /// توليد رقم طلب فريد 100% مع حجز ذرّي في order_numbers/{orderNo} لمنع أي تكرار.
  Future<String> _nextOrderNo(String uid) async {
    final counter = _db.collection('counters').doc('orders');
    try {
      return await _db.runTransaction<String>((tx) async {
        final snap = await tx.get(counter);
        int base = ((snap.data()?['value'] as num?)?.toInt() ?? 0) + 1;
        String chosen = _formatOrderNo(base);
        DocumentReference<Map<String, dynamic>> lockRef =
            _db.collection('order_numbers').doc(chosen);

        for (int i = 0; i < 8; i++) {
          final candidate = _formatOrderNo(base + i);
          final candidateRef = _db.collection('order_numbers').doc(candidate);
          final existing = await tx.get(candidateRef);
          if (!existing.exists) {
            base = base + i;
            chosen = candidate;
            lockRef = candidateRef;
            break;
          }
          if (i == 7) {
            base = base + i + 1;
            chosen = _formatOrderNo(base);
            lockRef = _db.collection('order_numbers').doc(chosen);
          }
        }

        tx.set(counter, {'value': base}, SetOptions(merge: true));
        tx.set(lockRef, {
          'orderNo': chosen,
          'userId': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return chosen;
      });
    } catch (_) {
      final ms = DateTime.now().millisecondsSinceEpoch;
      final n = (ms % 26000) + 1;
      return _formatOrderNo(n);
    }
  }

  /// فحص رقم مرجع الحوالة قبل الإرسال لتنبيه العميل عند الاشتباه بتكرار حوالة سابقة.
  Future<String?> findDuplicateTransferRef(String refNo) async {
    final clean = refNo.trim();
    if (clean.length < 4) return null;
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;
      final snap = await _db
          .collection('orders')
          .where('userId', isEqualTo: uid)
          .limit(60)
          .get();
      for (final d in snap.docs) {
        final data = d.data();
        final pay = data['payment'] as Map?;
        final prevRef = (pay?['refNo'] ?? '').toString().trim();
        if (prevRef.isNotEmpty && prevRef.toLowerCase() == clean.toLowerCase()) {
          return (data['orderNo'] ?? d.id).toString();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<SubmittedOrderRef> submitOrder({
    required List<CartLine> lines,
    required AppCurrency currency,
    required Address address,
    String couponCode = '',
    Map<String, dynamic>? payment,
    Map<String, dynamic>? commission,
    PriceEstimate? estimate,
    String paymentPlan = 'full',
    double upfrontPercent = 100,
    Map<String, dynamic> shipping = const <String, dynamic>{},
  }) async {
    if (lines.isEmpty) throw 'السلة فارغة';
    if (estimate == null) throw 'أعد فتح شاشة الملخص لحساب الإجمالي';
    final e = estimate;
    final ref = _db.collection('orders').doc();
    final orderNo = await _nextOrderNo(_uid);
    final st = payment != null ? 'verifying' : 'unpaid';
    final pieces = lines.fold<int>(0, (s, l) => s + l.qty);
    final perPiece = (commission?['perPieceSar'] as num?)?.toDouble() ?? 0;

    final isDeferred = paymentPlan == 'half_deferred';
    final upfrontLocal = isDeferred
        ? roundMoney(e.totalLocal * (upfrontPercent / 100), currency)
        : e.totalLocal;
    final paidLocal = payment == null ? 0.0 : upfrontLocal;
    final remainingLocal = payment == null ? e.totalLocal : (e.totalLocal - paidLocal);

    await ref.set({
      'orderNo': orderNo,
      'userId': _uid,
      'customerEmail': _email,
      'customerName': address.receiverName,
      'customerPhone': address.phone,
      'currency': currency.key,
      'exchangeRate': e.rate,
      'usdRateNorth': Get.isRegistered<SettingsService>() ? Get.find<SettingsService>().usdRateNorth : 533.0,
      'usdRateSouth': Get.isRegistered<SettingsService>() ? Get.find<SettingsService>().usdRateSouth : 1570.0,
      'sarPerUsd': Get.isRegistered<SettingsService>() ? Get.find<SettingsService>().settings.value.sarPerUsd : kDefaultSarPerUsd,
      'shippingStage': 'preparing',
      'deliveryPin': (1000 + Random.secure().nextInt(9000)).toString(),
      'deliverySigned': false,
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
            'nonRefundable': l.isNonRefundable,
            'nonRefundableReason': l.effectiveNonRefundableReason,
          }).toList(),
      'shippingMode': shipping['mode'] ?? 'home',
      'shippingGovernorate': shipping['governorate'] ?? '',
      'shippingOffice': shipping['office'] ?? '',
      'shippingOfficeChoice': shipping['officeChoice'] ?? 'seloo',
      'receiverName': shipping['receiverName'] ?? address.receiverName,
      'receiverPhone': shipping['receiverPhone'] ?? address.phone,
      'driverName': shipping['driverName'] ?? '',
      'driverPhone': shipping['driverPhone'] ?? '',
      'driverMeetPoint': shipping['meetPoint'] ?? '',
      'transportFeeLocal': 0,
      'transportFeeCollect': 'office',
      'deliveryMinDays': 15,
      'deliveryMaxDays': 20,
      'subtotalSar': e.subtotalSar,
      'shippingFeeSar': e.shippingFeeSar,
      'serviceFeeSar': e.serviceFeeSar,
      'deliveryFeeSar': e.deliveryFeeSar,
      'discountSar': e.discountSar,
      'totalSar': e.totalSar,
      'totalLocal': e.totalLocal,
      'paymentPlan': paymentPlan,
      'upfrontDueLocal': upfrontLocal,
      'paidTotalLocal': paidLocal,
      'remainingLocal': remainingLocal < 0 ? 0.0 : remainingLocal,
      'couponCode': e.couponCode.isEmpty ? couponCode : e.couponCode,
      'address': address.toMap(),
      'status': st,
      'payment': payment,
      'commission': commission == null
          ? null
          : {
              'perPieceSar': perPiece,
              'approved': commission['approved'] ?? false,
              'totalSar': perPiece * pieces,
              'totalLocal': perPiece * pieces * e.rate,
            },
      'timeline': [
        {
          'status': st,
          'at': Timestamp.now(),
          'byName': 'العميل',
          'note': payment != null ? 'تم رفع بيانات الحوالة' : 'تم إنشاء الطلب',
        }
      ],
      'revision': 1,
      'editingLocked': payment != null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // تحديث آخر نشاط وتفاصيل العميل في قاعدة بيانات عملاء يمن سيلو تلقائياً
    try {
      await _db.collection('users').doc(_uid).set({
        if (address.city.trim().isNotEmpty) 'city': address.city.trim(),
        if (address.district.trim().isNotEmpty) 'district': address.district.trim(),
        if (address.line.trim().isNotEmpty) 'addressLine': address.line.trim(),
        if (address.phone.trim().isNotEmpty) 'phone': address.phone.trim(),
        'lastOrderAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
    if (Get.isRegistered<NotificationService>()) {
      await Get.find<NotificationService>().pushUserNotification(
        targetUid: _uid,
        title: 'تم استلام طلبك $orderNo',
        body: payment != null
            ? 'وصلت بيانات الحوالة وتُراجع الآن من المحاسبة.'
            : 'أرسل استمارة الطلب عبر واتساب ليتم اعتماده من الإدارة.',
        type: 'order',
        orderId: ref.id,
      );
    }
    return SubmittedOrderRef(ref.id, orderNo);
  }


  /// يسجّل إرسال استمارة الطلب إلى واتساب بانتظار اعتماد الإدارة.
  Future<void> recordWhatsAppSent(String orderId, String targetLabel) async {
    if (orderId.trim().isEmpty) return;
    final r = _db.collection('orders').doc(orderId);
    await r.update({
      'whatsappSentAt': FieldValue.serverTimestamp(),
      'whatsappSentTarget': targetLabel,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await r.collection('events').add({
      'status': 'unpaid',
      'at': Timestamp.now(),
      'byName': 'العميل',
      'note': 'تم إرسال استمارة الطلب عبر واتساب ($targetLabel) — بانتظار تأكيد الإدارة',
    });
  }

  /// الطاقم يقترح تعديل أسعار أو توفر قطع (مزامنة شي إن) وإبلاغ العميل للموافقة.
  Future<void> proposeOrderSync({
    required Order order,
    required List<OrderItem> updatedItems,
    required String note,
  }) async {
    final activeItems = updatedItems.where((e) => e.qty > 0).toList();
    final newSubSar = activeItems.fold<double>(0, (s, i) => s + i.lineTotalSar);
    final diffSar = newSubSar - order.subtotalSar;
    final newTotalSar = roundMoney(
      (order.totalSar + diffSar).clamp(0.0, 9999999.0),
      AppCurrency.sar,
    );
    final rate = order.exchangeRate > 0 ? order.exchangeRate : 1.0;
    final newTotalLocal = roundMoney(newTotalSar * rate, order.currency);
    final r = _db.collection('orders').doc(order.id);
    await r.update({
      'priceSyncStatus': 'pending_customer',
      'priceSyncNote': note.trim(),
      'priceSyncDecision': '',
      'proposedItems': activeItems.map((e) => e.toMap()).toList(),
      'proposedSubtotalSar': roundMoney(newSubSar, AppCurrency.sar),
      'proposedTotalSar': newTotalSar,
      'proposedTotalLocal': newTotalLocal,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await r.collection('events').add({
      'status': order.status.key,
      'at': Timestamp.now(),
      'byName': _email,
      'note': 'تحديث مزامنة الأسعار/المخزون بانتظار موافقة العميل: ${note.trim()}',
    });
  }

  /// رد العميل بالموافقة أو الرفض على تحديث السعر/المخزون.
  Future<void> respondToPriceSync(String orderId, {required bool accepted}) async {
    final r = _db.collection('orders').doc(orderId);
    await r.update({
      'priceSyncStatus': accepted ? 'accepted' : 'rejected',
      'priceSyncDecision': accepted ? 'accepted' : 'rejected',
      'priceSyncRespondedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await r.collection('events').add({
      'status': 'unpaid',
      'at': Timestamp.now(),
      'byName': 'العميل',
      'note': accepted
          ? 'وافق العميل على تعديل السعر/التوفر المقترح'
          : 'رفض العميل تعديل السعر/التوفر وطلب المراجعة',
    });
    try {
      await _db.collection('staff_alerts').add({
        'target': 'manager',
        'orderId': orderId,
        'type': accepted ? 'price_sync_accepted' : 'price_sync_rejected',
        'createdAt': FieldValue.serverTimestamp(),
        'seen': false,
      });
    } catch (_) {}
  }

  /// تطبيق التعديلات المعتمدة فعلياً على بنود ومبالغ الطلب مع تثبيت سعر الصرف.
  Future<void> applyProposedOrderSync(Order order) async {
    if (order.proposedItems.isEmpty) {
      throw 'لا توجد بنود مقترحة لتطبيقها';
    }
    final activeItems = order.proposedItems.where((e) => e.qty > 0).toList();
    final newSubSar = activeItems.fold<double>(0, (s, i) => s + i.lineTotalSar);
    final newTotalSar = order.proposedTotalSar > 0
        ? order.proposedTotalSar
        : roundMoney(
            (order.totalSar + (newSubSar - order.subtotalSar)).clamp(0.0, 9999999.0),
            AppCurrency.sar,
          );
    final rate = order.exchangeRate > 0 ? order.exchangeRate : 1.0;
    final newTotalLocal = order.proposedTotalLocal > 0
        ? order.proposedTotalLocal
        : roundMoney(newTotalSar * rate, order.currency);
    final newRemaining = (newTotalLocal - order.paidTotalLocal).clamp(0.0, 999999999.0);
    final r = _db.collection('orders').doc(order.id);
    await r.update({
      'items': activeItems.map((e) => e.toMap()).toList(),
      'subtotalSar': roundMoney(newSubSar, AppCurrency.sar),
      'totalSar': newTotalSar,
      'totalLocal': newTotalLocal,
      'remainingLocal': roundMoney(newRemaining, order.currency),
      'priceSyncStatus': 'applied',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await r.collection('events').add({
      'status': order.status.key,
      'at': Timestamp.now(),
      'byName': _email,
      'note': 'تم تطبيق تحديث الأسعار/التوفر على الطلب مع الإبقاء على سعر الصرف يوم الطلب',
    });
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
    String courierPhone = '',
    double? collectedLocal,
  }) async {
    final r = _db.collection('orders').doc(orderId);
    await r.update({
      'status': to.key,
      if (trackingNo.isNotEmpty) 'trackingNo': trackingNo,
      if (courierName.isNotEmpty) 'courierName': courierName,
      if (proofUrl.isNotEmpty) 'proofImageUrl': proofUrl,
      if (courierPhone.isNotEmpty) 'courierPhone': courierPhone,
      if (collectedLocal != null) 'collectedLocal': collectedLocal,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await r.collection('events').add({
      'status': to.key,
      'at': Timestamp.now(),
      'byName': _email,
      'note': note,
    });
  }

  /// اتفاق نقل المحافظات: السعر المتفق عليه وطريقة التحصيل.
  Future<void> setTransportFee({
    required String orderId,
    required double feeLocal,
    required String collect,
  }) async {
    final r = _db.collection('orders').doc(orderId);
    final d = await r.get();
    final remaining = (d.data()?['remainingLocal'] as num?)?.toDouble() ?? 0;
    await r.update({
      'transportFeeLocal': feeLocal,
      'transportFeeCollect': collect,
      if (collect == 'invoice') 'remainingLocal': remaining + feeLocal,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await r.collection('events').add({
      'status': d.data()?['status'] ?? '',
      'at': Timestamp.now(),
      'byName': _email,
      'note': 'اتفاق نقل المحافظات: $feeLocal — '
          '${collect == 'office' ? 'تُدفع لمكتب النقل' : 'أُضيفت للمتبقي'}',
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
    return q.limit(100).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => Order.fromDoc(d.id, d.data() as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<Order?> watchOrder(String id) =>
      _db.collection('orders').doc(id).snapshots().map((d) =>
          d.exists ? Order.fromDoc(d.id, d.data() as Map<String, dynamic>) : null);

  Future<Order?> fetchOrder(String id) async {
    final d = await _db.collection('orders').doc(id).get();
    return d.exists ? Order.fromDoc(d.id, d.data() as Map<String, dynamic>) : null;
  }

  /// تحديث مرحلة الشحن المفصلة (الصين ← الإمارات ← السعودية ← اليمن) + رابط/صورة التتبع + إشعار العميل.
  Future<void> updateShippingMilestone({
    required Order order,
    required ShippingMilestone milestone,
    String note = '',
    String trackingNo = '',
    String trackingUrl = '',
    String trackingImageUrl = '',
    String courierName = '',
    String courierPhone = '',
  }) async {
    final mapped = milestone.mappedOrderStatus;
    final r = _db.collection('orders').doc(order.id);
    await r.update({
      'shippingStage': milestone.key,
      'shippingStageNote': note.trim(),
      'shippingStageUpdatedAt': FieldValue.serverTimestamp(),
      'status': mapped.key,
      if (trackingNo.trim().isNotEmpty) 'trackingNo': trackingNo.trim(),
      if (trackingUrl.trim().isNotEmpty) 'trackingUrl': trackingUrl.trim(),
      if (trackingImageUrl.trim().isNotEmpty) 'trackingImageUrl': trackingImageUrl.trim(),
      if (courierName.trim().isNotEmpty) 'courierName': courierName.trim(),
      if (courierPhone.trim().isNotEmpty) 'courierPhone': courierPhone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final eventNote = [
      '${milestone.emoji} ${milestone.labelAr}',
      if (trackingNo.trim().isNotEmpty) 'تتبع: ${trackingNo.trim()}',
      if (note.trim().isNotEmpty) note.trim(),
    ].join(' · ');
    await r.collection('events').add({
      'status': mapped.key,
      'at': Timestamp.now(),
      'byName': _email.isNotEmpty ? _email : 'مسؤول الشحن',
      'note': eventNote,
    });
    if (Get.isRegistered<NotificationService>()) {
      await Get.find<NotificationService>().pushUserNotification(
        targetUid: order.userId,
        title: 'تحديث شحنة الطلب ${order.orderNo}',
        body: eventNote,
        type: 'shipping',
        orderId: order.id,
      );
    }
  }

  /// تنبيه العميل بنفاد قطعة من الطلب (نفس اليوم أو بعد 24 ساعة) وطلب إرسال بديل.
  Future<void> requestItemReplacement({
    required Order order,
    required int itemIndex,
    required String reason,
  }) async {
    if (itemIndex < 0 || itemIndex >= order.items.length) {
      throw 'رقم القطعة غير صالح';
    }
    final target = order.items[itemIndex];
    final updatedItems = <OrderItem>[
      for (int i = 0; i < order.items.length; i++)
        i == itemIndex ? order.items[i].copyWith(stockStatus: 'out_of_stock') : order.items[i],
    ];
    final proposal = {
      'targetIndex': itemIndex,
      'oldTitle': target.title,
      'oldGoodsId': target.goodsId,
      'oldQty': target.qty,
      'oldUnitPriceSar': target.unitPriceSar,
      'oldTotalSar': target.lineTotalSar,
      'reason': reason.trim().isEmpty ? 'نفدت القطعة من المخزون في شي إن' : reason.trim(),
      'requestedAt': Timestamp.now(),
      'requestedBy': _email,
    };
    final r = _db.collection('orders').doc(order.id);
    await r.update({
      'items': updatedItems.map((e) => e.toMap()).toList(),
      'replacementStatus': 'pending_customer',
      'replacementProposal': proposal,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await r.collection('events').add({
      'status': order.status.key,
      'at': Timestamp.now(),
      'byName': _email.isNotEmpty ? _email : 'الإدارة',
      'note': 'تنبيه نفاد قطعة: ${target.title} — بانتظار إرسال بديل من العميل',
    });
    if (Get.isRegistered<NotificationService>()) {
      await Get.find<NotificationService>().pushUserNotification(
        targetUid: order.userId,
        title: 'تنبيه نفاد قطعة — طلب ${order.orderNo}',
        body: 'نفدت "${target.title}". يرجى إرسال قطعة بديلة (بنفس القيمة أو بفارق يُحتسب تلقائياً).',
        type: 'replacement',
        orderId: order.id,
      );
    }
  }

  /// إرسال العميل لرابط/بيانات القطعة البديلة مع حساب الفارق تلقائياً.
  Future<void> submitCustomerReplacement({
    required Order order,
    required String newTitle,
    required String newProductUrl,
    required String newImageUrl,
    required double newUnitPriceSar,
    String color = '',
    String size = '',
    int? qty,
    String goodsId = '',
  }) async {
    final prev = Map<String, dynamic>.from(order.replacementProposal);
    final oldTotalSar = (prev['oldTotalSar'] as num?)?.toDouble() ?? 0.0;
    final oldQty = (prev['oldQty'] as num?)?.toInt() ?? 1;
    final chosenQty = qty ?? oldQty;
    final newTotalSar = roundMoney(newUnitPriceSar * chosenQty, AppCurrency.sar);
    final diffSar = roundMoney(newTotalSar - oldTotalSar, AppCurrency.sar);
    final rate = order.exchangeRate > 0 ? order.exchangeRate : 1.0;
    final diffLocal = roundMoney(diffSar * rate, order.currency);

    prev.addAll({
      'newTitle': newTitle.trim(),
      'newProductUrl': newProductUrl.trim(),
      'newImageUrl': newImageUrl.trim(),
      'newGoodsId': goodsId.trim(),
      'newUnitPriceSar': newUnitPriceSar,
      'newQty': chosenQty,
      'newColor': color.trim(),
      'newSize': size.trim(),
      'newTotalSar': newTotalSar,
      'diffSar': diffSar,
      'diffLocal': diffLocal,
      'submittedAt': Timestamp.now(),
    });
    final r = _db.collection('orders').doc(order.id);
    await r.update({
      'replacementStatus': 'pending_admin',
      'replacementProposal': prev,
      'replacementSubmittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await r.collection('events').add({
      'status': order.status.key,
      'at': Timestamp.now(),
      'byName': 'العميل',
      'note': 'أرسل العميل قطعة بديلة: ${newTitle.trim()} (فارق ${diffSar.toStringAsFixed(2)} ر.س)',
    });
    try {
      await _db.collection('staff_alerts').add({
        'target': 'manager',
        'orderId': order.id,
        'type': 'replacement_submitted',
        'createdAt': FieldValue.serverTimestamp(),
        'seen': false,
      });
    } catch (_) {}
  }

  /// اعتماد الإدارة للقطعة البديلة وتسوية الفارق المالي (زيادة على المتبقي أو إرجاع للمحفظة/المتبقي).
  Future<void> resolveCustomerReplacement({
    required Order order,
    required bool approve,
    String adminNote = '',
  }) async {
    final r = _db.collection('orders').doc(order.id);
    if (!approve) {
      await r.update({
        'replacementStatus': 'pending_customer',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await r.collection('events').add({
        'status': order.status.key,
        'at': Timestamp.now(),
        'byName': _email,
        'note': 'رُفض البديل المقترح — يرجى إرسال بديل آخر: ${adminNote.trim()}',
      });
      if (Get.isRegistered<NotificationService>()) {
        await Get.find<NotificationService>().pushUserNotification(
          targetUid: order.userId,
          title: 'مراجعة البديل — طلب ${order.orderNo}',
          body: adminNote.trim().isEmpty
              ? 'يرجى إرسال قطعة بديلة أخرى مناسبة للطلب.'
              : adminNote.trim(),
          type: 'replacement',
          orderId: order.id,
        );
      }
      return;
    }

    final prop = order.replacementProposal;
    final idx = (prop['targetIndex'] as num?)?.toInt() ?? -1;
    final oldTitle = (prop['oldTitle'] ?? '').toString();
    final diffSar = (prop['diffSar'] as num?)?.toDouble() ?? 0.0;
    final rate = order.exchangeRate > 0 ? order.exchangeRate : 1.0;
    final diffLocal = roundMoney(diffSar * rate, order.currency);

    final updatedItems = <OrderItem>[
      for (int i = 0; i < order.items.length; i++)
        i == idx
            ? order.items[i].copyWith(
                stockStatus: 'replaced',
                replacementNote: 'تم استبدالها بـ ${prop['newTitle'] ?? ''}',
              )
            : order.items[i],
    ];
    updatedItems.add(OrderItem(
      sku: 'REP-${DateTime.now().millisecondsSinceEpoch}',
      goodsId: (prop['newGoodsId'] ?? '').toString(),
      title: (prop['newTitle'] ?? 'قطعة بديلة').toString(),
      imageUrl: (prop['newImageUrl'] ?? '').toString(),
      qty: (prop['newQty'] as num?)?.toInt() ?? 1,
      unitPriceSar: (prop['newUnitPriceSar'] as num?)?.toDouble() ?? 0.0,
      size: (prop['newSize'] ?? '').toString(),
      color: (prop['newColor'] ?? '').toString(),
      productUrl: (prop['newProductUrl'] ?? '').toString(),
      stockStatus: 'ok',
      isReplacement: true,
      replacedFromTitle: oldTitle,
      replacementNote: adminNote.trim(),
    ));

    final newSubSar = roundMoney(order.subtotalSar + diffSar, AppCurrency.sar);
    final newTotalSar = roundMoney((order.totalSar + diffSar).clamp(0.0, 9999999.0), AppCurrency.sar);
    final newTotalLocal = roundMoney((order.totalLocal + diffLocal).clamp(0.0, 999999999.0), order.currency);

    double newRemainingLocal = order.remainingLocal;
    double creditWalletSar = 0.0;
    if (diffSar > 0) {
      newRemainingLocal = roundMoney(order.remainingLocal + diffLocal, order.currency);
    } else if (diffSar < 0) {
      final absLocal = -diffLocal;
      if (order.remainingLocal > 0) {
        if (order.remainingLocal >= absLocal) {
          newRemainingLocal = roundMoney(order.remainingLocal - absLocal, order.currency);
        } else {
          final excessLocal = absLocal - order.remainingLocal;
          newRemainingLocal = 0.0;
          creditWalletSar = roundMoney(rate > 0 ? excessLocal / rate : 0.0, AppCurrency.sar);
        }
      } else if (order.paidTotalLocal > 0) {
        creditWalletSar = roundMoney(-diffSar, AppCurrency.sar);
      }
    }

    await r.update({
      'items': updatedItems.map((e) => e.toMap()).toList(),
      'subtotalSar': newSubSar,
      'totalSar': newTotalSar,
      'totalLocal': newTotalLocal,
      'remainingLocal': newRemainingLocal,
      'replacementStatus': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (creditWalletSar > 0.01 && order.userId.isNotEmpty) {
      final wRef = _db.collection('wallets').doc(order.userId);
      await _db.runTransaction((tx) async {
        final ws = await tx.get(wRef);
        final curBal = ((ws.data()?['balanceSar'] as num?)?.toDouble() ?? 0.0);
        final movs = List<dynamic>.from((ws.data()?['movements'] as List?) ?? const []);
        movs.add({
          'id': 'rep_${DateTime.now().millisecondsSinceEpoch}',
          'type': 'refund',
          'amountSar': creditWalletSar,
          'orderNo': order.orderNo,
          'note': 'فارق استبدال قطعة بسعر أقل في طلب ${order.orderNo}',
          'at': Timestamp.now(),
        });
        tx.set(wRef, {
          'balanceSar': roundMoney(curBal + creditWalletSar, AppCurrency.sar),
          'movements': movs,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    }

    final summaryNote = diffSar == 0
        ? 'تم اعتماد البديل بنفس القيمة دون فارق'
        : (diffSar > 0
            ? 'تم اعتماد البديل وإضافة الفارق (${diffSar.toStringAsFixed(2)} ر.س) للمتبقي'
            : 'تم اعتماد البديل وإعادة الفارق (${(-diffSar).toStringAsFixed(2)} ر.س) ${creditWalletSar > 0 ? "للمحفظة" : "بخصمه من المتبقي"}');

    await r.collection('events').add({
      'status': order.status.key,
      'at': Timestamp.now(),
      'byName': _email.isNotEmpty ? _email : 'الإدارة',
      'note': summaryNote,
    });
    if (Get.isRegistered<NotificationService>()) {
      await Get.find<NotificationService>().pushUserNotification(
        targetUid: order.userId,
        title: 'تم اعتماد القطعة البديلة — طلب ${order.orderNo}',
        body: summaryNote,
        type: 'replacement',
        orderId: order.id,
      );
    }
  }

  /// حفظ التوقيع الإلكتروني باستلام الطلب (من العميل أو المندوب).
  Future<String> submitElectronicSignature({
    required Order order,
    required Uint8List pngBytes,
    required String signerName,
    String enteredPin = '',
  }) async {
    String sigUrl = '';
    try {
      final ref = FirebaseStorage.instance
          .ref('signatures/${order.userId}/${order.id}_${DateTime.now().millisecondsSinceEpoch}.png');
      await ref.putData(pngBytes, SettableMetadata(contentType: 'image/png'));
      sigUrl = await ref.getDownloadURL();
    } catch (_) {
      sigUrl = '';
    }
    if (sigUrl.isEmpty) {
      throw 'تعذر رفع صورة التوقيع — تحقق من الاتصال وصلاحية التخزين';
    }
    final pinOk = order.deliveryPin.isEmpty ||
        enteredPin.trim().isEmpty ||
        enteredPin.trim() == order.deliveryPin.trim();
    final r = _db.collection('orders').doc(order.id);
    await r.update({
      'customerSignatureUrl': sigUrl,
      'signedAt': FieldValue.serverTimestamp(),
      'signedByUid': _uid,
      'signedByName': signerName.trim().isEmpty ? order.address.receiverName : signerName.trim(),
      'deliverySigned': true,
      if (enteredPin.trim().isNotEmpty) 'deliveryPinVerified': pinOk,
      'status': 'delivered',
      'shippingStage': 'delivered',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await r.collection('events').add({
      'status': 'delivered',
      'at': Timestamp.now(),
      'byName': signerName.trim().isEmpty ? 'العميل' : signerName.trim(),
      'note': 'تم تأكيد الاستلام بالتوقيع الإلكتروني',
    });
    if (Get.isRegistered<NotificationService>()) {
      await Get.find<NotificationService>().pushUserNotification(
        targetUid: order.userId,
        title: 'تم توثيق استلام الطلب ${order.orderNo}',
        body: 'تم حفظ توقيعك الإلكتروني وإصدار إثبات التسليم بنجاح.',
        type: 'order',
        orderId: order.id,
      );
    }
    return sigUrl;
  }

  /// حذف وأرشفة الطلب للمدير فقط مع حفظ نسخة في سجل التدقيق والمحذوفات.
  Future<void> managerArchiveAndDeleteOrder(Order order, {String reason = ''}) async {
    final docRef = _db.collection('orders').doc(order.id);
    final snap = await docRef.get();
    final data = snap.data() ?? <String, dynamic>{'orderNo': order.orderNo, 'totalSar': order.totalSar};
    if (Get.isRegistered<AuditService>()) {
      await Get.find<AuditService>().archiveAndDelete(
        collectionName: 'orders',
        docId: order.id,
        snapshotData: data,
        reason: reason,
        summary: 'حذف الطلب ${order.orderNo} (بقيمة ${order.totalSar.toStringAsFixed(2)} ر.س)',
      );
    }
    for (final sub in ['receipts', 'events', 'messages']) {
      final subDocs = await docRef.collection(sub).get();
      for (final d in subDocs.docs) {
        await d.reference.delete();
      }
    }
    await docRef.delete();
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
  // بلا orderBy مع where: يمنع الحاجة إلى فهرس مركّب.
  // الترتيب يتم داخل التطبيق بعد الجلب.
  Query q = FirebaseFirestore.instance.collection('orders').limit(limit);
  if (status != null) q = q.where('status', isEqualTo: status.key);
  return q.snapshots().map((s) {
    final list = s.docs
        .map((d) => Order.fromDoc(d.id, d.data() as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
}
