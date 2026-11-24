
import 'package:get/get.dart';

import '../../cart/application/cart_counter.dart';
import '../../cart/data/seloo_cart_service.dart';
import '../data/shein_image_resolver.dart';
import '../data/shein_product_scraper.dart';
import '../data/shein_share_api.dart';
import '../domain/shein_draft.dart';

/// نتيجة استيراد السلة المشتركة.
class SheinCartImportResult {
  const SheinCartImportResult({
    required this.success,
    required this.message,
    this.addedCount = 0,
    this.failedCount = 0,
  });

  final bool success;
  final String message;
  final int addedCount;
  final int failedCount;
}

class SheinCartImporter {
  SheinCartImporter({
    SheinShareApi? api,
    SelooCartService? cartService,
  })  : _api = api ?? SheinShareApi(),
        _cartService = cartService ?? SelooCartService();

  final SheinShareApi _api;
  final SelooCartService _cartService;

  Future<SheinCartImportResult> importSharedCart(
    String sharedLink,
  ) async {
    final String text = sharedLink.trim();

    if (text.isEmpty) {
      return const SheinCartImportResult(
        success: false,
        message: 'الصق رابط السلة المشتركة أولاً.',
      );
    }

    try {
      final List<Map<String, dynamic>> products =
          await _api.fetchSharedCart(text);

      if (products.isEmpty) {
        return const SheinCartImportResult(
          success: false,
          message: 'لم يتم العثور على منتجات في السلة المشتركة.',
        );
      }

      int added = 0;
      int failed = 0;

      for (final Map<String, dynamic> product in products) {
        try {
          final Map<String, dynamic> enriched = Map<String, dynamic>.from(product);
          final String gid = '${enriched['goodsId'] ?? ''}'.trim();
          final String curImg = '${enriched['imageUrl'] ?? ''}'.trim();
          final double curPrice = (enriched['sourcePrice'] is num)
              ? (enriched['sourcePrice'] as num).toDouble()
              : double.tryParse('${enriched['sourcePrice'] ?? 0}') ?? 0;
          final String curTitle = '${enriched['title'] ?? ''}'.trim();

          if (gid.isNotEmpty &&
              (curImg.isEmpty || curPrice <= 0.05 || curTitle.startsWith('منتج SHEIN'))) {
            final SheinScrapedProduct? scraped =
                await SheinProductScraper.fetchByGoodsId(gid);
            if (scraped != null) {
              if (curImg.isEmpty && scraped.imageUrl.isNotEmpty) {
                enriched['imageUrl'] = scraped.imageUrl;
              }
              if (curPrice <= 0.05 && scraped.priceSar > 0.05) {
                enriched['sourcePrice'] = scraped.priceSar;
              }
              if ((curTitle.isEmpty || curTitle.startsWith('منتج SHEIN')) &&
                  scraped.title.isNotEmpty) {
                enriched['title'] = scraped.title;
              }
            } else if (curImg.isEmpty) {
              final String? resolvedImg = await SheinImageResolver.byGoodsId(gid);
              if (resolvedImg != null && resolvedImg.isNotEmpty) {
                enriched['imageUrl'] = resolvedImg;
              }
            }
          }

          final SheinDraft draft =
              SheinDraft.fromBridgePayload(enriched);

          final result = await _cartService.addToCart(draft);

          if (result.isOk) {
            added++;

            if (Get.isRegistered<CartCounter>()) {
              await Get.find<CartCounter>().onItemAdded();
            }
          } else {
            failed++;
          }
        } catch (_) {
          failed++;
        }
      }

      if (added == 0) {
        return SheinCartImportResult(
          success: false,
          message: 'لم نتمكن من إضافة المنتجات. '
              'تحقق من بيانات المنتجات وحاول مجددًا.',
          failedCount: failed,
        );
      }

      String message = 'تم استيراد $added منتج إلى سلة يمن سيلو.';

      if (failed > 0) {
        message += ' تعذرت إضافة $failed منتج.';
      }

      return SheinCartImportResult(
        success: true,
        message: message,
        addedCount: added,
        failedCount: failed,
      );
    } catch (e) {
      return SheinCartImportResult(
        success: false,
        message: 'فشل استيراد السلة: $e',
      );
    }
  }
}
