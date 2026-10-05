import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'core/config/seloo_config.dart';
import 'features/cart/application/cart_counter.dart';
import 'features/cart/presentation/cart_screen.dart';
import 'features/checkout/presentation/checkout_screen.dart';
import 'features/shein/presentation/shein_web_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) نفتح الواجهة فورًا
  runApp(const SelooApp());

  // 2) Firebase في الخلفية
  _bootstrap();
}

Future<void> _bootstrap() async {
  try {
    await Firebase.initializeApp().timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Firebase init timeout'),
    );
    debugPrint('[Seloo] Firebase initialized ✓');

    if (FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance
            .signInAnonymously()
            .timeout(const Duration(seconds: 8));
        debugPrint('[Seloo] Anonymous sign-in OK ✓');
      } catch (e) {
        debugPrint('[Seloo] Anonymous sign-in failed: $e');
      }
    } else {
      debugPrint('[Seloo] Already signed in');
    }

    if (!Get.isRegistered<CartCounter>()) {
      Get.put<CartCounter>(CartCounter(), permanent: true);
      debugPrint('[Seloo] CartCounter registered ✓');
    }
  } catch (error, stack) {
    debugPrint('[Seloo] Bootstrap error: $error');
    debugPrint('[Seloo] Stack: $stack');
  }
}

class SelooApp extends StatelessWidget {
  const SelooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: SelooConfig.appName,
      debugShowCheckedModeBanner: false,

      // ⭐ الحل: delegates للترجمة العربية
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

      initialRoute: '/shein',
      getPages: <GetPage<dynamic>>[
        GetPage(name: '/shein', page: () => const SheinWebScreen()),
        GetPage(name: '/cartScreen', page: () => const CartScreen()),
        GetPage(name: '/checkoutScreen', page: () => const CheckoutScreen()),
      ],
    );
  }
}
