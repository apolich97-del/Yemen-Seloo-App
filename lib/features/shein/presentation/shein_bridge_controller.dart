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
          case 'openYamanCart':
            return _handleOpenYamanCart();
          case 'batchAddToCart': 
            _handleBatchAddToCart(envelope.payload);
            return _reply('ok', 'بدأ الاستيراد');
          default:
            return _reply('invalid', 'إجراء غير معروف');
        }
      },
    );
  }

  Future<Map<String, dynamic>> _handleAddToCart(Map<String, dynamic> payload) async {
    if (jsonEncode(payload).length > SelooConfig.maxPayloadBytes) {
      return _reply('invalid', 'حمولة أكبر من الحد المسموح');
    }

    final SheinDraft draft;
    try {
      draft = SheinDraft.fromBridgePayload(payload);
    } on DraftValidationException catch (error) {
      return _reply('invalid', 'بيانات المنتج غير مكتملة (${error.field})');
    }

    String? editingLineId;
    try { editingLineId = Get.find<CartCounter>().editingLineId.value; } catch (e) {}

    try {
      final BridgeResult result = await _cartService.addToCart(draft, editingLineId: editingLineId);
      try { await Get.find<CartCounter>().onItemAdded(); } catch (_) {}
      if (editingLineId != null && editingLineId.isNotEmpty && result.isOk) {
        try { Get.find<CartCounter>().clearEditing(); } catch (_) {}
      }
      return result.toJson();
    } catch (e) {
      return _reply('error', 'تعذّرت الإضافة: $e');
    }
  }

  // ⭐ دالة استقبال المنتجات دفعة واحدة (المسح الذكي)
  void _handleBatchAddToCart(Map<String, dynamic> payload) async {
    final List<dynamic> items = payload['items'] as List<dynamic>? ?? [];
    if (items.isEmpty) return;

    int added = 0;
    for (var item in items) {
      if (item is! Map) continue;
      try {
        // نمرر البيانات التي جمعها السكربت الذكي
        final draft = SheinDraft.fromBridgePayload(Map<String, dynamic>.from(item));
        await _cartService.addToCart(draft);
        added++;
      } catch (e) {
        debugPrint('[Seloo] تخطي منتج: $e');
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (Get.currentRoute == '/shein') Get.back();
      try {
        final CartCounter cart = Get.find<CartCounter>();
        await cart.onItemAdded();
        cart.clearEditing();
        Get.find<MainTabController>().goToCart();
      } catch (_) {}

      Get.snackbar(
        '✅ تم الاستيراد الجماعي',
        'أُضيف $added منتج من سلة شي إن',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF7C3AED),
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
      return _reply('error', 'تعذّر فتح السلة');
    }
  }

  Future<String> loadOverlayScript() async {
    return _scriptSource ??= await rootBundle.loadString(SheinWebConfig.scriptAssetPath);
  }

  Map<String, dynamic> _reply(String status, String message, [int? cartCount]) =>
      <String, dynamic>{ 'status': status, 'message': message, if (cartCount != null) 'cartCount': cartCount };
}

abstract final class SheinNavigationPolicy {
  static bool isInternal(Uri uri) {
    if (!uri.hasScheme) return false;
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;
    return SheinWebConfig.allowedHosts.any((String host) => uri.host == host || uri.host.endsWith('.$host'));
  }
  static NavigationActionPolicy decide(Uri uri) {
    if (isInternal(uri)) return NavigationActionPolicy.ALLOW;
    return NavigationActionPolicy.CANCEL;
  }
}
