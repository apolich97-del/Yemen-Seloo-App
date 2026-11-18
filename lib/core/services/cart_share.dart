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
          [i.goodsId, _short(i.title), i.sourcePrice, i.quantity, i.color, i.size]
      ]);

  /// يبني الرابط من سطور السلة المطبَّعة (شاشة الملخص).
  static String buildFromLines(List<dynamic> lines) => _build([
        for (final l in lines)
          [
            l.goodsId as String,
            _short(l.titleAr as String),
            l.unitPriceSar as double,
            l.qty as int,
            l.color as String,
            l.size as String,
          ]
      ]);

  /// يبني الرابط من منتجات طلب منشأ (لأجل ملخص الطلب وإيصالاته).
  static String fromOrderItems(dynamic order) {
    final items = order.items as List<dynamic>;
    final rows = <List<dynamic>>[];
    for (final it in items) {
      rows.add(<dynamic>[
        it.goodsId as String,
        _short(it.title as String),
        it.unitPriceSar as double,
        it.qty as int,
        it.color as String,
        it.size as String,
      ]);
    }
    return _build(rows);
  }

  /// يقتصر الاسم على 28 حرفاً — يُجلَب الاسم الكامل من الكتالوج.
  static String _short(String t) =>
      t.length <= 28 ? t : '${t.substring(0, 28)}…';

  static String _build(List<List<dynamic>> rows) {
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
        final dynamic raw = rows[i];
        final Map<String, dynamic> r;
        if (raw is List) {
          r = <String, dynamic>{
            'g': raw.isNotEmpty ? raw[0] : '',
            't': raw.length > 1 ? raw[1] : '',
            'p': raw.length > 2 ? raw[2] : 0,
            'q': raw.length > 3 ? raw[3] : 1,
            'c': raw.length > 4 ? raw[4] : '',
            's': raw.length > 5 ? raw[5] : '',
          };
        } else {
          r = Map<String, dynamic>.from(raw as Map);
        }
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
