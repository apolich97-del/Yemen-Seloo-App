import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// شعار يمن سيلو: نسخة نهارية ونسخة ليلية تتغيّر مع الثيم تلقائياً.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 30});

  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Get.isRegistered<ThemeController>()
        ? Get.find<ThemeController>().isDark.value
        : Theme.of(context).brightness == Brightness.dark;

    if (!dark) {
      return Image.asset('assets/images/logo.png', height: height);
    }

    return Image.asset(
      'assets/images/logo_dark.png',
      height: height,
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/images/logo_dark.jpg',
        height: height,
        errorBuilder: (_, __, ___) => Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[AppDark.cardHigh, AppDark.borderSoft],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppDark.borderSoft),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.shopping_cart_outlined, size: 16, color: AppDark.text),
            SizedBox(width: 6),
            Text('يمن سيلو',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppDark.text)),
          ],
        ),
        ),
      ),
    );
  }
}
