import 'dart:convert';

/// خطأ تحقق من مسودة منتج قادمة من الـWebView.
///
/// الحقول مُسمّاة كي يستطيع السجل (وهو مُصدَّر إلى Crashlytics) أن يخبرنا
/// أي حقل انكسر بالضبط عند تحديث واجهة SHEIN.
class DraftValidationException implements Exception {
  const DraftValidationException(this.field, this.reason);

  final String field;
  final String reason;

  @override
  String toString() => 'DraftValidationException($field): $reason';
}

/// مسودة منتج SHEIN كما وصلت من الجسر — بعد التحقق.
class SheinDraft {
  const SheinDraft({
    required this.goodsId,
    required this.productUrl,
    required this.title,
    required this.imageUrl,
    required this.priceOriginal,
    required this.currency,
    required this.quantity,
    required this.color,
    required this.size,
    required this.sku,
    required this.variantId,
    required this.source,
    required this.clientTs,
  });

  final String goodsId;
  final String productUrl;
  final String title;
  final String imageUrl;
  final double priceOriginal;
  final String currency;
  final int quantity;
  final String color;
  final String size;

  /// معرّف SKU/Variant إن وجد — يساعد على تطابق أدق مع SHEIN.
  final String sku;
  final String variantId;

  /// أي مصدر استُخدم في الاستخراج: jsonld | globals | meta | dom | merged.
  final String source;
  final DateTime clientTs;

  /// مفتاح السطر في السلة.
  String get lineKey => '$goodsId|$color|$size';

  /// تحقق صارم: لا يُقبل أي حقل ناقص، ولا سعر سالب، ولا كمية خارج الحدود.
  factory SheinDraft.fromBridgePayload(Map<String, dynamic> payload) {
    String requireText(String key, {int maxLength = 500}) {
      final Object? raw = payload[key];
      if (raw is! String || raw.trim().isEmpty) {
        throw DraftValidationException(key, 'حقل نصي مطلوب ومفقود');
      }
      final String value = raw.trim();
      if (value.length > maxLength) {
        throw DraftValidationException(key, 'النص أطول من الحد ($maxLength)');
      }
      return value;
    }

    final String goodsId = requireText('goodsId', maxLength: 32);
    if (!RegExp(r'^\d+$').hasMatch(goodsId)) {
      throw const DraftValidationException('goodsId', 'معرّف المنتج غير رقمي');
    }

    final String productUrl = requireText('productUrl', maxLength: 2048);
    final Uri? parsed = Uri.tryParse(productUrl);
    if (parsed == null || !(parsed.scheme == 'https' || parsed.scheme == 'http')) {
      throw const DraftValidationException('productUrl', 'رابط غير صالح');
    }

    final Object? rawPrice = payload['price'];
    final double? price =
        rawPrice is num ? rawPrice.toDouble() : double.tryParse('$rawPrice');
    if (price == null || price <= 0 || price > 1000000) {
      throw const DraftValidationException('price', 'سعر غير منطقي');
    }

    final Object? rawQty = payload['quantity'];
    final int quantity =
        rawQty is num ? rawQty.toInt() : int.tryParse('$rawQty') ?? 1;
    if (quantity < 1 || quantity > 50) {
      throw const DraftValidationException('quantity', 'كمية خارج الحد المسموح');
    }

    final String currency =
        (payload['currency'] as String?)?.trim().toUpperCase() ?? 'SAR';
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw const DraftValidationException('currency', 'رمز عملة غير صالح');
    }

    return SheinDraft(
      goodsId: goodsId,
      productUrl: productUrl,
      title: requireText('title', maxLength: 300),
      imageUrl: (payload['imageUrl'] as String?)?.trim() ?? '',
      priceOriginal: price,
      currency: currency,
      quantity: quantity,
      color: (payload['color'] as String?)?.trim() ?? '',
      size: (payload['size'] as String?)?.trim() ?? '',
      sku: (payload['sku'] as String?)?.trim() ?? '',
      variantId: (payload['variantId'] as String?)?.trim() ?? '',
      source: (payload['source'] as String?)?.trim() ?? 'merged',
      clientTs: DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'goodsId': goodsId,
        'productUrl': productUrl,
        'title': title,
        'imageUrl': imageUrl,
        'price': priceOriginal,
        'currency': currency,
        'quantity': quantity,
        'color': color,
        'size': size,
        'sku': sku,
        'variantId': variantId,
        'source': source,
      };
}

/// مغلّف الحمولة القادمة من السكربت: { action, payload }.
class BridgeEnvelope {
  const BridgeEnvelope({required this.action, required this.payload});

  final String action;
  final Map<String, dynamic> payload;

  static BridgeEnvelope? tryParse(Object? raw) {
    Map<String, dynamic>? map;
    if (raw is Map) {
      map = raw.cast<String, dynamic>();
    } else if (raw is String) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is Map) map = decoded.cast<String, dynamic>();
      } on FormatException {
        return null;
      }
    }
    if (map == null) return null;

    final Object? action = map['action'];
    final Object? payload = map['payload'];
    if (action is! String) return null;
    return BridgeEnvelope(
      action: action,
      payload: payload is Map
          ? payload.cast<String, dynamic>()
          : <String, dynamic>{},
    );
  }
}

/// نتيجة عملية سلة — تُعاد إلى السكربت ليُظهرها للمستخدم فورًا.
class BridgeResult {
  const BridgeResult({
    required this.status,
    required this.message,
    this.cartCount,
    this.orderId,
  });

  final String status;
  final String message;
  final int? cartCount;
  final String? orderId;

  bool get isOk => status == 'ok';

  factory BridgeResult.failure(String status, String message) =>
      BridgeResult(status: status, message: message);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'status': status,
        'message': message,
        if (cartCount != null) 'cartCount': cartCount,
        if (orderId != null) 'orderId': orderId,
      };
}
