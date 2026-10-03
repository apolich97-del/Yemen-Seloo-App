import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/config/seloo_config.dart';
import '../domain/cart_item.dart';
import '../../shein/domain/shein_draft.dart';

/// كل ما يتعلق بالسلة يمرّ عبر الدوال السحابية — لا كتابة مباشرة من العميل.
class SelooCartService {
  SelooCartService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: SelooConfig.functionsRegion);

  final FirebaseFunctions _functions;

  /// يُستدعى من جسر الـWebView عند ضغط زر «أضف إلى سلة سيلو».
  Future<BridgeResult> addToCart(SheinDraft draft) async {
    try {
      final HttpsCallableResult<dynamic> result =
          await _functions.httpsCallable(SelooFunctions.addToCart).call(
        <String, dynamic>{
          'goodsId': draft.goodsId,
          'productUrl': draft.productUrl,
          'title': draft.title,
          'imageUrl': draft.imageUrl,
          'price': draft.priceOriginal,
          'currency': draft.currency,
          'quantity': draft.quantity,
          'color': draft.color,
          'size': draft.size,
          'sku': draft.sku,
          'variantId': draft.variantId,
          'extractSource': draft.source,
          'clientTs': draft.clientTs.millisecondsSinceEpoch,
        },
      );
      return _parseResult(result.data);
    } on FirebaseFunctionsException catch (error) {
      return BridgeResult.failure(_mapCode(error.code), _arabicMessage(error));
    }
  }

  Future<BridgeResult> updateLine(String lineId, int quantity) async {
    final HttpsCallableResult<dynamic> result = await _functions
        .httpsCallable(SelooFunctions.updateCartLine)
        .call(<String, dynamic>{
      'lineId': lineId,
      'quantity': quantity,
    });
    return _parseResult(result.data);
  }

  Future<BridgeResult> removeLine(String lineId) async {
    final HttpsCallableResult<dynamic> result = await _functions
        .httpsCallable(SelooFunctions.removeCartLine)
        .call(<String, dynamic>{'lineId': lineId});
    return _parseResult(result.data);
  }

  Future<BridgeResult> clear() async {
    final HttpsCallableResult<dynamic> result =
        await _functions.httpsCallable(SelooFunctions.clearCart).call();
    return _parseResult(result.data);
  }

  Future<CartQuote> quote() async {
    final HttpsCallableResult<dynamic> result =
        await _functions.httpsCallable(SelooFunctions.quoteCart).call();
    final Object? data = result.data;
    if (data is! Map) {
      throw StateError('استجابة تسعير غير صالحة');
    }
    return CartQuote.fromMap(data.cast<String, dynamic>());
  }

  Future<BridgeResult> submitOrder({
    required String contactPhone,
    required String addressLine,
    required String city,
    required double lat,
    required double lng,
  }) async {
    final HttpsCallableResult<dynamic> result =
        await _functions.httpsCallable(SelooFunctions.submitOrder).call(
      <String, dynamic>{
        'contactPhone': contactPhone,
        'addressLine': addressLine,
        'city': city,
        'lat': lat,
        'lng': lng,
      },
    );
    return _parseResult(result.data);
  }

  BridgeResult _parseResult(Object? data) {
    if (data is! Map) {
      return BridgeResult.failure('invalid', 'استجابة غير مفهومة من الخادم');
    }
    final Map<String, dynamic> map = data.cast<String, dynamic>();
    return BridgeResult(
      status: '${map['status'] ?? 'invalid'}',
      message: '${map['message'] ?? 'تعذّرت العملية'}',
      cartCount: map['cartCount'] is num
          ? (map['cartCount'] as num).toInt()
          : null,
      orderId: map['orderId'] is String ? map['orderId'] as String : null,
    );
  }

  String _mapCode(String code) => switch (code) {
        'unauthenticated' => 'unauthenticated',
        'failed-precondition' => 'soldOut',
        'resource-exhausted' => 'limit',
        'invalid-argument' => 'invalid',
        'permission-denied' => 'forbidden',
        _ => 'error',
      };

  String _arabicMessage(FirebaseFunctionsException error) {
    final Object? details = error.details;
    if (details is Map && details['message'] is String) {
      return details['message'] as String;
    }
    return switch (error.code) {
      'unauthenticated' => 'سجّل الدخول أولًا لإضافة المنتجات',
      'resource-exhausted' => 'تجاوزت الحد المسموح لعدد المنتجات',
      'failed-precondition' => 'المنتج غير متوفر حاليًا',
      'permission-denied' => 'تعذّرت العملية على هذا الحساب',
      _ => 'تعذّرت الإضافة، حاول مرة أخرى',
    };
  }
}
