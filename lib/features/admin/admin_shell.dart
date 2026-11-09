import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import 'dashboard_tab.dart';
import 'orders_tab.dart';
import 'payments_tab.dart';
import 'settings_tab.dart';
import 'shipping_tab.dart';

/// المرحلة 5 — لوحة الإدارة (تعمل على الويب والجوال بنفس الكود).
/// الأدوار: manager / support / shipping / courier / accounting
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const _tabs = [
    _TabDef('لوحة المعلومات', Icons.dashboard_outlined),
    _TabDef('الطلبات', Icons.receipt_long_outlined),
    _TabDef('المدفوعات', Icons.account_balance_wallet_outlined),
    _TabDef('الشحن', Icons.local_shipping_outlined),
    _TabDef('الإعدادات', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    return Obx(() {
      if (!auth.isStaff) {
        return Scaffold(
          appBar: AppBar(title: const Text('لوحة الإدارة')),
          body: const Center(
            child: Text('هذه اللوحة مخصصة لحسابات الفريق فقط',
                style: TextStyle(fontSize: 13, color: AppColors.muted)),
          ),
        );
      }
      final wide = MediaQuery.of(context).size.width >= 900;
      final body = switch (_index) {
        0 => const DashboardTab(),
        1 => const OrdersTab(),
        2 => const PaymentsTab(),
        3 => const ShippingTab(),
        _ => const SettingsTab(),
      };
      if (wide) {
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                extended: true,
                selectedIndex: _index,
                backgroundColor: Colors.white,
                indicatorColor: AppColors.primary.withValues(alpha: .12),
                onDestinationSelected: (i) => setState(() => _index = i),
                leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('يمن سيلو · إدارة',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                ),
                destinations: _tabs
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
          title: Text(_tabs[_index].label),
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(
                child: Text(auth.role,
                    style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ),
            ),
          ],
        ),
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: _tabs
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
