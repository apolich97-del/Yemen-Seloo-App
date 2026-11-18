import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// الثيم النهاري/الليلي مع حفظ الاختيار محلياً.
class ThemeController extends GetxController {
  static const String _key = 'seloo_theme_dark';
  final GetStorage _box = GetStorage();

  final RxBool isDark = false.obs;

  @override
  void onInit() {
    isDark.value = (_box.read<bool>(_key) ?? false);
    super.onInit();
  }

  ThemeMode get mode => isDark.value ? ThemeMode.dark : ThemeMode.light;

  void toggle() => setDark(!isDark.value);

  void setDark(bool value) {
    isDark.value = value;
    _box.write(_key, value);
    Get.changeThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }
}
