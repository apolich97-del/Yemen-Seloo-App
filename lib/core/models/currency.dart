/// العملات المدعومة في يمن سيلو.
enum AppCurrency { sar, usd, north, south }

const double kDefaultSarPerUsd = 3.75;

extension AppCurrencyX on AppCurrency {
  String get key => switch (this) {
        AppCurrency.sar => 'sar',
        AppCurrency.usd => 'usd',
        AppCurrency.north => 'north',
        AppCurrency.south => 'south',
      };

  String get labelAr => switch (this) {
        AppCurrency.sar => 'ريال سعودي',
        AppCurrency.usd => 'دولار أمريكي',
        AppCurrency.north => 'ريال يمني (شمال)',
        AppCurrency.south => 'ريال يمني (جنوب)',
      };

  String get shortAr => switch (this) {
        AppCurrency.sar => 'ر.س',
        AppCurrency.usd => 'USD',
        AppCurrency.north => 'ريال ش',
        AppCurrency.south => 'ريال ج',
      };

  /// الريال السعودي والدولار بمنزلتين عشريتين، الريال اليمني بلا كسور.
  int get decimals => (this == AppCurrency.sar || this == AppCurrency.usd) ? 2 : 0;

  bool get isYemeni => this == AppCurrency.north || this == AppCurrency.south;

  static AppCurrency fromKey(String? key) => switch (key) {
        'usd' => AppCurrency.usd,
        'north' => AppCurrency.north,
        'south' => AppCurrency.south,
        'saudi' => AppCurrency.sar,
        _ => AppCurrency.sar,
      };
}

/// تنسيق المبالغ: "12,500 ريال" أو "1,240.00 ر.س" أو "330.67 USD"
String formatMoney(num amount, AppCurrency currency) {
  final d = currency.decimals;
  final fixed = amount.toStringAsFixed(d);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    final remaining = intPart.length - i;
    buf.write(intPart[i]);
    if (remaining > 1 && remaining % 3 == 1 && intPart[i] != '-') buf.write(',');
  }
  final s = d == 0 ? buf.toString() : '${buf.toString()}.${parts[1]}';
  return '$s ${currency.shortAr}';
}

/// تقريب آمن حسب العملة.
double roundMoney(num value, AppCurrency currency) {
  final f = currency.decimals == 0 ? 1 : 100;
  return (value * f).round() / f;
}

/// مصفوفة التحويل الرباعية (سعودي / دولار -> شمال / جنوب).
class CurrencyMatrix {
  final double sar;
  final double usd;
  final double northFromSar;
  final double northFromUsd;
  final double southFromSar;
  final double southFromUsd;
  final double rateNorth;
  final double rateSouth;
  final double usdRateNorth;
  final double usdRateSouth;

  const CurrencyMatrix({
    required this.sar,
    required this.usd,
    required this.northFromSar,
    required this.northFromUsd,
    required this.southFromSar,
    required this.southFromUsd,
    required this.rateNorth,
    required this.rateSouth,
    required this.usdRateNorth,
    required this.usdRateSouth,
  });

  factory CurrencyMatrix.fromSar({
    required double sar,
    required double rateNorth,
    required double rateSouth,
    required double usdRateNorth,
    required double usdRateSouth,
    double sarPerUsd = kDefaultSarPerUsd,
  }) {
    final safePeg = sarPerUsd > 0 ? sarPerUsd : kDefaultSarPerUsd;
    final usd = roundMoney(sar / safePeg, AppCurrency.usd);
    return CurrencyMatrix(
      sar: roundMoney(sar, AppCurrency.sar),
      usd: usd,
      northFromSar: roundMoney(sar * rateNorth, AppCurrency.north),
      northFromUsd: roundMoney(usd * usdRateNorth, AppCurrency.north),
      southFromSar: roundMoney(sar * rateSouth, AppCurrency.south),
      southFromUsd: roundMoney(usd * usdRateSouth, AppCurrency.south),
      rateNorth: rateNorth,
      rateSouth: rateSouth,
      usdRateNorth: usdRateNorth,
      usdRateSouth: usdRateSouth,
    );
  }
}
