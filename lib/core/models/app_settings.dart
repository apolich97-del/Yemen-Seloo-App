/// إعدادات الشركة — مستند واحد في Firestore: settings/app
/// تُقرأ للعرض في التطبيق، ويُعاد التحقق منها على السيرفر عند حساب الطلب.
class AppSettings {
  /// 1 ريال سعودي = rateNorth ريال يمني (شمال)
  final double rateNorth;

  /// 1 ريال سعودي = rateSouth ريال يمني (جنوب)
  final double rateSouth;

  final double shippingFeeSar;
  final double deliveryFeeSar;

  /// رسوم التوصيل بالعملة المحلية — تُعدَّل من اللوحة حسب الاتفاق.
  /// الافتراضي: 1500 ريال للشمال، 1000 ريال للجنوب، 0 للسعودي.
  final double deliveryFeeNorthLocal;
  final double deliveryFeeSouthLocal;
  final double deliveryFeeSarLocal;
  final double freeShippingThresholdSar;
  final String supportWhatsApp;
  final String supportPhone;
  final String companyNameAr;
  final bool codEnabled;

  /// رسوم الخدمة الثابتة على كل طلب (ريال سعودي).
  final double serviceFeeSar;

  /// شحن لكل قطعة تحت حد الشحن المجاني.
  final double shippingPerPieceSar;

  /// مدة التوصيل المتوقعة بالأيام — تُعدَّل من لوحة الإدارة.
  final int deliveryMinDays;
  final int deliveryMaxDays;

  const AppSettings({
    this.rateNorth = 140,
    this.rateSouth = 413,
    this.shippingFeeSar = 0,
    this.deliveryFeeSar = 10,
    this.deliveryFeeNorthLocal = 1500,
    this.deliveryFeeSouthLocal = 1000,
    this.deliveryFeeSarLocal = 0,
    this.freeShippingThresholdSar = 75,
    this.supportWhatsApp = '',
    this.supportPhone = '',
    this.companyNameAr = 'يمن سيلو',
    this.codEnabled = false,
    this.serviceFeeSar = 1.22,
    this.shippingPerPieceSar = 1,
    this.deliveryMinDays = 15,
    this.deliveryMaxDays = 20,
  });

  /// رسوم التوصيل بعملة العرض المختارة.
  double deliveryFeeLocalFor(String currencyKey) => switch (currencyKey) {
        'north' => deliveryFeeNorthLocal,
        'south' => deliveryFeeSouthLocal,
        _ => deliveryFeeSarLocal,
      };

  double rateFor(String currencyKey) => switch (currencyKey) {
        'north' => rateNorth,
        'south' => rateSouth,
        _ => 1,
      };

  AppSettings copyWith({
    double? rateNorth,
    double? rateSouth,
    double? shippingFeeSar,
    double? deliveryFeeSar,
    double? deliveryFeeNorthLocal,
    double? deliveryFeeSouthLocal,
    double? deliveryFeeSarLocal,
    double? freeShippingThresholdSar,
    String? supportWhatsApp,
    String? supportPhone,
    String? companyNameAr,
    bool? codEnabled,
  }) =>
      AppSettings(
        rateNorth: rateNorth ?? this.rateNorth,
        rateSouth: rateSouth ?? this.rateSouth,
        shippingFeeSar: shippingFeeSar ?? this.shippingFeeSar,
        deliveryFeeSar: deliveryFeeSar ?? this.deliveryFeeSar,
        deliveryFeeNorthLocal: deliveryFeeNorthLocal ?? this.deliveryFeeNorthLocal,
        deliveryFeeSouthLocal: deliveryFeeSouthLocal ?? this.deliveryFeeSouthLocal,
        deliveryFeeSarLocal: deliveryFeeSarLocal ?? this.deliveryFeeSarLocal,
        freeShippingThresholdSar:
            freeShippingThresholdSar ?? this.freeShippingThresholdSar,
        supportWhatsApp: supportWhatsApp ?? this.supportWhatsApp,
        supportPhone: supportPhone ?? this.supportPhone,
        companyNameAr: companyNameAr ?? this.companyNameAr,
        codEnabled: codEnabled ?? this.codEnabled,
      );

  factory AppSettings.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const AppSettings();
    double d(dynamic v, double def) => v is num ? v.toDouble() : def;
    return AppSettings(
      rateNorth: d(m['rateNorth'], 140),
      rateSouth: d(m['rateSouth'], 413),
      shippingFeeSar: d(m['shippingFeeSar'], 0),
      deliveryFeeSar: d(m['deliveryFeeSar'], 10),
      deliveryFeeNorthLocal: d(m['deliveryFeeNorthLocal'], 1500),
      deliveryFeeSouthLocal: d(m['deliveryFeeSouthLocal'], 1000),
      deliveryFeeSarLocal: d(m['deliveryFeeSarLocal'], 0),
      freeShippingThresholdSar: d(m['freeShippingThresholdSar'], 75),
      supportWhatsApp: (m['supportWhatsApp'] ?? '') as String,
      supportPhone: (m['supportPhone'] ?? '') as String,
      companyNameAr: (m['companyNameAr'] ?? 'يمن سيلو') as String,
      codEnabled: (m['codEnabled'] ?? false) as bool,
      serviceFeeSar: d(m['serviceFeeSar'], 1.22),
      shippingPerPieceSar: d(m['shippingPerPieceSar'], 1),
      deliveryMinDays: (m['deliveryMinDays'] as num?)?.toInt() ?? 15,
      deliveryMaxDays: (m['deliveryMaxDays'] as num?)?.toInt() ?? 20,
    );
  }

  Map<String, dynamic> toMap() => {
        'rateNorth': rateNorth,
        'rateSouth': rateSouth,
        'shippingFeeSar': shippingFeeSar,
        'deliveryFeeSar': deliveryFeeSar,
        'deliveryFeeNorthLocal': deliveryFeeNorthLocal,
        'deliveryFeeSouthLocal': deliveryFeeSouthLocal,
        'deliveryFeeSarLocal': deliveryFeeSarLocal,
        'freeShippingThresholdSar': freeShippingThresholdSar,
        'supportWhatsApp': supportWhatsApp,
        'supportPhone': supportPhone,
        'companyNameAr': companyNameAr,
        'codEnabled': codEnabled,
        'serviceFeeSar': serviceFeeSar,
        'shippingPerPieceSar': shippingPerPieceSar,
        'deliveryMinDays': deliveryMinDays,
        'deliveryMaxDays': deliveryMaxDays,
      };
}

/// كوبون خصم — يُقرأ للعرض من التطبيق ويُتحقق منه نهائياً على السيرفر.
class Coupon {
  final String code;
  final String type; // 'percent' | 'fixedSar'
  final double value;
  final double minOrderSar;
  final bool active;
  final DateTime? expiresAt;

  const Coupon({
    required this.code,
    required this.type,
    required this.value,
    this.minOrderSar = 0,
    this.active = true,
    this.expiresAt,
  });

  bool get isPercent => type == 'percent';

  factory Coupon.fromMap(String code, Map<String, dynamic> m) => Coupon(
        code: code,
        type: (m['type'] ?? 'percent') as String,
        value: ((m['value'] ?? 0) as num).toDouble(),
        minOrderSar: ((m['minOrderSar'] ?? 0) as num).toDouble(),
        active: (m['active'] ?? true) as bool,
        expiresAt: m['expiresAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                (m['expiresAt'] as dynamic).millisecondsSinceEpoch as int),
      );

  String get descriptionAr => isPercent
      ? 'خصم ${value.toStringAsFixed(0)}%'
      : 'خصم ${value.toStringAsFixed(2)} ر.س';
}
