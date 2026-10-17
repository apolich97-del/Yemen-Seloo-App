/// كل الثوابت والنطاقات والنصوص في مكان واحد.
abstract final class SelooConfig {
  // -------- الهوية --------
  static const String appName = 'يمن سيلو';
  static const String appNameEn = 'Yemen Seloo';
  static const String brandHost = 'yemenseloo.com';
  static const String tagline = 'وسيطك الموثوق للتسوق العالمي';

  // -------- التواصل --------
  static const String supportPhone = '770518757';
  static const String alternatePhone = '737383637';
  static const String supportEmail = 'yemenseloo.shop@gmail.com';

  // -------- الألوان --------
  static const int primaryColorHex = 0xFF7C3AED;
  static const int scaffoldBgHex = 0xFFFAF7FF;
  static const int accentColorHex = 0xFFA855F7;

  // -------- Firebase --------
  static const String functionsRegion = 'europe-west1';

  // -------- مجموعات Firestore --------
  static const String usersCollection = 'users';
  static const String cartCollection = 'cart';
  static const String ordersCollection = 'orders';
  static const String profileCollection = 'profile';
  static const String metaCollection = 'meta';

  // -------- حدود المنطق --------
  static const int maxQuantityPerLine = 50;
  static const int maxLinesPerCart = 40;
  static const int maxPayloadBytes = 20000;

  // -------- مصدر المنتجات --------
  static const String sourceStoreShein = 'SHEIN';

  // -------- سياسة العميل --------
  static const String priceDisclaimer =
      'سعر SHEIN هو سعر المصدر وقت الإضافة، وليس بالضرورة السعر النهائي. '
      'سيُحدَّد السعر النهائي من يمن سيلو بعد مراجعة الطلب.';
  static const String shippingEstimate =
      'مدة الوصول المتوقعة: 15–20 يومًا تقريبًا حسب ظروف الشحن والرحلات.';
  static const String paymentNote =
      'يتم الدفع قبل تنفيذ الطلب. إضافة المنتج إلى السلة لا تعني حجزه أو تثبيت سعره.';
  static const String damagePolicy =
      'في حال وصول منتج تالف أو مختلف عن المطلوب، '
      'يتواصل العميل مع خدمة العملاء لمراجعة الحالة.';
}

/// ثوابت التسعير والشحن والعملات.
abstract final class SelooPricing {
  static const String defaultCurrency = 'SAR';

  static const double northRate = 140.0;
  static const double southRate = 413.0;
  static const double saudiRate = 1.0;

  static const double freeShippingThresholdSar = 75.0;
  static const double shippingPerPieceSar = 1.0;
  static const double serviceFeeSar = 1.22;

  static const String defaultRegion = 'north';
  static const String regionNorth = 'north';
  static const String regionSouth = 'south';
  static const String regionSaudi = 'saudi';
}

/// إعدادات الجانب الخاص بـSHEIN.
abstract final class SheinWebConfig {
  static const String scheme = 'https';
  static const String host = 'm.shein.com'; // ⭐ تم التصحيح

  // ⭐ النطاقات العربية العامة (sa.shein.com للغة الإنجليزية)
  static const String homeAr = 'https://m.shein.com/ar/';
  static const String categoryAr = 'https://m.shein.com/ar/category/';

  static const List<String> allowedHosts = <String>[
    'm.shein.com',
    'www.shein.com',
    'shein.com',
    'ar.shein.com',
    'sa.shein.com',
  ];

  static const List<String> externalHosts = <String>[
    'paypal.com',
    'checkout.stripe.com',
    'sheinpay.com',
  ];

  static const List<String> loginHosts = <String>[
    'accounts.google.com',
    'appleid.apple.com',
  ];

  static const String bridgeName = 'selooBridge';
  static const String scriptAssetPath = 'assets/js/seloo_shein_overlay.js';

  static final RegExp productUrlPattern = RegExp(r'/-p-(\d{5,})\.html');
  static const Duration pageSettleDelay = Duration(milliseconds: 600);
}

/// أسماء الدوال السحابية.
abstract final class SelooFunctions {
  static const String addToCart = 'addToCart';
  static const String updateCartLine = 'updateCartLine';
  static const String removeCartLine = 'removeCartLine';
  static const String clearCart = 'clearCart';
  static const String quoteCart = 'quoteCart';
  static const String submitOrder = 'submitOrder';
  static const String advanceOrderStatus = 'advanceOrderStatus';
}

/// حالات الطلب.
abstract final class SelooOrderStatus {
  static const String unpaid = 'unpaid';
  static const String paid = 'paid';
  static const String purchasing = 'purchasing';
  static const String purchased = 'purchased';
  static const String shipped = 'shipped';
  static const String delivered = 'delivered';
  static const String cancelled = 'cancelled';
}
