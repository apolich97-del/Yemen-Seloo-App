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
      appBar: AppBar(title: const Text('حسابي')),
      body: Obx(() {
        final u = auth.user.value;
        if (u == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_outline, size: 64, color: AppColors.muted),
                const SizedBox(height: 12),
                const Text('سجّل الدخول لإدارة حسابك وطلباتك'),
                const SizedBox(height: 16),
                SizedBox(
                  width: 220,
                  child: ElevatedButton(
                    onPressed: () => Get.toNamed(AppRoutes.login),
                    child: const Text('تسجيل الدخول'),
                  ),
                ),
              ],
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

  Widget _identity(AppUser u) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withOpacity(.12),
                child: Text(
                  (u.displayName.isEmpty ? '؟' : u.displayName.characters.first),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.displayName.isEmpty ? 'مستخدم جديد' : u.displayName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(u.phone ?? u.email ?? '',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
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
        leading: Icon(icon, size: 20, color: AppColors.primary),
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
