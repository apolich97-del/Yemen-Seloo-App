import 'dart:math' as math;
import 'package:get/get.dart';
import '../../../core/config/seloo_config.dart';
import '../../../core/models/order.dart';
import '../../../core/services/refund_policy.dart';
import '../application/cart_counter.dart';
import '../domain/cart_item.dart';
import 'seloo_cart_service.dart';

/// سطر سلة مُطَبَّع — وحدة القراءة الوحيدة التي يعتمدها مسار الاستيراد.
class CartLine {
  const CartLine({
    required this.goodsId,
    required this.variantKey,
    required this.titleAr,
    required this.imageUrl,
    required this.color,
    required this.size,
    required this.qty,
    required this.unitPriceSar,
    this.nonRefundable = false,
    this.nonRefundableReason = '',
  });

  final String goodsId;
  final String variantKey;
  final String titleAr;
  final String imageUrl;
  final String color;
  final String size;
  final int qty;
  final double unitPriceSar;
  final bool nonRefundable;
  final String nonRefundableReason;

  bool get isNonRefundable =>
      nonRefundable || SelooRefundPolicy.detectNonRefundable(titleAr);

  String get effectiveNonRefundableReason =>
      SelooRefundPolicy.reasonFor(titleAr, '', nonRefundableReason);

  double get lineTotalSar => unitPriceSar * qty;

  Map<String, dynamic> toServer() => <String, dynamic>{
        'goodsId': goodsId,
        'qty': qty,
        'color': color,
        'size': size,
        'unitPriceSar': unitPriceSar,
        'nonRefundable': isNonRefundable,
        'nonRefundableReason': effectiveNonRefundableReason,
      };

  Map<String, dynamic> toJson() => <String, dynamic>{
        'goodsId': goodsId,
        'variantKey': variantKey,
        'titleAr': titleAr,
        'imageUrl': imageUrl,
        'color': color,
        'size': size,
        'qty': qty,
        'unitPriceSar': unitPriceSar,
        'nonRefundable': isNonRefundable,
        'nonRefundableReason': effectiveNonRefundableReason,
      };

  @override
  String toString() =>
      'CartLine($goodsId, "$color"/"$size", qty=$qty, $unitPriceSar SAR)';
}

/// قراءة السلة المحلية بشكل ثابت ومُطَبَّع.
class CartRepository {
  CartRepository({SelooCartService? service})
      : _service = service ?? SelooCartService();

  final SelooCartService _service;

  static const int maxQtyPerLine = SelooConfig.maxQuantityPerLine;

  static String variantKey(String goodsId, String color, String size) =>
      '$goodsId|${color.trim()}|${size.trim()}';

  static bool _isNumericId(String value) => RegExp(r'^\d+$').hasMatch(value);

  static int _normalizeQty(int raw) {
    if (raw < 0) return 0;
    if (raw == 0) return 0;
    if (raw > maxQtyPerLine) return maxQtyPerLine;
    return raw;
  }

  List<CartLine> read() {
    List<CartItem> items;
    try {
      items = _service.loadItems();
    } catch (_) {
      return const <CartLine>[];
    }

    final Map<String, _Acc> merged = <String, _Acc>{};

    for (final CartItem item in items) {
      final String goodsId = item.goodsId.trim();
      if (!_isNumericId(goodsId)) continue;

      final double price = item.sourcePrice;
      if (!price.isFinite || price <= 0) continue;

      final int qty = _normalizeQty(item.quantity);
      if (qty <= 0) continue;

      final String color = item.color.trim();
      final String size = item.size.trim();
      final String key = variantKey(goodsId, color, size);
      final bool nr = item.isNonRefundable;
      final String nrReason = item.effectiveNonRefundableReason;

      final _Acc? existing = merged[key];
      if (existing == null) {
        merged[key] = _Acc(
          goodsId: goodsId,
          variantKey: key,
          titleAr: item.title.trim(),
          imageUrl: item.imageUrl.trim(),
          color: color,
          size: size,
          qty: qty,
          unitPriceSar: price,
          nonRefundable: nr,
          nonRefundableReason: nrReason,
        );
        continue;
      }

      existing.qty = math.min(maxQtyPerLine, existing.qty + qty);
      if (price > 0) existing.unitPriceSar = price;
      if (existing.titleAr.isEmpty) existing.titleAr = item.title.trim();
      if (existing.imageUrl.isEmpty) existing.imageUrl = item.imageUrl.trim();
      if (nr) existing.nonRefundable = true;
      if (existing.nonRefundableReason.isEmpty && nrReason.isNotEmpty) {
        existing.nonRefundableReason = nrReason;
      }
    }

    final List<CartLine> lines = merged.values
        .where((_Acc a) => a.qty > 0)
        .map(
          (_Acc a) => CartLine(
            goodsId: a.goodsId,
            variantKey: a.variantKey,
            titleAr: a.titleAr,
            imageUrl: a.imageUrl,
            color: a.color,
            size: a.size,
            qty: a.qty,
            unitPriceSar: a.unitPriceSar,
            nonRefundable: a.nonRefundable,
            nonRefundableReason: a.nonRefundableReason,
          ),
        )
        .toList(growable: false);

    return List<CartLine>.unmodifiable(lines);
  }

  double subtotalSar(List<CartLine> lines) =>
      lines.fold<double>(0, (double sum, CartLine l) => sum + l.lineTotalSar);

  int pieces(List<CartLine> lines) =>
      lines.fold<int>(0, (int sum, CartLine l) => sum + l.qty);

  int count(List<CartLine> lines) => lines.length;

  Future<int> reorderOrderItems(List<OrderItem> orderItems) async {
    if (orderItems.isEmpty) return 0;
    final List<CartItem> existing = List<CartItem>.from(_service.loadItems());
    final List<String> addedLineIds = <String>[];
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    int idx = 0;
    for (final OrderItem it in orderItems) {
      idx++;
      final String goodsId = it.goodsId.trim();
      final String color = it.color.trim();
      final String size = it.size.trim();
      final int existingIdx = existing.indexWhere((e) =>
          e.goodsId.trim() == goodsId &&
          e.color.trim() == color &&
          e.size.trim() == size);
      if (existingIdx >= 0) {
        final CartItem prev = existing[existingIdx];
        final int mergedQty = math.min(maxQtyPerLine, prev.quantity + it.qty);
        existing[existingIdx] = prev.copyWith(quantity: mergedQty);
        addedLineIds.add(prev.lineId);
      } else {
        final String lid = 're_${nowMs}_$idx';
        existing.add(CartItem(
          lineId: lid,
          goodsId: goodsId.isNotEmpty ? goodsId : '$nowMs$idx',
          title: it.title,
          imageUrl: it.imageUrl,
          sourceUrl: it.productUrl,
          sourcePrice: it.unitPriceSar > 0 ? it.unitPriceSar : 1,
          sourceCurrency: 'SAR',
          exchangeRate: 1,
          quantity: _normalizeQty(it.qty),
          color: color,
          size: size,
          sku: it.sku,
          nonRefundable: it.isNonRefundable,
          nonRefundableReason: it.effectiveNonRefundableReason,
        ));
        addedLineIds.add(lid);
      }
    }
    await _service.saveItems(existing);
    try {
      final CartCounter cart = Get.find<CartCounter>();
      await cart.onItemAdded();
      cart.selected.addAll(addedLineIds);
    } catch (_) {}
    return orderItems.length;
  }

  Future<void> clear() async {
    await _service.clear();
    try {
      final CartCounter cart = Get.find<CartCounter>();
      cart.items.clear();
      cart.quote.value = null;
    } catch (_) {}
  }
}

class _Acc {
  _Acc({
    required this.goodsId,
    required this.variantKey,
    required this.titleAr,
    required this.imageUrl,
    required this.color,
    required this.size,
    required this.qty,
    required this.unitPriceSar,
    this.nonRefundable = false,
    this.nonRefundableReason = '',
  });

  final String goodsId;
  final String variantKey;
  String titleAr;
  String imageUrl;
  final String color;
  final String size;
  int qty;
  double unitPriceSar;
  bool nonRefundable;
  String nonRefundableReason;
}
