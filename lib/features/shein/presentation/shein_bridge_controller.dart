import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

import '../../../core/config/seloo_config.dart';
import '../../cart/application/cart_counter.dart';
import '../../cart/data/seloo_cart_service.dart';
import '../../home/presentation/main_tab_controller.dart';
import '../domain/shein_draft.dart';

/// يربط WebView SHEIN بمنطق التطبيق.
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
            return _reply('ok', '');
          case 'openYamanCart':
            return _handleOpenYamanCart();
          case 'importComplete':
            _handleImportComplete(envelope.payload);
            return _reply('ok', 'تم الاستيراد');
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

    // ⭐ اقرأ حالة التعديل من CartCounter
    String? editingLineId;
    try {
      final CartCounter cart = Get.find<CartCounter>();
      editingLineId = cart.editingLineId.value;
    } catch (e) {
      debugPrint('[Seloo] CartCounter غير متاح: $e');
    }

    try {
      final BridgeResult result = await _cartService.addToCart(
        draft,
        editingLineId: editingLineId,
      );
      debugPrint('[Seloo] نتيجة الإضافة: ${result.status}');

      try {
        final CartCounter cart = Get.find<CartCounter>();
        await cart.onItemAdded();
      } catch (_) {}

      if (editingLineId != null && editingLineId.isNotEmpty && result.isOk) {
        try {
          Get.find<CartCounter>().clearEditing();
        } catch (_) {}
        unawaited(_notifyEditCompleted());
      }

      unawaited(pushCartCountToPage());
      return result.toJson();
    } catch (e) {
      debugPrint('[Seloo] استثناء أثناء الإضافة: $e');
      return _reply('error', 'تعذّرت الإضافة: $e');
    }
  }

  /// [الحل B] اكتمل استيراد سلة SHEIN — يُغلق WebView وينتقل للسلة.
  void _handleImportComplete(Map<String, dynamic> payload) {
    final int count = (payload['count'] as num?)?.toInt() ?? 0;
    final int noPrice = (payload['noPrice'] as num?)?.toInt() ?? 0;

    debugPrint('[Seloo] اكتمل الاستيراد: $count منتج، $noPrice بدون سعر');

    // تأجيل العمليات لما بعد انتهاء الإطار الحالي
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 1. إغلاق SheinWebScreen (إذا كانت مفتوحة)
      if (Get.currentRoute == '/shein') {
        Get.back();
      }

      // 2. تحديث العدّاد
      try {
        Get.find<CartCounter>().onItemAdded();
      } catch (_) {}

      // 3. الانتقال لتبويب السلة (index = 2)
      try {
        Get.find<MainTabController>().goToCart();
      } catch (e) {
        debugPrint('[Seloo] تعذّر الانتقال للسلة: $e');
      }

      // 4. رسالة نجاح
      final String baseMsg = count > 0
          ? 'أُضيف $count منتج من سلة شي إن إلى سلة يمن سيلو'
          : 'لم يُرسل أي منتج — تأكد أنك في صفحة السلة';

      final String finalMsg = noPrice > 0
          ? '$baseMsg\n($noPrice منتج بدون سعر مقروء — عدّله يدوياً)'
          : baseMsg;

      Get.snackbar(
        count > 0 ? '✅ تم الاستيراد' : '⚠️ لم يُستورد شيء',
        finalMsg,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
        backgroundColor: count > 0
            ? const Color(0xFF7C3AED)
            : const Color(0xFFF97316),
        colorText: Colors.white,
      );
    });
  }

  Future<Map<String, dynamic>> _handleOpenYamanCart() async {
    try {
      final MainTabController tabCtrl = Get.find<MainTabController>();
      tabCtrl.goToCart();
      return _reply('ok', 'تم فتح السلة');
    } catch (e) {
      debugPrint('[Seloo] فشل الانتقال للسلة: $e');
      return _reply('error', 'تعذّر فتح السلة');
    }
  }

  Future<void> _notifyEditCompleted() async {
    final InAppWebViewController? controller = _webView;
    if (controller == null) return;
    try {
      await controller.evaluateJavascript(
        source:
            'window.__selooEditCompleted && window.__selooEditCompleted();',
      );
    } catch (_) {}
  }

  Future<void> pushCartCountToPage() async {
    final InAppWebViewController? controller = _webView;
    if (controller == null) return;
    try {
      await controller.evaluateJavascript(
        source: 'window.__selooSetCartCount && window.__selooSetCartCount();',
      );
    } catch (_) {}
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
