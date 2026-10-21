
import 'dart:convert';
import 'package:http/http.dart' as http;

class SheinShareApi {
  SheinShareApi({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const String _endpoint =
      'https://m.shein.com/ar/bff-api/order/cart/share/landing';

  Future<List<Map<String, dynamic>>> fetchSharedCart(
      String sharedLink) async {
    final groupId = _extractGroupId(sharedLink);

    if (groupId == null || groupId.isEmpty) {
      throw Exception(
        'تعذّر استخراج معرّف السلة من الرابط. '
        'قد يحتاج رابط SHEIN المختصر إلى معالجة إضافية.',
      );
    }

    final uri = Uri.parse(_endpoint).replace(
      queryParameters: const {
        '_ver': '1.1.8',
        '_lang': 'ar',
      },
    );

    final response = await _client
        .post(
          uri,
          headers: const {
            'Accept': 'application/json, text/plain, */*',
            'Content-Type': 'application/json',
            'Referer': 'https://m.shein.com/',
          },
          body: jsonEncode({
            'groupId': groupId,
            'localCountry': 'SA',
            'userLocalSizeCountry': '',
          }),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'فشل الاتصال بـ SHEIN: ${response.statusCode}',
      );
    }

    final dynamic decoded;

    try {
      decoded = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
    } on FormatException {
      throw Exception('استجابة SHEIN ليست بصيغة JSON صالحة.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('صيغة استجابة SHEIN غير متوقعة.');
    }

    final data = decoded;
    final nested = data['data'];
    final source =
        nested is Map<String, dynamic> ? nested : data;

    final code = source['code'] ?? data['code'];

    if (code != null && code.toString() != '0') {
      throw Exception(
        (source['info'] ?? data['info'] ??
                'تعذّر الحصول على السلة المشتركة')
            .toString(),
      );
    }

    final candidates = [
      source['normalProducts'],
      source['products'],
      source['productList'],
      source['goodsList'],
    ];

    for (final candidate in candidates) {
      if (candidate is! List) continue;

      final products = <Map<String, dynamic>>[];

      for (final item in candidate) {
        if (item is! Map) continue;

        final product = Map<String, dynamic>.from(item);
        final normalized = _normalizeProduct(product);

        if (normalized != null) {
          products.add(normalized);
        }
      }

      if (products.isNotEmpty) return products;
    }

    throw Exception(
      'لم يتم العثور على منتجات في السلة المشتركة.',
    );
  }

  String? _extractGroupId(String input) {
    final value = input.trim();

    if (value.isEmpty) return null;

    final patterns = [
      RegExp(
        r'[?&](?:group_id|groupId|groupid)=([^&#]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'["\x27]?(?:group_id|groupId|groupid)["\x27]?\s*:\s*'
        r'["\x27]([^"\x27]+)["\x27]',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(value);

      if (match != null) {
        final id = Uri.decodeComponent(
          match.group(1) ?? '',
        ).trim();

        if (id.isNotEmpty) return id;
      }
    }

    // يقبل المعرّف المباشر فقط، ولا يفترض أن رمز onelink
    // هو معرّف المجموعة.
    if (RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value) &&
        !value.toLowerCase().contains('onelink')) {
      return value;
    }

    return null;
  }

  Map<String, dynamic>? _normalizeProduct(
      Map<String, dynamic> item) {
    String read(List<String> keys) {
      for (final key in keys) {
        final value = item[key];

        if (value != null &&
            value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }

      return '';
    }

    final id = read([
      'goods_id',
      'goodsId',
      'productId',
      'product_id',
      'id',
    ]);

    final name = read([
      'goods_name',
      'goodsName',
      'productName',
      'title',
      'name',
    ]);

    final image = read([
      'goods_img',
      'goodsImg',
      'goods_image',
      'image',
      'imageUrl',
      'cover',
    ]);

    final url = read([
      'goods_url',
      'goodsUrl',
      'productUrl',
      'url',
      'detailUrl',
    ]);

    final rawPrice = read([
      'salePrice',
      'sale_price',
      'retailPrice',
      'retail_price',
      'price',
      'unitPrice',
    ]);

    final price = _parsePrice(rawPrice);

    if (id.isEmpty && name.isEmpty && url.isEmpty) {
      return null;
    }

    final title = name.isEmpty ? 'منتج من SHEIN' : name;

    return {
      'goodsId': id,
      'goods_id': id,
      'title': title.length > 300
          ? title.substring(0, 300)
          : title,
      'name': title,
      'image': image,
      'imageUrl': image,
      'url': url,
      'productUrl': url,
      'price': price,
      'salePrice': price,
      'currency': 'SAR',
      'quantity': 1,
    };
  }

  double _parsePrice(String value) {
    final normalized = value
        .replaceAll(',', '')
        .replaceAll('SAR', '')
        .replaceAll('ر.س', '')
        .trim();

    final match =
        RegExp(r'\d+(?:\.\d+)?').firstMatch(normalized);

    if (match == null) return 0;

    return double.tryParse(match.group(0) ?? '') ?? 0;
  }

  void close() {
    _client.close();
  }
}
