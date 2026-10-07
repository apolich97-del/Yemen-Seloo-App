import 'package:cloud_firestore/cloud_firestore.dart';

/// سطر واحد في سلة Yemen Seloo.
///
/// يحمل لقطة من بيانات المنتج لحظة الإضافة (سعر المصدر + سعر الصرف)،
/// لأن أسعار SHEIN تتغيّر ولا يجوز الاعتماد على إعادة القراءة من الصفحة.
class CartItem {
  const CartItem({
    required this.lineId,
    required this.goodsId,
    required this.productUrl,
    required this.title,
    required this.imageUrl,
    required this.color,
    required this.size,
    required this.options,
    required this.sourceStore,
    required this.quantity,
    required this.sourcePrice,
    required this.sourceCurrency,
    required this.exchangeRate,
    required this.unitPriceLocal,
    required this.source,
    this.sku,
    this.variantId,
    this.addedAt,
  });

  /// معرّف فريد للسطر — لا يتغير عند التعديل.
  final String lineId;

  final String goodsId;
  final String productUrl;
  final String title;
  final String imageUrl;
  final String color;
  final String size;

  /// الخيارات الإضافية (فارغة إذا لم نقرأها بثقة).
  final Map<String, String> options;

  /// اسم المتجر المصدر (SHEIN افتراضيًا).
  final String sourceStore;

  final int quantity;

  /// سعر المصدر (SAR عادة).
  final double sourcePrice;

  /// عملة المصدر.
  final String sourceCurrency;

  /// سعر الصرف: 1 sourceCurrency → كم YER.
  final double exchangeRate;

  /// سعر الوحدة بالريال اليمني.
  final double unitPriceLocal;

  /// كيف استُخرجت البيانات.
  final String source;

  final String? sku;
  final String? variantId;
  final DateTime? addedAt;

  double get lineTotalLocal =>
      double.parse((unitPriceLocal * quantity).toStringAsFixed(2));

  /// قراءة من Firestore / JSON (يدعم الأسماء القديمة والجديدة).
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

    // ⭐ دعم الأسماء القديمة والجديدة
    double sourcePrice() {
      final double sp = asDouble('sourcePrice');
      if (sp > 0) return sp;
      return asDouble('priceOriginal'); // fallback للبيانات القديمة
    }

    String sourceCurrency() {
      final String sc = '${data['sourceCurrency'] ?? ''}'.trim();
      if (sc.isNotEmpty) return sc;
      return '${data['currency'] ?? 'SAR'}'; // fallback
    }

    // ⭐ قراءة options
    final Map<String, String> options = <String, String>{};
    final Object? rawOptions = data['options'];
    if (rawOptions is Map) {
      rawOptions.forEach((Object? k, Object? v) {
        if (k is String && v is String) {
          final String ks = k.trim();
          final String vs = v.trim();
          if (ks.isNotEmpty && vs.isNotEmpty) {
            options[ks] = vs;
          }
        }
      });
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
      options: options,
      sourceStore: '${data['sourceStore'] ?? 'SHEIN'}',
      quantity: asInt('quantity'),
      sourcePrice: sourcePrice(),
      sourceCurrency: sourceCurrency(),
      exchangeRate: asDouble('exchangeRate'),
      unitPriceLocal: asDouble('unitPriceLocal'),
      source: '${data['source'] ?? 'unknown'}',
      sku: data['sku'] is String ? data['sku'] as String : null,
      variantId: data['variantId'] is String ? data['variantId'] as String : null,
      addedAt: ts is Timestamp
          ? ts.toDate()
          : (ts is String ? DateTime.tryParse(ts) : null),
    );
  }

  CartItem copyWith({
    int? quantity,
    double? exchangeRate,
    double? unitPriceLocal,
    String? color,
    String? size,
    Map<String, String>? options,
  }) =>
      CartItem(
        lineId: lineId,
        goodsId: goodsId,
        productUrl: productUrl,
        title: title,
        imageUrl: imageUrl,
        color: color ?? this.color,
        size: size ?? this.size,
        options: options ?? this.options,
        sourceStore: sourceStore,
        quantity: quantity ?? this.quantity,
        sourcePrice: sourcePrice,
        sourceCurrency: sourceCurrency,
        exchangeRate: exchangeRate ?? this.exchangeRate,
        unitPriceLocal: unitPriceLocal ?? this.unitPriceLocal,
        source: source,
        sku: sku,
        variantId: variantId,
        addedAt: addedAt,
      );

  /// تحويل إلى خريطة للتخزين المحلي (get_storage).
  Map<String, dynamic> toMap() => <String, dynamic>{
        'lineId': lineId,
        'goodsId': goodsId,
        'productUrl': productUrl,
        'title': title,
        'imageUrl': imageUrl,
        'color': color,
        'size': size,
        'options': options,
        'sourceStore': sourceStore,
        'quantity': quantity,
        'sourcePrice': sourcePrice,
        'sourceCurrency': sourceCurrency,
        'exchangeRate': exchangeRate,
        'unitPriceLocal': unitPriceLocal,
        'source': source,
        'sku': sku ?? '',
        'variantId': variantId ?? '',
        'addedAt': addedAt?.toIso8601String(),
      };
}

/// ملخّص تسعير السلة كما يعده الخادم / الخدمة.
class CartQuote {
  const CartQuote({
    required this.itemsSubtotalLocal,
    required this.serviceFeeLocal,
    required this.shippingLocal,
    required this.discountLocal,
    required this.grandTotalLocal,
    required this.currency,
    required this.lines,
    this.deliveryLocal = 0,
  });

  final double itemsSubtotalLocal;
  final double serviceFeeLocal;
  final double shippingLocal;

  /// التوصيل المحلي داخل اليمن — منفصل عن الشحن الدولي.
  final double deliveryLocal;

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
      deliveryLocal: asDouble(map['deliveryLocal']),
      discountLocal: asDouble(map['discountLocal']),
      grandTotalLocal: asDouble(map['grandTotalLocal']),
      currency: '${map['currency'] ?? 'YER'}',
      lines: parsed,
    );
  }
}
