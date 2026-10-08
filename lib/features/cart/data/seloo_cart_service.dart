import 'dart:math';
import 'package:get_storage/get_storage.dart';
import '../../../../core/config/seloo_config.dart';
import '../../shein/domain/shein_draft.dart';
import '../domain/cart_item.dart';

class SelooCartService {
  final GetStorage _box = GetStorage();
  static const String _cartKey = 'seloo_cart_items';

  List<CartItem> loadItems() {
    final List<dynamic>? rawList = _box.read<List<dynamic>>(_cartKey);
    if (rawList == null) return <CartItem>[];
    return rawList
        .whereType<Map>()
        .map((Map e) => CartItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> _saveItems(List<CartItem> items) async {
    await _box.write(_cartKey, items.map((e) => e.toMap()).toList());
  }

  String _generateLineId() {
    return 'ln_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${Random.secure().nextInt(0x7FFFFFFF).toRadixString(36)}';
  }

  Future<BridgeResult> addToCart(SheinDraft draft,
      {String? editingLineId}) async {
    try {
      List<CartItem> currentItems = loadItems();

      if (editingLineId != null) {
        final int index =
            currentItems.indexWhere((item) => item.lineId == editingLineId);
        if (index == -1) {
          return BridgeResult.error('لم يتم العثور على المنتج المراد تعديله.');
        }

        final CartItem oldItem = currentItems[index];

        currentItems[index] = CartItem(
          lineId: oldItem.lineId,
          goodsId: draft.goodsId,
          title: draft.title,
          imageUrl: draft.imageUrl,
          sourceUrl: draft.productUrl,
          sourcePrice: draft.price,
          sourceCurrency: draft.currency,
          exchangeRate: oldItem.exchangeRate,
          quantity: oldItem.quantity,
          color: draft.color,
          size: draft.size,
          options: draft.options,
          sourceStore: draft.sourceStore,
          deliveryLocal: 0.0,
          sku: draft.sku,
          variantId: draft.variantId,
        );
      } else {
        final CartItem newItem = CartItem(
          lineId: _generateLineId(),
          goodsId: draft.goodsId,
          title: draft.title,
          imageUrl: draft.imageUrl,
          sourceUrl: draft.productUrl,
          sourcePrice: draft.price,
          sourceCurrency: draft.currency,
          exchangeRate: SelooPricing.northRate,
          quantity: 1,
          color: draft.color,
          size: draft.size,
          options: draft.options,
          sourceStore: draft.sourceStore,
          deliveryLocal: 0.0,
          sku: draft.sku,
          variantId: draft.variantId,
        );
        currentItems.add(newItem);
      }

      await _saveItems(currentItems);
      return BridgeResult.ok('تمت الإضافة بنجاح');
    } catch (e) {
      return BridgeResult.error('حدث خطأ أثناء الإضافة: $e');
    }
  }

  Future<BridgeResult> updateLine(String lineId, int quantity) async {
    try {
      List<CartItem> currentItems = loadItems();
      final int index = currentItems.indexWhere((i) => i.lineId == lineId);
      if (index == -1) return BridgeResult.error('المنتج غير موجود.');
      currentItems[index] = currentItems[index].copyWith(quantity: quantity);
      await _saveItems(currentItems);
      return BridgeResult.ok('تم التحديث');
    } catch (e) {
      return BridgeResult.error('خطأ في التعديل: $e');
    }
  }

  Future<BridgeResult> removeLine(String lineId) async {
    try {
      List<CartItem> currentItems = loadItems();
      currentItems.removeWhere((i) => i.lineId == lineId);
      await _saveItems(currentItems);
      return BridgeResult.ok('تم الحذف');
    } catch (e) {
      return BridgeResult.error('خطأ في الحذف: $e');
    }
  }

  Future<BridgeResult> clear() async {
    try {
      await _box.remove(_cartKey);
      return BridgeResult.ok('تم التفريغ');
    } catch (e) {
      return BridgeResult.error('خطأ في التفريغ: $e');
    }
  }

  Future<CartQuote> quote() async {
    final List<CartItem> items = loadItems();
    return calculateQuote(items, 'north');
  }

  CartQuote calculateQuote(List<CartItem> items, String region) {
    double exchangeRate = SelooPricing.northRate;
    if (region == 'south') exchangeRate = SelooPricing.southRate;
    if (region == 'saudi') exchangeRate = SelooPricing.saudiRate;

    double itemsSubtotalSar = 0;
    int totalQuantity = 0;
    final int linesCount = items.length;

    for (var item in items) {
      itemsSubtotalSar += (item.sourcePrice * item.quantity);
      totalQuantity += item.quantity;
    }

    double shippingSar = 0;
    if (itemsSubtotalSar < SelooPricing.freeShippingThresholdSar) {
      shippingSar = totalQuantity * SelooPricing.shippingPerPieceSar;
    }

    final double serviceFeeSar = SelooPricing.serviceFeeSar;
    const double deliveryLocalSar = 0.0;

    final double itemsSubtotalLocal = itemsSubtotalSar * exchangeRate;
    final double shippingLocal = shippingSar * exchangeRate;
    final double serviceFeeLocal = serviceFeeSar * exchangeRate;
    final double deliveryLocal = deliveryLocalSar * exchangeRate;

    final double grandTotalLocal =
        itemsSubtotalLocal + shippingLocal + serviceFeeLocal + deliveryLocal;

    return CartQuote(
      itemsSubtotalLocal: itemsSubtotalLocal,
      shippingLocal: shippingLocal,
      serviceFeeLocal: serviceFeeLocal,
      discountLocal: 0.0,
      grandTotalLocal: grandTotalLocal,
      exchangeRate: exchangeRate,
      linesCount: linesCount,
      unitsCount: totalQuantity,
      deliveryLocal: deliveryLocal,
    );
  }
}

class BridgeResult {
  BridgeResult._({required this.isOk, required this.message});

  final bool isOk;
  final String message;

  factory BridgeResult.ok(String message) =>
      BridgeResult._(isOk: true, message: message);

  factory BridgeResult.error(String message) =>
      BridgeResult._(isOk: false, message: message);
}
