import 'currency.dart';

/// إعدادات الشركة — مستند واحد في Firestore: settings/app
class AppSettings {
  /// 1 ريال سعودي = rateNorth ريال يمني (شمال)
  final double rateNorth;

  /// 1 ريال سعودي = rateSouth ريال يمني (جنوب)
  final double rateSouth;
  final double shippingFeeSar;
  final double deliveryFeeSar;

  /// رسوم التوصيل المعتمدة بالعملة المحلية (تُدار من لوحة الإدارة).
  final double deliveryFeeNorthLocal;
  final double deliveryFeeSouthLocal;
  final double deliveryFeeSarLocal;
  final double freeShippingThresholdSar;
  final String supportWhatsApp;
  final String alternateWhatsApp;
  final String supportPhone;
  final String companyNameAr;
  final bool codEnabled;

  /// رسوم الخدمة الثابتة على كل طلب (ريال سعودي).
  final double serviceFeeSar;

  /// شحن لكل قطعة تحت حد الشحن المجاني.
  final double shippingPerPieceSar;

  /// نظام الطلبات الآجلة (الدفع بالنصف).
  final bool deferredEnabled;
  final double deferredThresholdSar;
  final double deferredUpfrontPercent;

  /// 1 دولار أمريكي = usdRateNorth ريال يمني (شمال) / usdRateSouth (جنوب).
  final double usdRateNorth;
  final double usdRateSouth;

  /// معامل التحويل القياسي من الدولار إلى السعودي (افتراضي 3.75).
  final double sarPerUsd;

  /// مدة التوصيل المتوقعة بالأيام — تُعدَّل من لوحة الإدارة.
  final int deliveryMinDays;
  final int deliveryMaxDays;

  /// اسم المُرسِل المعتمد على بوليصة شحن المحافظات.
  final String senderName;

  /// رقم الشركة الافتراضي الظاهر على بوليصة شحن المحافظات.
  final String waybillCompanyPhone;

  const AppSettings({
    this.rateNorth = 140,
    this.rateSouth = 413,
    this.shippingFeeSar = 0,
    this.deliveryFeeSar = 10,
    this.deliveryFeeNorthLocal = 1500,
    this.deliveryFeeSouthLocal = 1000,
    this.deliveryFeeSarLocal = 0,
    this.freeShippingThresholdSar = 75,
    this.supportWhatsApp = '967770518757',
    this.alternateWhatsApp = '967737383637',
    this.supportPhone = '770518757',
    this.companyNameAr = 'يمن سيلو',
    this.codEnabled = false,
    this.serviceFeeSar = 1.22,
    this.shippingPerPieceSar = 1,
    this.deferredEnabled = true,
    this.deferredThresholdSar = 150,
    this.deferredUpfrontPercent = 50,
    this.usdRateNorth = 533,
    this.usdRateSouth = 1570,
    this.sarPerUsd = kDefaultSarPerUsd,
    this.deliveryMinDays = 15,
    this.deliveryMaxDays = 20,
    this.senderName = 'يمن سيلو',
    this.waybillCompanyPhone = '770518757',
  });

  /// رسوم التوصيل بعملة العرض المختارة.
  double deliveryFeeLocalFor(String currencyKey) => switch (currencyKey) {
        'north' => deliveryFeeNorthLocal,
        'south' => deliveryFeeSouthLocal,
        'usd' => deliveryFeeSarLocal / (sarPerUsd > 0 ? sarPerUsd : kDefaultSarPerUsd),
        _ => deliveryFeeSarLocal,
      };

  double rateFor(String currencyKey) => switch (currencyKey) {
        'north' => rateNorth,
        'south' => rateSouth,
        'usd' => 1.0 / (sarPerUsd > 0 ? sarPerUsd : kDefaultSarPerUsd),
        _ => 1,
      };

  CurrencyMatrix matrixForSar(double sarAmount) => CurrencyMatrix.fromSar(
        sar: sarAmount,
        rateNorth: rateNorth,
        rateSouth: rateSouth,
        usdRateNorth: usdRateNorth,
        usdRateSouth: usdRateSouth,
        sarPerUsd: sarPerUsd,
      );

  AppSettings copyWith({
    double? rateNorth,
    bool? deferredEnabled,
    double? deferredThresholdSar,
    double? deferredUpfrontPercent,
    double? usdRateNorth,
    double? usdRateSouth,
    double? sarPerUsd,
    double? rateSouth,
    double? shippingFeeSar,
    double? deliveryFeeSar,
    double? deliveryFeeNorthLocal,
    double? deliveryFeeSouthLocal,
    double? deliveryFeeSarLocal,
    double? freeShippingThresholdSar,
    String? supportWhatsApp,
    String? alternateWhatsApp,
    String? supportPhone,
    String? companyNameAr,
    bool? codEnabled,
    String? senderName,
    String? waybillCompanyPhone,
    double? serviceFeeSar,
    double? shippingPerPieceSar,
    int? deliveryMinDays,
    int? deliveryMaxDays,
  }) =>
      AppSettings(
        rateNorth: rateNorth ?? this.rateNorth,
        deferredEnabled: deferredEnabled ?? this.deferredEnabled,
        deferredThresholdSar:
            deferredThresholdSar ?? this.deferredThresholdSar,
        deferredUpfrontPercent:
            deferredUpfrontPercent ?? this.deferredUpfrontPercent,
        usdRateNorth: usdRateNorth ?? this.usdRateNorth,
        usdRateSouth: usdRateSouth ?? this.usdRateSouth,
        sarPerUsd: sarPerUsd ?? this.sarPerUsd,
        rateSouth: rateSouth ?? this.rateSouth,
        shippingFeeSar: shippingFeeSar ?? this.shippingFeeSar,
        deliveryFeeSar: deliveryFeeSar ?? this.deliveryFeeSar,
        deliveryFeeNorthLocal: deliveryFeeNorthLocal ?? this.deliveryFeeNorthLocal,
        deliveryFeeSouthLocal: deliveryFeeSouthLocal ?? this.deliveryFeeSouthLocal,
        deliveryFeeSarLocal: deliveryFeeSarLocal ?? this.deliveryFeeSarLocal,
        freeShippingThresholdSar:
            freeShippingThresholdSar ?? this.freeShippingThresholdSar,
        supportWhatsApp: supportWhatsApp ?? this.supportWhatsApp,
        alternateWhatsApp: alternateWhatsApp ?? this.alternateWhatsApp,
        supportPhone: supportPhone ?? this.supportPhone,
        companyNameAr: companyNameAr ?? this.companyNameAr,
        senderName: senderName ?? this.senderName,
        waybillCompanyPhone:
            waybillCompanyPhone ?? this.waybillCompanyPhone,
        codEnabled: codEnabled ?? this.codEnabled,
        serviceFeeSar: serviceFeeSar ?? this.serviceFeeSar,
        shippingPerPieceSar: shippingPerPieceSar ?? this.shippingPerPieceSar,
        deliveryMinDays: deliveryMinDays ?? this.deliveryMinDays,
        deliveryMaxDays: deliveryMaxDays ?? this.deliveryMaxDays,
      );

  factory AppSettings.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const AppSettings();
    double d(dynamic v, double def) => v is num ? v.toDouble() : def;
    return AppSettings(
      rateNorth: d(m['rateNorth'], 140),
      deferredEnabled: (m['deferredEnabled'] as bool?) ?? true,
      deferredThresholdSar: d(m['deferredThresholdSar'], 150),
      deferredUpfrontPercent: d(m['deferredUpfrontPercent'], 50),
      usdRateNorth: d(m['usdRateNorth'], 533),
      usdRateSouth: d(m['usdRateSouth'], 1570),
      sarPerUsd: d(m['sarPerUsd'], kDefaultSarPerUsd),
      rateSouth: d(m['rateSouth'], 413),
      shippingFeeSar: d(m['shippingFeeSar'], 0),
      deliveryFeeSar: d(m['deliveryFeeSar'], 10),
      deliveryFeeNorthLocal: d(m['deliveryFeeNorthLocal'], 1500),
      deliveryFeeSouthLocal: d(m['deliveryFeeSouthLocal'], 1000),
      deliveryFeeSarLocal: d(m['deliveryFeeSarLocal'], 0),
      freeShippingThresholdSar: d(m['freeShippingThresholdSar'], 75),
      supportWhatsApp: ((m['supportWhatsApp'] ?? '') as String).trim().isNotEmpty
          ? (m['supportWhatsApp'] as String).trim()
          : '967770518757',
      alternateWhatsApp: ((m['alternateWhatsApp'] ?? '') as String).trim().isNotEmpty
          ? (m['alternateWhatsApp'] as String).trim()
          : '967737383637',
      supportPhone: ((m['supportPhone'] ?? '') as String).trim().isNotEmpty
          ? (m['supportPhone'] as String).trim()
          : '770518757',
      companyNameAr: (m['companyNameAr'] ?? 'يمن سيلو') as String,
      codEnabled: (m['codEnabled'] ?? false) as bool,
      serviceFeeSar: d(m['serviceFeeSar'], 1.22),
      shippingPerPieceSar: d(m['shippingPerPieceSar'], 1),
      deliveryMinDays: (m['deliveryMinDays'] as num?)?.toInt() ?? 15,
      deliveryMaxDays: (m['deliveryMaxDays'] as num?)?.toInt() ?? 20,
      senderName: (m['senderName'] ?? 'يمن سيلو') as String,
      waybillCompanyPhone: ((m['waybillCompanyPhone'] ?? '') as String).trim().isNotEmpty
          ? (m['waybillCompanyPhone'] as String).trim()
          : '770518757',
    );
  }

  Map<String, dynamic> toMap() => {
        'rateNorth': rateNorth,
        'rateSouth': rateSouth,
        'deferredEnabled': deferredEnabled,
        'deferredThresholdSar': deferredThresholdSar,
        'deferredUpfrontPercent': deferredUpfrontPercent,
        'usdRateNorth': usdRateNorth,
        'usdRateSouth': usdRateSouth,
        'sarPerUsd': sarPerUsd,
        'shippingFeeSar': shippingFeeSar,
        'deliveryFeeSar': deliveryFeeSar,
        'deliveryFeeNorthLocal': deliveryFeeNorthLocal,
        'deliveryFeeSouthLocal': deliveryFeeSouthLocal,
        'deliveryFeeSarLocal': deliveryFeeSarLocal,
        'freeShippingThresholdSar': freeShippingThresholdSar,
        'supportWhatsApp': supportWhatsApp,
        'alternateWhatsApp': alternateWhatsApp,
        'supportPhone': supportPhone,
        'companyNameAr': companyNameAr,
        'codEnabled': codEnabled,
        'serviceFeeSar': serviceFeeSar,
        'shippingPerPieceSar': shippingPerPieceSar,
        'deliveryMinDays': deliveryMinDays,
        'deliveryMaxDays': deliveryMaxDays,
        'senderName': senderName,
        'waybillCompanyPhone': waybillCompanyPhone,
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
