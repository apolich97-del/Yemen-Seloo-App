import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../models/order.dart';
import '../routes/app_routes.dart';

/// إشعارات تغيير حالة الطلب على الخطة المجانية (Firestore Live Watcher + FCM).
class PushService extends GetxService {
  final _fm = FirebaseMessaging.instance;
  final RxString pendingOrderId = ''.obs;
  final RxString token = ''.obs;

  StreamSubscription? _authSub;
  StreamSubscription? _ordersSub;
  final Map<String, String> _knownStatuses = <String, String>{};
  final Map<String, String> _knownSync = <String, String>{};
  bool _seeded = false;

  Future<void> init() async {
    try {
      final settings = await _fm.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus != AuthorizationStatus.denied) {
        final t = await _fm.getToken();
        if (t != null) token.value = t;
        _fm.onTokenRefresh.listen((t) => token.value = t);
      }
      FirebaseMessaging.onMessage.listen((m) {
        final id = m.data['orderId'];
        if (id is String && id.isNotEmpty) pendingOrderId.value = id;
      });
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        final id = m.data['orderId'];
        if (id is String && id.isNotEmpty) {
          Get.toNamed(AppRoutes.orderDetail, arguments: id);
        }
      });
    } catch (e) {
      debugPrint('push init: $e');
    }

    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      if (u == null) {
        _stopWatcher();
      } else {
        startOrderWatcher(u.uid);
      }
    });
  }

  void _stopWatcher() {
    _ordersSub?.cancel();
    _ordersSub = null;
    _knownStatuses.clear();
    _knownSync.clear();
    _seeded = false;
  }

  /// يراقب طلبات العميل لحظياً ويُشعره داخل التطبيق فور انتقال أي مرحلة أو وصول تعديل سعر.
  void startOrderWatcher(String uid) {
    _stopWatcher();
    _ordersSub = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .limit(50)
        .snapshots()
        .listen((snap) {
      if (!_seeded) {
        for (final doc in snap.docs) {
          final d = doc.data();
          _knownStatuses[doc.id] = (d['status'] ?? '') as String;
          _knownSync[doc.id] = (d['priceSyncStatus'] ?? '') as String;
        }
        _seeded = true;
        return;
      }

      for (final doc in snap.docs) {
        final d = doc.data();
        final orderNo = (d['orderNo'] ?? doc.id).toString();
        final st = (d['status'] ?? '').toString();
        final sync = (d['priceSyncStatus'] ?? '').toString();
        final prevSt = _knownStatuses[doc.id];
        final prevSync = _knownSync[doc.id];

        if (prevSt != null && prevSt != st && st.isNotEmpty) {
          final label = OrderStatusX.fromKey(st).labelAr;
          Get.snackbar(
            'تحديث مرحلة الطلب $orderNo',
            'انتقل طلبك الآن إلى مرحلة: $label',
            duration: const Duration(seconds: 5),
            onTap: (_) => Get.toNamed(AppRoutes.orderDetail, arguments: doc.id),
          );
        }

        if (prevSync != sync && sync == 'pending_customer') {
          Get.snackbar(
            'تحديث سعر/توفر للطلب $orderNo',
            'يرجى مراجعة التعديل المقترح من الإدارة والموافقة عليه',
            duration: const Duration(seconds: 6),
            onTap: (_) => Get.toNamed(AppRoutes.orderDetail, arguments: doc.id),
          );
        }

        _knownStatuses[doc.id] = st;
        _knownSync[doc.id] = sync;
      }
    }, onError: (_) {});
  }

  @override
  void onClose() {
    _authSub?.cancel();
    _stopWatcher();
    super.onClose();
  }
}
