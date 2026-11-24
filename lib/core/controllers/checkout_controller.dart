import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../models/app_settings.dart';
import '../models/cart.dart';
import '../models/currency.dart';
import '../models/order.dart';
import '../routes/app_routes.dart';
import '../../features/orders/order_confirmed_screen.dart';
import '../services/auth_service.dart';
import '../services/customer_accounting_service.dart';
import '../services/order_documents.dart';
import '../services/order_service.dart';
import '../../features/cart/application/cart_counter.dart';
import '../services/pricing_service.dart';
import '../services/settings_service.dart';
import '../services/wallet_service.dart';

/// الحمولة المنقولة من شاشة الملخص إلى شاشة الدفع.
class CheckoutPayload {
  final List<CartLine> lines;
  final AppCurrency currency;
  final Address address;
  final PriceEstimate estimate;

  /// 'full' أو 'half_deferred'.
  final String paymentPlan;
  final double upfrontPercent;
  final double walletUseSar;

  /// تفاصيل التوصيل المختارة.
  final Map<String, dynamic> shipping;

  const CheckoutPayload({
    required this.lines,
    required this.currency,
    required this.address,
    required this.estimate,
    this.paymentPlan = 'full',
    this.upfrontPercent = 100,
    this.walletUseSar = 0,
    this.shipping = const <String, dynamic>{},
  });
}

class CheckoutController extends GetxController {
  /// الخطة المختارة: كاش أو آجل 50%.
  final paymentPlan = 'full'.obs;
  final _cart = Get.find<CartRepository>();
  final _settings = Get.find<SettingsService>();
  final _pricing = Get.find<PricingService>();
  final _orders = Get.find<OrderService>();
  final _auth = Get.find<AuthService>();
  final _store = GetStorage();
  final _db = FirebaseFirestore.instance;

  static const _currencyKey = 'display_currency';

  final lines = <CartLine>[].obs;
  final currency = AppCurrency.sar.obs;
  final address = Rxn<Address>();
  final estimate = Rxn<PriceEstimate>();
  final coupon = Rxn<Coupon>();
  final couponMessage = ''.obs;
  final couponAccepted = false.obs;
  final busy = false.obs;
  /// الخصم من رصيد المحفظة (0 = بلا خصم).
  final walletUseSar = 0.0.obs;
  final loadingAddress = true.obs;
  final activeDeferredRemainingSar = 0.0.obs;

  final couponCtrl = TextEditingController();

  /// تفاصيل التوصيل: home | governorate | driver
  final shippingMode = 'home'.obs;
  final shippingGovernorate = ''.obs;
  final shippingOffice = ''.obs;
  final shippingOfficeChoice = 'seloo'.obs;
  final receiverNameCtrl = TextEditingController();
  final receiverPhoneCtrl = TextEditingController();
  final driverNameCtrl = TextEditingController();
  final driverPhoneCtrl = TextEditingController();
  final meetPointCtrl = TextEditingController();

  Map<String, dynamic> get shippingMap => <String, dynamic>{
        'mode': shippingMode.value,
        'governorate': shippingGovernorate.value.trim(),
        'office': shippingOffice.value.trim(),
        'officeChoice': shippingOfficeChoice.value,
        'receiverName': receiverNameCtrl.text.trim(),
        'receiverPhone': receiverPhoneCtrl.text.trim(),
        'driverName': driverNameCtrl.text.trim(),
        'driverPhone': driverPhoneCtrl.text.trim(),
        'meetPoint': meetPointCtrl.text.trim(),
      };

  @override
  void onInit() {
    super.onInit();
    final all = _cart.read();
    // إن حدد العميل قطعاً في السلة تُحسب الفاتورة على المحدد فقط.
    Set<String> sel = const <String>{};
    if (Get.isRegistered<CartCounter>()) {
      sel = Get.find<CartCounter>().selectedVariantKeys;
    }
    lines.assignAll(
        sel.isEmpty ? all : all.where((l) => sel.contains(l.variantKey)).toList());
    currency.value = AppCurrencyX.fromKey(_store.read<String>(_currencyKey));
    _settings.displayCurrency.value = currency.value;
    _loadAddress();
    _loadCustomerDeferredUsage();
    recompute();
  }

  @override
  void onClose() {
    couponCtrl.dispose();
    super.onClose();
  }

  int get pieces => lines.fold(0, (s, l) => s + l.qty);
  List<String> get thumbnails =>
      lines.map((l) => l.imageUrl).where((e) => e.isNotEmpty).take(4).toList();

  String get expectedDeliveryAr {
    final now = DateTime.now();
    final AppSettings st = _settings.settings.value;
    final int minDays = st.deliveryMinDays > 0 ? st.deliveryMinDays : 15;
    final int maxDays = st.deliveryMaxDays >= minDays ? st.deliveryMaxDays : minDays;
    String d(DateTime x) => '${x.day}/${x.month}';
    final DateTime from = now.add(Duration(days: minDays));
    final DateTime to = now.add(Duration(days: maxDays));
    return 'من $minDays إلى $maxDays يوماً (${d(from)} – ${d(to)})';
  }

  void setCurrency(AppCurrency c) {
    if (currency.value == c) return;
    currency.value = c;
    _settings.displayCurrency.value = c;
    _store.write(_currencyKey, c.key);
    recompute();
  }

  void recompute() {
    estimate.value = _pricing.estimate(
      lines: lines,
      currency: currency.value,
      settings: _settings.settings.value,
      coupon: couponAccepted.value ? coupon.value : null,
    );
  }

  Future<void> _loadAddress() async {
    loadingAddress.value = true;
    try {
      final uid = _auth.uid;
      if (uid != null) {
        final snap = await _db
            .collection('users')
            .doc(uid)
            .collection('addresses')
            .orderBy('isDefault', descending: true)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          address.value = Address.fromMap(
            {'id': snap.docs.first.id, ...snap.docs.first.data()},
          );
        } else {
          final u = _auth.user.value;
          if (u != null && u.city.trim().isNotEmpty) {
            address.value = Address(
              id: 'profile_default',
              label: 'المنزل',
              city: u.city.trim(),
              district: u.district.trim(),
              line: u.addressLine.trim(),
              phone: (u.phone ?? '').trim(),
              receiverName: u.displayName.isNotEmpty ? u.displayName : 'العميل',
            );
          }
        }
      }
    } catch (_) {
      // لا عنوان محفوظ — سيُطلب من العميل إضافته.
    } finally {
      loadingAddress.value = false;
    }
  }

  Future<void> applyCoupon() async {
    final code = couponCtrl.text.trim();
    if (code.isEmpty) {
      couponMessage.value = 'أدخل كود القسيمة';
      return;
    }
    busy.value = true;
    couponMessage.value = '';
    try {
      final c = await _orders.lookupCoupon(code);
      if (c == null) {
        coupon.value = null;
        couponAccepted.value = false;
        couponMessage.value = 'كود غير موجود';
      } else {
        final probe = _pricing.estimate(
          lines: lines,
          currency: currency.value,
          settings: _settings.settings.value,
          coupon: c,
        );
        if (probe.couponError != null) {
          coupon.value = c;
          couponAccepted.value = false;
          couponMessage.value = probe.couponError!;
        } else {
          coupon.value = c;
          couponAccepted.value = true;
          couponMessage.value = 'تم تطبيق ${c.descriptionAr}';
        }
      }
    } catch (_) {
      couponMessage.value = 'تعذر التحقق من الكود';
    } finally {
      busy.value = false;
      recompute();
    }
  }

  void removeCoupon() {
    coupon.value = null;
    couponAccepted.value = false;
    couponCtrl.clear();
    couponMessage.value = '';
    recompute();
  }

  Future<void> editAddress() async {
    // العنوان يُحفظ تحت حساب المستخدم: بلا دخول لا يوجد uid.
    if (!_auth.isSignedIn) {
      Get.snackbar(
        'تسجيل الدخول مطلوب',
        'سجّل الدخول أولاً لتتمكن من إضافة عنوان التوصيل',
      );
      Get.toNamed(AppRoutes.login);
      return;
    }
    final res = await Get.toNamed<Address>(AppRoutes.addressForm, arguments: address.value);
    if (res != null) {
      address.value = res;
    }
  }

  Future<void> _loadCustomerDeferredUsage() async {
    final uid = _auth.uid;
    if (uid == null) return;
    try {
      final snap = await _db
          .collection('orders')
          .where('userId', isEqualTo: uid)
          .limit(80)
          .get();
      double sumSar = 0;
      for (final d in snap.docs) {
        final o = Order.fromDoc(d.id, d.data());
        if (o.status != OrderStatus.cancelled && o.hasRemaining) {
          sumSar += o.remainingSar;
        }
      }
      activeDeferredRemainingSar.value = sumSar;
    } catch (_) {}
  }

  CustomerTier get customerTier =>
      _auth.user.value?.tier ?? CustomerTier.normal;

  double get deferredCreditLimitSar =>
      _auth.user.value?.effectiveCreditLimitSar ??
      CustomerTier.normal.defaultCreditLimitSar;

  double get availableDeferredCreditSar =>
      (deferredCreditLimitSar - activeDeferredRemainingSar.value)
          .clamp(0.0, double.infinity);

  String? deferredRestrictionReason(PriceEstimate est, AppSettings sf) {
    if (!sf.deferredEnabled) return 'الطلب الآجل غير مفعّل حالياً';
    if (customerTier == CustomerTier.blockedDeferred) {
      return 'الطلب الآجل موقوف لهذا الحساب — يرجى السداد الكامل أو التواصل مع الدعم';
    }
    if (est.subtotalSar < sf.deferredThresholdSar) {
      return 'قيمة السلة أقل من الحد الأدنى (${sf.deferredThresholdSar.toStringAsFixed(0)} ر.س)';
    }
    final pct = sf.deferredUpfrontPercent / 100.0;
    final candidateRemainingSar = est.totalSar * (1.0 - pct);
    if (activeDeferredRemainingSar.value + candidateRemainingSar >
        deferredCreditLimitSar + 0.5) {
      return 'يتجاوز الحد الائتماني الآجل المتاح (${availableDeferredCreditSar.toStringAsFixed(0)} ر.س متاح من ${deferredCreditLimitSar.toStringAsFixed(0)} ر.س)';
    }
    return null;
  }

  bool canUseDeferredPlan(PriceEstimate est, AppSettings sf) =>
      deferredRestrictionReason(est, sf) == null;

  void continueToPayment() {
    if (lines.isEmpty) {
      Get.snackbar('السلة فارغة', 'أضف منتجاً واحداً على الأقل');
      return;
    }
    if (address.value == null) {
      Get.snackbar('العنوان مطلوب', 'أضف عنوان التوصيل للمتابعة');
      return;
    }
    if (!_auth.isSignedIn) {
      Get.toNamed(AppRoutes.login);
      return;
    }
    final est = estimate.value;
    if (est == null) return;
    if (paymentPlan.value == 'half_deferred') {
      final sf = _settings.settings.value;
      final reason = deferredRestrictionReason(est, sf);
      if (reason != null) {
        Get.snackbar('تعذر استخدام الآجل', reason);
        return;
      }
    }
    Get.toNamed(
      AppRoutes.payment,
      arguments: CheckoutPayload(
        lines: lines,
        currency: currency.value,
        address: address.value!,
        estimate: est,
        paymentPlan: paymentPlan.value,
        shipping: shippingMap,
        upfrontPercent: _settings.settings.value.deferredUpfrontPercent,
        walletUseSar: walletUseSar.value,
      ),
    );
  }

  /// تأكيد الطلب الآجل مباشرة + التحويل لمسار استمارة واتساب الإجباري.
  Future<void> confirmDeferredWithoutDeposit() async {
    if (lines.isEmpty) {
      Get.snackbar('السلة فارغة', 'أضف منتجاً واحداً على الأقل');
      return;
    }
    if (address.value == null) {
      Get.snackbar('العنوان مطلوب', 'أضف عنوان التوصيل للمتابعة');
      return;
    }
    if (!_auth.isSignedIn) {
      Get.toNamed(AppRoutes.login);
      return;
    }
    final est = estimate.value;
    if (est == null) return;
    final sf = _settings.settings.value;
    final reason = deferredRestrictionReason(est, sf);
    if (reason != null) {
      Get.snackbar('تعذر تأكيد الآجل', reason);
      return;
    }

    busy.value = true;
    try {
      final cc = Get.isRegistered<CartCounter>() ? Get.find<CartCounter>() : null;
      final upfrontPct = sf.deferredUpfrontPercent;
      final sub = await _orders.submitOrder(
        lines: lines,
        currency: currency.value,
        address: address.value!,
        couponCode: est.couponCode,
        estimate: est,
        paymentPlan: 'half_deferred',
        upfrontPercent: upfrontPct,
        shipping: shippingMap,
        payment: null,
        commission: cc == null
            ? null
            : <String, dynamic>{
                'perPieceSar': cc.commissionPerPiece.value,
                'approved': cc.commissionApproved.value,
              },
      );

      if (walletUseSar.value > 0 && Get.isRegistered<WalletService>()) {
        await Get.find<WalletService>().debit(
          amountSar: walletUseSar.value,
          amountLocal: walletUseSar.value * est.rate,
          note: 'خصم من المحفظة — طلب آجل ${sub.orderNo}',
        );
      }

      await _cart.clear();
      final upfrontLocal =
          roundMoney(est.totalLocal * (upfrontPct / 100), currency.value);
      final sm = shippingMap;
      final shippingText = sm['mode'] == 'governorate'
          ? 'مكتب نقل — ${sm['governorate']} — ${(sm['office'] as String? ?? '').isEmpty ? 'يمن سيلو يختار أنسب مكتب' : sm['office']}'
          : sm['mode'] == 'driver'
              ? 'سائق خاص: ${sm['driverName'] ?? ''} — ${sm['driverPhone'] ?? ''}'
              : 'توصيل محلي للمنزل';

      final form = await OrderDocuments.officialWhatsAppFormAsync(
        orderNo: sub.orderNo,
        customerName: address.value!.receiverName,
        customerPhone: address.value!.phone,
        addressAr: address.value!.fullAr,
        shippingSummary: shippingText,
        lines: lines,
        currency: currency.value,
        totalLocal: est.totalLocal,
        paymentPlan: 'half_deferred',
        upfrontDueLocal: upfrontLocal,
        paidLocal: 0,
        remainingLocal: est.totalLocal,
      );

      Get.offAll(() => OrderConfirmedScreen(
            orderNo: sub.orderNo,
            orderId: sub.id,
            summary: form,
            totalLocal: est.totalLocal,
            currencyKey: currency.value.key,
            paymentPlan: 'half_deferred',
            upfrontDueLocal: upfrontLocal,
            paidLocal: 0,
            remainingLocal: est.totalLocal,
            customerName: address.value!.receiverName,
            customerPhone: address.value!.phone,
            addressAr: address.value!.fullAr,
            itemsCount: pieces,
            thumbnails: thumbnails,
          ));
    } catch (e) {
      Get.snackbar('تعذر إرسال الطلب الآجل', '$e',
          duration: const Duration(seconds: 5));
    } finally {
      busy.value = false;
    }
  }
}
