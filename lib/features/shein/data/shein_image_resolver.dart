import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// يجلب صورة المنتج الحقيقية من صفحة شي إن عبر `og:image`.
/// يقوم بتحويل روابط الصور المصغرة إلى روابط الصور الأصلية عالية الدقة.
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

  /// صور منتجات شي إن الحقيقية تحت مسار /imagesN_pi/
  static final RegExp _productImg = RegExp(r'/images\d+_pi/', caseSensitive: false);

  static final RegExp _goodsImg = RegExp(
    r'"(?:goods_img|goods_image|main_image)"\s*:\s*"([^"]+)"',
  );

  /// يُرجع رابط صورة مطلقاً أو null.
  static Future<String?> byGoodsId(
    String goodsId, {
    Duration timeout = const Duration(seconds: 6),
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

      // حماية: لا نقبل صورة من صفحة لا تخص هذا المنتج (صفحة تحقق أو صفحة قديمة)
      if (!html.contains(id)) continue;

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
    if (a != null && !_isBad(a.group(1)!)) return a.group(1);

    final RegExpMatch? b = _ogContentFirst.firstMatch(html);
    if (b != null && !_isBad(b.group(1)!)) return b.group(1);

    final RegExpMatch? c = _goodsImg.firstMatch(html);
    if (c != null && !_isBad(c.group(1)!)) return c.group(1);
    
    return null;
  }

  /// فلتر لرفض شعار SHEIN والصور التالفة
  static bool _isBad(String url) {
    return RegExp(
      r'logo|shein_logo|\/s\.(png|jpg)|placeholder|loading|transparent|noimage|no_image|blank|/icon/',
      caseSensitive: false,
    ).hasMatch(url);
  }

  static String? _absolute(String raw) {
    String u = raw.trim().replaceAll('&amp;', '&').replaceAll(' ', '');
    if (u.isEmpty) return null;

    if (u.startsWith('//')) u = 'https:$u';

    if (!u.startsWith('http')) {
      final int host = u.indexOf('ltwebstatic.com');
      if (host >= 0) {
        u = 'https://img.ltwebstatic.com${u.substring(host + 'ltwebstatic.com'.length)}';
      } else if (u.startsWith('/')) {
        u = 'https://m.shein.com$u';
      } else {
        return null;
      }
    }

    if (_isBad(u)) return null;
    if (!_productImg.hasMatch(u)) return null;

    // ⭐ إزالة لاحقة التصغير لجلب الصورة الأصلية الكاملة
    u = u.replaceAll(RegExp(r'_thumbnail_\d+x\d+\.(jpg|jpeg|png|webp)', caseSensitive: false), '.$1');
    u = u.replaceAll(RegExp(r'_thumbnail\.(jpg|jpeg|png|webp)', caseSensitive: false), '.$1');

    return u;
  }

  static Future<String?> _fetch(String url, Duration timeout) async {
    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = timeout
        ..userAgent = _userAgent;

      final HttpClientRequest req = await client.getUrl(Uri.parse(url));
      req.followRedirects = true;
      req.maxRedirects = 5;
      req.headers.set(HttpHeaders.acceptLanguageHeader, 'ar,ar-SA;q=0.9,en;q=0.6');
      req.headers.set(HttpHeaders.refererHeader, 'https://m.shein.com/ar/');
      req.headers.set(HttpHeaders.acceptHeader, 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');

      final HttpClientResponse res = await req.close().timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 400) return null;

      final String body = await res.transform(utf8.decoder).join().timeout(timeout);
      return body;
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }
}
