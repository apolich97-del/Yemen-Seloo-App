import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/app_settings.dart';
import '../models/currency.dart';

/// يقرأ settings/app لحظياً. القيم الافتراضية = 140 / 413.
class SettingsService extends GetxService {
  final _db = FirebaseFirestore.instance;

  final Rx<AppSettings> settings = const AppSettings().obs;
  final Rx<AppCurrency> displayCurrency = AppCurrency.sar.obs;

  @override
  void onInit() {
    super.onInit();
    _db.collection('settings').doc('app').snapshots().listen((snap) {
      settings.value = AppSettings.fromMap(snap.data());
    }, onError: (_) {});
  }

  double get rateNorth => settings.value.rateNorth;
  double get rateSouth => settings.value.rateSouth;

  /// تحويل من الريال السعودي (عملة التسعير) إلى عملة العرض.
  double toDisplay(num sarAmount, AppCurrency currency) {
    final rate = settings.value.rateFor(currency.key);
    return roundMoney(sarAmount * rate, currency);
  }

  String money(num sarAmount, [AppCurrency? currency]) =>
      formatMoney(toDisplay(sarAmount, currency ?? displayCurrency.value),
          currency ?? displayCurrency.value);
}
