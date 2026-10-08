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
        // حالة التعديل: نحدّث السطر الموجود
        final int index =
            currentItems.indexWhere((item) => item.lineId == editingLineId);
        if (index == -1) {
          return BridgeResult.failure(
              'error', 'لم يتم العثور على المنتج المراد تعديله.');
        }

        final CartItem oldItem = currentItems[index];

        currentItems[index] = CartItem(
          lineId: oldItem.lineId,
          goodsId: draft.goodsId,
          title: draft.title,
          imageUrl: draft.imageUrl,
          sourceUrl: draft.productUrl,
          sourcePrice: draft.sourcePrice,
          sourceCurrency: draft.sourceCurrency,
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
        // حالة الإضافة الجديدة
        final CartItem newItem = CartItem(
          lineId: _generateLineId(),
          goodsId: draft.goodsId,
          title: draft.title,
          imageUrl: draft.imageUrl,
          sourceUrl: draft.productUrl,
          sourcePrice: draft.sourcePrice,
          sourceCurrency: draft.sourceCurrency,
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
      return const BridgeResult(status: 'ok', message: 'تمت الإضافة بنجاح');
    } catch (e) {
      return BridgeResult.failure('error', 'حدث خطأ أثناء الإضافة: $e');
    }
  }

  Future<BridgeResult> updateLine(String lineId, int quantity) async {
    try {
      List<CartItem> currentItems = loadItems();
      final int index = currentItems.indexWhere((i) => i.lineId == lineId);
      if (index == -1) {
        return BridgeResult.failure('error', 'المنتج غير موجود.');
      }
      currentItems[index] = currentItems[index].copyWith(quantity: quantity);
      await _saveItems(currentItems);
      return const BridgeResult(status: 'ok', message: 'تم التحديث');
    } catch (e) {
      return BridgeResult.failure('error', 'خطأ في التعديل: $e');
    }
  }

  Future<BridgeResult> removeLine(String lineId) async {
    try {
      List<CartItem> currentItems = loadItems();
      currentItems.removeWhere((i) => i.lineId == lineId);
      await _saveItems(currentItems);
      return const BridgeResult(status: 'ok', message: 'تم الحذف');
    } catch (e) {
      return BridgeResult.failure('error', 'خطأ في الحذف: $e');
    }
  }

  Future<BridgeResult> clear() async {
    try {
      await _box.remove(_cartKey);
      return const BridgeResult(status: 'ok', message: 'تم التفريغ');
    } catch (e) {
      return BridgeResult.failure('error', 'خطأ في التفريغ: $e');
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

  /// إنشاء طلب محلي — بدون Backend رسمي، بدون دفع.
  /// يعتمد حصراً على التسعير الجديد (1.22 SAR + شحن 75 SAR + صرف 140/413).
  Future<BridgeResult> submitOrder({
    required String contactPhone,
    required String addressLine,
    required String city,
    required double lat,
    required double lng,
  }) async {
    try {
      final List<CartItem> items = loadItems();
      if (items.isEmpty) {
        return BridgeResult.failure('error', 'السلة فارغة.');
      }

      // التسعير الجديد حصراً
      final CartQuote q = calculateQuote(items, 'north');

      final String orderId =
          'ord_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

      // حفظ محلي فقط (GetStorage) — لا Firestore، لا دفع
      final List<dynamic> orders =
          _box.read<List<dynamic>>('seloo_orders') ?? <dynamic>[];

      orders.add(<String, dynamic>{
        'orderId': orderId,
        'contactPhone': contactPhone,
        'addressLine': addressLine,
        'city': city,
        'lat': lat,
        'lng': lng,
        'items': items.map((CartItem i) => i.toMap()).toList(),
        'quote': <String, dynamic>{
          'itemsSubtotalLocal': q.itemsSubtotalLocal,
          'serviceFeeLocal': q.serviceFeeLocal,   // ← 1.22 SAR فقط
          'shippingLocal': q.shippingLocal,       // ← سياسة 75 SAR الجديدة
          'discountLocal': q.discountLocal,
          'grandTotalLocal': q.grandTotalLocal,
          'exchangeRate': q.exchangeRate,         // ← 140 / 413
          'linesCount': q.linesCount,
          'unitsCount': q.unitsCount,
          'deliveryLocal': q.deliveryLocal,
        },
        'status': 'pending',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });

      await _box.write('seloo_orders', orders);

      // تفريغ السلة بعد نجاح حفظ الطلب
      await clear();

      return BridgeResult(
        status: 'ok',
        message: 'تم استلام طلبك',
        orderId: orderId,
      );
    } catch (e) {
      return BridgeResult.failure('error', 'تعذّر إنشاء الطلب: $e');
    }
  }
}
