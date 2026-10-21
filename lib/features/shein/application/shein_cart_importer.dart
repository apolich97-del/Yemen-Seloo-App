
import 'package:get/get.dart';

import '../../cart/application/cart_counter.dart';
import '../../cart/data/seloo_cart_service.dart';
import '../data/shein_share_api.dart';
import '../domain/shein_draft.dart';

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
    try {
      final products = await _api.fetchSharedCart(sharedLink);

      if (products.isEmpty) {
        return const SheinCartImportResult(
          success: false,
          message: 'لم يتم العثور على منتجات في السلة المشتركة.',
        );
      }

      int addedCount = 0;
      int failedCount = 0;

      for (final product in products) {
        try {
          final draft = SheinDraft.fromBridgePayload(product);
          final result = await _cartService.addToCart(draft);

          if (result.isOk) {
            addedCount++;

            if (Get.isRegistered<CartCounter>()) {
              Get.find<CartCounter>().onItemAdded();
            }
          } else {
            failedCount++;
          }
        } catch (_) {
          failedCount++;
        }
      }

      if (addedCount > 0) {
        final message = failedCount == 0
            ? 'تمت إضافة $addedCount منتج إلى سلة يمن سيلو.'
            : 'تمت إضافة $addedCount منتج، وتعذرت إضافة '
                '$failedCount منتج.';

        return SheinCartImportResult(
          success: true,
          addedCount: addedCount,
          failedCount: failedCount,
          message: message,
        );
      }

      return SheinCartImportResult(
        success: false,
        failedCount: failedCount,
        message: 'لم نتمكن من إضافة المنتجات إلى السلة.',
      );
    } catch (e) {
      return SheinCartImportResult(
        success: false,
        message: 'فشل استيراد السلة: $e',
      );
    }
  }
}

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
