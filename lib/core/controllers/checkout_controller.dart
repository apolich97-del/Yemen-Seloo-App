import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../models/app_settings.dart';
import '../models/cart.dart';
import '../models/currency.dart';
import '../models/order.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/pricing_service.dart';
import '../services/settings_service.dart';

/// الحمولة المنقولة من شاشة الملخص إلى شاشة الدفع.
class CheckoutPayload {
  final List<CartLine> lines;
  final AppCurrency currency;
  final Address address;
  final PriceEstimate estimate;

  const CheckoutPayload({
    required this.lines,
    required this.currency,
    required this.address,
    required this.estimate,
  });
}

class CheckoutController extends GetxController {
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
  final loadingAddress = true.obs;

  final couponCtrl = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    lines.assignAll(_cart.read());
    currency.value = AppCurrencyX.fromKey(_store.read<String>(_currencyKey));
    _settings.displayCurrency.value = currency.value;
    _loadAddress();
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
    String d(DateTime x) => '${x.day}/${x.month}';
    return 'متوقع بين ${d(now.add(const Duration(days: 4)))} و ${d(now.add(const Duration(days: 9)))}';
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
    final res = await Get.toNamed<Address>(AppRoutes.addressForm, arguments: address.value);
    if (res != null) {
      address.value = res;
    }
  }

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
    Get.toNamed(
      AppRoutes.payment,
      arguments: CheckoutPayload(
        lines: lines,
        currency: currency.value,
        address: address.value!,
        estimate: estimate.value!,
      ),
    );
  }
}
