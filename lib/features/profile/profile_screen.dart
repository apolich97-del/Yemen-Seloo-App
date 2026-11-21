import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_header.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/theme/theme_controller.dart';
import '../guide/interactive_guide.dart';

import '../../core/controllers/profile_controller.dart';
import '../../core/routes/app_routes.dart';
import '../home/presentation/main_tab_controller.dart';
import '../support/data/support_models.dart';
import '../support/data/support_service.dart';
import '../../core/services/auth_service.dart';
import 'address_form_screen.dart';

/// المرحلة 4 — «حسابي»
class ProfileScreen extends GetView<ProfileController> {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', height: 26),
            const SizedBox(width: 8),
            const Text('حسابي'),
          ],
        ),
      ),
      body: Obx(() {
        final u = auth.user.value;
        if (u == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Image.asset('assets/images/logo.png', height: 64),
                  ),
                  const SizedBox(height: 16),
                  const Text('يمن سيلو',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark)),
                  const SizedBox(height: 4),
                  Text('وسيطك الموثوق للتسوق العالمي',
                      style: TextStyle(fontSize: 12, color: T.muted)),
                  const SizedBox(height: 20),
                  const Text('سجّل الدخول لإدارة حسابك وطلباتك',
                      style: TextStyle(fontSize: 13.5)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 240,
                    child: ElevatedButton(
                      onPressed: () => Get.toNamed(AppRoutes.login),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('تسجيل الدخول',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _identity(u),
            const SizedBox(height: 12),
            const _OrderShortcuts(),
            const SizedBox(height: 12),
            SectionCard(
              title: 'البيانات الشخصية',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller.firstName,
                          decoration: const InputDecoration(labelText: 'الاسم'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: controller.lastName,
                          decoration: const InputDecoration(labelText: 'اللقب'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller.phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'الهاتف (واتساب)',
                      hintText: '967xxxxxxxxx',
                      helperText: 'يُستخدم للتواصل عبر واتساب بخصوص الطلب',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: controller.busy.value ? null : controller.savePersonal,
                    child: const Text('حفظ التغييرات'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _menu(),
            const SizedBox(height: 12),
            _addresses(),
            if (u.isStaff) ...[
              const SizedBox(height: 12),
              SectionCard(
                title: 'لوحة الإدارة',
                child: OutlinedButton.icon(
                  onPressed: () => Get.toNamed(AppRoutes.admin),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: Text('الدخول كـ ${u.role}'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: controller.signOut,
              icon: Icon(Icons.logout, color: T.danger, size: 18),
              label: Text('تسجيل الخروج', style: TextStyle(color: T.danger)),
            ),
            const SizedBox(height: 24),
          ],
        );
      }),
    );
  }

  Widget _identity(AppUser u) => Column(
        children: [
          BrandHeader(
            title: u.displayName.isEmpty ? 'مستخدم جديد' : u.displayName,
            subtitle: u.phone ?? u.email ?? 'يمن سيلو · حسابك',
            badge: u.role == 'customer' ? 'عميل' : u.role,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withOpacity(.2),
                  child: Text(
                    (u.displayName.isEmpty
                        ? '؟'
                        : u.displayName.characters.first),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          u.displayName.isEmpty ? 'مستخدم جديد' : u.displayName,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(u.phone ?? u.email ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 6),
                  const Text('وسيطك الموثوق للتسوق العالمي',
                      style: TextStyle(fontSize: 10.5, color: Colors.white60)),
                ],
              ),
            ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const BrandLogo(height: 30),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _menu() => Card(
        child: Column(
          children: [
            _tile(Icons.shopping_cart_outlined, 'سلة التسوق', () => Get.toNamed(AppRoutes.cart)),
            _tile(Icons.favorite_border, 'المفضلة', () {
              Get.snackbar('المفضلة', 'الشاشة مرتبطة بـ WishlistController في مشروعك');
            }),
            _tile(Icons.receipt_long_outlined, 'طلباتي', () => Get.toNamed(AppRoutes.orders)),
            _tile(Icons.request_quote_outlined, 'إيصالات السداد',
                () => Get.toNamed(AppRoutes.myReceipts)),
            _tile(Icons.headset_mic_outlined, 'خدمة العملاء', () {
              Get.snackbar('خدمة العملاء', 'افتح واتساب على رقم الدعم من الإعدادات');
            }),

              _appSettingsCard(),
          ],
        ),
      );

  Widget _tile(IconData icon, String label, VoidCallback onTap) => ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        title: Text(label, style: const TextStyle(fontSize: 14)),
        trailing: Icon(Icons.arrow_back_ios_new, size: 14, color: T.muted),
        onTap: onTap,
      );

  Widget _addresses() => SectionCard(
        title: 'عنواني',
        trailing: TextButton.icon(
          onPressed: () async {
            final r = await Get.to(() => const AddressFormScreen());
            if (r != null) await controller.loadAddresses();
          },
          icon: const Icon(Icons.add, size: 16),
          label: const Text('إضافة'),
        ),
        child: Obx(() {
          if (controller.addresses.isEmpty) {
            return Text('لا توجد عناوين محفوظة',
                style: TextStyle(fontSize: 12, color: T.muted));
          }
          return Column(
            children: controller.addresses
                .map((a) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                      title: Text(a.label, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(a.fullAr,
                          style: TextStyle(fontSize: 11.5, color: T.muted)),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, size: 18, color: T.danger),
                        onPressed: () => controller.deleteAddress(a.id),
                      ),
                    ))
                .toList(),
          );
        }),
      );
}


/// بطاقة إعدادات التطبيق: الثيم والإرشادات.
Widget _appSettingsCard() {
  final tc = Get.isRegistered<ThemeController>() ? Get.find<ThemeController>() : null;
  final gc = Get.isRegistered<InteractiveGuideController>()
      ? Get.find<InteractiveGuideController>()
      : null;
  return Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Get.isDarkMode ? const Color(0xFF130F24) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Get.isDarkMode ? const Color(0xFF2D2354) : T.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('إعدادات التطبيق',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (tc != null)
          Obx(() => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: tc.isDark.value,
                title: const Text('الثيم الليلي (أسود)',
                    style: TextStyle(fontSize: 12.5)),
                subtitle: Text(
                    tc.isDark.value ? 'المظهر الحالي: ليلي' : 'المظهر الحالي: نهاري',
                    style: const TextStyle(fontSize: 11)),
                onChanged: (v) => tc.setDark(v),
              )),
        if (gc != null)
          Obx(() => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: gc.enabled.value,
                title: const Text('الإشعارات الإرشادية التفاعلية',
                    style: TextStyle(fontSize: 12.5)),
                subtitle: const Text('بطاقات توضيحية تظهر مرة واحدة لكل صفحة وزر',
                    style: TextStyle(fontSize: 11)),
                onChanged: (v) => gc.setEnabled(v),
              )),
        if (gc != null)
          TextButton.icon(
            onPressed: () {
              gc.reset();
              Get.snackbar('تم', 'سيعرض التطبيق الإرشادات من البداية');
            },
            icon: const Icon(Icons.restart_alt, size: 16),
            label: const Text('إعادة تشغيل الدليل الإرشادي من البداية'),
          ),
      ],
    ),
  );
}


/// صف اختصارات «طلبي»: 5 أيقونات بعدّادات حيّة من Firestore.
class _OrderShortcuts extends StatelessWidget {
  const _OrderShortcuts();

  Stream<Map<String, int>> _counts() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const <String, int>{});
    return FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((s) {
      var unpaid = 0, processing = 0, shipped = 0, refunds = 0;
      for (final d in s.docs) {
        final st = (d.data()['status'] ?? '').toString();
        if (st == 'unpaid') unpaid++;
        if (st == 'processing') processing++;
        if (st == 'shipped') shipped++;
        final list = (d.data()['refunds'] as List?) ?? const [];
        refunds += list.length;
      }
      return <String, int>{
        'unpaid': unpaid,
        'processing': processing,
        'shipped': shipped,
        'refunds': refunds,
      };
    });
  }

  void _go(int tab) {
    if (Get.isRegistered<MainTabController>()) {
      Get.find<MainTabController>().goTo(tab);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: _counts(),
      builder: (context, snap) {
        final c = snap.data ?? const <String, int>{};
        final support = Get.isRegistered<SupportService>()
            ? Get.find<SupportService>()
            : Get.put(SupportService(), permanent: false);
        return StreamBuilder<List<SupportThread>>(
          stream: support.myThreads(),
          builder: (context, ts) {
            final open = (ts.data ?? const <SupportThread>[])
                .where((t) => t.mode != 'closed')
                .length;
            final items = <_Shortcut>[
              _Shortcut('غير مدفوع', Icons.schedule, c['unpaid'] ?? 0,
                  () => _go(3)),
              _Shortcut('قيد التجهيز', Icons.inventory_2_outlined,
                  c['processing'] ?? 0, () => _go(3)),
              _Shortcut('تم الشحن', Icons.local_shipping_outlined,
                  c['shipped'] ?? 0, () => _go(3)),
              _Shortcut('المنتجات المسترجعة',
                  Icons.assignment_return_outlined, c['refunds'] ?? 0,
                  () => _go(3)),
              _Shortcut('خدمة العملاء', Icons.support_agent, open,
                  () => _go(4)),
            ];
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                color: T.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: T.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: Text('طلبي',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: T.text)),
                  ),
                  Row(
                    children: items
                        .map((s) => Expanded(child: _tile(s)))
                        .toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _tile(_Shortcut s) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: s.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: T.soft,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: T.softBorder),
                    ),
                    child: Icon(s.icon, size: 19, color: T.primary),
                  ),
                  if (s.count > 0)
                    Positioned(
                      top: -4,
                      left: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 17),
                        decoration: BoxDecoration(
                          color: T.danger,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: T.card, width: 1.4),
                        ),
                        child: Text('${s.count}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(s.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 8.5, height: 1.3, color: T.muted)),
            ],
          ),
        ),
      );
}

class _Shortcut {
  final String label;
  final IconData icon;
  final int count;
  final VoidCallback onTap;
  const _Shortcut(this.label, this.icon, this.count, this.onTap);
}
