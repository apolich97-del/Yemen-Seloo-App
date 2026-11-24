import 'dart:convert';

import '../../features/cart/data/seloo_cart_link.dart';
import '../../features/cart/domain/cart_item.dart';
import '../../features/shein/domain/shein_draft.dart';

/// رابط «السلة كاملة»: موحّد على صيغة `https://seloo-cart.vercel.app/#d=z...`
/// مع دعم استيراد الروابط المختصرة (`tinyurl.com`, `is.gd`) والنسخة القديمة `#cart=`.
class CartShare {
  static const String host = SelooCartLink.webBase;

  static List<List<Object?>> _rowsFromItems(List<CartItem> items) => [
        for (final i in items)
          [
            i.goodsId,
            _short(i.title),
            i.imageUrl,
            i.sourcePrice,
            i.color,
            i.size,
            i.quantity,
          ]
      ];

  static List<List<Object?>> _rowsFromLines(List<dynamic> lines) => [
        for (final l in lines)
          [
            '${l.goodsId ?? ''}',
            _short('${l.titleAr ?? ''}'),
            '${l.imageUrl ?? ''}',
            (l.unitPriceSar as num?)?.toDouble() ?? 0.0,
            '${l.color ?? ''}',
            '${l.size ?? ''}',
            (l.qty as num?)?.toInt() ?? 1,
          ]
      ];

  static List<List<Object?>> _rowsFromOrder(dynamic order) {
    final items = order.items as List<dynamic>;
    return [
      for (final it in items)
        [
          '${it.goodsId ?? ''}',
          _short('${it.title ?? ''}'),
          '${it.imageUrl ?? ''}',
          (it.unitPriceSar as num?)?.toDouble() ?? 0.0,
          '${it.color ?? ''}',
          '${it.size ?? ''}',
          (it.qty as num?)?.toInt() ?? 1,
        ]
    ];
  }

  /// يبني الرابط الكامل الموحد من منتجات السلة.
  static String buildFromItems(List<CartItem> items) =>
      items.isEmpty ? '' : SelooCartLink.webLinkFromRows(_rowsFromItems(items));

  static String buildFromLines(List<dynamic> lines) =>
      lines.isEmpty ? '' : SelooCartLink.webLinkFromRows(_rowsFromLines(lines));

  static String fromOrderItems(dynamic order) {
    final rows = _rowsFromOrder(order);
    return rows.isEmpty ? '' : SelooCartLink.webLinkFromRows(rows);
  }

  /// يولّد رابطاً مختصراً (TinyURL / is.gd) مع Fallback تلقائي للرابط الكامل.
  static Future<String> shortFromItems(List<CartItem> items) async =>
      items.isEmpty ? '' : SelooCartLink.shortWebLinkFromRows(_rowsFromItems(items));

  static Future<String> shortFromLines(List<dynamic> lines) async =>
      lines.isEmpty ? '' : SelooCartLink.shortWebLinkFromRows(_rowsFromLines(lines));

  static Future<String> shortFromOrder(dynamic order) async {
    final rows = _rowsFromOrder(order);
    return rows.isEmpty ? '' : SelooCartLink.shortWebLinkFromRows(rows);
  }

  static String _short(String t) {
    final s = t.trim();
    return s.length <= 90 ? s : '${s.substring(0, 88)}..';
  }

  /// هل النص رابط سلة يمن سيلو (طويل أو مختصر أو قديم) أو رمز سلة؟
  static bool isCartLink(String input) {
    final s = input.trim();
    if (s.isEmpty) return false;
    final low = s.toLowerCase();
    if (low.contains('seloo-cart.vercel.app') ||
        low.contains('yemenseloo://') ||
        low.contains('tinyurl.com/') ||
        low.contains('is.gd/') ||
        s.contains('d=') ||
        s.contains('cart=')) {
      return true;
    }
    if (RegExp(r'^z[A-Za-z0-9_-]{12,}$').hasMatch(s)) return true;
    if (RegExp(r'^[A-Za-z0-9_-]{40,}$').hasMatch(s)) return true;
    return false;
  }

  static String? _legacyToken(String raw) {
    final String s = raw.trim();
    if (s.isEmpty) return null;
    if (s.contains('cart=')) {
      final String part = s.split('cart=').last;
      final String token = part.split('&').first.split('#').first.trim();
      return token.isEmpty ? null : token;
    }
    if (!s.startsWith('z') && RegExp(r'^[A-Za-z0-9_-]{40,}$').hasMatch(s)) {
      return s;
    }
    return null;
  }

  /// يفك الرابط/الرمز محلياً (دون شبكة).
  static List<CartItem>? parse(String input, {double exchangeRate = 1}) {
    final drafts = SelooCartLink.draftsFromLink(input);
    if (drafts.isNotEmpty) {
      return drafts
          .asMap()
          .entries
          .map((e) => CartItem(
                lineId: 'shared_${DateTime.now().millisecondsSinceEpoch}_${e.key}',
                goodsId: e.value.goodsId,
                title: e.value.title,
                imageUrl: e.value.imageUrl,
                sourceUrl: e.value.productUrl,
                sourcePrice: e.value.sourcePrice,
                sourceCurrency: 'SAR',
                exchangeRate: exchangeRate,
                quantity: e.value.quantity,
                color: e.value.color,
                size: e.value.size,
              ))
          .toList();
    }

    final String? token = _legacyToken(input);
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

  /// يحل الروابط المختصرة (مثل tinyurl.com) ثم يعيد عناصر السلة كاملة.
  static Future<List<CartItem>?> parseAsync(String input,
      {double exchangeRate = 1}) async {
    final resolved = await SelooCartLink.resolveUrl(input);
    return parse(resolved, exchangeRate: exchangeRate);
  }

  static Future<List<SheinDraft>> draftsAsync(String input) async {
    final resolved = await SelooCartLink.resolveUrl(input);
    final drafts = SelooCartLink.draftsFromLink(resolved);
    if (drafts.isNotEmpty) return drafts;
    final legacy = parse(resolved);
    if (legacy == null || legacy.isEmpty) return const <SheinDraft>[];
    return legacy
        .map((i) => SheinDraft(
              goodsId: i.goodsId,
              productUrl: i.sourceUrl.isNotEmpty
                  ? i.sourceUrl
                  : 'https://ar.shein.com/-p-${i.goodsId}.html',
              title: i.title,
              imageUrl: i.imageUrl,
              sourcePrice: i.sourcePrice > 0 ? i.sourcePrice : 0.01,
              sourceCurrency: 'SAR',
              quantity: i.quantity,
              color: i.color,
              size: i.size,
              options: const <String, String>{},
              sourceStore: 'SHEIN',
              sku: i.sku,
              variantId: '',
              source: 'shared-cart-link',
              clientTs: DateTime.now().toUtc(),
            ))
        .toList();
  }

  static String tokenFromUrl(String url) {
    final m = RegExp(r'd=([^&#\s]+)').firstMatch(url);
    if (m != null) return m.group(1)!;
    return _legacyToken(url) ?? '';
  }

  static String whatsappSection(String url) {
    final token = tokenFromUrl(url);
    final b = StringBuffer('\n🛒 رابط السلة كاملة:\n$url\n');
    if (token.isNotEmpty && token.length <= 180) {
      b.writeln(
          'إن لم يفتح الرابط: افتح التطبيق ← تبويب السلة ← «استيراد رابط السلة / شي إن» '
          'والصق الرابط أو الرمز.');
    }
    return b.toString();
  }
}
