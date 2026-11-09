import '../models/currency.dart';

/// حساب دفع يدوي (حوالة) يظهر للعميل حسب عملة الطلب.
class PaymentAccount {
  final String id;
  final String bankAr;
  final String titleAr;
  final List<String> numbers;
  final Set<AppCurrency> currencies;
  final String noteAr;

  const PaymentAccount({
    required this.id,
    required this.bankAr,
    required this.titleAr,
    required this.numbers,
    required this.currencies,
    this.noteAr = 'حوّل المبلغ ثم أدخل بيانات الحوالة.',
  });

  String get primaryNumber => numbers.first;
  bool supports(AppCurrency c) => currencies.contains(c);
}

/// الأرقام كما وردت في وثيقة المتطلبات — لا تُضاف أرقام غير مذكورة.
/// ملاحظة: القطيبي له رقم واحد فقط (480642452) ويُستخدم للعملات الثلاث.
const List<PaymentAccount> kPaymentAccounts = [
  PaymentAccount(
    id: 'kuraimi_yemeni',
    bankAr: 'بنك الكريمي',
    titleAr: 'الكريمي — حساب يمني',
    numbers: ['3141952047', '3055509637'],
    currencies: {AppCurrency.north, AppCurrency.south},
  ),
  PaymentAccount(
    id: 'kuraimi_saudi',
    bankAr: 'بنك الكريمي',
    titleAr: 'الكريمي — حساب سعودي',
    numbers: ['3168803857', '3116991917'],
    currencies: {AppCurrency.sar},
  ),
  PaymentAccount(
    id: 'qatibi',
    bankAr: 'القطيبي',
    titleAr: 'القطيبي',
    numbers: ['480642452'],
    currencies: {AppCurrency.sar, AppCurrency.north, AppCurrency.south},
    noteAr: 'حساب واحد يستقبل العملات الثلاث — أدخل المبلغ بعملة الطلب.',
  ),
  PaymentAccount(
    id: 'shilling',
    bankAr: 'شلن',
    titleAr: 'شلن',
    numbers: ['600589797', '775801198'],
    currencies: {AppCurrency.north, AppCurrency.south},
  ),
  PaymentAccount(
    id: 'jaib',
    bankAr: 'جيب',
    titleAr: 'جيب',
    numbers: ['2291789', '775801198'],
    currencies: {AppCurrency.north, AppCurrency.south},
  ),
];

/// ترتيب الظهور محفوظ كما في الطلب: كريمي ‹ قطيبي ‹ شلن ‹ جيب.
List<PaymentAccount> accountsForCurrency(AppCurrency currency) =>
    kPaymentAccounts.where((a) => a.supports(currency)).toList(growable: false);

PaymentAccount? accountById(String? id) {
  for (final a in kPaymentAccounts) {
    if (a.id == id) return a;
  }
  return null;
}

/// للتحقق على السيرفر (functions/index.js يملك نفس القائمة).
const Map<String, List<String>> kAllowedAccountIdsByCurrency = {
  'sar': ['kuraimi_saudi', 'qatibi'],
  'north': ['kuraimi_yemeni', 'qatibi', 'shilling', 'jaib'],
  'south': ['kuraimi_yemeni', 'qatibi', 'shilling', 'jaib'],
};
