import '../models/app_settings.dart';
import '../models/cart.dart';
import '../models/currency.dart';

/// نتيجة تقدير السعر — تُعرض في شاشة الملخص، وتوحّد أسعار الصرف (سعودي / دولار / شمال / جنوب).
class PriceEstimate {
  final double subtotalSar;
  final double shippingFeeSar;
  final double serviceFeeSar;
  final double deliveryFeeSar;
  final double deliveryLocal;
  final double discountSar;
  final double totalSar;
  final double totalLocal;
  final AppCurrency currency;
  final double rate;
  final CurrencyMatrix matrix;
  final String couponCode;
  final String? couponError;

  const PriceEstimate({
    required this.subtotalSar,
    required this.shippingFeeSar,
    required this.serviceFeeSar,
    required this.deliveryFeeSar,
    required this.deliveryLocal,
    required this.discountSar,
    required this.totalSar,
    required this.totalLocal,
    required this.currency,
    required this.rate,
    required this.matrix,
    this.couponCode = '',
    this.couponError,
  });

  bool get shippingIsFree => shippingFeeSar == 0;
  double localOf(num sar) => roundMoney(sar * rate, currency);
}

class PricingService {
  PriceEstimate estimate({
    required List<CartLine> lines,
    required AppCurrency currency,
    required AppSettings settings,
    Coupon? coupon,
  }) {
    final subtotal = lines.fold<double>(0, (s, l) => s + l.lineTotalSar);
    final units = lines.fold<int>(0, (s, l) => s + l.qty);

    final shipping = subtotal >= settings.freeShippingThresholdSar
        ? 0.0
        : roundMoney(units * settings.shippingPerPieceSar, AppCurrency.sar);
    final serviceFee = roundMoney(settings.serviceFeeSar, AppCurrency.sar);

    final rate0 = settings.rateFor(currency.key);
    final deliveryLocal = settings.deliveryFeeLocalFor(currency.key);
    final delivery = rate0 > 0
        ? roundMoney(deliveryLocal / rate0, AppCurrency.sar)
        : 0.0;

    var discount = 0.0;
    String? couponError;
    if (coupon != null) {
      final expired =
          coupon.expiresAt != null && coupon.expiresAt!.isBefore(DateTime.now());
      if (!coupon.active) {
        couponError = 'الكود غير مُفعّل';
      } else if (expired) {
        couponError = 'انتهت صلاحية الكود';
      } else if (subtotal < coupon.minOrderSar) {
        couponError =
            'الحد الأدنى للكود ${coupon.minOrderSar.toStringAsFixed(0)} ر.س';
      } else if (coupon.isPercent) {
        discount = subtotal * (coupon.value / 100);
      } else {
        discount = coupon.value;
      }
      if (discount > subtotal) discount = subtotal;
    }

    final baseTotalSar =
        (subtotal + shipping + serviceFee - discount).clamp(0.0, 99999999.0);
    final totalSar =
        roundMoney(baseTotalSar + delivery, AppCurrency.sar);
    final totalLocal = roundMoney(
      baseTotalSar * rate0 + deliveryLocal,
      currency,
    );

    final matrix = settings.matrixForSar(totalSar);

    return PriceEstimate(
      subtotalSar: subtotal,
      shippingFeeSar: shipping,
      serviceFeeSar: serviceFee,
      deliveryFeeSar: delivery,
      deliveryLocal: deliveryLocal,
      discountSar: roundMoney(discount, AppCurrency.sar),
      totalSar: totalSar,
      totalLocal: totalLocal,
      currency: currency,
      rate: rate0,
      matrix: matrix,
      couponCode: coupon?.code ?? '',
      couponError: couponError,
    );
  }
}
