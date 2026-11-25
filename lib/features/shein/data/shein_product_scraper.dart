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

class _OnelinkMeta {
  String goodsId = '';
  String targetUrl = '';
  String ogTitle = '';
  String ogImage = '';
}

/// مستخرج بيانات منتج SHEIN الحقيقية: يدعم لصق نص المشاركة الكامل من شي إن،
/// وروابط onelink المختصرة، وروابط المنتج المباشرة، وأكواد goodsId.
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

  /// يستخرج أول رابط حقيقي من داخل نص المشاركة المنسوخ من شي إن.
  static String extractFirstUrl(String raw) {
    final RegExpMatch? m =
        RegExp(r'''https?://[^\s<>"'\)]+''', caseSensitive: false)
            .firstMatch(raw);
    return m?.group(0) ?? '';
  }

  /// يستخرج وصف المنتج العربي من نص المشاركة المنسوخ (يتجاهل الروابط وعبارة الترحيب).
  static String extractShareTextTitle(String raw) {
    final List<String> lines = raw
        .split(RegExp(r'[\r\n]+'))
        .map((e) => e.trim())
        .where((e) =>
            e.length >= 6 &&
            !RegExp(r'https?://|sheinlink://|onelink\.shein', caseSensitive: false)
                .hasMatch(e) &&
            !e.contains('اكتشفت منتجات رائعة') &&
            !e.contains('تعالوا وتحققوا منها'))
        .toList();
    if (lines.isEmpty) return '';
    lines.sort((a, b) => b.length.compareTo(a.length));
    final String t = lines.first.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length > 160 ? '${t.substring(0, 158)}…' : t;
  }

  static String extractGoodsId(String input) {
    final String s = normalizeDigits(input).trim();
    if (s.isEmpty) return '';
    if (RegExp(r'^\d{6,}$').hasMatch(s)) return s;
    final List<RegExp> patterns = <RegExp>[
      RegExp(r'-p-(\d{5,})\.html', caseSensitive: false),
      RegExp(r'product-itemv2-(\d{5,})\.html', caseSensitive: false),
      RegExp(r'goods_id[=":\s&quot;]+(\d{5,})', caseSensitive: false),
      RegExp(r'goodsId[=":\s&quot;]+(\d{5,})', caseSensitive: false),
      RegExp(r'/p/(\d{5,})', caseSensitive: false),
      RegExp(r'/pdsearch/(\d{5,})', caseSensitive: false),
    ];
    for (final RegExp p in patterns) {
      final RegExpMatch? m = p.firstMatch(s);
      if (m != null) return m.group(1)!;
    }
    return '';
  }

  static String _normalizeImgUrl(String raw) {
    String u = raw
        .trim()
        .replaceAll(r'\u002F', '/')
        .replaceAll(r'\/', '/')
        .replaceAll('&amp;', '&');
    if (u.startsWith('//')) u = 'https:$u';
    if (u.startsWith('http://')) u = 'https://${u.substring(7)}';
    if (!u.startsWith('http')) return '';
    if (RegExp(r'logo|shein_logo|/s\.(png|jpg)|placeholder|transparent|blank',
            caseSensitive: false)
        .hasMatch(u)) {
      return '';
    }
    return u;
  }

  /// يقرأ صفحة onelink.shein.com / الروابط المختصرة ويستخرج goods_id + og:title + og:image من الـ HTML.
  static Future<_OnelinkMeta> _inspectUrl(
    String rawUrl, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final _OnelinkMeta meta = _OnelinkMeta();
    final String urlOnly = extractFirstUrl(rawUrl);
    if (urlOnly.isEmpty) return meta;
    String current = urlOnly;
    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = timeout
        ..userAgent = _ua;
      for (int hop = 0; hop < 6; hop++) {
        final Uri uri = Uri.parse(current);
        final HttpClientRequest req = await client.getUrl(uri);
        req.followRedirects = false;
        req.headers.set(
            HttpHeaders.acceptLanguageHeader, 'ar-SA,ar;q=0.9,en;q=0.7');
        final HttpClientResponse res = await req.close().timeout(timeout);
        if (res.statusCode >= 300 && res.statusCode < 400) {
          final String? loc = res.headers.value(HttpHeaders.locationHeader);
          await res.drain<void>().catchError((_) {});
          if (loc == null || loc.isEmpty) break;
          current = uri.resolve(loc).toString();
          final String gFromUrl = extractGoodsId(current);
          if (gFromUrl.isNotEmpty) meta.goodsId = gFromUrl;
          continue;
        }
        final String body = await res
            .transform(utf8.decoder)
            .join()
            .timeout(timeout)
            .catchError((_) => '');
        meta.targetUrl = current;

        // 1) deeplink من صفحة onelink (يحوي goods_id الحقيقي مثل 565426890)
        final String decodedBody = _decodeHtml(body);
        final String g1 = extractGoodsId(decodedBody);
        if (g1.isNotEmpty) {
          meta.goodsId = g1;
        } else {
          final String gUrl = extractGoodsId(current);
          if (gUrl.isNotEmpty) meta.goodsId = gUrl;
        }

        // 2) og:url / input#url
        final RegExpMatch? ogUrl = RegExp(
          r'''(?:property=["']og:url["'][^>]*content=|id=["']url["'][^>]*value=)["']([^"']+)["']''',
          caseSensitive: false,
        ).firstMatch(body);
        if (ogUrl != null) {
          final String uVal = _decodeHtml(ogUrl.group(1)!);
          if (uVal.startsWith('http')) {
            meta.targetUrl = uVal;
            if (meta.goodsId.isEmpty) {
              meta.goodsId = extractGoodsId(uVal);
            }
          }
        }

        // 3) og:title + og:image من صفحة onelink مباشرة
        meta.ogTitle = _extractTitle(body);
        meta.ogImage = _extractImage(body);
        break;
      }
    } catch (_) {
    } finally {
      client?.close(force: true);
    }
    return meta;
  }

  static Future<String> resolveRedirects(
    String rawUrl, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final _OnelinkMeta meta = await _inspectUrl(rawUrl, timeout: timeout);
    if (meta.goodsId.isNotEmpty) {
      return 'https://ar.shein.com/-p-${meta.goodsId}.html';
    }
    return meta.targetUrl.isNotEmpty ? meta.targetUrl : rawUrl;
  }

  static Future<SheinScrapedProduct?> fetchFromInput(String input) async {
    final String raw = input.trim();
    if (raw.isEmpty) return null;

    final String shareTitle = extractShareTextTitle(raw);
    final String urlOnly = extractFirstUrl(raw);
    String goodsId = extractGoodsId(urlOnly.isNotEmpty ? urlOnly : raw);
    _OnelinkMeta? linkMeta;

    if (goodsId.isEmpty && urlOnly.isNotEmpty) {
      linkMeta = await _inspectUrl(urlOnly);
      goodsId = linkMeta.goodsId;
    }

    if (goodsId.isNotEmpty) {
      final SheinScrapedProduct? fetched = await fetchByGoodsId(
        goodsId,
        fallbackTitle: (linkMeta?.ogTitle.isNotEmpty == true)
            ? linkMeta!.ogTitle
            : shareTitle,
        fallbackImage: linkMeta?.ogImage ?? '',
        fallbackUrl: (linkMeta?.targetUrl.isNotEmpty == true)
            ? linkMeta!.targetUrl
            : '',
      );
      if (fetched != null) return fetched;
    }

    // احتياط: حتى لو فشل جلب السعر، نُرجع العنوان والصورة والرابط من onelink أو النص المنسوخ
    final String bestTitle =
        (linkMeta?.ogTitle.isNotEmpty == true) ? linkMeta!.ogTitle : shareTitle;
    final String bestImg = linkMeta?.ogImage ?? '';
    final String bestUrl =
        goodsId.isNotEmpty
            ? 'https://ar.shein.com/-p-$goodsId.html'
            : (linkMeta?.targetUrl.isNotEmpty == true
                ? linkMeta!.targetUrl
                : (urlOnly.isNotEmpty ? urlOnly : raw));

    if (bestTitle.isNotEmpty || bestImg.isNotEmpty) {
      return SheinScrapedProduct(
        goodsId: goodsId.isNotEmpty ? goodsId : '${DateTime.now().millisecondsSinceEpoch % 1000000}',
        productUrl: bestUrl,
        title: bestTitle.isNotEmpty ? bestTitle : 'قطعة SHEIN',
        imageUrl: bestImg,
        priceSar: 0,
      );
    }
    return null;
  }

  static Future<SheinScrapedProduct?> fetchByGoodsId(
    String goodsId, {
    Duration timeout = const Duration(seconds: 9),
    String fallbackTitle = '',
    String fallbackImage = '',
    String fallbackUrl = '',
  }) async {
    final String id = goodsId.trim();
    if (id.isEmpty || !RegExp(r'^\d+$').hasMatch(id)) return null;
    final String canonicalUrl =
        fallbackUrl.isNotEmpty && fallbackUrl.contains('shein.com')
            ? fallbackUrl
            : 'https://ar.shein.com/-p-$id.html';
    final List<String> urls = <String>[
      'https://m.shein.com/ar/product-itemv2-$id.html',
      'https://m.shein.com/ar/-p-$id.html',
      'https://ar.shein.com/-p-$id.html',
      'https://m.shein.com/-p-$id.html',
    ];
    String title = fallbackTitle;
    String imageUrl = fallbackImage;
    double priceSar = 0;
    final List<String> colors = <String>[];
    final List<String> sizes = <String>[];

    for (final String url in urls) {
      final String? html = await _fetchHtml(url, timeout);
      if (html == null || html.isEmpty) continue;
      final String t2 = _extractTitle(html);
      if (t2.isNotEmpty && title.isEmpty) title = t2;
      final String i2 = _extractImage(html);
      if (i2.isNotEmpty && imageUrl.isEmpty) imageUrl = i2;
      if (priceSar <= 0.05) priceSar = _extractPrice(html);
      if (colors.isEmpty) colors.addAll(_extractColors(html));
      if (sizes.isEmpty) sizes.addAll(_extractSizes(html));
      if (title.isNotEmpty && imageUrl.isNotEmpty && priceSar > 0.05) break;
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
        return t.length > 160 ? '${t.substring(0, 158)}…' : t;
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
      final String u = _normalizeImgUrl(m.group(1)!);
      if (u.isNotEmpty) return u;
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
