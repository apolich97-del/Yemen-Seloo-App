import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../core/config/seloo_config.dart';
import '../../cart/data/seloo_cart_service.dart';
import '../domain/shein_draft.dart';

/// يربط WebView SHEIN بمنطق التطبيق: يقرأ الحمولة، يتحقق منها، يرسلها للسلة،
/// ثم يعيد ردًا واضحًا إلى الصفحة عبر نفس الجسر.
class SheinBridgeController {
  SheinBridgeController({SelooCartService? cartService})
      : _cartService = cartService ?? SelooCartService();

  final SelooCartService _cartService;

  String? _scriptSource;
  InAppWebViewController? _webView;

  /// يُسجَّل مرة واحدة عند إنشاء الـWebView.
  Future<void> attach(InAppWebViewController controller) async {
    _webView = controller;

    controller.addJavaScriptHandler(
      handlerName: SheinWebConfig.bridgeName,
      callback: (List<dynamic> args) async {
        if (args.isEmpty) {
          return _reply('invalid', 'حمولة مفقودة');
        }
        final BridgeEnvelope? envelope = BridgeEnvelope.tryParse(args.first);
        if (envelope == null) {
          return _reply('invalid', 'شكل الحمولة غير صالح');
        }
        switch (envelope.action) {
          case 'addToCart':
            return _handleAddToCart(envelope.payload);
          case 'openCart':
            return _reply('ok', '');
          case 'requestCartCount':
            return _reply('ok', '', await _currentCartCount());
          default:
            return _reply('invalid', 'إجراء غير معروف');
        }
      },
    );
  }

  Future<Map<String, dynamic>> _handleAddToCart(
      Map<String, dynamic> payload) async {
    if (jsonEncode(payload).length > SelooConfig.maxPayloadBytes) {
      return _reply('invalid', 'حمولة أكبر من الحد المسموح');
    }
    if (FirebaseAuth.instance.currentUser == null) {
      return _reply('unauthenticated', 'سجّل الدخول أولًا لإضافة المنتجات');
    }

    final SheinDraft draft;
    try {
      draft = SheinDraft.fromBridgePayload(payload);
    } on DraftValidationException catch (error) {
      debugPrint('رفض مسودة منتج: ${error.field} — ${error.reason}');
      return _reply('invalid', 'بيانات المنتج غير مكتملة (${error.field})');
    }

    final BridgeResult result = await _cartService.addToCart(draft);
    if (result.isOk) {
      unawaited(pushCartCountToPage());
    }
    return result.toJson();
  }

  Future<int> _currentCartCount() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await FirebaseFirestore.instance
            .collection(SelooConfig.usersCollection)
            .doc(user.uid)
            .collection(SelooConfig.cartCollection)
            .get();
    return snapshot.docs.length;
  }

  Future<void> pushCartCountToPage() async {
    final InAppWebViewController? controller = _webView;
    if (controller == null) return;
    try {
      final int count = await _currentCartCount();
      await controller.evaluateJavascript(
        source:
            'window.__selooSetCartCount && window.__selooSetCartCount($count);',
      );
    } catch (error, stack) {
      debugPrint('تعذّر تحديث العدّاد: $error\n$stack');
    }
  }

  Future<String> loadOverlayScript() async {
    return _scriptSource ??=
        await rootBundle.loadString(SheinWebConfig.scriptAssetPath);
  }

  Map<String, dynamic> _reply(String status, String message, [int? cartCount]) =>
      <String, dynamic>{
        'status': status,
        'message': message,
        if (cartCount != null) 'cartCount': cartCount,
      };
}

/// قواعد التنقّل داخل الـWebView.
abstract final class SheinNavigationPolicy {
  static bool isInternal(Uri uri) {
    if (!uri.hasScheme) return false;
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;
    return SheinWebConfig.allowedHosts.any(
      (String host) => uri.host == host || uri.host.endsWith('.$host'),
    );
  }

  static bool isExternalRedirect(Uri uri) => SheinWebConfig.externalHosts.any(
        (String host) => uri.host == host || uri.host.endsWith('.$host'),
      );

  static NavigationActionPolicy decide(Uri uri) {
    if (isInternal(uri)) return NavigationActionPolicy.ALLOW;
    return NavigationActionPolicy.CANCEL;
  }
}
