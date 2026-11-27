import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/controllers/profile_controller.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/customer_accounting_service.dart';
import '../../core/services/review_service.dart';
import '../../core/services/wallet_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/currency.dart';
import '../../core/services/saved_accounts_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/theme_controller.dart';
import '../cart/application/cart_counter.dart';
import '../support/presentation/support_screen.dart';
import '../../core/widgets/brand_header.dart';
import '../../core/widgets/brand_logo.dart';
import '../guide/interactive_guide.dart';
import '../home/presentation/main_tab_controller.dart';
import '../support/data/support_models.dart';
import '../support/data/support_service.dart';
import '../wallet/wallet_screen.dart';
import 'address_form_screen.dart';

void _goMainTab(BuildContext context, int tab, {String? ordersFilter}) {
  if (Get.isRegistered<MainTabController>()) {
    final ctrl = Get.find<MainTabController>();
    if (tab == 4 && ordersFilter != null) {
      ctrl.goToOrders(ordersFilter);
    } else {
      ctrl.goTo(tab);
    }
  }
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }
}

/// المرحلة 4 — «حسابي» بنمط SHEIN:
/// شريط 4 خانات (محفظة، إيصال، نقاط، كوبونات) + بانر المحفظة السريع
/// + اختصارات «طلبي» (5 أيقونات مع عدادات حية منها «تعليق»).
class ProfileScreen extends StatelessWidget {
  final bool embedded;
  const ProfileScreen({super.key, this.embedded = false});

  ProfileController get controller => Get.isRegistered<ProfileController>()
      ? Get.find<ProfileController>()
      : Get.put<ProfileController>(ProfileController(), permanent: false);

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final content = Obx(() {
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
                  if (Get.isRegistered<SavedAccountsService>() &&
                      Get.find<SavedAccountsService>().accounts.isNotEmpty) ...[
                    _savedAccountsCard(context, auth, null),
                    const SizedBox(height: 14),
                  ],
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
            _identity(u, auth),
            if (u.isStaff) ...[
              const SizedBox(height: 12),
              SectionCard(
                title: 'بوابة الطاقم والإدارة',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_user_outlined, size: 17, color: T.primary),
                        const SizedBox(width: 6),
                        Text('الصلاحية المفعّلة: ${auth.roleLabelAr}',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: T.primary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => Get.toNamed(AppRoutes.admin),
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: Text('دخول لوحة الإدارة (${auth.roleLabelAr})'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _savedAccountsCard(context, auth, u),
            const SizedBox(height: 12),
            _sheinStatsBar(context),
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller.city,
                          decoration: const InputDecoration(
                            labelText: 'المحافظة / المدينة',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: controller.district,
                          decoration: const InputDecoration(
                            labelText: 'المديرية / الحي (اختياري)',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller.addressLine,
                    decoration: const InputDecoration(
                      labelText: 'العنوان التفصيلي',
                      isDense: true,
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
            _menu(context),
            const SizedBox(height: 12),
            _addresses(),
            if (u.isStaff) ...[
              const SizedBox(height: 12),
              SectionCard(
                title: 'لوحة الإدارة والصلاحيات',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_user_outlined, size: 17, color: T.primary),
                        const SizedBox(width: 6),
                        Text('الدور الحالي: ${auth.roleLabelAr}',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: T.primary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => Get.toNamed(AppRoutes.admin),
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: Text('فتح لوحة الإدارة (${auth.roleLabelAr})'),
                    ),
                  ],
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
      });
    if (embedded) {
      return Container(color: T.bg, child: content);
    }
    return Scaffold(
      backgroundColor: T.bg,
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', height: 26),
            const SizedBox(width: 8),
            Text('me_title'.tr),
          ],
        ),
      ),
      body: content,
    );
  }

  Widget _savedAccountsCard(BuildContext context, AuthService auth, AppUser? current) {
    if (!Get.isRegistered<SavedAccountsService>()) return const SizedBox.shrink();
    final savedSvc = Get.find<SavedAccountsService>();
    return Obx(() {
      final list = savedSvc.accounts;
      return SectionCard(
        title: 'switch_account'.tr,
        trailing: TextButton.icon(
          onPressed: () async {
            try {
              await auth.switchGoogleAccount();
            } catch (_) {
              Get.toNamed(AppRoutes.login);
            }
          },
          icon: const Icon(Icons.swap_horiz_rounded, size: 17),
          label: const Text('تبديل / إضافة'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (list.isEmpty)
              Text(
                'سجّل الدخول بحساباتك ليتم حفظها هنا والتنقل بينها بسهولة.',
                style: TextStyle(fontSize: 11.5, color: T.muted),
              )
            else
              ...list.map((acc) {
                final isCurrent = current?.uid == acc.uid;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCurrent ? T.soft : T.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent ? T.primary : T.border,
                      width: isCurrent ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: T.primary.withOpacity(.16),
                        child: Text(
                          acc.name.isEmpty ? '؟' : acc.name.characters.first,
                          style: TextStyle(
                              fontWeight: FontWeight.w900, color: T.primary),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    acc.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: T.text),
                                  ),
                                ),
                                if (isCurrent) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: T.success.withOpacity(.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('نشط',
                                        style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: T.success)),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              [
                                if (acc.email.isNotEmpty) acc.email,
                                if (acc.phone.isNotEmpty) acc.phone,
                                if (acc.role != 'customer') acc.role,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10.5, color: T.muted),
                            ),
                          ],
                        ),
                      ),
                      if (!isCurrent) ...[
                        TextButton(
                          onPressed: () async {
                            if (acc.email.isNotEmpty) {
                              await auth.switchGoogleAccount();
                            } else {
                              Get.toNamed(AppRoutes.login);
                            }
                          },
                          child: const Text('تبديل', style: TextStyle(fontSize: 11)),
                        ),
                        IconButton(
                          tooltip: 'إزالة من القائمة',
                          icon: Icon(Icons.close, size: 16, color: T.muted),
                          onPressed: () => savedSvc.removeAccount(acc.uid),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      );
    });
  }

  Widget _identity(AppUser u, AuthService auth) => Column(
        children: [
          BrandHeader(
            title: u.displayName.isEmpty ? 'مستخدم جديد' : u.displayName,
            subtitle: u.phone ?? u.email ?? 'يمن سيلو · حسابك',
            badge: u.role == 'customer'
                ? '${u.effectiveCode} · ${u.tier.labelAr}'
                : auth.roleLabelAr,
          ),
          const SizedBox(height: 10),
          Container(
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
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 6),
                      const Text('وسيطك الموثوق للتسوق العالمي',
                          style:
                              TextStyle(fontSize: 10.5, color: Colors.white60)),
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

  /// شريط SHEIN الرباعي: محفظة · إيصال · نقاط · كوبونات + بانر الرصيد المتاح.
  Widget _sheinStatsBar(BuildContext context) {
    final walletSvc = Get.put(WalletService(), permanent: false);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final ordersStream = uid == null
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: uid)
            .snapshots();
    final couponsStream = FirebaseFirestore.instance
        .collection('coupons')
        .where('active', isEqualTo: true)
        .snapshots();

    return StreamBuilder<Map<String, dynamic>?>(
      stream: walletSvc.watch(),
      builder: (context, wSnap) {
        final bal = ((wSnap.data?['balanceSar'] as num?) ?? 0).toDouble();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ordersStream,
          builder: (context, oSnap) {
            final deliveredCount = (oSnap.data?.docs ?? const [])
                .where((d) => (d.data()['status'] ?? '') == 'delivered')
                .length;
            final points = deliveredCount * 15;
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: couponsStream,
              builder: (context, cSnap) {
                final couponDocs = cSnap.data?.docs ?? const [];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: T.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: T.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _statCell(
                              value: 'SAR ${bal.toStringAsFixed(2)}',
                              label: 'محفظة',
                              icon: Icons.account_balance_wallet_outlined,
                              highlight: bal > 0,
                              onTap: () =>
                                  Get.to(() => const WalletScreen()),
                            ),
                          ),
                          Expanded(
                            child: _statCell(
                              value: 'سجل',
                              label: 'إيصال',
                              icon: Icons.receipt_long_outlined,
                              onTap: () => Get.toNamed(AppRoutes.myReceipts),
                            ),
                          ),
                          Expanded(
                            child: _statCell(
                              value: '$points',
                              label: 'نقاط',
                              icon: Icons.stars_outlined,
                              onTap: () => _goMainTab(context, 4,
                                  ordersFilter: 'reviews'),
                            ),
                          ),
                          Expanded(
                            child: _statCell(
                              value: '${couponDocs.length}',
                              label: 'كوبونات',
                              icon: Icons.local_offer_outlined,
                              onTap: () =>
                                  _showCouponsSheet(context, couponDocs),
                            ),
                          ),
                        ],
                      ),
                      if (bal > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: T.soft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: T.softBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.account_balance_wallet,
                                      size: 16, color: T.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'لديك رصيد متاح: ${bal.toStringAsFixed(2)} ر.س — يمكنك استخدامه في طلبك أو طلب سحبه',
                                      style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: T.text),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Get.to(
                                          () => const WalletScreen()),
                                      style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 34)),
                                      child: const Text('طلب سحب نقدي',
                                          style: TextStyle(fontSize: 11)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          _goMainTab(context, 1),
                                      style: ElevatedButton.styleFrom(
                                          minimumSize: const Size(0, 34)),
                                      child: const Text('استخدم في طلب',
                                          style: TextStyle(fontSize: 11)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _statCell({
    required String value,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool highlight = false,
  }) =>
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            children: [
              Icon(icon, size: 19, color: highlight ? T.success : T.primary),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: highlight ? T.success : T.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: T.muted)),
            ],
          ),
        ),
      );

  void _showCouponsSheet(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الكوبونات المتاحة',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900, color: T.text)),
            const SizedBox(height: 4),
            Text('اضغط على أي كوبون لنسخه واستخدامه عند الدفع',
                style: TextStyle(fontSize: 11, color: T.muted)),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('لا توجد كوبونات فعّالة حالياً',
                      style: TextStyle(fontSize: 12, color: T.muted)),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    final type = (d['type'] ?? 'percent') as String;
                    final val = ((d['value'] as num?) ?? 0).toDouble();
                    final minSar =
                        ((d['minOrderSar'] as num?) ?? 0).toDouble();
                    final desc = type == 'percent'
                        ? 'خصم ${val.toStringAsFixed(0)}%'
                        : 'خصم ${val.toStringAsFixed(2)} ر.س';
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: doc.id));
                        Get.back();
                        Get.snackbar('تم النسخ', 'تم نسخ الكود ${doc.id}');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: T.soft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: T.softBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.local_offer_outlined,
                                size: 18, color: T.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(doc.id,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: T.primary)),
                                  Text(
                                    minSar > 0
                                        ? '$desc · للطلبات فوق ${minSar.toStringAsFixed(0)} ر.س'
                                        : desc,
                                    style: TextStyle(
                                        fontSize: 11, color: T.muted),
                                  ),
                                ],
                              ),
                            ),
                            Text('نسخ',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: T.primary)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _menu(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: T.border),
        ),
        child: Column(
          children: [
            _tile(Icons.notifications_none_rounded, 'notifications'.tr,
                () => Get.toNamed(AppRoutes.notifications)),
            _tile(Icons.shopping_cart_outlined, 'سلة التسوق',
                () => Get.toNamed(AppRoutes.cart)),
            _tile(Icons.account_balance_wallet_outlined, 'محفظتي والسحب النقدي',
                () => Get.to(() => const WalletScreen())),
            _tile(Icons.receipt_long_outlined, 'طلباتي',
                () => _goMainTab(context, 4, ordersFilter: 'all')),
            _tile(Icons.rate_review_outlined, 'تعليقاتي وتقييم الطلبات',
                () => _goMainTab(context, 4, ordersFilter: 'reviews')),
            _tile(Icons.account_balance_outlined, 'كشف الحساب المحاسبي والوثائق',
                () => Get.toNamed(AppRoutes.accountStatement)),
            _tile(Icons.request_quote_outlined, 'إيصالات السداد',
                () => Get.toNamed(AppRoutes.myReceipts)),
            _tile(Icons.headset_mic_outlined, 'خدمة العملاء',
                () => Get.to(() => const SupportScreen())),
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
        title: Text(label, style: TextStyle(fontSize: 14, color: T.text)),
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
                      leading: const Icon(Icons.location_on_outlined,
                          color: AppColors.primary),
                      title:
                          Text(a.label, style: TextStyle(fontSize: 13, color: T.text)),
                      subtitle: Text(a.fullAr,
                          style: TextStyle(fontSize: 11.5, color: T.muted)),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: T.danger),
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
  final tc =
      Get.isRegistered<ThemeController>() ? Get.find<ThemeController>() : null;
  final gc = Get.isRegistered<InteractiveGuideController>()
      ? Get.find<InteractiveGuideController>()
      : null;
  final ss =
      Get.isRegistered<SettingsService>() ? Get.find<SettingsService>() : null;
  final cc = Get.isRegistered<CartCounter>() ? Get.find<CartCounter>() : null;
  return Obx(() {
    final bool isDark = tc?.isDark.value ?? T.dark;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppDark.card : T.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF2D2354) : T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('إعدادات الواجهة واللغة والعملة',
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w900, color: T.text)),
          const SizedBox(height: 10),
          if (ss != null) ...[
            Text('language'.tr,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: T.muted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('العربية'),
                  selected: ss.languageCode.value == 'ar',
                  onSelected: (_) => ss.setLanguage('ar'),
                ),
                ChoiceChip(
                  label: const Text('English'),
                  selected: ss.languageCode.value == 'en',
                  onSelected: (_) => ss.setLanguage('en'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('currency'.tr,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: T.muted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: AppCurrency.values.map((c) {
                final on = ss.displayCurrency.value == c;
                return ChoiceChip(
                  label: Text(c.labelAr, style: const TextStyle(fontSize: 11)),
                  selected: on,
                  onSelected: (_) {
                    ss.setCurrency(c);
                    cc?.setRegion(c == AppCurrency.sar ? 'saudi' : c.key);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Divider(color: T.border),
          ],
          if (tc != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: tc.isDark.value,
              title: Text('الثيم الليلي (أسود)',
                  style: TextStyle(fontSize: 12.5, color: T.text)),
              subtitle: Text(
                  tc.isDark.value
                      ? 'المظهر الحالي: ليلي'
                      : 'المظهر الحالي: نهاري',
                  style: TextStyle(fontSize: 11, color: T.muted)),
              onChanged: (v) => tc.setDark(v),
            ),
          if (gc != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: gc.enabled.value,
              title: Text('الإشعارات الإرشادية التفاعلية',
                  style: TextStyle(fontSize: 12.5, color: T.text)),
              subtitle: Text(
                  'بطاقات توضيحية تظهر مرة واحدة لكل صفحة وزر',
                  style: TextStyle(fontSize: 11, color: T.muted)),
              onChanged: (v) => gc.setEnabled(v),
            ),
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
  });
}

/// صف اختصارات «طلبي» بنمط SHEIN:
/// 5 أيقونات (غير مدفوع · قيد التجهيز · تم الشحن · تعليق · المنتجات المسترجعة)
/// + شريط خدمة العملاء والإيصال.
class _OrderShortcuts extends StatelessWidget {
  const _OrderShortcuts();

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final reviewSvc = Get.put(ReviewService(), permanent: false);
    final support = Get.isRegistered<SupportService>()
        ? Get.find<SupportService>()
        : Get.put(SupportService(), permanent: false);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ordersStream(),
      builder: (context, oSnap) {
        final orderDocs = oSnap.data?.docs ?? const [];
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: reviewSvc.mine(),
          builder: (context, rSnap) {
            final reviewedIds = (rSnap.data?.docs ?? const [])
                .map((d) => (d.data()['orderId'] ?? '') as String)
                .toSet();
            var unpaid = 0,
                processing = 0,
                shipped = 0,
                pendingReviews = 0,
                refunds = 0;
            for (final d in orderDocs) {
              final data = d.data();
              final st = (data['status'] ?? '').toString();
              if (st == 'unpaid' || st == 'verifying') unpaid++;
              if (st == 'processing') processing++;
              if (st == 'shipped' || st == 'outForDelivery') shipped++;
              if (st == 'delivered' && !reviewedIds.contains(d.id)) {
                pendingReviews++;
              }
              final list = (data['refunds'] as List?) ?? const [];
              refunds += list.length;
            }

            return StreamBuilder<List<SupportThread>>(
              stream: support.myThreads(),
              builder: (context, ts) {
                final open = (ts.data ?? const <SupportThread>[])
                    .where((t) => t.mode != 'closed')
                    .length;

                final items = <_Shortcut>[
                  _Shortcut(
                    'غير مدفوع',
                    Icons.credit_card_outlined,
                    unpaid,
                    () => _goMainTab(context, 4, ordersFilter: 'unpaid'),
                  ),
                  _Shortcut(
                    'قيد التجهيز',
                    Icons.inventory_2_outlined,
                    processing,
                    () => _goMainTab(context, 4, ordersFilter: 'processing'),
                  ),
                  _Shortcut(
                    'تم الشحن',
                    Icons.local_shipping_outlined,
                    shipped,
                    () => _goMainTab(context, 4, ordersFilter: 'shipped'),
                  ),
                  _Shortcut(
                    'تعليق',
                    Icons.chat_bubble_outline,
                    pendingReviews,
                    () => _goMainTab(context, 4, ordersFilter: 'reviews'),
                  ),
                  _Shortcut(
                    'المنتجات المسترجعة',
                    Icons.assignment_return_outlined,
                    refunds,
                    () => _goMainTab(context, 4, ordersFilter: 'refunds'),
                  ),
                ];

                return Container(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
                  decoration: BoxDecoration(
                    color: T.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: T.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                        child: Row(
                          children: [
                            Text('طلبي',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: T.text)),
                            const Spacer(),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _goMainTab(context, 4,
                                  ordersFilter: 'all'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('عرض الكل',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: T.muted)),
                                    Icon(Icons.chevron_left,
                                        size: 16, color: T.muted),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: items
                            .map((s) => Expanded(child: _tile(s)))
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      Divider(color: T.border, height: 1),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => Get.to(() => const SupportScreen()),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.support_agent,
                                        size: 16, color: T.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      open > 0
                                          ? 'خدمة العملاء ($open)'
                                          : 'خدمة العملاء',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: T.text),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(
                              width: 1, height: 18, color: T.border),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => Get.toNamed(AppRoutes.myReceipts),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_outlined,
                                        size: 16, color: T.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'إيصال وسجل الدفعات',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: T.text),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
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
