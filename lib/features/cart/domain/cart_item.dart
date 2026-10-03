import 'package:cloud_firestore/cloud_firestore.dart';

/// سطر واحد في سلة Yemen Seloo.
///
/// سطر السلة مستقل عن منتج SHEIN: يحمل لقطة من بيانات المنتج لحظة الإضافة
/// (السعر الأصلي + سعر الصرف)، لأن أسعار SHEIN تتغيّر ولا يجوز الاعتماد على
/// إعادة القراءة من الصفحة.
class CartItem {
  const CartItem({
    required this.lineId,
    required this.goodsId,
    required this.productUrl,
    required this.title,
    required this.imageUrl,
    required this.color,
    required this.size,
    required this.quantity,
    required this.priceOriginal,
    required this.currency,
    required this.exchangeRate,
    required this.unitPriceLocal,
    required this.source,
    this.sku,
    this.variantId,
    this.addedAt,
  });

  final String lineId; // goodsId_color_size مُنقّحة
  final String goodsId;
  final String productUrl;
  final String title;
  final String imageUrl;
  final String color;
  final String size;
  final int quantity;
  final double priceOriginal; // عملة SHEIN
  final String currency; // SAR / USD ...
  final double exchangeRate; // currency -> YER
  final double unitPriceLocal; // بالريال اليمني
  final String source; // jsonld | globals | meta | dom
  final String? sku;
  final String? variantId;
  final DateTime? addedAt;

  double get lineTotalLocal =>
      double.parse((unitPriceLocal * quantity).toStringAsFixed(2));

  factory CartItem.fromFirestore(String id, Map<String, dynamic> data) {
    double asDouble(String key) {
      final Object? v = data[key];
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? 0;
    }

    int asInt(String key) {
      final Object? v = data[key];
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? 1;
    }

    final Object? ts = data['addedAt'];
    return CartItem(
      lineId: id,
      goodsId: '${data['goodsId'] ?? ''}',
      productUrl: '${data['productUrl'] ?? ''}',
      title: '${data['title'] ?? ''}',
      imageUrl: '${data['imageUrl'] ?? ''}',
      color: '${data['color'] ?? ''}',
      size: '${data['size'] ?? ''}',
      quantity: asInt('quantity'),
      priceOriginal: asDouble('priceOriginal'),
      currency: '${data['currency'] ?? 'SAR'}',
      exchangeRate: asDouble('exchangeRate'),
      unitPriceLocal: asDouble('unitPriceLocal'),
      source: '${data['source'] ?? 'unknown'}',
      sku: data['sku'] is String ? data['sku'] as String : null,
      variantId: data['variantId'] is String ? data['variantId'] as String : null,
      addedAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  CartItem copyWith({
    int? quantity,
    double? exchangeRate,
    double? unitPriceLocal,
  }) =>
      CartItem(
        lineId: lineId,
        goodsId: goodsId,
        productUrl: productUrl,
        title: title,
        imageUrl: imageUrl,
        color: color,
        size: size,
        quantity: quantity ?? this.quantity,
        priceOriginal: priceOriginal,
        currency: currency,
        exchangeRate: exchangeRate ?? this.exchangeRate,
        unitPriceLocal: unitPriceLocal ?? this.unitPriceLocal,
        source: source,
        sku: sku,
        variantId: variantId,
        addedAt: addedAt,
      );
}

/// ملخّص تسعير السلة كما يعيده الخادم.
class CartQuote {
  const CartQuote({
    required this.itemsSubtotalLocal,
    required this.serviceFeeLocal,
    required this.shippingLocal,
    required this.discountLocal,
    required this.grandTotalLocal,
    required this.currency,
    required this.lines,
  });

  final double itemsSubtotalLocal;
  final double serviceFeeLocal;
  final double shippingLocal;
  final double discountLocal;
  final double grandTotalLocal;
  final String currency;
  final List<CartItem> lines;

  int get linesCount => lines.length;
  int get unitsCount =>
      lines.fold<int>(0, (int sum, CartItem item) => sum + item.quantity);

  factory CartQuote.fromMap(Map<String, dynamic> map) {
    double asDouble(Object? v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    final List<CartItem> parsed = <CartItem>[];
    final Object? rawLines = map['lines'];
    if (rawLines is List) {
      for (final Object? entry in rawLines) {
        if (entry is Map) {
          final Map<String, dynamic> m = entry.cast<String, dynamic>();
          parsed.add(CartItem.fromFirestore('${m['lineId'] ?? ''}', m));
        }
      }
    }
    return CartQuote(
      itemsSubtotalLocal: asDouble(map['itemsSubtotalLocal']),
      serviceFeeLocal: asDouble(map['serviceFeeLocal']),
      shippingLocal: asDouble(map['shippingLocal']),
      discountLocal: asDouble(map['discountLocal']),
      grandTotalLocal: asDouble(map['grandTotalLocal']),
      currency: '${map['currency'] ?? 'YER'}',
      lines: parsed,
    );
  }
}
