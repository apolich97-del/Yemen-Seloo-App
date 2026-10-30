import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// يجلب صورة المنتج الحقيقية من صفحة شي إن عبر `og:image`.
///
/// السبب: صور الصفحة داخل WebView قد تكون صوراً نائبة (lazy placeholder)،
/// فرابطها يُخزَّن صحيحاً لكنه لا يمثّل المنتج.
class SheinImageResolver {
  SheinImageResolver._();

  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  // ترتيب الصفات قد يختلف، لذا نجرّب الحالتين
  static final RegExp _ogPropertyFirst = RegExp(
    r'''property=["']og:image["'][^>]*content=["']([^"']+)''',
    caseSensitive: false,
  );

  static final RegExp _ogContentFirst = RegExp(
    r'''content=["']([^"']+)["'][^>]*property=["']og:image["']''',
    caseSensitive: false,
  );

  /// صور منتجات شي إن الحقيقية تحت مسار /imagesN_pi/ — غير ذلك شعار أو صورة نائبة
  static final RegExp _productImg = RegExp(r'/images\d+_pi/', caseSensitive: false);

  static final RegExp _goodsImg = RegExp(
    r'"(?:goods_img|goods_image|main_image)"\s*:\s*"([^"]+)"',
  );

  /// يُرجع رابط صورة مطلقاً أو null.
  static Future<String?> byGoodsId(
    String goodsId, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final String id = goodsId.trim();
    if (id.isEmpty || !RegExp(r'^\d+$').hasMatch(id)) return null;

    final List<String> urls = <String>[
      'https://m.shein.com/ar/pdsearch/$id/',
      'https://m.shein.com/ar/-p-$id.html',
      'https://ar.shein.com/-p-$id.html',
    ];

    for (final String url in urls) {
      final String? html = await _fetch(url, timeout);
      if (html == null || html.isEmpty) continue;

      final String? raw = _extract(html);
      if (raw != null) {
        final String? absolute = _absolute(raw);
        if (absolute != null) return absolute;
      }
    }

    return null;
  }

  static String? _extract(String html) {
    final RegExpMatch? a = _ogPropertyFirst.firstMatch(html);
    if (a != null) return a.group(1);

    final RegExpMatch? b = _ogContentFirst.firstMatch(html);
    if (b != null) return b.group(1);

    final RegExpMatch? c = _goodsImg.firstMatch(html);
    return c?.group(1);
  }

  static String? _absolute(String raw) {
    String u = raw.trim().replaceAll('&amp;', '&').replaceAll(' ', '');
    if (u.isEmpty) return null;

    if (u.startsWith('//')) u = 'https:$u';

    if (!u.startsWith('http')) {
      final int host = u.indexOf('ltwebstatic.com');
      if (host >= 0) {
        u = 'https://img.ltwebstatic.com'
            '${u.substring(host + 'ltwebstatic.com'.length)}';
      } else if (u.startsWith('/')) {
        u = 'https://m.shein.com$u';
      } else {
        return null;
      }
    }

    final RegExp bad = RegExp(
      r'placeholder|loading|transparent|noimage|no_image|blank|/icon/',
      caseSensitive: false,
    );
    if (bad.hasMatch(u)) return null;
    if (!_productImg.hasMatch(u)) return null;

    return u;
  }

  static Future<String?> _fetch(String url, Duration timeout) async {
    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = timeout
        ..userAgent = _userAgent
        ..followRedirects = true;

      final HttpClientRequest req = await client.getUrl(Uri.parse(url));
      req.headers.set(HttpHeaders.acceptLanguageHeader, 'ar,ar-SA;q=0.9,en;q=0.6');
      req.headers.set(HttpHeaders.refererHeader, 'https://m.shein.com/ar/');
      req.headers.set(HttpHeaders.acceptHeader,
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');

      final HttpClientResponse res = await req.close().timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 400) return null;

      final String body =
          await res.transform(utf8.decoder).join().timeout(timeout);
      return body;
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }
}
