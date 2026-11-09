import '../models/app_settings.dart';
import '../models/cart.dart';
import '../models/currency.dart';

/// نتيجة تقدير السعر — تُعرض في شاشة الملخص، ويُعاد حسابها على السيرفر.
class PriceEstimate {
  final double subtotalSar;
  final double shippingFeeSar;
  final double deliveryFeeSar;

  /// التوصيل بعملة العرض كما اتُّفق (1500 شمال · 1000 جنوب).
  final double deliveryLocal;
  final double discountSar;
  final double totalSar;
  final double totalLocal;
  final AppCurrency currency;
  final double rate;
  final String couponCode;
  final String? couponError;

  const PriceEstimate({
    required this.subtotalSar,
    required this.shippingFeeSar,
    required this.deliveryFeeSar,
    required this.deliveryLocal,
    required this.discountSar,
    required this.totalSar,
    required this.totalLocal,
    required this.currency,
    required this.rate,
    this.couponCode = '',
    this.couponError,
  });

  bool get shippingIsFree => shippingFeeSar == 0;

  double localOf(num sar) => roundMoney(sar * rate, currency);

}

class PricingService {
  /// نفس معادلة السيرفر (functions/index.js › computeTotals):
  /// subtotal → شحن (مجاني فوق حد) → توصيل → خصم → إجمالي → تحويل للعملة.
  PriceEstimate estimate({
    required List<CartLine> lines,
    required AppCurrency currency,
    required AppSettings settings,
    Coupon? coupon,
  }) {
    final subtotal = lines.fold<double>(0, (s, l) => s + l.lineTotalSar);
    final shipping = subtotal >= settings.freeShippingThresholdSar ? 0.0 : settings.shippingFeeSar;

    // التوصيل يُحدَّد بالعملة المحلية (1500 شمال / 1000 جنوب) ويُحوَّل
    // للريال السعودي لحساب الإجمالي، فلا يتغيّر الرقم المعروض بكسر.
    final rate0 = settings.rateFor(currency.key);
    final deliveryLocal = settings.deliveryFeeLocalFor(currency.key);
    final delivery = roundMoney(deliveryLocal / rate0, AppCurrency.sar);

    var discount = 0.0;
    String? couponError;
    if (coupon != null) {
      final expired = coupon.expiresAt != null && coupon.expiresAt!.isBefore(DateTime.now());
      if (!coupon.active) {
        couponError = 'الكود غير مُفعّل';
      } else if (expired) {
        couponError = 'انتهت صلاحية الكود';
      } else if (subtotal < coupon.minOrderSar) {
        couponError = 'الحد الأدنى للكود ${coupon.minOrderSar.toStringAsFixed(0)} ر.س';
      } else if (coupon.isPercent) {
        discount = subtotal * (coupon.value / 100);
      } else {
        discount = coupon.value;
      }
      if (discount > subtotal) discount = subtotal;
    }

    final totalSar = roundMoney(subtotal + shipping + delivery - discount, AppCurrency.sar);
    final rate = rate0;
    final totalLocal = roundMoney(
      (subtotal + shipping - discount) * rate + deliveryLocal,
      currency,
    );

    return PriceEstimate(
      subtotalSar: subtotal,
      shippingFeeSar: shipping,
      deliveryFeeSar: delivery,
      deliveryLocal: deliveryLocal,
      discountSar: roundMoney(discount, AppCurrency.sar),
      totalSar: totalSar,
      totalLocal: totalLocal,
      currency: currency,
      rate: rate,
      couponCode: coupon?.code ?? '',
      couponError: couponError,
    );
  }
}
