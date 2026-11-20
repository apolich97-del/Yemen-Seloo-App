import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import 'dashboard_tab.dart';
import 'orders_tab.dart';
import 'payments_tab.dart';
import 'receipts_tab.dart';
import 'support_tab.dart';
import 'settings_tab.dart';
import 'shipping_tab.dart';

/// المرحلة 5 — لوحة الإدارة (تعمل على الويب والجوال بنفس الكود).
/// الأدوار: manager / support / shipping / courier / accounting
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

/// تحكم تنقّل داخل لوحة الإدارة (تستخدمه لوحة المعلومات للانتقال).
/// يعمل بالاسم لا بالرقم، لأن ترتيب التبويبات يختلف حسب الدور.
class AdminNav extends GetxController {
  final RxString label = 'لوحة المعلومات'.obs;
  void goTo(String name) => label.value = name;
}

class _AdminShellState extends State<AdminShell> {
  late final AdminNav _nav = Get.put(AdminNav(), permanent: false);

  /// تبويبات كل دور: المحاسب، الشحن، خدمة العملاء، المدير.
  static List<_TabDef> _tabsFor(String role) {
    const dash = _TabDef('لوحة المعلومات', Icons.dashboard_outlined);
    const orders = _TabDef('الطلبات', Icons.receipt_long_outlined);
    const pays = _TabDef('المدفوعات', Icons.account_balance_wallet_outlined);
    const receipts = _TabDef('إيصال', Icons.qr_code_2_outlined);
    const support = _TabDef('دعم العملاء', Icons.support_agent);
    const ship = _TabDef('الشحن', Icons.local_shipping_outlined);
    const settings = _TabDef('الإعدادات', Icons.settings_outlined);
    switch (role) {
      case 'accounting':
        return [pays, receipts, orders];
      case 'shipping':
      case 'courier':
        return [ship, orders];
      case 'support':
        return [support, orders, receipts];
      case 'marketer':
        // مسوّق الكتالوج: يرى الكتالوج والطلبات والإعدادات لضبط الأسعار.
        return [dash, orders];
      default:
        return [dash, orders, pays, receipts, support, ship, settings];
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    return Obx(() {
      if (!auth.isStaff) {
        return Scaffold(
          appBar: AppBar(title: const Text('لوحة الإدارة')),
          body: Center(
            child: Text('هذه اللوحة مخصصة لحسابات الفريق فقط',
                style: TextStyle(fontSize: 13, color: T.muted)),
          ),
        );
      }
      final wide = MediaQuery.of(context).size.width >= 900;
      final tabs = _tabsFor(auth.role);
      final wanted = _nav.label.value;
      final found = tabs.indexWhere((t) => t.label == wanted);
      final idx = (found < 0 ? 0 : found).clamp(0, tabs.length - 1);
      final body = switch (tabs[idx].label) {
        'لوحة المعلومات' => const DashboardTab(),
        'الطلبات' => const OrdersTab(),
        'المدفوعات' => const PaymentsTab(),
        'إيصال' => const ReceiptsTab(),
        'دعم العملاء' => const AdminSupportTab(),
        'الشحن' => const ShippingTab(),
        _ => const SettingsTab(),
      };
      if (wide) {
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                extended: true,
                selectedIndex: idx,
                backgroundColor: T.card,
                indicatorColor: AppColors.primary.withOpacity(.12),
                onDestinationSelected: (i) => _nav.label.value = tabs[i].label,
                leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('يمن سيلو · إدارة',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                ),
                destinations: tabs
                    .map((t) => NavigationRailDestination(
                          icon: Icon(t.icon),
                          label: Text(t.label),
                        ))
                    .toList(),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(tabs[idx].label),
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(
                child: Text(auth.role,
                    style: TextStyle(fontSize: 11, color: T.muted)),
              ),
            ),
          ],
        ),
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: (i) => _nav.label.value = tabs[i].label,
          destinations: tabs
              .map((t) => NavigationDestination(icon: Icon(t.icon), label: t.label))
              .toList(),
        ),
      );
    });
  }
}

class _TabDef {
  final String label;
  final IconData icon;
  const _TabDef(this.label, this.icon);
}
