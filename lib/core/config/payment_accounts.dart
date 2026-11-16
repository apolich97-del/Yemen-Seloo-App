import 'package:flutter/material.dart';

import '../models/currency.dart';

/// حساب دفع يدوي (حوالة) يظهر للعميل حسب عملة الطلب.
class PaymentAccount {
  final String id;
  final String bankAr;
  final String titleAr;
  final List<String> numbers;
  final Set<AppCurrency> currencies;
  final String noteAr;

  /// لون هوية الجهة، يميّز البطاقة بصرياً.
  final Color brandColor;

  /// شارة الجهة داخل البطاقة (كريمي · قطيبي · شلن · جيب).
  final String brandShortAr;

  /// الجهة التي يخدمها الحساب: «شمال» أو «جنوب» أو «شمال وجنوب».
  final String regionAr;

  /// مسار شعار الجهة داخل assets (فارغ = شارة نصية بلون الجهة).
  final String logoAsset;

  const PaymentAccount({
    required this.id,
    required this.bankAr,
    required this.titleAr,
    required this.numbers,
    required this.currencies,
    required this.brandColor,
    required this.brandShortAr,
    this.regionAr = 'شمال وجنوب',
    this.logoAsset = '',
    this.noteAr = 'حوّل المبلغ ثم أدخل بيانات الحوالة.',
  });

  String get primaryNumber => numbers.first;
  bool supports(AppCurrency c) => currencies.contains(c);
}

const Color _kuraimi = Color(0xFF1565C0);
const Color _qatibi = Color(0xFF2E7D32);
const Color _shilling = Color(0xFF00897B);
const Color _jaib = Color(0xFF6A1B9A);

/// سعر صرف الدولار المعتمد للتحويل اليدوي (يحدّثه المالك عند تغيّر السوق).
const String _usdRateNorth = '533';
const String _usdRateSouth = '1570';

/// سعر الدولار يُقرأ من settings/app في الشاشة؛ هذه نسخة احتياطية فقط.
const String _usdNote =
    'حوّل ما يعادل إجمالي الطلب بالدولار ثم أدخل المبلغ المرسل.';

/// القائمة المعتمدة (الاسم: عبدالله عبدالعالم عبدالله) — محدثة 2026-11-15.
const List<PaymentAccount> kPaymentAccounts = [
  // ── بنك الكريمي ──
  PaymentAccount(
    id: 'kuraimi_yer_old',
    bankAr: 'بنك الكريمي',
    titleAr: 'الكريمي — يمني قديم',
    numbers: ['3141952047'],
    currencies: {AppCurrency.north},
    brandColor: _kuraimi,
    regionAr: 'شمال',
    brandShortAr: 'كريمي',
    logoAsset: 'assets/images/payments/kuraimi.jpg',
  ),
  PaymentAccount(
    id: 'kuraimi_yer_new',
    bankAr: 'بنك الكريمي',
    titleAr: 'الكريمي — يمني جديد',
    numbers: ['3055509637'],
    currencies: {AppCurrency.south},
    brandColor: _kuraimi,
    regionAr: 'جنوب',
    brandShortAr: 'كريمي',
    logoAsset: 'assets/images/payments/kuraimi.jpg',
  ),
  PaymentAccount(
    id: 'kuraimi_sar_old',
    bankAr: 'بنك الكريمي',
    titleAr: 'الكريمي — سعودي قديم',
    numbers: ['3168803857'],
    currencies: {AppCurrency.sar},
    brandColor: _kuraimi,
    brandShortAr: 'كريمي',
    logoAsset: 'assets/images/payments/kuraimi.jpg',
    regionAr: 'شمال',
  ),
  PaymentAccount(
    id: 'kuraimi_sar_south',
    bankAr: 'بنك الكريمي',
    titleAr: 'الكريمي — سعودي (حساب الجنوب)',
    numbers: ['3116991917'],
    currencies: {AppCurrency.sar, AppCurrency.south},
    brandColor: _kuraimi,
    brandShortAr: 'كريمي',
    logoAsset: 'assets/images/payments/kuraimi.jpg',
    regionAr: 'جنوب',
  ),
  PaymentAccount(
    id: 'kuraimi_usd_old',
    bankAr: 'بنك الكريمي',
    titleAr: 'الكريمي — دولار قديم',
    numbers: ['3207365296'],
    currencies: {AppCurrency.sar, AppCurrency.north},
    brandColor: _kuraimi,
    regionAr: 'شمال',
    brandShortAr: 'كريمي',
    logoAsset: 'assets/images/payments/kuraimi.jpg',
    noteAr: _usdNote,
  ),
  PaymentAccount(
    id: 'kuraimi_usd_new',
    bankAr: 'بنك الكريمي',
    titleAr: 'الكريمي — دولار جديد',
    numbers: ['3124522861'],
    currencies: {AppCurrency.sar, AppCurrency.south},
    brandColor: _kuraimi,
    regionAr: 'جنوب',
    brandShortAr: 'كريمي',
    logoAsset: 'assets/images/payments/kuraimi.jpg',
    noteAr: _usdNote,
  ),

  // ── القطيبي ──
  PaymentAccount(
    id: 'qatibi',
    bankAr: 'القطيبي',
    titleAr: 'القطيبي — يمني / سعودي / دولار',
    numbers: ['480642452'],
    currencies: {AppCurrency.sar, AppCurrency.south},
    brandColor: _qatibi,
    regionAr: 'جنوب',
    brandShortAr: 'قطيبي',
    logoAsset: 'assets/images/payments/qatibi.png',
    noteAr: 'حساب واحد يستقبل العملات الثلاث — أدخل المبلغ بعملة الطلب.',
  ),

  // ── محفظة شلن ──
  PaymentAccount(
    id: 'shilling',
    bankAr: 'محفظة شلن',
    titleAr: 'شلن — يمني',
    numbers: ['600589797', '775801198'],
    currencies: {AppCurrency.south},
    brandColor: _shilling,
    regionAr: 'جنوب',
    brandShortAr: 'شلن',
    logoAsset: 'assets/images/payments/shilling.png',
  ),

  // ── محفظة جيب ──
  PaymentAccount(
    id: 'jaib',
    bankAr: 'محفظة جيب',
    titleAr: 'جيب — يمني',
    numbers: ['2291789', '775801198'],
    currencies: {AppCurrency.north},
    brandColor: _jaib,
    regionAr: 'شمال',
    brandShortAr: 'جيب',
    logoAsset: 'assets/images/payments/jaib.jpg',
    noteAr: 'أرسل إلى محفظة الرقم الأول، أو «تحويل إلى مشترك جيب» على الرقم الثاني.',
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
  'sar': ['kuraimi_sar_old', 'kuraimi_sar_south', 'kuraimi_usd_old', 'kuraimi_usd_new', 'qatibi'],
  'north': ['kuraimi_yer_old', 'kuraimi_sar_old', 'kuraimi_usd_old', 'jaib'],
  'south': ['kuraimi_yer_new', 'kuraimi_sar_south', 'kuraimi_usd_new', 'qatibi', 'shilling'],
};
