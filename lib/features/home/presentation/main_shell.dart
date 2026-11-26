import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/controllers/profile_controller.dart';
import '../../../core/models/currency.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../cart/application/cart_counter.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../catalog/presentation/store_tab.dart';
import '../../guide/interactive_guide.dart';
import '../../profile/profile_screen.dart';
import '../../shein/presentation/shein_web_screen.dart';
import '../../support/presentation/support_screen.dart';
import 'home_tab.dart';
import 'main_tab_controller.dart';
import 'orders_tab.dart';

const Color _purple = Color(0xFF7C3AED);

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final MainTabController _tabCtrl = Get.find<MainTabController>();
  final CartCounter _cart = Get.find<CartCounter>();

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<ProfileController>()) {
      Get.put<ProfileController>(ProfileController(), permanent: false);
    }
  }

  List<String> get _titles => <String>[
        'nav_home'.tr,
        'nav_catalog'.tr,
        'nav_shein'.tr,
        'nav_cart'.tr,
        'nav_orders'.tr,
        'nav_me'.tr,
      ];

  /// إرشاد تفاعلي عند أول دخول لكل تبويب.
  void _guideTab(int index) {
    if (!Get.isRegistered<InteractiveGuideController>()) return;
    final c = Get.find<InteractiveGuideController>();
    switch (index) {
      case 0:
        guideForPage(c, 'page_home', 'الرئيسية',
            'من هنا تبدأ رحلتك: عروض مختارة، حالة آخر طلب، وروابط سريعة للسلة والدعم.');
        break;
      case 1:
        guideForPage(c, 'page_catalog', 'كتالوج يمن سيلو',
            'منتجات مختارة ومُسعّرة تلقائياً حسب منطقتك — اختر المقاس واللون وأضف للسلة بضغطة واحدة.');
        break;
      case 2:
        guideForPage(c, 'page_shein', 'تصفح SHEIN',
            'كل منتج تفتحه هنا يُضاف إلى سلة يمن سيلو مع سعره بالريال السعودي.');
        break;
      case 3:
        guideForPage(c, 'page_cart', 'سلة التسوق',
            'تراجع المنتجات وتُعدّل الكميات وتحول السلة للطلب.');
        break;
      case 4:
        guideForPage(c, 'page_orders', 'طلباتي',
            'تتبع مراحل كل طلب خطوة بخطوة: الصين ← الإمارات ← السعودية ← اليمن.');
        break;
      case 5:
        guideForPage(c, 'page_me', 'أنا وحسابي',
            'التنقل بين الحسابات المسجلة، اللغة، العملة، الثيم الليلي، والعناوين.');
        break;
    }
  }

  void _selectCurrency(AppCurrency c) {
    if (Get.isRegistered<SettingsService>()) {
      Get.find<SettingsService>().setCurrency(c);
    }
    _cart.setRegion(c == AppCurrency.sar ? 'saudi' : c.key);
    Get.back();
  }

  void _showCurrencyDialog() {
    final svc = Get.isRegistered<SettingsService>()
        ? Get.find<SettingsService>()
        : null;
    final sf = svc?.settings.value;
    final rNorth = (sf?.rateNorth ?? 140).toStringAsFixed(0);
    final rSouth = (sf?.rateSouth ?? 413).toStringAsFixed(0);
    final uNorth = (sf?.usdRateNorth ?? 533).toStringAsFixed(0);
    final uSouth = (sf?.usdRateSouth ?? 1570).toStringAsFixed(0);

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: T.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: <Widget>[
              Icon(Icons.currency_exchange, color: T.primary),
              const SizedBox(width: 8),
              Text('اختر العملة ومنطقة التسعير',
                  style: TextStyle(color: T.text, fontSize: 15.5, fontWeight: FontWeight.w800)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _currTile(
                icon: Icons.monetization_on,
                iconColor: _purple,
                title: 'الريال السعودي (SAR)',
                subtitle: 'عملة التسعير الأساسية',
                code: AppCurrency.sar,
              ),
              Divider(color: T.border),
              _currTile(
                icon: Icons.attach_money_rounded,
                iconColor: Colors.teal,
                title: 'الدولار الأمريكي (USD)',
                subtitle: '1 USD = 3.75 ر.س',
                code: AppCurrency.usd,
              ),
              Divider(color: T.border),
              _currTile(
                icon: Icons.public,
                iconColor: Colors.green,
                title: 'الريال اليمني (شمال)',
                subtitle: '1 ر.س = $rNorth · 1 USD = $uNorth',
                code: AppCurrency.north,
              ),
              Divider(color: T.border),
              _currTile(
                icon: Icons.public,
                iconColor: Colors.orange,
                title: 'الريال اليمني (جنوب)',
                subtitle: '1 ر.س = $rSouth · 1 USD = $uSouth',
                code: AppCurrency.south,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Get.back(),
              child: Text('إغلاق', style: TextStyle(color: T.muted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _currTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required AppCurrency code,
  }) {
    return Obx(() {
      final active = Get.isRegistered<SettingsService>()
          ? Get.find<SettingsService>().displayCurrency.value == code
          : _cart.region.value == (code == AppCurrency.sar ? 'saudi' : code.key);
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: TextStyle(color: T.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: TextStyle(color: T.muted, fontSize: 11.5)),
        trailing: active ? Icon(Icons.check_circle, color: T.primary) : const SizedBox(),
        onTap: () => _selectCurrency(code),
      );
    });
  }

  Future<bool> _confirmExit() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: T.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: <Widget>[
              Icon(Icons.exit_to_app, color: T.primary),
              const SizedBox(width: 8),
              Text('الخروج من يمن سيلو', style: TextStyle(color: T.text)),
            ],
          ),
          content: Text('هل تريد الخروج من التطبيق؟',
              style: TextStyle(fontSize: 14, color: T.text)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('البقاء', style: TextStyle(color: T.muted)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: _purple),
              child: const Text('خروج'),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final notifSvc = Get.isRegistered<NotificationService>()
        ? Get.find<NotificationService>()
        : null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        if (_tabCtrl.index.value != 0) {
          _tabCtrl.goToHome();
          return;
        }
        final bool exit = await _confirmExit();
        if (exit) {
          SystemNavigator.pop();
        }
      },
      child: Obx(
        () {
          final isEn = Get.isRegistered<SettingsService>() &&
              Get.find<SettingsService>().languageCode.value == 'en';
          return Directionality(
            textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
            child: Scaffold(
              backgroundColor: T.bg,
              appBar: AppBar(
                backgroundColor: T.dark ? const Color(0xFF1A1233) : _purple,
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: false,
                title: Row(
                  children: <Widget>[
                    const ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                      child: BrandLogo(height: 30),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _titles[_tabCtrl.index.value],
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                actions: <Widget>[
                  // جرس الإشعارات
                  if (notifSvc != null)
                    Obx(() {
                      final count = notifSvc.unreadCount;
                      return IconButton(
                        tooltip: 'notifications'.tr,
                        onPressed: () => Get.toNamed(AppRoutes.notifications),
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications_none_rounded, color: Colors.white),
                            if (count > 0)
                              Positioned(
                                top: -4,
                                right: -5,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(minWidth: 16),
                                  child: Text(
                                    count > 99 ? '99+' : '$count',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  IconButton(
                    tooltip: 'support'.tr,
                    icon: const Icon(Icons.support_agent_outlined, color: Colors.white),
                    onPressed: () => Get.to(() => const SupportScreen()),
                  ),
                  const ThemeToggleButton(),
                  IconButton(
                    tooltip: 'currency'.tr,
                    icon: const Icon(Icons.currency_exchange, color: Colors.white),
                    onPressed: _showCurrencyDialog,
                  ),
                ],
              ),
              body: IndexedStack(
                index: _tabCtrl.index.value,
                children: const <Widget>[
                  HomeTab(),
                  StoreTab(),
                  SheinWebScreen(),
                  CartScreen(),
                  OrdersTab(),
                  ProfileScreen(embedded: true),
                ],
              ),
              bottomNavigationBar: Container(
                decoration: BoxDecoration(
                  color: T.surface,
                  border: Border(top: BorderSide(color: T.border)),
                ),
                child: BottomNavigationBar(
                  currentIndex: _tabCtrl.index.value,
                  onTap: (int i) {
                    _tabCtrl.goTo(i);
                    if (i == 3) _cart.onItemAdded();
                    _guideTab(i);
                  },
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: T.surface,
                  elevation: 0,
                  selectedItemColor: T.primary,
                  unselectedItemColor: T.muted,
                  selectedFontSize: 10,
                  unselectedFontSize: 9.5,
                  items: <BottomNavigationBarItem>[
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.home_outlined),
                      activeIcon: const Icon(Icons.home),
                      label: 'nav_home'.tr,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.storefront_outlined),
                      activeIcon: const Icon(Icons.storefront),
                      label: 'nav_catalog'.tr,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.language_outlined),
                      activeIcon: const Icon(Icons.language),
                      label: 'nav_shein'.tr,
                    ),
                    BottomNavigationBarItem(
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          const Icon(Icons.shopping_cart_outlined),
                          if (_cart.count > 0)
                            Positioned(
                              top: -4,
                              right: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                constraints: const BoxConstraints(minWidth: 16),
                                child: Text(
                                  '${_cart.count}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      activeIcon: const Icon(Icons.shopping_cart),
                      label: 'nav_cart'.tr,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.receipt_long_outlined),
                      activeIcon: const Icon(Icons.receipt_long),
                      label: 'nav_orders'.tr,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.person_outline),
                      activeIcon: const Icon(Icons.person),
                      label: 'nav_me'.tr,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
