
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'shein_link_resolver.dart';

/// استثناء برسالة واضحة تُعرض للمستخدم مباشرة.
class SheinShareException implements Exception {
  const SheinShareException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// يستدعي endpoint سلة شي إن المشتركة من جهاز العميل.
/// يزور صفحة الهبوط أولاً لمحاولة الحصول على كوكيز الجلسة،
/// ثم ينفذ طلب POST مع ترويسات المتصفح وثلاث محاولات تلقائية.
class SheinShareApi {
  static const String _api =
      'https://m.shein.com/ar/bff-api/order/cart/share/landing'
      '?_ver=1.1.8&_lang=ar';

  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/131.0.0.0 Safari/537.36';

  static const Duration _timeout = Duration(seconds: 25);
  static const int _attempts = 3;
  static const Duration _retryDelay = Duration(seconds: 3);
  static const int _maxTitleLength = 300;

  Future<List<Map<String, dynamic>>> fetchSharedCart(
    String input,
  ) async {
    final String text = input.trim();

    if (text.isEmpty) {
      throw const SheinShareException(
        'الصق رابط السلة المشتركة أولاً.',
      );
    }

    // نحوّل أولاً بمنطق يفهم الترميز المزدوج (%22group_id%22...)
    String? groupId =
        SheinLinkResolver.groupIdIn(text) ?? _extractGroupId(text);

    // صيغة "نسخ الرابط" من شي إن تكون رابط onelink قصيراً بلا معرّف،
    // فنفتحه ونقرأ معرّف السلة من داخله.
    if (groupId == null) {
      final String? resolved = await SheinLinkResolver.resolve(text);
      if (resolved != null) {
        groupId = _extractGroupId(resolved);
      }
    }

    if (groupId == null) {
      throw const SheinShareException(
        'لم أجد معرّف السلة في النص — تأكد من نسخ رابط المشاركة كاملاً',
      );
    }

    // بناء رابط صفحة الهبوط من معرّف السلة.
    final String landingUrl =
        'https://m.shein.com/ar/cart/share/landing'
        '?group_id=${Uri.encodeQueryComponent(groupId)}';

    Object lastError =
        const SheinShareException('فشل غير متوقع');

    for (int attempt = 1; attempt <= _attempts; attempt++) {
      try {
        return await _tryFetch(landingUrl, groupId);
      } catch (e) {
        lastError = e is SheinShareException
            ? e
            : const SheinShareException(
                'تعذر الاتصال بشي إن — تحقق من الإنترنت وأعد المحاولة',
              );

        if (attempt < _attempts) {
          await Future<void>.delayed(_retryDelay);
        }
      }
    }

    throw lastError;
  }

  /// زيارة صفحة الهبوط ثم طلب بيانات السلة المشتركة.
  Future<List<Map<String, dynamic>>> _tryFetch(
    String landingUrl,
    String groupId,
  ) async {
    // الخطوة الأولى: محاولة الحصول على كوكيز الجلسة.
    String cookieHeader = '';

    try {
      final http.Response landing = await http
          .get(
            Uri.parse(landingUrl),
            headers: const <String, String>{
              'User-Agent': _ua,
              'Accept':
                  'text/html,application/xhtml+xml,'
                  'application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'ar,ar-SA;q=0.9,en;q=0.5',
            },
          )
          .timeout(_timeout);

      final String? setCookie = landing.headers['set-cookie'];

      if (setCookie != null && setCookie.isNotEmpty) {
        final List<String> pairs = <String>[];

        for (final String raw in setCookie.split(', ')) {
          final String pair = raw.split(';').first.trim();

          if (pair.contains('=')) {
            pairs.add(pair);
          }
        }

        cookieHeader = pairs.join('; ');
      }
    } catch (_) {
      // نواصل المحاولة حتى لو تعذر الحصول على الكوكيز.
    }

    // الخطوة الثانية: طلب بيانات السلة.
    final String origin = Uri.parse(landingUrl).origin;
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
              'Accept': 'application/json, text/plain, */*',
              'Accept-Language': 'ar,ar-SA;q=0.9,en;q=0.5',
              'Origin': origin,
              'Referer': landingUrl,
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
        'تعذر الاتصال بشي إن — تحقق من الإنترنت وأعد المحاولة',
      );
    }

    if (response.statusCode != 200) {
      throw SheinShareException(
        'شي إن رفضت الطلب (رمز ${response.statusCode}) — '
        'أعد المحاولة بعد قليل',
      );
    }

    // قراءة استجابة JSON والتحقق من بنيتها.
    final Map<String, dynamic> data;

    try {
      final Object? decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw const FormatException('Invalid response');
      }

      data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw const SheinShareException(
        'تعذر الحصول على السلة من شي إن — أعد المحاولة بعد قليل',
      );
    }

    if ('${data['code']}' != '0' || data['info'] is! Map) {
      throw const SheinShareException(
        'السلة غير متاحة أو منتهية الصلاحية',
      );
    }

    final Map<String, dynamic> info =
        Map<String, dynamic>.from(data['info'] as Map);

    final List<Map<String, dynamic>> products =
        <Map<String, dynamic>>[];

    final Object? normalProducts = info['normalProducts'];

    if (normalProducts is List) {
      for (final Object? raw in normalProducts) {
        if (raw == null) continue;

        final Map<String, dynamic>? payload = _mapPayload(raw);

        if (payload != null) {
          products.add(payload);
        }
      }
    }

    if (products.isEmpty) {
      final int outOfStock = _listLength(info['outStock']) +
          _listLength(info['unavailable']);

      throw SheinShareException(
        outOfStock > 0
            ? 'كل منتجات السلة غير متوفرة حالياً'
            : 'لم يتم العثور على منتجات في السلة المشتركة.',
      );
    }

    return products;
  }

  static int _listLength(Object? value) {
    return value is List ? value.length : 0;
  }

  /// استخراج group_id من الرابط أو النص أو بعض صيغ الترميز.
  static String? _extractGroupId(String text) {
    final RegExp pattern = RegExp(
      r'group_id[^0-9]{0,3}(\d{5,})',
      caseSensitive: false,
    );

    RegExpMatch? match = pattern.firstMatch(text);

    if (match != null) {
      return match.group(1);
    }

    // فك الترميز مرة أولى.
    String decoded = text;

    try {
      decoded = Uri.decodeFull(text);
    } catch (_) {
      // نتابع باستخدام النص الأصلي.
    }

    match = pattern.firstMatch(decoded);

    if (match != null) {
      return match.group(1);
    }

    // بعض روابط المشاركة تحتوي على ترميز متداخل.
    try {
      final String decodedAgain =
          Uri.decodeComponent(decoded);

      match = pattern.firstMatch(decodedAgain);

      if (match != null) {
        return match.group(1);
      }
    } catch (_) {
      // نتابع التحقق من المعرّف المباشر.
    }

    final String trimmed = text.trim();

    if (RegExp(r'^\d{5,}$').hasMatch(trimmed)) {
      return trimmed;
    }

    return null;
  }

  /// تحويل منتج شي إن إلى البنية التي يتوقعها التطبيق.
  static Map<String, dynamic>? _mapPayload(Object raw) {
    if (raw is! Map) return null;

    final Map<String, dynamic> it =
        Map<String, dynamic>.from(raw);

    final String goodsId =
        '${it['goods_id'] ?? it['goodsId'] ?? ''}'.trim();

    if (goodsId.isEmpty ||
        !RegExp(r'^\d+$').hasMatch(goodsId)) {
      return null;
    }

    final double? salePrice =
        _priceAmount(it['salePrice']);

    final double? retailPrice =
        _priceAmount(it['retailPrice']);

    final double price =
        (salePrice != null && salePrice > 0)
            ? salePrice
            : (retailPrice != null && retailPrice > 0)
                ? retailPrice
                : 0.01;

    if (price <= 0) return null;

    String title =
        '${it['goods_name'] ?? it['goodsName'] ?? ''}'.trim();

    if (title.isEmpty) {
      title = 'منتج SHEIN #$goodsId';
    }

    if (title.length > _maxTitleLength) {
      title = '${title.substring(0, _maxTitleLength - 1)}…';
    }

    final String imageUrl = _cleanImage(it);

    final String attributes =
        '${it['goodsAttr'] ?? ''}';

    final List<String> parts = attributes.split('/');

    final String color =
        parts.isNotEmpty ? parts[0].trim() : '';

    final String size =
        parts.length > 1 ? parts[1].trim() : '';

    // رابط منتج فعلي، وليس نص Markdown.
    final String productUrl =
        'https://ar.shein.com/-p-$goodsId.html';

    return <String, dynamic>{
      'goodsId': goodsId,
      'productUrl': productUrl,
      'title': title,
      'imageUrl': imageUrl,
      'sourcePrice': price,
      'sourceCurrency': 'SAR',
      'quantity': 1,
      'color': color,
      'size': size,
      'options': const <String, String>{},
      'sourceStore': 'SHEIN',
      'sku': '${it['sku_code'] ?? it['itemSku'] ?? ''}'.trim(),
      'variantId': '',
      'source': 'shared-cart',
    };
  }

  /// قراءة السعر سواء جاء رقماً أو داخل كائن amount.
  static double? _priceAmount(Object? value) {
    Object? amount = value;

    if (value is Map) {
      amount = value['amount'];
    }

    if (amount == null) return null;

    return double.tryParse('$amount');
  }

  /// البحث عن الصورة في عدة حقول محتملة وتوحيد الرابط.
  static String _cleanImage(Map<String, dynamic> it) {
    final List<String> candidates = <String>[
      '${it['goods_img'] ?? ''}',
      '${it['goodsImg'] ?? ''}',
      '${it['main_image'] ?? ''}',
      '${it['detail_image'] ?? ''}',
    ];

    final Object? images = it['goods_imgs'];

    if (images is List && images.isNotEmpty) {
      final Object? first = images.first;

      if (first is String) {
        candidates.add(first);
      } else if (first is Map) {
        candidates.add(
          '${first['goods_img'] ?? first['goodsImg'] ?? first['url'] ?? ''}',
        );
      }
    }

    for (final String candidate in candidates) {
      String url = candidate.trim();

      if (url.isEmpty || url.startsWith('data:')) {
        continue;
      }

      if (url.startsWith('//')) {
        url = 'https:$url';
      }

      if (url.startsWith('http://')) {
        url = url.replaceFirst('http://', 'https://');
      }

      if (url.startsWith('https://')) {
        return url;
      }

      if (url.startsWith('img.ltwebstatic.com/')) {
        return 'https://$url';
      }

      // المسارات النسبية فقط؛ لا نضيف نطاق الصور إلى رابط كامل.
      url = url.replaceFirst(RegExp(r'^/+'), '');

      if (url.isNotEmpty) {
        return 'https://img.ltwebstatic.com/$url';
      }
    }

    return '';
  }
}
