
import 'dart:convert';

import 'package:http/http.dart' as http;

/// استثناء برسالة عربية واضحة.
class SheinShareException implements Exception {
  const SheinShareException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// قراءة منتجات سلة SHEIN المشتركة.
class SheinShareApi {
  static const String _api =
      'https://m.shein.com/ar/bff-api/order/cart/share/landing'
      '?_ver=1.1.8&_lang=ar';

  static const String _ua =
      'Mozilla/5.0 (Linux; Android 13) '
      'AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36';

  static const Duration _timeout = Duration(seconds: 25);
  static const int _maxTitleLength = 300;

  /// يقبل رابط السلة الكامل أو group_id مباشرة.
  Future<List<Map<String, dynamic>>> fetchSharedCart(
    String input,
  ) async {
    final String text = input.trim();

    if (text.isEmpty) {
      throw const SheinShareException(
        'الصق رابط السلة المشتركة أولاً.',
      );
    }

    String? groupId = _extractGroupId(text);

    if (groupId == null &&
        RegExp(r'^\d{5,}$').hasMatch(text)) {
      groupId = text;
    }

    if (groupId == null) {
      final Match? match =
          RegExp(r'https?://[^\s"<>]+').firstMatch(text);

      final String? url = match?.group(0);

      if (url != null) {
        try {
          final http.Response response = await http
              .get(
                Uri.parse(url),
                headers: <String, String>{
                  'User-Agent': _ua,
                },
              )
              .timeout(_timeout);

          groupId = _extractGroupId(
            '${response.headers['location'] ?? ''}\n'
            '${response.body}',
          );
        } catch (_) {
          // ستظهر رسالة مناسبة إذا تعذر استخراج المعرّف.
        }
      }
    }

    if (groupId == null) {
      throw const SheinShareException(
        'لم أجد معرّف السلة. تأكد من نسخ رابط المشاركة كاملاً.',
      );
    }

    final http.Response response;

    try {
      response = await http
          .post(
            Uri.parse(_api),
            headers: <String, String>{
              'Accept': 'application/json, text/plain, */*',
              'Content-Type': 'application/json',
              'Referer': 'https://m.shein.com/',
              'AppCurrency': 'SAR',
              'AppLanguage': 'ar',
              'User-Agent': _ua,
            },
            body: jsonEncode(<String, dynamic>{
              'groupId': groupId,
              'localCountry': 'SA',
              'userLocalSizeCountry': '',
            }),
          )
          .timeout(_timeout);
    } catch (_) {
      throw const SheinShareException(
        'تعذر الاتصال بشي إن. تحقق من الإنترنت وأعد المحاولة.',
      );
    }

    if (response.statusCode != 200 ||
        !response.body.trimLeft().startsWith('{')) {
      throw const SheinShareException(
        'تعذر الحصول على السلة من شي إن. أعد المحاولة لاحقاً.',
      );
    }

    final Map<String, dynamic> data;

    try {
      final dynamic decoded = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (decoded is! Map) {
        throw const FormatException();
      }

      data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw const SheinShareException(
        'استجابة شي إن غير متوقعة.',
      );
    }

    final Object? rawData = data['data'];
    final Map<String, dynamic> source =
        rawData is Map
            ? Map<String, dynamic>.from(rawData)
            : data;

    final Object? code = source['code'] ?? data['code'];

    if (code != null && code.toString() != '0') {
      throw SheinShareException(
        (source['info'] ?? data['info'] ??
                'السلة غير متاحة أو انتهت صلاحيتها.')
            .toString(),
      );
    }

    // قد تختلف بنية الاستجابة بين إصدارات SHEIN.
    final Object? rawInfo = source['info'] ?? data['info'];

    final Map<String, dynamic> info =
        rawInfo is Map
            ? Map<String, dynamic>.from(rawInfo)
            : source;

    final List<Object?> candidates = <Object?>[
      info['normalProducts'],
      info['products'],
      info['productList'],
      info['goodsList'],
    ];

    final List<Map<String, dynamic>> products =
        <Map<String, dynamic>>[];

    for (final Object? candidate in candidates) {
      if (candidate is! List) continue;

      for (final Object? rawProduct in candidate) {
        if (rawProduct is! Map) continue;

        try {
          final Map<String, dynamic>? payload =
              _mapPayload(
            Map<String, dynamic>.from(rawProduct),
          );

          if (payload != null) {
            products.add(payload);
          }
        } catch (_) {
          // تجاوز المنتج ذي البيانات غير الصالحة.
        }
      }

      if (products.isNotEmpty) break;
    }

    if (products.isEmpty) {
      throw const SheinShareException(
        'لم يتم العثور على منتجات قابلة للاستيراد. '
        'قد تكون السلة فارغة أو أن استجابة شي إن مختلفة.',
      );
    }

    return products;
  }

  static String? _extractGroupId(String text) {
    final Match? match = RegExp(
      r'[?&]group_id=(\d+)',
      caseSensitive: false,
    ).firstMatch(text);

    return match?.group(1);
  }

  static Map<String, dynamic>? _mapPayload(
    Map<String, dynamic> item,
  ) {
    String readText(List<String> keys) {
      for (final String key in keys) {
        final Object? value = item[key];

        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }

      return '';
    }

    final String goodsId = readText(
      <String>['goods_id', 'goodsId', 'product_id'],
    );

    if (goodsId.isEmpty ||
        !RegExp(r'^\d+$').hasMatch(goodsId)) {
      return null;
    }

    double readPrice(Object? value) {
      if (value is num) return value.toDouble();

      if (value is Map) {
        final Object? amount = value['amount'];
        if (amount is num) return amount.toDouble();

        return double.tryParse('$amount') ?? 0;
      }

      return double.tryParse('$value') ?? 0;
    }

    final double salePrice = readPrice(item['salePrice']);
    final double retailPrice = readPrice(item['retailPrice']);
    final double price =
        salePrice > 0 ? salePrice : retailPrice;

    if (price <= 0) return null;

    String title = readText(
      <String>['goods_name', 'goodsName', 'title', 'name'],
    );

    if (title.isEmpty) {
      title = 'منتج SHEIN #$goodsId';
    }

    if (title.length > _maxTitleLength) {
      title = '${title.substring(0, _maxTitleLength - 1)}…';
    }

    String imageUrl = readText(
      <String>['goods_img', 'goodsImg', 'image', 'imageUrl'],
    );

    if (imageUrl.startsWith('//')) {
      imageUrl = 'https:$imageUrl';
    }

    String productUrl = readText(
      <String>['goods_url', 'goodsUrl', 'productUrl', 'url'],
    );

    if (productUrl.startsWith('//')) {
      productUrl = 'https:$productUrl';
    }

    if (!productUrl.startsWith('https://') &&
        !productUrl.startsWith('http://')) {
      productUrl = 'https://ar.shein.com/-p-$goodsId.html';
    }

    final List<String> attributes =
        readText(<String>['goodsAttr']).split('/');

    return <String, dynamic>{
      'goodsId': goodsId,
      'productUrl': productUrl,
      'title': title,
      'imageUrl': imageUrl,
      'sourcePrice': price,
      'sourceCurrency': 'SAR',
      'quantity': 1,
      'color': attributes.isNotEmpty ? attributes[0].trim() : '',
      'size': attributes.length > 1 ? attributes[1].trim() : '',
      'options': <String, String>{},
      'sourceStore': 'SHEIN',
      'sku': readText(<String>['sku_code', 'itemSku', 'sku']),
      'variantId': '',
      'source': 'shared-cart',
    };
  }
}
