import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'core/config/seloo_config.dart';
import 'features/cart/application/cart_counter.dart';
import 'features/cart/data/seloo_cart_link.dart';
import 'features/cart/data/seloo_cart_service.dart';
import 'features/shein/domain/shein_draft.dart';
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
  _listenForDeepLinks();

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

// ═══ روابط شي إن القادمة من أندرويد (فتح بواسطة يمن سيلو) ═══
const MethodChannel _deeplinkChannel = MethodChannel('seloo/deeplink');

void _listenForDeepLinks() {
  _deeplinkChannel.setMethodCallHandler((MethodCall call) async {
    if (call.method == 'onLink') {
      final Object? arg = call.arguments;
      if (arg is String && arg.isNotEmpty) _openLink(arg);
    }
  });

  _deeplinkChannel.invokeMethod<String>('getInitialLink').then((String? raw) {
    if (raw != null && raw.isNotEmpty) _openLink(raw);
  }).catchError((Object e) {
    debugPrint('[Seloo] initial link error: $e');
  });
}

void _openLink(String raw) {
  if (raw.isEmpty) return;

  // رابط سلة يمن سيلو الكاملة
  if (raw.startsWith('yemenseloo://')) {
    _importCartFromLink(raw);
    return;
  }

  if (!raw.toLowerCase().contains('shein')) return;

  debugPrint('[Seloo] link: $raw');
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    try {
      Get.toNamed('/shein', arguments: <String, dynamic>{'shareCartUrl': raw});
    } catch (e) {
      debugPrint('[Seloo] link navigate failed: $e');
    }
  });
}

/// يستورد سلة يمن سيلو كاملة من رابط
Future<void> _importCartFromLink(String raw) async {
  final List<SheinDraft> drafts = SelooCartLink.draftsFromLink(raw);
  if (drafts.isEmpty) {
    Get.snackbar('رابط غير صالح', 'لم أجد منتجات في هذا الرابط',
        snackPosition: SnackPosition.BOTTOM);
    return;
  }

  final SelooCartService service = SelooCartService();
  int added = 0;
  for (final SheinDraft draft in drafts) {
    try {
      final BridgeResult result = await service.addToCart(draft);
      if (result.status == 'ok') added++;
    } catch (e) {
      debugPrint('[Seloo] cart link item failed: $e');
    }
  }

  try {
    await Get.find<CartCounter>().refreshQuote();
  } catch (_) {}

  Get.snackbar(
    added > 0 ? '✓ تم فتح السلة' : 'لم تُضف منتجات',
    added > 0 ? 'أُضيف $added منتج إلى سلة يمن سيلو' : 'المنتجات موجودة مسبقاً',
    snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 4),
  );

  try {
    Get.toNamed('/cartScreen');
  } catch (_) {}
}

void _handleShared(List<SharedMediaFile> items) {
  for (final SharedMediaFile item in items) {
    if (item.type == SharedMediaType.image) {
      // صورة مشاركة → البحث بالصورة داخل شي إن
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        try {
          Get.toNamed('/shein', arguments: <String, dynamic>{'imageSearch': true});
          Get.snackbar(
            '🔍 البحث بالصورة',
            'اضغط أيقونة البحث بالصورة داخل شي إن ثم اختر الصورة',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 6),
          );
        } catch (e) {
          debugPrint('[Seloo] image share failed: $e');
        }
      });
      continue;
    }

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
