import 'dart:convert';

/// خطأ تحقق من مسودة منتج قادمة من الـWebView.
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
    required this.sourcePrice,
    required this.sourceCurrency,
    required this.quantity,
    required this.color,
    required this.size,
    required this.options,
    required this.sourceStore,
    required this.sku,
    required this.variantId,
    required this.source,
    required this.clientTs,
  });

  final String goodsId;
  final String productUrl;
  final String title;
  final String imageUrl;

  /// سعر المصدر كما ظهر في SHEIN.
  final double sourcePrice;

  /// عملة المصدر (SAR عادة).
  final String sourceCurrency;

  final int quantity;
  final String color;
  final String size;

  /// الخيارات الإضافية (الطول، القماش، إلخ).
  /// فارغة إذا لم نتمكن من قراءتها بثقة.
  final Map<String, String> options;

  /// اسم المتجر المصدر (SHEIN افتراضيًا).
  final String sourceStore;

  final String sku;
  final String variantId;

  /// كيف استُخرجت البيانات: jsonld | globals | meta | dom | merged.
  final String source;
  final DateTime clientTs;

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
    if (parsed == null ||
        !(parsed.scheme == 'https' || parsed.scheme == 'http')) {
      throw const DraftValidationException('productUrl', 'رابط غير صالح');
    }

    // ⭐ نقرأ من sourcePrice أو price (دعم مؤقت للحقل القديم)
    final Object? rawPrice = payload['sourcePrice'] ?? payload['price'];
    final double? price =
        rawPrice is num ? rawPrice.toDouble() : double.tryParse('$rawPrice');
    if (price == null || price <= 0 || price > 1000000) {
      throw const DraftValidationException('sourcePrice', 'سعر غير منطقي');
    }

    final Object? rawQty = payload['quantity'];
    final int quantity =
        rawQty is num ? rawQty.toInt() : int.tryParse('$rawQty') ?? 1;
    if (quantity < 1 || quantity > 50) {
      throw const DraftValidationException('quantity', 'كمية خارج الحد المسموح');
    }

    // ⭐ نقرأ من sourceCurrency أو currency
    final String currencyRaw =
        (payload['sourceCurrency'] as String?) ??
            (payload['currency'] as String?) ??
            'SAR';
    final String currency = currencyRaw.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw const DraftValidationException('sourceCurrency', 'رمز عملة غير صالح');
    }

    // ⭐ قراءة options (قد تكون فارغة)
    final Map<String, String> options = <String, String>{};
    final Object? rawOptions = payload['options'];
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

    // ⭐ sourceStore (افتراضي SHEIN)
    final String sourceStoreRaw =
        (payload['sourceStore'] as String?)?.trim().toUpperCase() ?? 'SHEIN';
    final String sourceStore =
        sourceStoreRaw.isEmpty ? 'SHEIN' : sourceStoreRaw;

    return SheinDraft(
      goodsId: goodsId,
      productUrl: productUrl,
      title: requireText('title', maxLength: 300),
      imageUrl: (payload['imageUrl'] as String?)?.trim() ?? '',
      sourcePrice: price,
      sourceCurrency: currency,
      quantity: quantity,
      color: (payload['color'] as String?)?.trim() ?? '',
      size: (payload['size'] as String?)?.trim() ?? '',
      options: options,
      sourceStore: sourceStore,
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
        'sourcePrice': sourcePrice,
        'sourceCurrency': sourceCurrency,
        'quantity': quantity,
        'color': color,
        'size': size,
        'options': options,
        'sourceStore': sourceStore,
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
