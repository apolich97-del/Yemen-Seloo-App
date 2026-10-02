import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/config/seloo_config.dart';
import 'features/cart/application/cart_counter.dart';
import 'features/cart/presentation/cart_screen.dart';
import 'features/checkout/presentation/checkout_screen.dart';
import 'features/shein/presentation/shein_web_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // حالة السلة تُسجَّل مرة واحدة قبل بناء الواجهة.
  Get.put<CartCounter>(CartCounter(), permanent: true);

  runApp(const SelooApp());
}

class SelooApp extends StatelessWidget {
  const SelooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: SelooConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF7C3AED), // بنفسجي — هوية يمن سيلو
        fontFamily: 'Tajawal',
        scaffoldBackgroundColor: const Color(0xFFFAF7FF),
      ),
      locale: const Locale('ar'),
      fallbackLocale: const Locale('en'),
      initialRoute: '/shein',
      getPages: <GetPage<dynamic>>[
        GetPage(name: '/shein', page: () => const SheinWebScreen()),
        GetPage(name: '/cartScreen', page: () => const CartScreen()),
        GetPage(name: '/checkoutScreen', page: () => const CheckoutScreen()),
      ],
    );
  }
}
