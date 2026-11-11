import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/profile_controller.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

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
                  const Text('وسيطك الموثوق للتسوق العالمي',
                      style: TextStyle(fontSize: 12, color: AppColors.muted)),
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
              icon: const Icon(Icons.logout, color: AppColors.danger, size: 18),
              label: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.danger)),
            ),
            const SizedBox(height: 24),
          ],
        );
      }),
    );
  }

  Widget _identity(AppUser u) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
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
                (u.displayName.isEmpty ? '؟' : u.displayName.characters.first),
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
                  Text(u.displayName.isEmpty ? 'مستخدم جديد' : u.displayName,
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
              child: Image.asset('assets/images/logo.png', height: 30),
            ),
          ],
        ),
      );

  Widget _menu() => Card(
        child: Column(
          children: [
            _tile(Icons.shopping_cart_outlined, 'سلة التسوق', () => Get.toNamed(AppRoutes.cart)),
            _tile(Icons.favorite_border, 'المفضلة', () {
              Get.snackbar('المفضلة', 'الشاشة مرتبطة بـ WishlistController في مشروعك');
            }),
            _tile(Icons.receipt_long_outlined, 'طلباتي', () => Get.toNamed(AppRoutes.orders)),
            _tile(Icons.headset_mic_outlined, 'خدمة العملاء', () {
              Get.snackbar('خدمة العملاء', 'افتح واتساب على رقم الدعم من الإعدادات');
            }),
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
        trailing: const Icon(Icons.arrow_back_ios_new, size: 14, color: AppColors.muted),
        onTap: onTap,
      );

  Widget _addresses() => SectionCard(
        title: 'عنواني',
        trailing: TextButton.icon(
          onPressed: controller.addAddress,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('إضافة'),
        ),
        child: Obx(() {
          if (controller.addresses.isEmpty) {
            return const Text('لا توجد عناوين محفوظة',
                style: TextStyle(fontSize: 12, color: AppColors.muted));
          }
          return Column(
            children: controller.addresses
                .map((a) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                      title: Text(a.label, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(a.fullAr,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                        onPressed: () => controller.deleteAddress(a.id),
                      ),
                    ))
                .toList(),
          );
        }),
      );
}
