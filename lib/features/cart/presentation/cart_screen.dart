import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// يحوّل أي صيغة مشاركة من شي إن إلى رابط سلة صالح.
///
/// الصيغ المدعومة:
/// 1) `sheinlink://applink/share_receiver?data={...}`  (زر المشاركة داخل التطبيق)
/// 2) `https://onelink.shein.com/58/xxxx?shc=...`        (زر النسخ / Copy link)
/// 3) رابط فيه `group_id` جاهز.
class SheinLinkResolver {
  SheinLinkResolver._();

  static final RegExp _groupIdPattern = RegExp(
    r'group_id(?:%[0-9A-Fa-f]{2}|[^0-9A-Za-z_]){0,16}(\d{6,})',
    caseSensitive: false,
  );

  static final RegExp _shcPattern = RegExp(
    r'shc(?:%[0-9A-Fa-f]{2}|[^0-9A-Za-z_]){0,16}([0-9A-Za-z_]{4,})',
    caseSensitive: false,
  );

  static final RegExp _httpPattern = RegExp(r'https?://[^\s]+');

  /// رابط المشاركة داخل التطبيق كما يظهر داخل وسوم الصفحة.
  static final RegExp _appLinkPattern = RegExp(r'''sheinlink://[^"'\s<]+''');

  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static String? groupIdIn(String text) {
    if (text.trim().isEmpty) return null;
    final RegExpMatch? direct = _groupIdPattern.firstMatch(text);
    if (direct != null) return direct.group(1);

    try {
      final String decoded = Uri.decodeFull(text);
      return _groupIdPattern.firstMatch(decoded)?.group(1);
    } catch (_) {
      return null;
    }
  }

  static String? shcIn(String text) {
    if (text.trim().isEmpty) return null;
    final RegExpMatch? direct = _shcPattern.firstMatch(text);
    if (direct != null) return direct.group(1);
    try {
      return _shcPattern.firstMatch(Uri.decodeFull(text))?.group(1);
    } catch (_) {
      return null;
    }
  }

  static String landingUrl(String groupId, {String? shc}) {
    final String base =
        'https://m.shein.com/ar/cart/share/landing'
        '?group_id=${Uri.encodeQueryComponent(groupId)}';
    return (shc == null || shc.isEmpty)
        ? base
        : '$base&shc=${Uri.encodeQueryComponent(shc)}';
  }

  /// يعيد رابط سلة صالحاً أو null إن تعذّر الحل.
  /// قد يجلب صفحة onelink (قصيرة) لقراءة معرّف السلة منها.
  static Future<String?> resolve(
    String input, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final String text = input.trim();
    if (text.isEmpty) return null;

    final String? known = groupIdIn(text);
    if (known != null) return landingUrl(known, shc: shcIn(text));

    final RegExpMatch? linkMatch = _httpPattern.firstMatch(text);
    if (linkMatch == null) return null;

    final String url = linkMatch.group(0)!;
    if (!url.toLowerCase().contains('shein')) return null;

    try {
      final HttpClient client = HttpClient()
        ..connectionTimeout = timeout
        ..userAgent = _userAgent;
      try {
        final HttpClientRequest req = await client.getUrl(Uri.parse(url));
        req.headers.set(HttpHeaders.acceptLanguageHeader, 'ar,en;q=0.8');
        final HttpClientResponse res = await req.close().timeout(timeout);
        final String body =
            await res.transform(utf8.decoder).join().timeout(timeout);

        final String? gid = groupIdIn(body);
        if (gid != null) {
          return landingUrl(gid, shc: shcIn(body) ?? shcIn(text));
        }

        // بعض الصفحات تُرجع رابط المشاركة داخل وسم مخفي
        final RegExpMatch? deeplink = _appLinkPattern.firstMatch(body);
        if (deeplink != null) {
          final String deepLink = deeplink.group(0)!;
          final String? gid2 = groupIdIn(deepLink);
          if (gid2 != null) {
            return landingUrl(gid2, shc: shcIn(deepLink));
          }
        }
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      // نتجاهل ونعيد null ليتولى المستدعي الرسالة المناسبة
    }

    return null;
  }
}
