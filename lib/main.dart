import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'core/config/seloo_config.dart';
import 'features/cart/application/cart_counter.dart';
import 'features/cart/presentation/cart_screen.dart';
import 'features/checkout/presentation/checkout_screen.dart';
import 'features/home/presentation/main_shell.dart';
import 'features/home/presentation/main_tab_controller.dart'; // ⭐ المسار الصحيح
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

  // ⭐ 3.1) سجّل MainTabController (للتحكم في التبويب من WebView)
  Get.put<MainTabController>(MainTabController(), permanent: true);
  debugPrint('[Seloo] MainTabController registered ✓');

  // 4) استقبال روابط المشاركة من شي إن (مشاركة ← يمن سيلو)
  _listenForSharedLinks();

  // 5) افتح التطبيق
  runApp(const SelooApp());
}

// ═══ استقبال رابط السلة المشترك من شي إن عبر "مشاركة" ═══
StreamSubscription<List<SharedMediaFile>>? _shareSub;

void _listenForSharedLinks() {
  try {
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> items) {
      _handleShared(items);
      ReceiveSharingIntent.instance.reset();
    }).catchError((Object e) {
      debugPrint('[Seloo] share initial error: $e');
    });

    _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleShared,
      onError: (Object e) => debugPrint('[Seloo] share stream error: $e'),
    );
  } catch (e) {
    debugPrint('[Seloo] share init failed: $e');
  }
}

/// يستخرج رابط سلة شي إن من نص المشاركة:
/// 1) رابط https مباشر.
/// 2) رابط sheinlink://applink/share_receiver/?data=<JSON> (مشاركة تطبيق شي إن).
String _extractSheinUrl(String text) {
  final RegExpMatch? direct = RegExp(r'https?://[^\s]+').firstMatch(text);
  if (direct != null && direct.group(0)!.toLowerCase().contains('shein')) {
    return direct.group(0)!;
  }

  if (!text.toLowerCase().contains('sheinlink') && !text.contains('group_id')) {
    return '';
  }

  final RegExpMatch? dataMatch = RegExp(r'data=([^&\s]+)').firstMatch(text);
  if (dataMatch != null) {
    try {
      final String decoded = Uri.decodeComponent(dataMatch.group(1)!);
      final Object? parsed = jsonDecode(decoded);
      if (parsed is Map) {
        final Object? gid = parsed['group_id'] ?? parsed['groupId'];
        final Object? shc = parsed['shc'];
        if (gid != null) {
          final String base =
              'https://m.shein.com/ar/cart/share/landing?group_id=$gid';
          return shc != null ? '$base&shc=$shc' : base;
        }
      }
    } catch (e) {
      debugPrint('[Seloo] sheinlink parse failed: $e');
    }
  }

  final RegExpMatch? gidMatch =
      RegExp(r'group_?id[^0-9]{0,3}(\d{5,})', caseSensitive: false).firstMatch(text);
  if (gidMatch != null) {
    return 'https://m.shein.com/ar/cart/share/landing?group_id=${gidMatch.group(1)}';
  }

  return '';
}

void _handleShared(List<SharedMediaFile> items) {
  for (final SharedMediaFile item in items) {
    final String url = _extractSheinUrl(item.path);
    if (url.isEmpty) continue;

    debugPrint('[Seloo] shared shein link: $url');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      try {
        Get.toNamed('/shein', arguments: <String, dynamic>{'shareCartUrl': url});
      } catch (e) {
        debugPrint('[Seloo] share navigate failed: $e');
      }
    });
    break;
  }
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
      initialRoute: '/main',
      getPages: <GetPage<dynamic>>[
        GetPage(name: '/main', page: () => const MainShell()),
        GetPage(name: '/shein', page: () => const SheinWebScreen()),
        GetPage(name: '/cartScreen', page: () => const CartScreen()),
        GetPage(name: '/checkoutScreen', page: () => const CheckoutScreen()),
      ],
    );
  }
}
