import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/config/seloo_config.dart';
import 'features/cart/application/cart_counter.dart';
import 'features/cart/presentation/cart_screen.dart';
import 'features/checkout/presentation/checkout_screen.dart';
import 'features/shein/presentation/shein_web_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const SelooApp());

  // التهيئة في الخلفية — لا تمنع فتح الواجهة
  _bootstrap();
}

Future<void> _bootstrap() async {
  try {
    await Firebase.initializeApp().timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Firebase init timeout'),
    );
    debugPrint('[Seloo] Firebase initialized');

    // إذا لم يوجد مستخدم، سجّل مجهولًا — لكن لا ننتظر للأبد
    if (FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance
            .signInAnonymously()
            .timeout(const Duration(seconds: 8));
        debugPrint('[Seloo] Anonymous sign-in OK');
      } catch (e) {
        debugPrint('[Seloo] Anonymous sign-in failed: $e');
      }
    }

    Get.put<CartCounter>(CartCounter(), permanent: true);
    debugPrint('[Seloo] CartCounter registered');
  } catch (error) {
    debugPrint('[Seloo] Bootstrap error: $error');
  }
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
        colorSchemeSeed: const Color(0xFF7C3AED),
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
