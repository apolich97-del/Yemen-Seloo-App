import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'core/config/seloo_config.dart';
import 'features/cart/application/cart_counter.dart';
import 'features/shein/presentation/shein_web_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) تهيئة Firebase أولًا (مضمونة الآن)
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 10));
    debugPrint('[Seloo] Firebase OK ✓');
  } catch (e) {
    debugPrint('[Seloo] Firebase FAILED: $e');
  }

  // 2) تسجيل CartCounter قبل أي شاشة
  Get.put<CartCounter>(CartCounter(), permanent: true);
  debugPrint('[Seloo] CartCounter registered ✓');

  // 3) تسجيل الدخول المجهول في الخلفية (لا يوقف التطبيق)
  _signInAnonymously();

  // 4) فتح التطبيق
  runApp(const SelooApp());
}

Future<void> _signInAnonymously() async {
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance
          .signInAnonymously()
          .timeout(const Duration(seconds: 8));
      debugPrint('[Seloo] Anonymous sign-in OK ✓');
    }
  } catch (e) {
    debugPrint('[Seloo] Anonymous sign-in failed: $e');
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
      home: const SheinWebScreen(),
    );
  }
}
