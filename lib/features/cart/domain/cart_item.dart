import 'dart:convert';

/// عنصر سلة واحد — يخزّن بيانات المنتج القادمة من SHEIN.
class CartItem {
  CartItem({
    required this.lineId,
    required this.goodsId,
    required this.title,
    required this.imageUrl,
    required this.sourceUrl,
    required this.sourcePrice,
    required this.sourceCurrency,
    required this.exchangeRate,
    required this.quantity,
    this.color = '',
    this.size = '',
    this.options = const <String, String>{},
    this.sourceStore = 'SHEIN',
    this.deliveryLocal = 0.0,
    this.sku = '',
    this.variantId = '',
  });

  final String lineId;
  final String goodsId;
  final String title;
  final String imageUrl;
  final String sourceUrl;
  final double sourcePrice;
  final String sourceCurrency;
  final double exchangeRate;
  final int quantity;
  final String color;
  final String size;
  final Map<String, String> options;
  final String sourceStore;
  final double deliveryLocal;
  final String sku;
  final String variantId;

  double get unitPriceLocal => sourcePrice * exchangeRate;
  double get lineTotalLocal => unitPriceLocal * quantity;

  CartItem copyWith({
    String? lineId,
    String? goodsId,
    String? title,
    String? imageUrl,
    String? sourceUrl,
    double? sourcePrice,
    String? sourceCurrency,
    double? exchangeRate,
    int? quantity,
    String? color,
    String? size,
    Map<String, String>? options,
    String? sourceStore,
    double? deliveryLocal,
    String? sku,
    String? variantId,
  }) {
    return CartItem(
      lineId: lineId ?? this.lineId,
      goodsId: goodsId ?? this.goodsId,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourcePrice: sourcePrice ?? this.sourcePrice,
      sourceCurrency: sourceCurrency ?? this.sourceCurrency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      quantity: quantity ?? this.quantity,
      color: color ?? this.color,
      size: size ?? this.size,
      options: options ?? this.options,
      sourceStore: sourceStore ?? this.sourceStore,
      deliveryLocal: deliveryLocal ?? this.deliveryLocal,
      sku: sku ?? this.sku,
      variantId: variantId ?? this.variantId,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'lineId': lineId,
      'goodsId': goodsId,
      'title': title,
      'imageUrl': imageUrl,
      'sourceUrl': sourceUrl,
      'sourcePrice': sourcePrice,
      'sourceCurrency': sourceCurrency,
      'exchangeRate': exchangeRate,
      'quantity': quantity,
      'color': color,
      'size': size,
      'options': jsonEncode(options),
      'sourceStore': sourceStore,
      'deliveryLocal': deliveryLocal,
      'sku': sku,
      'variantId': variantId,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      lineId: map['lineId'] as String? ?? '',
      goodsId: map['goodsId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      sourceUrl: map['sourceUrl'] as String? ?? '',
      sourcePrice: (map['sourcePrice'] as num?)?.toDouble() ?? 0.0,
      sourceCurrency: map['sourceCurrency'] as String? ?? 'SAR',
      exchangeRate: (map['exchangeRate'] as num?)?.toDouble() ?? 1.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      color: map['color'] as String? ?? '',
      size: map['size'] as String? ?? '',
      options: map['options'] != null
          ? Map<String, String>.from(
              jsonDecode(map['options'] as String) as Map<String, dynamic>,
            )
          : <String, String>{},
      sourceStore: map['sourceStore'] as String? ?? 'SHEIN',
      deliveryLocal: (map['deliveryLocal'] as num?)?.toDouble() ?? 0.0,
      sku: map['sku'] as String? ?? '',
      variantId: map['variantId'] as String? ?? '',
    );
  }

  /// يُستخدم في حال استخدام Firestore لاحقاً.
  factory CartItem.fromFirestore(Map<String, dynamic> data) {
    return CartItem.fromMap(data);
  }
}

/// ملخص التسعير القادم من الخدمة.
class CartQuote {
  CartQuote({
    required this.itemsSubtotalLocal,
    required this.serviceFeeLocal,
    required this.shippingLocal,
    required this.discountLocal,
    required this.grandTotalLocal,
    required this.linesCount,
    required this.unitsCount,
    required this.deliveryLocal,
    this.exchangeRate = 1.0,
  });

  final double itemsSubtotalLocal;
  final double serviceFeeLocal;
  final double shippingLocal;
  final double discountLocal;
  final double grandTotalLocal;
  final double exchangeRate;
  final int linesCount;
  final int unitsCount;
  final double deliveryLocal;
}
