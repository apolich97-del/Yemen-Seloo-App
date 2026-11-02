import '../data/shein_image_resolver.dart';
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
  SheinBridgeController({SelooCartService? cartService}) : _cartService = cartService ?? SelooCartService();
  final SelooCartService _cartService;
  String? _scriptSource;

  String? editingLineId;
  InAppWebViewController? _webView;

  Function(int total)? onStartClickCrawl;
  Function()? onCrawlStepFailed;

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
            return await _handleAddToCart(envelope.payload);
          case 'startClickCrawl':
            onStartClickCrawl?.call(envelope.payload['total'] ?? 0);
            return _reply('ok', 'بدأ الزحف');
          case 'crawlStepFailed':
            onCrawlStepFailed?.call();
            return _reply('ok', 'تخطي');
          default:
            return _reply('invalid', 'إجراء غير معروف');
        }
      },
    );
  }

  Future<void> _resolveImageLater(String goodsId) async {
    try {
      final String? real = await SheinImageResolver.byGoodsId(goodsId);
      if (real == null || real.isEmpty) return;
      final bool patched = await _cartService.patchImage(goodsId, real);
      if (patched) {
        try { await Get.find<CartCounter>().refreshQuote(); } catch (_) {}
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _handleAddToCart(Map<String, dynamic> payload) async {
    final Map<String, dynamic> safePayload = Map<String, dynamic>.from(payload);
    final String goodsIdRaw = (safePayload['goodsId'] ?? '').toString().trim();

    final SheinDraft draft;
    try {
      draft = SheinDraft.fromBridgePayload(safePayload);
    } on DraftValidationException catch (error) {
      onCrawlStepFailed?.call();
      return _reply('invalid', 'بيانات المنتج غير مكتملة');
    }

    try {
      final BridgeResult result = await _cartService.addToCart(draft, editingLineId: editingLineId);
      try { await Get.find<CartCounter>().onItemAdded(); } catch (_) {}

      // ⭐ نطلب دائماً جلب الصورة الصحيحة وتصحيحها في الخلفية
      if (result.isOk && RegExp(r'^\d+$').hasMatch(goodsIdRaw)) {
        unawaited(_resolveImageLater(goodsIdRaw));
      }

      return result.toJson();
    } catch (e) {
      onCrawlStepFailed?.call();
      return _reply('error', 'تعذّرت الإضافة: $e');
    }
  }

  Future<String> loadOverlayScript() async {
    return _scriptSource ??= await rootBundle.loadString(SheinWebConfig.scriptAssetPath);
  }

  Map<String, dynamic> _reply(String status, String message) => <String, dynamic>{'status': status, 'message': message};
}
