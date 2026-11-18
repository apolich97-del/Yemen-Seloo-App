import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';

/// توزيع أدوار الفريق: يضبط users/{uid}.role لكل موظف.
class TeamTab extends StatelessWidget {
  const TeamTab({super.key});

  static const List<MapEntry<String, String>> _roles = <MapEntry<String, String>>[
    MapEntry('customer', 'عميل'),
    MapEntry('manager', 'مدير'),
    MapEntry('accounting', 'محاسب'),
    MapEntry('shipping', 'شحن'),
    MapEntry('courier', 'مندوب توصيل'),
    MapEntry('support', 'خدمة عملاء'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('توزيع أدوار الفريق')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').limit(200).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('تعذر تحميل المستخدمين\n${snap.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: T.muted)),
              ),
            );
          }
          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(
                child: Text('لا يوجد مستخدمون بعد',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i];
              final m = d.data() as Map<String, dynamic>;
              final name = '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim();
              final email = (m['email'] ?? '') as String;
              final role = (m['role'] ?? 'customer') as String;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: T.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: T.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name.isEmpty ? 'بدون اسم' : name,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: T.text)),
                          if (email.isNotEmpty)
                            Text(email,
                                style:
                                    TextStyle(fontSize: 10.5, color: T.muted)),
                        ],
                      ),
                    ),
                    DropdownButton<String>(
                      value: _roles.any((e) => e.key == role) ? role : 'customer',
                      underline: const SizedBox(),
                      items: _roles
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value,
                                    style: const TextStyle(fontSize: 11.5)),
                              ))
                          .toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        try {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(d.id)
                              .set({'role': v}, SetOptions(merge: true));
                          Get.snackbar('تم', 'حُدِّث دور الموظف');
                        } catch (e) {
                          Get.snackbar('تعذر الحفظ', '$e');
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
