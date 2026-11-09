import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

/// حارس الأدوار — يعرض الشاشة فقط إن كان الدور يملك الصلاحية.
class RoleGuard extends StatelessWidget {
  final List<String> allow;
  final Widget child;
  const RoleGuard({super.key, required this.allow, required this.child});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    return Obx(() {
      final role = auth.user.value?.role ?? 'customer';
      if (!allow.contains(role) && role != 'manager') {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48, color: AppColors.muted),
                const SizedBox(height: 12),
                const Text('لا تملك صلاحية الوصول إلى هذا القسم',
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 4),
                Text('دورك الحالي: $role',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
        );
      }
      return child;
    });
  }
}
