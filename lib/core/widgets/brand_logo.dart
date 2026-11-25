import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// شعار يمن سيلو: يتبع الثيم فوراً عبر Obx — ليلي من logo_dark.jpg ثم png ثم الاحتياطي.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 30});
  final double height;

  @override
  Widget build(BuildContext context) {
    Widget buildFor(bool dark) {
      if (!dark) {
        return Image.asset(
          'assets/images/logo.png',
          height: height,
          errorBuilder: (_, __, ___) => _fallback(),
        );
      }
      return Image.asset(
        'assets/images/logo_dark.jpg',
        height: height,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/images/logo_dark.png',
          height: height,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }

    if (Get.isRegistered<ThemeController>()) {
      return Obx(() => buildFor(T.dark));
    }
    return buildFor(Theme.of(context).brightness == Brightness.dark);
  }

  Widget _fallback() => Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[T.card, T.soft],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: T.softBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.shopping_cart_outlined, size: 16, color: T.primary),
            const SizedBox(width: 6),
            Text('يمن سيلو',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: T.text)),
          ],
        ),
      );
}
