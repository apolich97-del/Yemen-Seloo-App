/// عملات التطبيق — متوافقة مع CartCounter الحالي (3 عملات).
///
/// قاعدة الحساب في السيرفر (Cloud Functions) هي الريال السعودي [sar]،
/// وتُحوَّل بقية العملات عبر أسعار الصرف القابلة للتعديل من لوحة الإدارة.
enum AppCurrency { sar, north, south }

extension AppCurrencyX on AppCurrency {
  String get key => switch (this) {
        AppCurrency.sar => 'sar',
        AppCurrency.north => 'north',
        AppCurrency.south => 'south',
      };

  String get labelAr => switch (this) {
        AppCurrency.sar => 'ريال سعودي',
        AppCurrency.north => 'ريال يمني (شمال)',
        AppCurrency.south => 'ريال يمني (جنوب)',
      };

  String get shortAr => switch (this) {
        AppCurrency.sar => 'ر.س',
        AppCurrency.north => 'ريال',
        AppCurrency.south => 'ريال',
      };

  /// الريال السعودي بمنزلتين عشريتين، الرياليْن اليمنيين بلا كسور.
  int get decimals => this == AppCurrency.sar ? 2 : 0;

  bool get isYemeni => this != AppCurrency.sar;

  static AppCurrency fromKey(String? key) => switch (key) {
        'north' => AppCurrency.north,
        'south' => AppCurrency.south,
        _ => AppCurrency.sar,
      };
}

/// تنسيق المبالغ: "12,500 ريال" أو "1,240.00 ر.س"
String formatMoney(num amount, AppCurrency currency) {
  final d = currency.decimals;
  final fixed = amount.toStringAsFixed(d);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    final remaining = intPart.length - i;
    buf.write(intPart[i]);
    if (remaining > 1 && remaining % 3 == 1) buf.write(',');
  }
  final s = d == 0 ? buf.toString() : '${buf.toString()}.${parts[1]}';
  return '$s ${currency.shortAr}';
}

/// تقريب آمن حسب العملة (يمنع فروق الكسور بين التطبيق والسيرفر).
num roundMoney(num value, AppCurrency currency) {
  final f = currency.decimals == 0 ? 1 : 100;
  return (value * f).round() / f;
}
