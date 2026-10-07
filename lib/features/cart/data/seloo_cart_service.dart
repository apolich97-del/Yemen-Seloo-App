import 'dart:convert';

import 'package:get_storage/get_storage.dart';

import '../../shein/domain/shein_draft.dart';
import '../domain/cart_item.dart';

/// سلة محلية على الجهاز — بدون Cloud Functions.
///
/// نستخدم get_storage لتخزين السلة كـ JSON.
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
    final List<Map<String, dynamic>> list = items
        .map((CartItem i) => <String, dynamic>{
              'lineId': i.lineId,
              'goodsId': i.goodsId,
              'productUrl': i.productUrl,
              'title': i.title,
              'imageUrl': i.imageUrl,
              'color': i.color,
              'size': i.size,
              'options': i.options,
              'sourceStore': i.sourceStore,
              'quantity': i.quantity,
              'sourcePrice': i.sourcePrice,
              'sourceCurrency': i.sourceCurrency,
              'exchangeRate': i.exchangeRate,
              'unitPriceLocal': i.unitPriceLocal,
              'source': i.source,
              'sku': i.sku ?? '',
              'variantId': i.variantId ?? '',
              'addedAt': i.addedAt?.toIso8601String(),
            })
        .toList();
    await _box.write(_cartKey, jsonEncode(list));
  }

  // ============ عمليات السلة ============

  Future<BridgeResult> addToCart(SheinDraft draft) async {
    final List<CartItem> items = loadItems();

    // ⚠️ مؤقتًا: سيُستبدل في Commit 2 بسعر صرف المنطقة
    const double sarRate = 72.0;
    final double unitLocal = draft.sourcePrice * sarRate;

    // ⚠️ مؤقتًا: lineId قديم — سيُستبدل في Commit 2
    final String lineId =
        '${draft.goodsId}_${draft.color}_${draft.size}'.toLowerCase();

    final int idx = items.indexWhere((CartItem i) => i.lineId == lineId);

    if (idx >= 0) {
      final CartItem existing = items[idx];
      final int newQty = (existing.quantity + draft.quantity).clamp(1, 50);
      items[idx] = existing.copyWith(quantity: newQty);
    } else {
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
        exchangeRate: sarRate,
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
      message: 'تمت الإضافة إلى سلة سيلو',
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

  // ============ التسعير ============

  Future<CartQuote> quote() async {
    final List<CartItem> items = loadItems();

    double subtotal = 0;
    for (final CartItem i in items) {
      subtotal += i.unitPriceLocal * i.quantity;
    }

    // ⚠️ مؤقتًا: سيُستبدل في Commit 2 بـ 1.22 SAR
    final double serviceFee = subtotal * 0.07;
    // ⚠️ مؤقتًا: سيُستبدل في Commit 2 بسياسة 75 SAR
    final double shipping = subtotal > 0 ? 2500.0 : 0.0;
    final double discount = 0;
    final double grandTotal = subtotal + serviceFee + shipping - discount;

    return CartQuote(
      itemsSubtotalLocal: subtotal,
      serviceFeeLocal: serviceFee,
      shippingLocal: shipping,
      discountLocal: discount,
      grandTotalLocal: grandTotal,
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
