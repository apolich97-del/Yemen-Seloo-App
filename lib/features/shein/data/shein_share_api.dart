import 'dart:convert';

import 'package:http/http.dart' as http;

/// استثناء بحالة نصية واضحة تُعرض للمستخدم مباشرة.
class SheinShareException implements Exception {
  const SheinShareException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// يستدعي endpoint سلة شي إن المشتركة مباشرة من جهاز العميل.
///
/// ⭐ الاكتشاف الحاسم (مُجرّب فعلياً): شي إن ترفض POST مباشراً بردّ
/// 302 إلى صفحة الحماية risk/limit. الحل: زيارة صفحة الهبوط
/// (landing) أولاً لأخذ كوكيز الجلسة، ثم POST بالكوكيز نفسها.
/// هذه هي "قراءة الرابط كما يقرؤه كروم" بالضبط.
class SheinShareApi {
  static const _api =
      'https://m.shein.com/ar/bff-api/order/cart/share/landing?_ver=1.1.8&_lang=ar';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
  static const _timeout = Duration(seconds: 25);

  /// SheinDraft.fromBridgePayload يرفض العناوين الأطول من 300 حرف.
  static const _maxTitleLength = 300;

  /// يقبل: نص المشاركة الكامل، أو الرابط وحده، أو رقم groupId فقط.
  /// يرجع قائمة payloads جاهزة لـ SheinDraft.fromBridgePayload.
  /// يرمي SheinShareException عند أي فشل.
  Future<List<Map<String, dynamic>>> fetchSharedCart(String input) async {
    final String text = (input ?? '').trim();
    if (text.isEmpty) {
      throw const SheinShareException('الصق رابط السلة المشتركة أولاً.');
    }

    String? groupId = _extractGroupId(text);

    // الرابط داخل النص (إن وُجد) نستخدمه لصفحة الهبوط، وإلا نبنيه من groupId
    final String? shareUrl =
        RegExp(r'https?://[^\s"<>]+').firstMatch(text)?.group(0);

    final String landingUrl = (shareUrl != null && groupId != null)
        ? shareUrl
        : 'https://m.shein.com/ar/cart/share/landing?group_id=$groupId';

    // رقم مجرد فقط
    if (groupId == null && RegExp(r'^\d{5,}$').hasMatch(text)) {
      groupId = text;
    }

    if (groupId == null) {
      throw const SheinShareException(
          'لم أجد معرّف السلة في النص — تأكد من نسخ رابط المشاركة كاملاً');
    }

    // ═══════════════════════════════════════════════════════════════
    // ⭐ الخطوة 1: زيارة صفحة الهبوط لأخذ كوكيز الجلسة (مثل كروم تماماً)
    // ═══════════════════════════════════════════════════════════════
    String cookieHeader = '';
    try {
      final http.Response landing = await http
          .get(Uri.parse(landingUrl), headers: {'User-Agent': _ua})
          .timeout(_timeout);

      // نجمع كوكيز Set-Cookie يدوياً (حزمة http لا تحفظ الكوكيز تلقائياً)
      final List<String> rawCookies =
          landing.headers['set-cookie']?.split(', ') ?? <String>[];
      final List<String> pairs = <String>[];
      for (final String raw in rawCookies) {
        final String pair = raw.split(';').first.trim();
        if (pair.contains('=')) pairs.add(pair);
      }
      cookieHeader = pairs.join('; ');
    } catch (_) {
      // حتى لو فشل فتح الصفحة نكمل: أحياناً الـ POST ينجح بدون كوكيز
    }

    // ═══════════════════════════════════════════════════════════════
    // ⭐ الخطوة 2: POST مع كوكيز الجلسة
    // ═══════════════════════════════════════════════════════════════
    final http.Response res;
    try {
      final http.Response r = await http
          .post(
            Uri.parse(_api),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'AppCurrency': 'SAR',
              'AppLanguage': 'ar',
              'User-Agent': _ua,
              'Accept': 'application/json',
              if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
            },
            body: jsonEncode(<String, dynamic>{
              'groupId': groupId,
              'localCountry': 'SA',
              'userLocalSizeCountry': '',
            }),
          )
          .timeout(_timeout);
      res = r;
    } catch (_) {
      throw const SheinShareException(
          'تعذر الاتصال بشي إن — تحقق من الإنترنت وأعد المحاولة');
    }

    if (res.statusCode != 200) {
      throw const SheinShareException(
          'شي إن رفضت الطلب مؤقتاً — انتظر دقيقة وأعد المحاولة');
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      // الرد صفحة HTML = حماية/تحقق، ليس JSON
      throw const SheinShareException(
          'تعذر الحصول على السلة من شي إن — انتظر قليلاً وأعد المحاولة');
    }

    if (data['code'] != '0' || data['info'] == null) {
      throw const SheinShareException('السلة غير متاحة أو منتهية الصلاحية');
    }

    final Map<String, dynamic> info =
        Map<String, dynamic>.from(data['info'] as Map);

    // المتوفرة فقط تُضاف للسلة (outStock/unavailable تُستثنى)
    final List<Map<String, dynamic>> products = <Map<String, dynamic>>[];
    for (final Object raw in (info['normalProducts'] as List? ?? [])) {
      final Map<String, dynamic>? payload = _mapPayload(raw);
      if (payload != null) products.add(payload);
    }

    if (products.isEmpty) {
      final int outOfStock = (info['outStock'] as List? ?? []).length +
          (info['unavailable'] as List? ?? []).length;
      throw SheinShareException(outOfStock > 0
          ? 'كل منتجات السلة غير متوفرة حالياً'
          : 'لم يتم العثور على منتجات في السلة المشتركة.');
    }

    return products;
  }

  static String? _extractGroupId(String text) {
    return RegExp(r'group_id[^0-9]{0,3}(\d{5,})', caseSensitive: false)
        .firstMatch(text)
        ?.group(1);
  }

  /// يحوّل عقدة منتج من رد شي إن إلى payload تطابق
  /// SheinDraft.fromBridgePayload بالضبط. يرجع null عند البيانات الناقصة.
  static Map<String, dynamic>? _mapPayload(Object raw) {
    final Map<String, dynamic> it = Map<String, dynamic>.from(raw as Map);
    final String goodsId = (it['goods_id'] ?? '').toString().trim();
    if (goodsId.isEmpty || !RegExp(r'^\d+$').hasMatch(goodsId)) return null;

    final Object? sale = ((it['salePrice'] ?? const {}) as Map)['amount'];
    final Object? retail = ((it['retailPrice'] ?? const {}) as Map)['amount'];
    final double price =
        double.tryParse('$sale') ?? double.tryParse('$retail') ?? 0.01;
    if (price <= 0) return null;

    // قص العنوان: فاليداشن SheinDraft يرفض الأطول من 300 حرف
    String title = (it['goods_name'] ?? '').toString().trim();
    if (title.isEmpty) title = 'منتج SHEIN #$goodsId';
    if (title.length > _maxTitleLength) {
      title = '${title.substring(0, _maxTitleLength - 1)}…';
    }

    String img = (it['goods_img'] ?? '').toString().trim();
    if (img.startsWith('//')) img = 'https:$img';

    final List<String> parts = (it['goodsAttr'] ?? '').toString().split('/');
    final String color = parts.isNotEmpty ? parts[0].trim() : '';
    final String size = parts.length > 1 ? parts[1].trim() : '';

    return <String, dynamic>{
      'goodsId': goodsId,
      'productUrl': 'https://ar.shein.com/-p-$goodsId.html',
      'title': title,
      'imageUrl': img,
      'sourcePrice': price,
      'sourceCurrency': 'SAR',
      'quantity': 1,
      'color': color,
      'size': size,
      'options': const <String, String>{},
      'sourceStore': 'SHEIN',
      'sku': (it['sku_code'] ?? it['itemSku'] ?? '').toString().trim(),
      'variantId': '',
      'source': 'shared-cart',
    };
  }
}
