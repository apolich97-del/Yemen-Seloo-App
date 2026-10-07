import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

import '../../../core/config/seloo_config.dart';
import '../../cart/application/cart_counter.dart';
import '../../cart/data/seloo_cart_service.dart';
import '../domain/shein_draft.dart';

class SheinBridgeController {
  SheinBridgeController({SelooCartService? cartService})
      : _cartService = cartService ?? SelooCartService();

  final SelooCartService _cartService;

  String? _scriptSource;
  InAppWebViewController? _webView;

  Future<void> attach(InAppWebViewController controller) async {
    _webView = controller;

    controller.addJavaScriptHandler(
      handlerName: SheinWebConfig.bridgeName,
      callback: (List<dynamic> args) async {
        if (args.isEmpty) return _reply('invalid', 'حمولة مفقودة');
        final BridgeEnvelope? envelope = BridgeEnvelope.tryParse(args.first);
        if (envelope == null) return _reply('invalid', 'شكل الحمولة غير صالح');

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

    final SheinDraft draft;
    try {
      draft = SheinDraft.fromBridgePayload(payload);
    } on DraftValidationException catch (error) {
      debugPrint('[Seloo] رفض مسودة: ${error.field} — ${error.reason}');
      return _reply('invalid', 'بيانات المنتج غير مكتملة (${error.field})');
    }

    // حفظ في السلة المحلية مباشرة
    try {
      final BridgeResult result = await _cartService.addToCart(draft);
      debugPrint('[Seloo] نتيجة الإضافة: ${result.status}');

      // ⭐ تحديث CartCounter
      try {
        final CartCounter counter = Get.find<CartCounter>();
        await counter.onItemAdded();
      } catch (e) {
        debugPrint('[Seloo] تعذّر تحديث counter: $e');
      }

      unawaited(pushCartCountToPage());
      return result.toJson();
    } catch (e) {
      debugPrint('[Seloo] استثناء أثناء الإضافة: $e');
      return _reply('error', 'تعذّرت الإضافة: $e');
    }
  }

  Future<int> _currentCartCount() async {
    try {
      final CartCounter counter = Get.find<CartCounter>();
      return counter.count;
    } catch (_) {
      return 0;
    }
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
    } catch (error) {
      debugPrint('[Seloo] تحديث العدّاد: $error');
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
