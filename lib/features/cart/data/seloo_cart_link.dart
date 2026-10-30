import 'dart:convert';

import '../../shein/domain/shein_draft.dart';
import '../domain/cart_item.dart';

/// يبني رابط سلة كاملة يحتوي كل منتجات سلة يمن سيلو.
///
/// الصيغة: البيانات مضغوطة في JSON ثم base64url داخل الرابط.
/// 1) رابط ويب يُفتح في أي متصفح ويعرض كل المنتجات.
/// 2) رابط تطبيق `yemenseloo://cart` يستورد السلة داخل التطبيق.
class SelooCartLink {
  SelooCartLink._();

  static const String scheme = 'yemenseloo';

  /// صفحة عرض السلة على الويب (استضافة ثابتة — يمكن تغييرها)
  static const String webBase = 'https://litter.catbox.moe/fcbcya.html';

  static String encodePayload(List<CartItem> items) {
    final List<Map<String, Object?>> list = items
        .map(
          (CartItem e) => <String, Object?>{
            'i': e.goodsId,
            't': e.title,
            'u': e.imageUrl,
            'p': e.sourcePrice,
            'c': e.color,
            's': e.size,
            'q': e.quantity,
            'r': e.sourceUrl,
            'k': e.sku,
          },
        )
        .toList();

    final String json = jsonEncode(<String, Object?>{
      'v': 1,
      'it': list,
    });

    return base64Url.encode(utf8.encode(json)).replaceAll('=', '');
  }

  static String webLink(List<CartItem> items) =>
      '$webBase#d=${encodePayload(items)}';

  static String appLink(List<CartItem> items) =>
      '$scheme://cart?d=${encodePayload(items)}';

  /// يستخرج المنتجات من رابط التطبيق أو من رابط الويب
  static List<SheinDraft> draftsFromLink(String raw) {
    final String text = raw.trim();
    if (text.isEmpty) return <SheinDraft>[];

    String? payload;
    final RegExpMatch? dataMatch = RegExp(r'd=([^&#\s]+)').firstMatch(text);
    if (dataMatch != null) payload = dataMatch.group(1);
    if (payload == null) return <SheinDraft>[];

    try {
      String b64 = Uri.decodeComponent(payload)
          .replaceAll('-', '+')
          .replaceAll('_', '/');
      while (b64.length % 4 != 0) {
        b64 += '=';
      }

      final Object? parsed = jsonDecode(utf8.decode(base64Decode(b64)));
      if (parsed is! Map || parsed['it'] is! List) return <SheinDraft>[];

      final List<SheinDraft> drafts = <SheinDraft>[];
      for (final Object? rawItem in parsed['it'] as List) {
        if (rawItem is! Map) continue;

        final String goodsId = '${rawItem['i'] ?? ''}'.trim();
        final String title = '${rawItem['t'] ?? ''}'.trim();
        final double price =
            double.tryParse('${rawItem['p'] ?? 0}') ?? 0;
        if (goodsId.isEmpty || title.isEmpty || price <= 0) continue;

        drafts.add(
          SheinDraft(
            goodsId: goodsId,
            productUrl: 'https://m.shein.com/ar/pdsearch/$goodsId/',
            title: title,
            imageUrl: '${rawItem['u'] ?? ''}'.trim(),
            sourcePrice: price,
            sourceCurrency: 'SAR',
            quantity: int.tryParse('${rawItem['q'] ?? 1}') ?? 1,
            color: '${rawItem['c'] ?? ''}'.trim(),
            size: '${rawItem['s'] ?? ''}'.trim(),
            options: const <String, String>{},
            sourceStore: 'SHEIN',
            sku: '${rawItem['k'] ?? ''}'.trim(),
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
