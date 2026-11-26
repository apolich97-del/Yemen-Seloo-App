import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../models/app_settings.dart';
import '../models/currency.dart';

/// يقرأ settings/app لحظياً ويوحّد العملة واللغة عبر كل شاشات التطبيق.
class SettingsService extends GetxService {
  final _db = FirebaseFirestore.instance;
  final _box = GetStorage();

  static const _kCurrencyKey = 'display_currency';
  static const _kLegacyRegionKey = 'seloo_cart_region';
  static const _kLangKey = 'seloo_lang';

  final Rx<AppSettings> settings = const AppSettings().obs;
  final Rx<AppCurrency> displayCurrency = AppCurrency.north.obs;
  final RxString languageCode = 'ar'.obs;

  @override
  void onInit() {
    super.onInit();
    final savedCurr = _box.read<String>(_kCurrencyKey) ??
        _box.read<String>(_kLegacyRegionKey);
    if (savedCurr != null && savedCurr.isNotEmpty) {
      displayCurrency.value = AppCurrencyX.fromKey(savedCurr);
    } else {
      displayCurrency.value = AppCurrency.north;
    }
    final savedLang = _box.read<String>(_kLangKey) ?? 'ar';
    languageCode.value = (savedLang == 'en') ? 'en' : 'ar';

    _db.collection('settings').doc('app').snapshots().listen((snap) {
      settings.value = AppSettings.fromMap(snap.data());
    }, onError: (_) {});
  }

  void setCurrency(AppCurrency c) {
    displayCurrency.value = c;
    _box.write(_kCurrencyKey, c.key);
    _box.write(_kLegacyRegionKey, c.key == 'sar' ? 'saudi' : c.key);
  }

  void setLanguage(String code) {
    final norm = code == 'en' ? 'en' : 'ar';
    languageCode.value = norm;
    _box.write(_kLangKey, norm);
    Get.updateLocale(Locale(norm));
  }

  double get rateNorth => settings.value.rateNorth;
  double get rateSouth => settings.value.rateSouth;
  double get usdRateNorth => settings.value.usdRateNorth;
  double get usdRateSouth => settings.value.usdRateSouth;

  /// تحويل من الريال السعودي (عملة التسعير) إلى عملة العرض.
  double toDisplay(num sarAmount, AppCurrency currency) {
    final rate = settings.value.rateFor(currency.key);
    return roundMoney(sarAmount * rate, currency);
  }

  CurrencyMatrix matrix(num sarAmount) =>
      settings.value.matrixForSar(sarAmount.toDouble());

  String money(num sarAmount, [AppCurrency? currency]) => formatMoney(
        toDisplay(sarAmount, currency ?? displayCurrency.value),
        currency ?? displayCurrency.value,
      );
}
