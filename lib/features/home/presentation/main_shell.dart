import 'package:flutter/material.dart';
import 'package:flutter/services.dart';           // ⭐ جديد
import 'package:get/get.dart';

import '../../cart/application/cart_counter.dart';
import 'home_tab.dart';
import 'orders_tab.dart';
import 'support_tab.dart';
import '../application/main_tab_controller.dart';   // ⭐ جديد
import '../../cart/presentation/cart_screen.dart';
import '../../shein/presentation/shein_web_screen.dart';

const Color _purple = Color(0xFF7C3AED);

/// الهيكل الرئيسي للتطبيق: يحتوي شريط التنقل السفلي + 5 تبويبات.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final MainTabController _tabCtrl = Get.find<MainTabController>(); // ⭐

  static const List<String> _titles = <String>[
    'الرئيسية',
    'تصفح SHEIN',
    'سلة التسوق',
    'طلباتي',
    'الدعم',
  ];

  // ⭐ نافذة تأكيد الخروج
  Future<bool> _confirmExit() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: <Widget>[
              Icon(Icons.exit_to_app, color: _purple),
              SizedBox(width: 8),
              Text('الخروج من يمن سيلو'),
            ],
          ),
          content: const Text(
            'هل تريد الخروج من التطبيق؟',
            style: TextStyle(fontSize: 14),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'البقاء',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
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
    final CartCounter cart = Get.find<CartCounter>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;

        // إذا لم نكن في الرئيسية → انتقل للرئيسية
        if (_tabCtrl.index.value != 0) {
          _tabCtrl.goToHome();
          return;
        }

        // في الرئيسية → اسأل عن الخروج
        final bool exit = await _confirmExit();
        if (exit) {
          SystemNavigator.pop();
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Obx(
          () => Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
              title: Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 30,
                      height: 30,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.storefront,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _titles[_tabCtrl.index.value],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            body: IndexedStack(
              index: _tabCtrl.index.value,
              children: const <Widget>[
                HomeTab(),
                SheinWebScreen(),
                CartScreen(),
                OrdersTab(),
                SupportTab(),
              ],
            ),
            bottomNavigationBar: Obx(
              () => BottomNavigationBar(
                currentIndex: _tabCtrl.index.value,
                onTap: (int i) => _tabCtrl.goTo(i),
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                selectedItemColor: _purple,
                unselectedItemColor: const Color(0xFF9CA3AF),
                selectedFontSize: 11,
                unselectedFontSize: 11,
                items: <BottomNavigationBarItem>[
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'الرئيسية',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.storefront_outlined),
                    activeIcon: Icon(Icons.storefront),
                    label: 'المتجر',
                  ),
                  BottomNavigationBarItem(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        const Icon(Icons.shopping_cart_outlined),
                        if (cart.count > 0)
                          Positioned(
                            top: -4,
                            right: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(minWidth: 16),
                              child: Text(
                                '${cart.count}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    activeIcon: const Icon(Icons.shopping_cart),
                    label: 'السلة',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.receipt_long_outlined),
                    activeIcon: Icon(Icons.receipt_long),
                    label: 'طلباتي',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.support_agent_outlined),
                    activeIcon: Icon(Icons.support_agent),
                    label: 'الدعم',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
