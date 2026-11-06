import 'dart:convert';
import 'dart:io' show gzip;

import 'package:http/http.dart' as http;

import '../../shein/domain/shein_draft.dart';
import '../domain/cart_item.dart';

class SelooCartLink {
  SelooCartLink._();

  static const String scheme = 'yemenseloo';
  static const String webBase = 'https://seloo-cart.vercel.app/';

  // دالة مساعدة لتنظيف الصور قبل وضعها في الرابط
  static String _cleanImageForLink(String raw) {
    if (raw.isEmpty) return '';
    // استبعاد شعار SHEIN والصور التالفة لتجنب إرسالها
    if (raw.contains('shein.com/images') || raw.contains('logo') || raw.length < 20) {
      return ''; 
    }
    return raw;
  }

  static String encodePayload(List<CartItem> items) {
    final List<List<Object?>> list = items.map((CartItem e) {
      String title = e.title.trim();
      // ⭐ تقصير اسم المنتج إلى 15 حرفاً لتقليل حجم الرابط
      // نُبقي وصفاً كاملاً: كانت 13 حرفاً فتُقطع أسماء المنتجات عند الاستيراد
      if (title.length > 90) title = '${title.substring(0, 88)}..';
      
      return [
        e.goodsId,
        title,
        _cleanImageForLink(e.imageUrl), // تنظيف الصورة
        e.sourcePrice,
        e.color,
        e.size,
        e.quantity,
      ];
    }).toList();

    final String json = jsonEncode(<String, Object?>{'it': list});
    final List<int> packed = gzip.encode(utf8.encode(json));
    final String body = base64Url.encode(packed).replaceAll('=', '');
    return 'z$body';
  }

  /// ═══ روابط سلة مختصرة ═══
  ///
  /// الافتراضي: tinyurl (بلا إعداد ولا تكلفة).
  /// عند توفّر نطاق خاص، ابنِ بـ:
  ///   flutter build apk --dart-define=SELOO_SHORT_BASE=https://seloo.link
  /// فيصبح الرابط https://seloo.link/s/AbC123 تلقائياً،
  /// وإن تعطّل النطاق يرجع إلى tinyurl ثم إلى الرابط الطويل، بلا أي توقف.
  static const String shortBase =
      String.fromEnvironment('SELOO_SHORT_BASE', defaultValue: '');

  /// يبقى قصيراً مهما زاد عدد المنتجات. لا يرمي استثناءً أبداً.
  static Future<String> shortWebLink(List<CartItem> items) async {
    final String long = webLink(items);
    if (long.length <= 90) return long;

    if (shortBase.isNotEmpty) {
      final String? custom = await _shortViaServer(long);
      if (custom != null) return custom;
    }

    final String? tiny = await _shortViaTinyUrl(long);
    if (tiny != null) return tiny;

    return long;
  }

  static Future<String?> _shortViaServer(String long) async {
    try {
      final Uri base =
          Uri.parse(shortBase.endsWith('/') ? shortBase : '$shortBase/');
      final http.Response r = await http
          .post(
            base.resolve('api/short'),
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, String>{'d': _payloadOf(long)}),
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final Object? body = jsonDecode(r.body);
      if (body is! Map) return null;
      final String code = '${body['code'] ?? ''}'.trim();
      if (code.isEmpty || code.length > 24) return null;
      return base.resolve('s/$code').toString();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _shortViaTinyUrl(String long) async {
    try {
      final Uri api = Uri.parse(
        'https://tinyurl.com/api-create.php?url=${Uri.encodeComponent(long)}',
      );
      final http.Response r =
          await http.get(api).timeout(const Duration(seconds: 8));
      final String body = r.body.trim();
      if (r.statusCode == 200 && body.startsWith('http') && body.length <= 60) {
        return body;
      }
    } catch (_) {}
    return null;
  }

  /// ما بعد `#d=` في رابط الصفحة
  static String _payloadOf(String long) {
    final int i = long.indexOf('#d=');
    return i == -1 ? '' : long.substring(i + 3);
  }

  static String webLink(List<CartItem> items) =>
      '$webBase#d=${encodePayload(items)}';

  static String appLink(List<CartItem> items) =>
      '$scheme://cart?d=${encodePayload(items)}';

  static List<SheinDraft> draftsFromLink(String raw) {
    final String text = raw.trim();
    if (text.isEmpty) return <SheinDraft>[];

    String? payload;
    final RegExpMatch? dataMatch = RegExp(r'd=([^&#\s]+)').firstMatch(text);
    if (dataMatch != null) payload = dataMatch.group(1);
    if (payload == null) return <SheinDraft>[];

    try {
      String data = Uri.decodeComponent(payload);
      bool compressed = false;
      if (data.startsWith('z')) {
        compressed = true;
        data = data.substring(1);
      }

      String b64 = data.replaceAll('-', '+').replaceAll('_', '/');
      while (b64.length % 4 != 0) {
        b64 += '=';
      }

      final List<int> bytes = base64Decode(b64);
      final List<int> raw = compressed ? gzip.decode(bytes) : bytes;
      final Object? parsed = jsonDecode(utf8.decode(raw));
      if (parsed is! Map || parsed['it'] is! List) return <SheinDraft>[];

      final List<SheinDraft> drafts = <SheinDraft>[];
      for (final Object? rawItem in parsed['it'] as List) {
        String goodsId = '';
        String title = '';
        String imageUrl = '';
        double price = 0;
        String color = '';
        String size = '';
        int quantity = 1;

        if (rawItem is List && rawItem.length >= 7) {
          goodsId = '${rawItem[0] ?? ''}'.trim();
          title = '${rawItem[1] ?? ''}'.trim();
          imageUrl = '${rawItem[2] ?? ''}'.trim();
          price = double.tryParse('${rawItem[3] ?? 0}') ?? 0;
          color = '${rawItem[4] ?? ''}'.trim();
          size = '${rawItem[5] ?? ''}'.trim();
          quantity = int.tryParse('${rawItem[6] ?? 1}') ?? 1;
        } else if (rawItem is Map) {
          goodsId = '${rawItem['i'] ?? ''}'.trim();
          title = '${rawItem['t'] ?? ''}'.trim();
          imageUrl = '${rawItem['u'] ?? ''}'.trim();
          price = double.tryParse('${rawItem['p'] ?? 0}') ?? 0;
          color = '${rawItem['c'] ?? ''}'.trim();
          size = '${rawItem['s'] ?? ''}'.trim();
          quantity = int.tryParse('${rawItem['q'] ?? 1}') ?? 1;
        } else {
          continue;
        }

        if (goodsId.isEmpty || title.isEmpty || price <= 0) continue;

        drafts.add(
          SheinDraft(
            goodsId: goodsId,
            productUrl: 'https://m.shein.com/ar/pdsearch/$goodsId/',
            title: title,
            imageUrl: imageUrl,
            sourcePrice: price,
            sourceCurrency: 'SAR',
            quantity: quantity,
            color: color,
            size: size,
            options: const <String, String>{},
            sourceStore: 'SHEIN',
            sku: '',
            variantId: '',
            source: 'shared-cart-link',
            clientTs: DateTime.now().toUtc(),
          ),
        );
      }
      return drafts;
    } catch (_) {
      return <SheinDraft>[];
    }
  }
}
