import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'core/config/seloo_config.dart';
import 'features/cart/application/cart_counter.dart';
import 'features/cart/presentation/cart_screen.dart';
import 'features/checkout/presentation/checkout_screen.dart';
import 'features/home/presentation/main_shell.dart'; // ⭐ جديد
import 'features/shein/presentation/shein_web_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) تهيئة التخزين المحلي
  await GetStorage.init();
  debugPrint('[Seloo] GetStorage OK ✓');

  // 2) Firebase في الخلفية (لا يوقف التطبيق)
  _initFirebase();

  // 3) سجّل CartCounter قبل أي شاشة
  Get.put<CartCounter>(CartCounter(), permanent: true);
  debugPrint('[Seloo] CartCounter registered ✓');

  // 4) افتح التطبيق
  runApp(const SelooApp());
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 10));
    debugPrint('[Seloo] Firebase OK ✓');
  } catch (e) {
    debugPrint('[Seloo] Firebase FAILED: $e');
  }
}

class SelooApp extends StatelessWidget {
  const SelooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: SelooConfig.appName,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('ar'),
        Locale('en'),
      ],
      locale: const Locale('ar'),
      fallbackLocale: const Locale('en'),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF7C3AED),
        scaffoldBackgroundColor: const Color(0xFFFAF7FF),
      ),
      initialRoute: '/main', // ⭐ تم التعديل
      getPages: <GetPage<dynamic>>[
        GetPage(name: '/main', page: () => const MainShell()), // ⭐ جديد
        GetPage(name: '/shein', page: () => const SheinWebScreen()),
        GetPage(name: '/cartScreen', page: () => const CartScreen()),
        GetPage(name: '/checkoutScreen', page: () => const CheckoutScreen()),
      ],
    );
  }
}
