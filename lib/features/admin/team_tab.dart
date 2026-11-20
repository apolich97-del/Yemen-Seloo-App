import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

/// توزيع أدوار الفريق ديناميكياً — للمدير الرئيسي فقط.
/// السجل يُحفظ في staff_invites/{email} ويُطبَّق تلقائياً عند دخول الموظف.
class TeamTab extends StatelessWidget {
  const TeamTab({super.key});

  static const List<MapEntry<String, String>> _roles = <MapEntry<String, String>>[
    MapEntry('manager', 'مدير'),
    MapEntry('marketer', 'مسوّق الكتالوج'),
    MapEntry('accounting', 'محاسب'),
    MapEntry('shipping', 'مسؤول شحن'),
    MapEntry('support', 'خدمة عملاء'),
    MapEntry('courier', 'مندوب توصيل'),
    MapEntry('customer', 'عميل (بلا صلاحيات)'),
  ];

  static String labelFor(String key) {
    for (final e in _roles) {
      if (e.key == key) return e.value;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.isRegistered<AuthService>() ? Get.find<AuthService>() : null;
    if (auth == null || !auth.isMainManager) {
      return Scaffold(
        appBar: AppBar(title: const Text('توزيع أدوار الفريق')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: T.muted),
                const SizedBox(height: 12),
                Text(
                  'توزيع الأدوار متاح للمدير الرئيسي فقط',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: T.text),
                ),
                const SizedBox(height: 4),
                Text(
                  'راجع المدير الرئيسي لتغيير دورك أو صلاحياتك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: T.muted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('توزيع أدوار الفريق'),
        actions: [
          IconButton(
            tooltip: 'إضافة موظف',
            icon: Icon(Icons.person_add_alt_1, color: T.primary),
            onPressed: () => _openAddDialog(auth),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('staff_invites')
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('تعذر تحميل الفريق\n${snap.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: T.muted)),
              ),
            );
          }
          final docs = snap.data?.docs ?? const [];
          final staff = docs
              .map((d) => d.data() as Map<String, dynamic>)
              .where((m) => (m['email'] ?? '') != '')
              .toList()
            ..sort((a, b) => (a['name'] ?? '')
                .toString()
                .compareTo((b['name'] ?? '').toString()));

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: T.soft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: T.softBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 15, color: T.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'أضف الموظف ببريده ودوره. عند دخوله بالبريد نفسه '
                        'يُمنح الصلاحية تلقائياً.',
                        style: TextStyle(
                            fontSize: 10.5, height: 1.6, color: T.text),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // المديران الرئيسيان — محميان من الإزالة
              ...AuthService.mainManagerEmails.map((email) => _memberCard(
                    name: 'مدير رئيسي',
                    email: email,
                    role: 'manager',
                    protectedMember: true,
                  )),
              const SizedBox(height: 4),
              Text('الموظفون (${staff.length})',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: T.muted)),
              const SizedBox(height: 8),
              if (staff.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('لا يوجد موظفون مضافون بعد',
                        style: TextStyle(fontSize: 12, color: T.muted)),
                  ),
                )
              else
                ...staff.map((m) => _memberCard(
                      name: (m['name'] ?? '').toString(),
                      email: (m['email'] ?? '').toString(),
                      role: (m['role'] ?? 'customer').toString(),
                      protectedMember: false,
                    )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openAddDialog(auth),
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: const Text('إضافة موظف بالبريد'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _memberCard({
    required String name,
    required String email,
    required String role,
    required bool protectedMember,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: protectedMember ? T.softBorder : T.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: T.soft,
                  child: Text(
                    name.trim().isEmpty
                        ? '؟'
                        : name.trim().characters.first,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: T.primary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? 'بدون اسم' : name,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: T.text)),
                      Text(email,
                          style:
                              TextStyle(fontSize: 10.5, color: T.muted)),
                    ],
                  ),
                ),
                if (protectedMember)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: T.soft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: T.softBorder),
                    ),
                    child: Text('محمي',
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: T.primary)),
                  )
                else
                  IconButton(
                    tooltip: 'إزالة من الفريق',
                    icon: Icon(Icons.person_remove_outlined,
                        size: 18, color: AppColors.danger),
                    onPressed: () => _confirmRemove(email),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (protectedMember)
              Text('المدير الرئيسي يملك كل الصلاحيات دائماً.',
                  style: TextStyle(fontSize: 10, color: T.muted))
            else
              DropdownButtonFormField<String>(
                value: _roles.any((e) => e.key == role) ? role : 'customer',
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'الدور', isDense: true),
                items: _roles
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value,
                              style: TextStyle(
                                  fontSize: 11.5, color: T.text)),
                        ))
                    .toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  try {
                    if (v == 'customer') {
                      await Get.find<AuthService>().removeStaff(email);
                      Get.snackbar('تم', 'أُزيل $email من الفريق');
                    } else {
                      await Get.find<AuthService>().upsertStaff(
                          name: name, email: email, role: v);
                      Get.snackbar('تم', 'دور $email أصبح: ${labelFor(v)}');
                    }
                  } catch (e) {
                    Get.snackbar('تعذر الحفظ', '$e');
                  }
                },
              ),
          ],
        ),
      );

  Future<void> _confirmRemove(String email) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('إزالة من الفريق؟'),
        content: Text(
            'سيُحذف $email من قائمة الفريق ويُعاد إلى دور عميل عادي فوراً.',
            style: const TextStyle(fontSize: 12)),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger),
            onPressed: () => Get.back(result: true),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Get.find<AuthService>().removeStaff(email);
      Get.snackbar('تمت الإزالة', 'سُحبت صلاحيات $email');
    } catch (e) {
      Get.snackbar('تعذر الإزالة', '$e');
    }
  }

  Future<void> _openAddDialog(AuthService auth) async {
    final name = TextEditingController();
    final email = TextEditingController();
    var role = 'support';

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('إضافة موظف',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                    labelText: 'اسم الموظف', isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني', isDense: true),
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setLocal) => DropdownButtonFormField<String>(
                  value: role,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'الدور', isDense: true),
                  items: _roles
                      .where((e) => e.key != 'customer')
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value,
                                style: TextStyle(
                                    fontSize: 11.5, color: T.text)),
                          ))
                      .toList(),
                  onChanged: (v) => setLocal(() => role = v ?? role),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Get.back(result: true),
              child: const Text('إضافة')),
        ],
      ),
    );
    if (ok != true) return;

    final e = email.text.trim().toLowerCase();
    if (e.isEmpty || !e.contains('@')) {
      Get.snackbar('بريد غير صحيح', 'أدخل بريداً إلكترونياً صالحاً');
      return;
    }
    try {
      await auth.upsertStaff(name: name.text, email: e, role: role);
      Get.snackbar('تمت الإضافة',
          'سيحصل $e على دور «${labelFor(role)}» عند تسجيل الدخول');
    } catch (err) {
      Get.snackbar('تعذر الإضافة', '$err');
    }
  }
}
