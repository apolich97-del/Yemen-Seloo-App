
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
/// ⭐ زيارة صفحة الهبوط أولاً لأخذ كوكيز الجلسة، ثم POST بترويسات
/// متصفح كاملة (Origin/Referer/Accept-Language) مع 3 محاولات تلقائية.
/// لو استمر الرفض فهو حظر على عنوان IP — والحل البديل المضمون:
/// فتح الرابط داخل متصفح التطبيق (زر الزحف الأخضر).
class SheinShareApi {
static const _api =
'https://m.shein.com/ar/bff-api/order/cart/share/landing?_ver=1.1.8&_lang=ar';
static const _ua =
'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
static const _timeout = Duration(seconds: 25);
static const _attempts = 3;
static const _retryDelay = Duration(seconds: 3);

/// SheinDraft.fromBridgePayload يرفض العناوين الأطول من 300 حرف.
static const _maxTitleLength = 300;

Future<List<Map<String, dynamic>>> fetchSharedCart(String input) async {
final String text = (input ?? '').trim();
if (text.isEmpty) {
throw const SheinShareException('الصق رابط السلة المشتركة أولاً.');
}

String? groupId = _extractGroupId(text);

final String? shareUrl =
    RegExp(r'https?://[^\s"<>]+').firstMatch(text)?.group(0);

final String landingUrl = (shareUrl != null && groupId != null)
    ? shareUrl
    : '[https\:\/\/m\.shein\.com\/ar\/cart\/share\/landing\?group\_id\=\$groupId](<https://m.shein.com/ar/cart/share/landing?group_id=$groupId>)';

if (groupId == null && RegExp(r'^\d{5,}$').hasMatch(text)) {
  groupId = text;
}

if (groupId == null) {
  throw const SheinShareException(
      'لم أجد معرّف السلة في النص — تأكد من نسخ رابط المشاركة كاملاً');
}

// ═══ 3 محاولات تلقائية (شي إن ترفض مؤقتاً أحياناً) ═══
Object lastError = const SheinShareException('فشل غير متوقع');
for (int attempt = 1; attempt <= _attempts; attempt++) {
  try {
    return await _tryFetch(landingUrl, groupId);
  } catch (e) {
    lastError = e is SheinShareException
        ? e
        : const SheinShareException(
            'تعذر الاتصال بشي إن — تحقق من الإنترنت وأعد المحاولة');
    if (attempt < _attempts) {
      await Future<void>.delayed(_retryDelay);
    }
  }
}
throw lastError;


}

/// محاولة واحدة: صفحة الهبوط (كوكيز) ثم POST بترويسات متصفح كاملة.
Future<List<Map<String, dynamic>>> _tryFetch(
String landingUrl, String groupId) async {
// ── الخطوة 1: زيارة صفحة الهبوط لأخذ كوكيز الجلسة ──
String cookieHeader = '';
try {
final http.Response landing = await http
.get(
Uri.parse(landingUrl),
headers: <String, String>{
'User-Agent': _ua,
'Accept':
'text/html,application/xhtml+xml,application/xml;q=0.9,/;q=0.8',
'Accept-Language': 'ar,ar-SA;q=0.9,en;q=0.5',
},
)
.timeout(_timeout);

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

// ── الخطوة 2: POST بترويسات متصفح كاملة ──
final String origin = Uri.parse(landingUrl).origin;
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
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'ar,ar-SA;q=0.9,en;q=0.5',
          'Origin': origin,
          'Referer': landingUrl,
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
  // رمز الحالة يكشف نوع الحظر للتشخيص (302=حماية، 403=منع...)
  throw SheinShareException(
      'شي إن رفضت الطلب (رمز ${res.statusCode}) — أعد المحاولة بعد قليل');
}

final Map<String, dynamic> data;
try {
  data = jsonDecode(res.body) as Map<String, dynamic>;
} catch (_) {
  throw const SheinShareException(
      'تعذر الحصول على السلة من شي إن — أعد المحاولة بعد قليل');
}

if (data['code'] != '0' \|\| data['info'] == null) {
  throw const SheinShareException('السلة غير متاحة أو منتهية الصلاحية');
}

final Map<String, dynamic> info =
    Map<String, dynamic>.from(data['info'] as Map);

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
  'productUrl': '[https\:\/\/ar\.shein\.com\/\-p\-\$goodsId\.html](<https://ar.shein.com/-p-$goodsId.html>)',
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
