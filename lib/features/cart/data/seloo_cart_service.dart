import 'dart:math';
import 'package:get_storage/get_storage.dart';
import '../../../../core/config/seloo_config.dart';
import '../../shein/domain/shein_draft.dart';
import '../domain/cart_item.dart';

class SelooCartService {
  final GetStorage _box = GetStorage();
  static const String _cartKey = 'seloo_cart_items';
  static const String _orderSeqKey = 'seloo_order_seq';

  // ═══════════════════════════════════════════════════════════════
  // تحميل وحفظ السلة
  // ═══════════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════════
  // توليد lineId
  // ═══════════════════════════════════════════════════════════════

  String _generateLineId() {
    return 'ln_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${Random.secure().nextInt(0x7FFFFFFF).toRadixString(36)}';
  }

  // ═══════════════════════════════════════════════════════════════
  // إضافة / تعديل منتج
  // ═══════════════════════════════════════════════════════════════

  Future<BridgeResult> addToCart(SheinDraft draft,
      {String? editingLineId}) async {
    try {
      List<CartItem> currentItems = loadItems();

      if (editingLineId != null) {
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

  // ═══════════════════════════════════════════════════════════════
  // تعديل الكمية / الحذف / التفريغ
  // ═══════════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════════
  // حساب الإجمالي (Quote)
  // ═══════════════════════════════════════════════════════════════

  Future<CartQuote> quote() async {
    final List<CartItem> items = loadItems();
    return calculateQuote(items, 'north');
  }

  Future<CartQuote> quoteFor(String region) async {
    final List<CartItem> items = loadItems();
    return calculateQuote(items, region);
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

  // ═══════════════════════════════════════════════════════════════
  // خوارزمية رقم الطلب (YS + سنة + شهر + أسبوع - حرف + رقم)
  // ═══════════════════════════════════════════════════════════════

  String _buildOrderId(int sequence) {
    final DateTime now = DateTime.now();
    final String yy = (now.year % 100).toString().padLeft(2, '0');

    const List<String> monthCodes = <String>[
      'JA', 'FE', 'MR', 'AP', 'MY', 'JN',
      'JL', 'AU', 'SE', 'OC', 'NV', 'DE',
    ];
    final String mm = monthCodes[now.month - 1];

    final int week = ((now.day - 1) ~/ 7) + 1;
    final String letter = String.fromCharCode(65 + ((sequence - 1) % 26));
    final String seq =
        (((sequence - 1) % 1000) + 1).toString().padLeft(3, '0');

    return 'YS$yy$mm$week-$letter$seq';
  }

  int _nextSequence() {
    final int last = _box.read<int>(_orderSeqKey) ?? 0;
    final int next = last + 1;
    _box.write(_orderSeqKey, next);
    return next;
  }

  // ═══════════════════════════════════════════════════════════════
  // ⭐ إنشاء طلب محلي — يدعم عمولة المندوب
  // ═══════════════════════════════════════════════════════════════

  /// إنشاء طلب محلي — بدون Backend رسمي.
  /// يدعم إضافة عمولة المندوب إذا وافق عليها.
  Future<BridgeResult> submitOrder({
    required String contactPhone,
    required String addressLine,
    required String city,
    required double lat,
    required double lng,
    String region = 'north',
    double commissionPerPiece = 0.0,
    bool commissionApproved = false,
  }) async {
    try {
      final List<CartItem> items = loadItems();
      if (items.isEmpty) {
        return BridgeResult.failure('error', 'السلة فارغة.');
      }

      // التسعير الأساسي
      final CartQuote q = calculateQuote(items, region);

      // ⭐ حساب العمولة (إن وجدت وموافق عليها)
      final int totalPieces = items.fold<int>(
          0, (int sum, CartItem i) => sum + i.quantity);
      final bool hasCommission = commissionApproved && commissionPerPiece > 0;
      final double commissionTotalSar =
          hasCommission ? commissionPerPiece * totalPieces : 0.0;
      final double commissionTotalYer =
          commissionTotalSar * q.exchangeRate;

      // ⭐ الإجمالي النهائي (مع العمولة إن وُجدت)
      final double finalTotalLocal =
          q.grandTotalLocal + (hasCommission ? commissionTotalYer : 0.0);

      final int seq = _nextSequence();
      final String orderId = _buildOrderId(seq);

      // حفظ محلي
      final List<dynamic> orders =
          _box.read<List<dynamic>>('seloo_orders') ?? <dynamic>[];

      orders.add(<String, dynamic>{
        'orderId': orderId,
        'contactPhone': contactPhone,
        'addressLine': addressLine,
        'city': city,
        'lat': lat,
        'lng': lng,
        'region': region,
        'items': items.map((CartItem i) => i.toMap()).toList(),
        'quote': <String, dynamic>{
          'itemsSubtotalLocal': q.itemsSubtotalLocal,
          'serviceFeeLocal': q.serviceFeeLocal,
          'shippingLocal': q.shippingLocal,
          'discountLocal': q.discountLocal,
          'grandTotalLocal': q.grandTotalLocal, // قبل العمولة
          'exchangeRate': q.exchangeRate,
          'linesCount': q.linesCount,
          'unitsCount': q.unitsCount,
          'deliveryLocal': q.deliveryLocal,
        },
        // ⭐ العمولة (إن وُجدت)
        'commission': hasCommission
            ? <String, dynamic>{
                'perPieceSar': commissionPerPiece,
                'totalPieces': totalPieces,
                'totalSar': commissionTotalSar,
                'totalYer': commissionTotalYer,
                'exchangeRate': q.exchangeRate,
                'approved': true,
              }
            : null,
        // ⭐ المستحق للمندوب (بالعملة اليمنية)
        'amountDueToAgent': hasCommission ? commissionTotalYer : 0.0,
        // ⭐ الإجمالي النهائي (بعد العمولة)
        'finalTotalLocal': finalTotalLocal,
        'status': 'pending',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });

      await _box.write('seloo_orders', orders);

      // تفريغ السلة
      await clear();

      return BridgeResult(
        status: 'ok',
        message: hasCommission
            ? 'تم إنشاء الطلب مع العمولة'
            : 'تم إنشاء الطلب',
        orderId: orderId,
      );
    } catch (e) {
      return BridgeResult.failure('error', 'تعذّر إنشاء الطلب: $e');
    }
  }
}
