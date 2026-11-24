import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

/// قطعة في كتالوج يمن سيلو.
class CatalogItem {
  CatalogItem({
    required this.id,
    required this.title,
    required this.goodsId,
    required this.sourceUrl,
    required this.imageUrl,
    required this.category,
    required this.colors,
    required this.sizes,
    required this.basePriceSar,
    required this.marginSar,
    required this.region,
    required this.badge,
    required this.active,
    this.createdAt,
  });

  final String id;
  final String title;
  final String goodsId;
  final String sourceUrl;
  final String imageUrl;
  final String category;
  final List<String> colors;
  final List<String> sizes;

  /// السعر الأساسي بالريال السعودي قبل الهامش.
  final double basePriceSar;

  /// هامش الربح بالريال السعودي.
  final double marginSar;

  /// منطقة التسعير: south | north | sar
  final String region;

  /// شارة ترويجية: new | best | offer | ''
  final String badge;
  final bool active;
  final DateTime? createdAt;

  double get priceSar => basePriceSar + marginSar;

  String get regionAr => switch (region) {
        'south' => 'جنوب',
        'north' => 'شمال',
        _ => 'سعودي',
      };

  String get badgeAr => switch (badge) {
        'new' => 'وصل حديثاً',
        'best' => 'الأكثر مبيعاً',
        'offer' => 'عرض خاص',
        _ => '',
      };

  /// السعر النهائي بعملة المنطقة المختارة.
  double priceIn(String regionKey, {required double rateSouth, required double rateNorth}) {
    final p = priceSar;
    return switch (regionKey) {
      'south' => p * rateSouth,
      'north' => p * rateNorth,
      _ => p,
    };
  }

  String currencyLabel(String regionKey) =>
      regionKey == 'sar' ? 'ر.س' : 'ر.ي';

  Map<String, dynamic> toMap() => <String, dynamic>{
        'title': title,
        'goodsId': goodsId,
        'sourceUrl': sourceUrl,
        'imageUrl': imageUrl,
        'category': category,
        'colors': colors,
        'sizes': sizes,
        'basePriceSar': basePriceSar,
        'marginSar': marginSar,
        'region': region,
        'badge': badge,
        'active': active,
        'createdAt': createdAt == null
            ? Timestamp.now()
            : Timestamp.fromDate(createdAt!),
      };

  factory CatalogItem.fromDoc(String id, Map<String, dynamic> m) => CatalogItem(
        id: id,
        title: (m['title'] ?? '') as String,
        goodsId: (m['goodsId'] ?? '') as String,
        sourceUrl: (m['sourceUrl'] ?? '') as String,
        imageUrl: (m['imageUrl'] ?? '') as String,
        category: (m['category'] ?? 'عام') as String,
        colors: ((m['colors'] as List?) ?? const []).map((e) => '$e').toList(),
        sizes: ((m['sizes'] as List?) ?? const []).map((e) => '$e').toList(),
        basePriceSar: ((m['basePriceSar'] as num?) ?? 0).toDouble(),
        marginSar: ((m['marginSar'] as num?) ?? 0).toDouble(),
        region: (m['region'] ?? 'south') as String,
        badge: (m['badge'] ?? '') as String,
        active: (m['active'] ?? true) as bool,
        createdAt: (m['createdAt'] is Timestamp)
            ? (m['createdAt'] as Timestamp).toDate()
            : null,
      );

  CatalogItem copyWith({
    String? title,
    String? category,
    List<String>? colors,
    List<String>? sizes,
    double? basePriceSar,
    double? marginSar,
    String? region,
    String? badge,
    bool? active,
    String? imageUrl,
  }) =>
      CatalogItem(
        id: id,
        title: title ?? this.title,
        goodsId: goodsId,
        sourceUrl: sourceUrl,
        imageUrl: imageUrl ?? this.imageUrl,
        category: category ?? this.category,
        colors: colors ?? this.colors,
        sizes: sizes ?? this.sizes,
        basePriceSar: basePriceSar ?? this.basePriceSar,
        marginSar: marginSar ?? this.marginSar,
        region: region ?? this.region,
        badge: badge ?? this.badge,
        active: active ?? this.active,
        createdAt: createdAt,
      );

  /// يستخرج goodsId من رابط SHEIN أو من كود رقمي مباشر.
  static String extractGoodsId(String input) {
    final s = input.trim();
    if (RegExp(r'^\d{6,}$').hasMatch(s)) return s;
    final patterns = <RegExp>[
      RegExp(r'-p-(\d+)\.html'),
      RegExp(r'goods_id=(\d+)'),
      RegExp(r'/p/(\d+)'),
      RegExp(r'(\d{6,})'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(s);
      if (m != null) return m.group(1)!;
    }
    return '';
  }

  static String imageFromGoodsId(String goodsId) => '';
}
