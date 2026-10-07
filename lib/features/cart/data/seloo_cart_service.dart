import 'dart:convert';
import 'dart:math';

import 'package:get_storage/get_storage.dart';

import '../../../core/config/seloo_config.dart';
import '../../shein/domain/shein_draft.dart';
import '../domain/cart_item.dart';

/// سلة محلية على الجهاز — بدون Cloud Functions.
class SelooCartService {
  static const String _cartKey = 'seloo_cart_v1';

  GetStorage get _box => GetStorage();

  // ============ قراءة ============

  List<CartItem> loadItems() {
    try {
      final Object? raw = _box.read(_cartKey);
      if (raw == null) return <CartItem>[];
      final String json = raw is String ? raw : jsonEncode(raw);
      final List<dynamic> list = jsonDecode(json) as List<dynamic>;
      return list
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> m) => CartItem.fromFirestore(
                '${m['lineId'] ?? ''}',
                Map<String, dynamic>.from(m),
              ))
          .toList();
    } catch (_) {
      return <CartItem>[];
    }
  }

  Future<void> _save(List<CartItem> items) async {
    final List<Map<String, dynamic>> list =
        items.map((CartItem i) => i.toMap()).toList();
    await _box.write(_cartKey, jsonEncode(list));
  }

  // ⭐ توليد lineId فريد
  String _generateLineId() {
    final String ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final String rand = Random.secure().nextInt(0x7FFFFFFF).toRadixString(36);
    return 'ln_${ts}_$rand';
  }

  // ⭐ سعر الصرف حسب المنطقة
  double _rateFor(String region) {
    switch (region) {
      case SelooPricing.regionSouth:
        return SelooPricing.southRate;
      case SelooPricing.regionSaudi:
        return SelooPricing.saudiRate;
      case SelooPricing.regionNorth:
      default:
        return SelooPricing.northRate;
    }
  }

  // ============ عمليات السلة ============

  Future<BridgeResult> addToCart(
    SheinDraft draft, {
    String? editingLineId,
  }) async {
    final List<CartItem> items = loadItems();

    final double rate = _rateFor(SelooPricing.defaultRegion);
    final double unitLocal = draft.sourcePrice * rate;

    // ⭐ تحديد lineId
    final String lineId;
    if (editingLineId != null && editingLineId.isNotEmpty) {
      lineId = editingLineId;
    } else {
      lineId = _generateLineId();
    }

    final int idx = items.indexWhere((CartItem i) => i.lineId == lineId);

    if (editingLineId != null && editingLineId.isNotEmpty) {
      // ⭐ وضع التعديل: تحديث السطر بنفس lineId
      if (idx < 0) {
        return BridgeResult.failure(
            'not-found', 'السطر المراد تعديله لم يُعد موجودًا');
      }
      final CartItem original = items[idx];
      items[idx] = CartItem(
        lineId: lineId,
        goodsId: draft.goodsId,
        productUrl: draft.productUrl,
        title: draft.title,
        imageUrl: draft.imageUrl,
        color: draft.color,
        size: draft.size,
        options: draft.options,
        sourceStore: draft.sourceStore,
        quantity: original.quantity,
        sourcePrice: draft.sourcePrice,
        sourceCurrency: draft.sourceCurrency,
        exchangeRate: rate,
        unitPriceLocal: unitLocal,
        source: draft.source,
        sku: draft.sku,
        variantId: draft.variantId,
        addedAt: original.addedAt ?? DateTime.now(),
      );
    } else {
      // ⭐ إضافة جديدة
      items.add(CartItem(
        lineId: lineId,
        goodsId: draft.goodsId,
        productUrl: draft.productUrl,
        title: draft.title,
        imageUrl: draft.imageUrl,
        color: draft.color,
        size: draft.size,
        options: draft.options,
        sourceStore: draft.sourceStore,
        quantity: draft.quantity,
        sourcePrice: draft.sourcePrice,
        sourceCurrency: draft.sourceCurrency,
        exchangeRate: rate,
        unitPriceLocal: unitLocal,
        source: draft.source,
        sku: draft.sku,
        variantId: draft.variantId,
        addedAt: DateTime.now(),
      ));
    }

    await _save(items);

    return BridgeResult(
      status: 'ok',
      message: (editingLineId != null && editingLineId.isNotEmpty)
          ? 'تم تحديث المنتج'
          : 'تمت الإضافة إلى سلة سيلو',
      cartCount: items.length,
    );
  }

  Future<BridgeResult> updateLine(String lineId, int quantity) async {
    final List<CartItem> items = loadItems();
    final int idx = items.indexWhere((CartItem i) => i.lineId == lineId);
    if (idx < 0) {
      return BridgeResult.failure('not-found', 'المنتج غير موجود');
    }
    items[idx] = items[idx].copyWith(quantity: quantity);
    await _save(items);
    return BridgeResult(
      status: 'ok',
      message: 'تم تحديث الكمية',
      cartCount: items.length,
    );
  }

  Future<BridgeResult> removeLine(String lineId) async {
    final List<CartItem> items = loadItems();
    items.removeWhere((CartItem i) => i.lineId == lineId);
    await _save(items);
    return BridgeResult(
      status: 'ok',
      message: 'تم الحذف',
      cartCount: items.length,
    );
  }

  Future<BridgeResult> clear() async {
    await _box.remove(_cartKey);
    return const BridgeResult(
      status: 'ok',
      message: 'تم تفريغ السلة',
      cartCount: 0,
    );
  }

  // ============ التسعير الجديد ============

  Future<CartQuote> quote() async {
    final List<CartItem> items = loadItems();
    final double rate = _rateFor(SelooPricing.defaultRegion);

    double itemsSubtotalSar = 0;
    int units = 0;
    for (final CartItem i in items) {
      itemsSubtotalSar += i.sourcePrice * i.quantity;
      units += i.quantity;
    }

    // الشحن الدولي (السعودية → اليمن)
    double shippingSar = 0;
    if (itemsSubtotalSar > 0 &&
        itemsSubtotalSar < SelooPricing.freeShippingThresholdSar) {
      shippingSar = units * SelooPricing.shippingPerPieceSar;
    }

    // رسوم الخدمة = 1.22 SAR لكل طلب
    final double serviceFeeSar =
        itemsSubtotalSar > 0 ? SelooPricing.serviceFeeSar : 0;

    // التحويل إلى YER
    final double itemsSubtotalLocal = itemsSubtotalSar * rate;
    final double shippingLocal = shippingSar * rate;
    final double serviceFeeLocal = serviceFeeSar * rate;

    final double grandTotalLocal =
        itemsSubtotalLocal + shippingLocal + serviceFeeLocal;

    return CartQuote(
      itemsSubtotalLocal: itemsSubtotalLocal,
      serviceFeeLocal: serviceFeeLocal,
      shippingLocal: shippingLocal,
      deliveryLocal: 0,
      discountLocal: 0,
      grandTotalLocal: grandTotalLocal,
      currency: 'YER',
      lines: items,
    );
  }

  Future<BridgeResult> submitOrder({
    required String contactPhone,
    required String addressLine,
    required String city,
    required double lat,
    required double lng,
  }) async {
    return BridgeResult(
      status: 'ok',
      message: 'طلبك-${DateTime.now().millisecondsSinceEpoch}',
      cartCount: 0,
      orderId: 'order-${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}
