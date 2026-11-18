import 'dart:convert';

import '../../features/cart/domain/cart_item.dart';

/// رابط «السلة كاملة»: يحمل كل منتجات السلة داخل الرابط بصيغة
/// Base64URL لـ UTF-8، ويُستعاد بالكامل عند فتحه أو لصقه.
class CartShare {
  static const String host = 'https://yemenseloo.shop/cart';
  static const String _version = 'v1';

  /// يبني الرابط من منتجات السلة.
  static String buildFromItems(List<CartItem> items) => _build([
        for (final i in items)
          {
            'g': i.goodsId,
            'k': i.sku,
            't': i.title,
            'p': i.sourcePrice,
            'q': i.quantity,
            'c': i.color,
            's': i.size,
            'u': i.sourceUrl,
            'm': i.imageUrl,
          }
      ]);

  /// يبني الرابط من سطور السلة المطبَّعة (شاشة الملخص).
  static String buildFromLines(List<dynamic> lines) => _build([
        for (final l in lines)
          {
            'g': l.goodsId as String,
            'k': l.variantKey as String,
            't': l.titleAr as String,
            'p': l.unitPriceSar as double,
            'q': l.qty as int,
            'c': l.color as String,
            's': l.size as String,
            'u': '',
            'm': l.imageUrl as String,
          }
      ]);

  /// يبني الرابط من منتجات طلب منشأ (لأجل ملخص الطلب وإيصالاته).
  static String fromOrderItems(dynamic order) {
    final items = order.items as List<dynamic>;
    final rows = <Map<String, dynamic>>[];
    for (final it in items) {
      rows.add({
        'g': it.goodsId as String,
        'k': it.sku as String,
        't': it.title as String,
        'p': it.unitPriceSar as double,
        'q': it.qty as int,
        'c': it.color as String,
        's': it.size as String,
        'u': it.productUrl as String,
        'm': it.imageUrl as String,
      });
    }
    return _build(rows);
  }

  static String _build(List<Map<String, dynamic>> rows) {
    final Map<String, dynamic> payload = {'s': _version, 'i': rows};
    final String token = base64Url
        .encode(utf8.encode(jsonEncode(payload)))
        .replaceAll('=', '');
    return '$host#cart=$token';
  }

  /// هل النص رابط سلة كاملة (أو رمزه)؟
  static bool isCartLink(String input) => _token(input) != null;

  static String? _token(String raw) {
    final String s = raw.trim();
    if (s.isEmpty) return null;
    if (s.contains('cart=')) {
      final String part = s.split('cart=').last;
      final String token = part.split('&').first.split('#').first.trim();
      return token.isEmpty ? null : token;
    }
    // قد يكون الرمز وحده (بلا رابط)
    if (RegExp(r'^[A-Za-z0-9_-]{40,}$').hasMatch(s)) return s;
    return null;
  }

  /// يفك تشفير الرابط أو الرمز. يرجع null إن لم يكن صالحاً.
  static List<CartItem>? parse(String input, {double exchangeRate = 1}) {
    final String? token = _token(input);
    if (token == null) return null;
    try {
      final String normalized = token.replaceAll('-', '+').replaceAll('_', '/');
      final String padded = normalized.padRight(
          normalized.length + (4 - normalized.length % 4) % 4, '=');
      final dynamic decoded = jsonDecode(utf8.decode(base64Url.decode(padded)));
      if (decoded is! Map) return null;
      final rows = decoded['i'];
      if (rows is! List || rows.isEmpty) return null;

      final List<CartItem> items = [];
      for (var i = 0; i < rows.length; i++) {
        final Map<String, dynamic> r = Map<String, dynamic>.from(rows[i] as Map);
        items.add(CartItem(
          lineId: 'shared_${DateTime.now().millisecondsSinceEpoch}_$i',
          goodsId: (r['g'] ?? '') as String,
          title: (r['t'] ?? '') as String,
          imageUrl: (r['m'] ?? '') as String,
          sourceUrl: (r['u'] ?? '') as String,
          sourcePrice: (r['p'] as num?)?.toDouble() ?? 0,
          sourceCurrency: 'SAR',
          exchangeRate: exchangeRate,
          quantity: (r['q'] as num?)?.toInt() ?? 1,
          color: (r['c'] ?? '') as String,
          size: (r['s'] ?? '') as String,
          sku: (r['k'] ?? '') as String,
        ));
      }
      return items;
    } catch (_) {
      return null;
    }
  }

  /// الرمز وحده (بلا رابط) — يُلصق في نافذة الاستيراد.
  static String tokenFromUrl(String url) => _token(url) ?? '';

  /// نص رسالة واتساب: بند «رابط السلة كاملة» مع بديل الرمز.
  static String whatsappSection(String url) {
    final token = tokenFromUrl(url);
    final b = StringBuffer('\n🛒 رابط السلة كاملة:\n$url\n');
    if (token.isNotEmpty) {
      b.writeln(
          'إن لم يفتح الرابط: افتح التطبيق ← تبويب السلة ← «استيراد سلة شي ان» '
          'والصق الرمز التالي:\n$token');
    }
    return b.toString();
  }
}
