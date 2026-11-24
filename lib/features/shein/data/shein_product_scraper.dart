import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'shein_image_resolver.dart';

class SheinScrapedProduct {
  const SheinScrapedProduct({
    required this.goodsId,
    required this.productUrl,
    required this.title,
    required this.imageUrl,
    required this.priceSar,
    this.colors = const <String>[],
    this.sizes = const <String>[],
  });

  final String goodsId;
  final String productUrl;
  final String title;
  final String imageUrl;
  final double priceSar;
  final List<String> colors;
  final List<String> sizes;
}

/// مستخرج بيانات منتج SHEIN الحقيقية عبر متابعة الروابط المختصرة وقراءة صفحة المنتج.
class SheinProductScraper {
  SheinProductScraper._();

  static const String _ua =
      'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  static String normalizeDigits(String raw) {
    const String ar = '٠١٢٣٤٥٦٧٨٩';
    const String fa = '۰۱۲۳۴۵۶۷۸۹';
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      final String ch = raw[i];
      final int idxAr = ar.indexOf(ch);
      final int idxFa = fa.indexOf(ch);
      if (idxAr >= 0) {
        b.write(idxAr);
      } else if (idxFa >= 0) {
        b.write(idxFa);
      } else {
        b.write(ch);
      }
    }
    return b.toString();
  }

  static String extractGoodsId(String input) {
    final String s = normalizeDigits(input).trim();
    if (s.isEmpty) return '';
    if (RegExp(r'^\d{6,}$').hasMatch(s)) return s;
    final List<RegExp> patterns = <RegExp>[
      RegExp(r'-p-(\d{5,})\.html', caseSensitive: false),
      RegExp(r'goods_id=(\d{5,})', caseSensitive: false),
      RegExp(r'goodsId=(\d{5,})', caseSensitive: false),
      RegExp(r'/p/(\d{5,})', caseSensitive: false),
      RegExp(r'(\d{6,})'),
    ];
    for (final RegExp p in patterns) {
      final RegExpMatch? m = p.firstMatch(s);
      if (m != null) return m.group(1)!;
    }
    return '';
  }

  /// يتابع إعادة التوجيه للروابط المختصرة مثل api-shein / onelink / tinyurl / bit.ly.
  static Future<String> resolveRedirects(
    String rawUrl, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final String s = rawUrl.trim();
    final RegExpMatch? m = RegExp(r'https?://[^\s]+').firstMatch(s);
    if (m == null) return s;
    String current = m.group(0)!;
    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = timeout
        ..userAgent = _ua;
      for (int hop = 0; hop < 6; hop++) {
        final Uri uri = Uri.parse(current);
        final HttpClientRequest req = await client.getUrl(uri);
        req.followRedirects = false;
        req.headers.set(HttpHeaders.acceptLanguageHeader, 'ar,ar-SA;q=0.9,en;q=0.7');
        final HttpClientResponse res = await req.close().timeout(timeout);
        if (res.statusCode >= 300 && res.statusCode < 400) {
          final String? loc = res.headers.value(HttpHeaders.locationHeader);
          await res.drain<void>().catchError((_) {});
          if (loc == null || loc.isEmpty) break;
          current = uri.resolve(loc).toString();
          continue;
        }
        // لو رجع HTML فيه canonical أو og:url أو goods_id
        if (extractGoodsId(current).isEmpty) {
          final String body = await res
              .transform(utf8.decoder)
              .join()
              .timeout(timeout)
              .catchError((_) => '');
          final RegExpMatch? ogUrl = RegExp(
            r'''property=["']og:url["'][^>]*content=["']([^"']+)["']''',
            caseSensitive: false,
          ).firstMatch(body);
          if (ogUrl != null) {
            current = ogUrl.group(1)!;
          } else {
            final String inBody = extractGoodsId(body);
            if (inBody.isNotEmpty) {
              return 'https://ar.shein.com/-p-$inBody.html';
            }
          }
        } else {
          await res.drain<void>().catchError((_) {});
        }
        break;
      }
    } catch (_) {
    } finally {
      client?.close(force: true);
    }
    return current;
  }

  static Future<SheinScrapedProduct?> fetchFromInput(String input) async {
    final String raw = input.trim();
    if (raw.isEmpty) return null;
    String goodsId = extractGoodsId(raw);
    if (goodsId.isEmpty && raw.contains('http')) {
      final String resolved = await resolveRedirects(raw);
      goodsId = extractGoodsId(resolved);
    }
    if (goodsId.isEmpty) return null;
    return fetchByGoodsId(goodsId);
  }

  static Future<SheinScrapedProduct?> fetchByGoodsId(
    String goodsId, {
    Duration timeout = const Duration(seconds: 9),
  }) async {
    final String id = goodsId.trim();
    if (id.isEmpty || !RegExp(r'^\d+$').hasMatch(id)) return null;

    final String canonicalUrl = 'https://ar.shein.com/-p-$id.html';
    final List<String> urls = <String>[
      'https://m.shein.com/ar/-p-$id.html',
      'https://ar.shein.com/-p-$id.html',
      'https://m.shein.com/-p-$id.html',
    ];

    String title = '';
    String imageUrl = '';
    double priceSar = 0;
    final List<String> colors = <String>[];
    final List<String> sizes = <String>[];

    for (final String url in urls) {
      final String? html = await _fetchHtml(url, timeout);
      if (html == null || html.isEmpty) continue;

      if (title.isEmpty) {
        title = _extractTitle(html);
      }
      if (imageUrl.isEmpty) {
        imageUrl = _extractImage(html);
      }
      if (priceSar <= 0.05) {
        priceSar = _extractPrice(html);
      }
      if (colors.isEmpty) {
        colors.addAll(_extractColors(html));
      }
      if (sizes.isEmpty) {
        sizes.addAll(_extractSizes(html));
      }
      if (title.isNotEmpty && imageUrl.isNotEmpty && priceSar > 0.05) {
        break;
      }
    }

    if (imageUrl.isEmpty) {
      imageUrl = (await SheinImageResolver.byGoodsId(id)) ?? '';
    }

    if (title.isEmpty && imageUrl.isEmpty && priceSar <= 0) {
      return null;
    }

    return SheinScrapedProduct(
      goodsId: id,
      productUrl: canonicalUrl,
      title: title.isEmpty ? 'قطعة SHEIN #$id' : title,
      imageUrl: imageUrl,
      priceSar: priceSar,
      colors: colors,
      sizes: sizes,
    );
  }

  static Future<String?> _fetchHtml(String url, Duration timeout) async {
    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = timeout
        ..userAgent = _ua;
      final HttpClientRequest req = await client.getUrl(Uri.parse(url));
      req.followRedirects = true;
      req.maxRedirects = 5;
      req.headers.set(HttpHeaders.acceptLanguageHeader, 'ar-SA,ar;q=0.9,en;q=0.6');
      req.headers.set(HttpHeaders.refererHeader, 'https://m.shein.com/ar/');
      req.headers.set(
        HttpHeaders.acceptHeader,
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      );
      final HttpClientResponse res = await req.close().timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 400) return null;
      return await res.transform(utf8.decoder).join().timeout(timeout);
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  static String _decodeHtml(String raw) => raw
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _extractTitle(String html) {
    final List<RegExp> patterns = <RegExp>[
      RegExp(r'''property=["']og:title["'][^>]*content=["']([^"']+)["']''',
          caseSensitive: false),
      RegExp(r'''content=["']([^"']+)["'][^>]*property=["']og:title["']''',
          caseSensitive: false),
      RegExp(r'"goods_name"\s*:\s*"([^"]+)"'),
      RegExp(r'"goodsTitle"\s*:\s*"([^"]+)"'),
      RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false),
    ];
    for (final RegExp p in patterns) {
      final RegExpMatch? m = p.firstMatch(html);
      if (m == null) continue;
      String t = _decodeHtml(m.group(1)!);
      t = t.replaceAll(RegExp(r'\s*[|–-]\s*SHEIN.*$', caseSensitive: false), '').trim();
      if (t.length >= 3 && !t.toLowerCase().startsWith('shein')) {
        return t.length > 140 ? '${t.substring(0, 138)}…' : t;
      }
    }
    return '';
  }

  static String _extractImage(String html) {
    final List<RegExp> patterns = <RegExp>[
      RegExp(r'''property=["']og:image["'][^>]*content=["']([^"']+)["']''',
          caseSensitive: false),
      RegExp(r'''content=["']([^"']+)["'][^>]*property=["']og:image["']''',
          caseSensitive: false),
      RegExp(r'"(?:goods_img|goods_image|main_image|origin_image|original_img)"\s*:\s*"([^"]+)"'),
    ];
    for (final RegExp p in patterns) {
      final RegExpMatch? m = p.firstMatch(html);
      if (m == null) continue;
      String u = m.group(1)!.trim().replaceAll(r'\u002F', '/').replaceAll('&amp;', '&');
      if (u.startsWith('//')) u = 'https:$u';
      if (!u.startsWith('http')) continue;
      if (RegExp(r'logo|shein_logo|/s\.(png|jpg)|placeholder|transparent|blank',
              caseSensitive: false)
          .hasMatch(u)) {
        continue;
      }
      return u;
    }
    return '';
  }

  static double _extractPrice(String html) {
    final List<RegExp> patterns = <RegExp>[
      RegExp(r'"salePrice"\s*:\s*\{[^}]*"amount"\s*:\s*"?([0-9٠-٩۰-۹.,]+)"?'),
      RegExp(r'"retailPrice"\s*:\s*\{[^}]*"amount"\s*:\s*"?([0-9٠-٩۰-۹.,]+)"?'),
      RegExp(r'"srAmount"\s*:\s*"?([0-9٠-٩۰-۹.,]+)"?'),
      RegExp(r'"amountWithSymbol"\s*:\s*"[^"]*?([0-9٠-٩۰-۹]+(?:[.,][0-9٠-٩۰-۹]+)?)"'),
      RegExp(r'''property=["']product:price:amount["'][^>]*content=["']([0-9٠-٩۰-۹.,]+)["']''',
          caseSensitive: false),
      RegExp(r'"price"\s*:\s*"?([0-9٠-٩۰-۹]+(?:\.[0-9٠-٩۰-۹]+)?)"?'),
    ];
    for (final RegExp p in patterns) {
      final RegExpMatch? m = p.firstMatch(html);
      if (m == null) continue;
      final String cleaned = normalizeDigits(m.group(1)!)
          .replaceAll(',', '')
          .replaceAll(RegExp(r'[^0-9.]'), '');
      final double? v = double.tryParse(cleaned);
      if (v != null && v > 0.05 && v < 100000) {
        return v;
      }
    }
    return 0;
  }

  static List<String> _extractColors(String html) {
    final Set<String> out = <String>{};
    for (final RegExpMatch m in RegExp(r'"goods_color"\s*:\s*"([^"]{1,30})"').allMatches(html)) {
      final String c = _decodeHtml(m.group(1)!);
      if (c.isNotEmpty) out.add(c);
      if (out.length >= 6) break;
    }
    return out.toList();
  }

  static List<String> _extractSizes(String html) {
    final Set<String> out = <String>{};
    for (final RegExpMatch m
        in RegExp(r'"attr_value_name"\s*:\s*"((?:XXS|XS|S|M|L|XL|XXL|2XL|3XL|4XL|\d{2,3}))"')
            .allMatches(html)) {
      final String s = m.group(1)!.trim();
      if (s.isNotEmpty) out.add(s);
      if (out.length >= 8) break;
    }
    return out.toList();
  }
}
