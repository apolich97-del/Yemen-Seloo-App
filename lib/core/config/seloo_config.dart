/// كل الثوابت والنطاقات والنصوص في مكان واحد.
///
/// لماذا هذا الملف؟ لأن القيم الحرفية المنتشرة في الكود (النطاقات المسموحة،
/// أسماء الجسر، مسارات الأصول) هي أول ما يتغيّر عند تحديث واجهة SHEIN أو عند
/// نقل المشروع لبيئة أخرى (emulator/إنتاج).
abstract final class SelooConfig {
  // -------- الهوية --------
  static const String appName = 'يمن سيلو';
  static const String appNameEn = 'Yemen Seloo';
  static const String brandHost = 'yemenseloo.com';
  static const String tagline = 'وسيطك الموثوق للتسوق العالمي';

  // -------- التواصل --------
  /// رقم خدمة العملاء / واتساب.
  static const String supportPhone = '770518757';
  static const String alternatePhone = '737383637';
  static const String supportEmail = 'yemenseloo.shop@gmail.com';

  // -------- الألوان (هوية بنفسجية) --------
  static const int primaryColorHex = 0xFF7C3AED;
  static const int scaffoldBgHex = 0xFFFAF7FF;
  static const int accentColorHex = 0xFFA855F7;

  // -------- Firebase --------
  /// منطقة واحدة للدوال كي لا يتوزّع زمن الاستجابة.
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

  /// أقصى حجم لحمولة الجسر (بايت) قبل أن تُرفض بلا تحليل.
  static const int maxPayloadBytes = 20000;

  // -------- سياسة العميل --------
  static const String priceDisclaimer =
      'الأسعار الظاهرة قد تتغير حتى تأكيد الطلب. السعر النهائي المعتمد هو السعر وقت تنفيذ الشراء.';
  static const String shippingEstimate =
      'مدة الوصول المتوقعة: 20–25 يومًا تقريبًا حسب ظروف الشحن والرحلات.';
  static const String paymentNote =
      'يتم الدفع قبل تنفيذ الطلب. إضافة المنتج إلى السلة لا تعني حجزه أو تثبيت سعره.';
  static const String damagePolicy =
      'في حال وصول منتج تالف أو مختلف عن المطلوب، يتواصل العميل مع خدمة العملاء لمراجعة الحالة.';
}

/// إعدادات الجانب الخاص بـSHEIN: أين نتصفّح، وكيف نتواصل مع الصفحة.
abstract final class SheinWebConfig {
  static const String scheme = 'https';
  static const String host = 'm.shein.com';

  /// صفحات البداية المسموح بها (عربية أولًا لأن الأسعار بالريال/الدولار واضحة).
  static const String homeAr = 'https://m.shein.com/ar/';
  static const String categoryAr = 'https://m.shein.com/ar/category/';

  /// كل نطاق يوافق هذا الشرط يُحمَّل داخل التطبيق.
  static const List<String> allowedHosts = <String>[
    'm.shein.com',
    'www.shein.com',
    'shein.com',
    'ar.shein.com',
  ];

  /// نطاقات الدفع/الدعم: تُفتح خارجيًا ولا ندخلها في الـWebView إطلاقًا.
  static const List<String> externalHosts = <String>[
    'paypal.com',
    'checkout.stripe.com',
    'sheinpay.com',
  ];

  /// اسم الجسر كما يُستخدم في JS.
  static const String bridgeName = 'selooBridge';

  /// مسار السكربت المحقون داخل الـWebView.
  static const String scriptAssetPath = 'assets/js/seloo_shein_overlay.js';

  /// نمط رابط صفحة المنتج في SHEIN: .../-p-12345678.html
  static final RegExp productUrlPattern = RegExp(r'/-p-(\d{5,})\.html');

  /// حدّ ثابت لفاصل الانتظار قبل قراءة الصفحة.
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
