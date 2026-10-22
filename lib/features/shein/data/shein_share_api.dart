import 'dart:convert';

import 'package:http/http.dart' as http;

/// استثناء بحالة نصية واضحة تُعرض للمستخدم مباشرة.
class SheinShareException implements Exception {
  const SheinShareException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// يستدعي endpoint سلة شي إن المشتركة من جهاز العميل.
class SheinShareApi {
  static const String _api =
      'https://m.shein.com/ar/bff-api/order/cart/share/landing?_ver=1.1.8&_lang=ar';

  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/131.0.0.0 Safari/537.36';

  static const Duration _timeout = Duration(seconds: 25);
  static const int _maxTitleLength = 300;

  /// يقبل نص المشاركة الكامل أو الرابط أو رقم group_id.
  /// يعيد بيانات المنتجات المتوافقة مع SheinDraft.fromBridgePayload.
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

    // استخراج الرابط الموجود داخل النص.
    final String? shareUrl =
        RegExp(r'https?://[^\s"<>]+').firstMatch(text)?.group(0);

    // دعم إدخال رقم group_id وحده.
    if (groupId == null &&
        RegExp(r'^\d{5,}$').hasMatch(text)) {
      groupId = text;
    }

    if (groupId == null) {
      throw const SheinShareException(
        'لم أجد معرّف السلة في النص. '
        'تأكد من نسخ رابط المشاركة كاملاً.',
      );
    }

    final String landingUrl =
        shareUrl != null && _extractGroupId(shareUrl) != null
            ? shareUrl
            : 'https://m.shein.com/ar/cart/share/landing'
                '?group_id=$groupId&local_country=SA';

    // الخطوة الأولى: زيارة صفحة الهبوط لمحاولة الحصول على الكوكيز.
    String cookieHeader = '';

    try {
      final http.Response landing = await http
          .get(
            Uri.parse(landingUrl),
            headers: <String, String>{
              'User-Agent': _ua,
            },
          )
          .timeout(_timeout);

      final List<String> rawCookies =
          landing.headers['set-cookie'] == null
              ? <String>[]
              : <String>[landing.headers['set-cookie']!];

      final List<String> pairs = <String>[];

      for (final String raw in rawCookies) {
        final String pair = raw.split(';').first.trim();

        if (pair.contains('=')) {
          pairs.add(pair);
        }
      }

      cookieHeader = pairs.join('; ');
    } catch (_) {
      // قد تنجح الخطوة التالية حتى لو تعذر جلب الكوكيز.
    }

    // الخطوة الثانية: طلب بيانات السلة.
    final http.Response response;

    try {
      response = await http
          .post(
            Uri.parse(_api),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'AppCurrency': 'SAR',
              'AppLanguage': 'ar',
              'User-Agent': _ua,
              'Accept': 'application/json',
              if (cookieHeader.isNotEmpty)
                'Cookie': cookieHeader,
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
        'تعذر الاتصال بشي إن. '
        'تحقق من الإنترنت وأعد المحاولة.',
      );
    }

    if (response.statusCode != 200) {
      throw const SheinShareException(
        'شي إن رفضت الطلب مؤقتاً. '
        'انتظر قليلاً ثم أعد المحاولة.',
      );
    }

    final Map<String, dynamic> data;

    try {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw const FormatException('Invalid response');
      }

      data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw const SheinShareException(
        'تعذر الحصول على السلة من شي إن. '
        'قد تكون صفحة حماية أو تحقق.',
      );
    }

    if (data['code'].toString() != '0' ||
        data['info'] is! Map) {
      throw const SheinShareException(
        'السلة غير متاحة أو منتهية الصلاحية.',
      );
    }

    final Map<String, dynamic> info =
        Map<String, dynamic>.from(data['info'] as Map);

    final List<Map<String, dynamic>> products =
        <Map<String, dynamic>>[];

    final dynamic normalProducts = info['normalProducts'];

    if (normalProducts is List) {
      for (final dynamic raw in normalProducts) {
        try {
          final Map<String, dynamic>? payload =
              _mapPayload(raw);

          if (payload != null) {
            products.add(payload);
          }
        } catch (_) {
          // تجاهل المنتج الذي لا تتوافق بياناته مع البنية المطلوبة.
        }
      }
    }

    if (products.isEmpty) {
      final int outOfStock =
          _listLength(info['outStock']) +
          _listLength(info['unavailable']);

      throw SheinShareException(
        outOfStock > 0
            ? 'كل منتجات السلة غير متوفرة حالياً.'
            : 'لم يتم العثور على منتجات في السلة المشتركة.',
      );
    }

    return products;
  }

  static int _listLength(dynamic value) {
    return value is List ? value.length : 0;
  }

  static String? _extractGroupId(String text) {
    final RegExpMatch? match = RegExp(
      r'group_id[^0-9]{0,3}(\d{5,})',
      caseSensitive: false,
    ).firstMatch(text);

    if (match != null) {
      return match.group(1);
    }

    // دعم رقم groupId بصيغة camelCase.
    final RegExpMatch? camelMatch = RegExp(
      r'groupId[^0-9]{0,3}(\d{5,})',
      caseSensitive: false,
    ).firstMatch(text);

    return camelMatch?.group(1);
  }

  /// تحويل بيانات المنتج إلى صيغة SheinDraft.fromBridgePayload.
  static Map<String, dynamic>? _mapPayload(dynamic raw) {
    if (raw is! Map) {
      return null;
    }

    final Map<String, dynamic> item =
        Map<String, dynamic>.from(raw);

    final String goodsId =
        (item['goods_id'] ?? '').toString().trim();

    if (goodsId.isEmpty ||
        !RegExp(r'^\d+$').hasMatch(goodsId)) {
      return null;
    }

    final dynamic salePrice = item['salePrice'];
    final dynamic retailPrice = item['retailPrice'];

    final dynamic saleAmount =
        salePrice is Map ? salePrice['amount'] : null;

    final dynamic retailAmount =
        retailPrice is Map ? retailPrice['amount'] : null;

    final double? parsedSale =
        double.tryParse('$saleAmount');

    final double? parsedRetail =
        double.tryParse('$retailAmount');

    final double price =
        parsedSale != null && parsedSale > 0
            ? parsedSale
            : parsedRetail ?? 0;

    if (price <= 0) {
      return null;
    }

    String title =
        (item['goods_name'] ?? '').toString().trim();

    if (title.isEmpty) {
      title = 'منتج SHEIN #$goodsId';
    }

    if (title.length > _maxTitleLength) {
      title = '${title.substring(0, _maxTitleLength - 1)}…';
    }

    String imageUrl =
        (item['goods_img'] ?? '').toString().trim();

    if (imageUrl.startsWith('//')) {
      imageUrl = 'https:$imageUrl';
    }

    final List<String> attributes =
        (item['goodsAttr'] ?? '').toString().split('/');

    final String color =
        attributes.isNotEmpty ? attributes[0].trim() : '';

    final String size =
        attributes.length > 1 ? attributes[1].trim() : '';

    return <String, dynamic>{
      'goodsId': goodsId,
      'productUrl': 'https://ar.shein.com/-p-$goodsId.html',
      'title': title,
      'imageUrl': imageUrl,
      'sourcePrice': price,
      'sourceCurrency': 'SAR',
      'quantity': 1,
      'color': color,
      'size': size,
      'options': const <String, String>{},
      'sourceStore': 'SHEIN',
      'sku': (item['sku_code'] ?? item['itemSku'] ?? '')
          .toString()
          .trim(),
      'variantId': '',
      'source': 'shared-cart',
    };
  }
}
