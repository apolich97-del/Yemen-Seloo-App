import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'auth_service.dart';

/// إشعارات تغيير حالة الطلب.
/// الخادم يرسل إلى التوكنات المحفوظة في users/{uid}.fcmTokens
/// عبر Cloud Function [registerFcmToken] (لا كتابة مباشرة من العميل).
class PushService extends GetxService {
  final _fm = FirebaseMessaging.instance;
  final _fn = FirebaseFunctions.instanceFor(region: 'europe-west1');

  final RxString pendingOrderId = ''.obs;
  final RxString token = ''.obs;

  Future<void> init() async {
    try {
      final settings = await _fm.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final t = await _fm.getToken();
      if (t != null) {
        token.value = t;
        await registerToken(t);
      }
      _fm.onTokenRefresh.listen(registerToken);

      FirebaseMessaging.onMessage.listen((m) {
        final id = m.data['orderId'];
        if (id is String && id.isNotEmpty) pendingOrderId.value = id;
      });

      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        final id = m.data['orderId'];
        if (id is String && id.isNotEmpty) Get.toNamed('/order', arguments: id);
      });
    } catch (e) {
      debugPrint('push init: $e');
    }
  }

  /// يُنادى بعد تسجيل الدخول (التوكن قبل الدخول لا يخص مستخدماً).
  Future<void> registerToken(String t) async {
    final auth = Get.isRegistered<AuthService>() ? Get.find<AuthService>() : null;
    if (auth?.uid == null) return;
    try {
      await _fn.httpsCallable('registerFcmToken').call({'token': t});
    } on FirebaseFunctionsException catch (e) {
      debugPrint('registerFcmToken: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('registerFcmToken: $e');
    }
  }
}
