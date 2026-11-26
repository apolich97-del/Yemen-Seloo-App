import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import 'role_guard.dart';

/// سجل التدقيق وأرشيف المحذوفات — مخصص للمدير فقط.
class AuditTab extends StatelessWidget {
  const AuditTab({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allow: ['manager'],
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              color: T.surface,
              child: TabBar(
                labelColor: T.primary,
                unselectedLabelColor: T.muted,
                indicatorColor: T.primary,
                tabs: const [
                  Tab(text: 'أرشيف المحذوفات'),
                  Tab(text: 'سجل التدقيق والعمليات'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _DeletedArchiveList(),
                  _AuditLogsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeletedArchiveList extends StatelessWidget {
  const _DeletedArchiveList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('deleted_records')
          .orderBy('deletedAt', descending: true)
          .limit(60)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text('لا توجد سجلات محذوفة',
                style: TextStyle(fontSize: 13, color: T.muted)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final m = docs[i].data();
            final col = (m['collection'] ?? '').toString();
            final docId = (m['docId'] ?? '').toString();
            final summary = (m['summary'] ?? '').toString();
            final reason = (m['reason'] ?? '').toString();
            final byEmail = (m['deletedByEmail'] ?? '').toString();
            final snapshot = (m['snapshot'] is Map)
                ? Map<String, dynamic>.from(m['snapshot'] as Map)
                : <String, dynamic>{};
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.delete_sweep_outlined,
                            size: 18, color: T.danger),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            summary.isEmpty ? '$col / $docId' : summary,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: T.text),
                          ),
                        ),
                      ],
                    ),
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('السبب: $reason',
                          style: TextStyle(fontSize: 11.5, color: T.warning)),
                    ],
                    const SizedBox(height: 4),
                    Text('بواسطة: $byEmail · المجموعة: $col',
                        style: TextStyle(fontSize: 10.5, color: T.muted)),
                    if (col == 'orders' && snapshot.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              await FirebaseFirestore.instance
                                  .collection(col)
                                  .doc(docId)
                                  .set(snapshot, SetOptions(merge: true));
                              Get.snackbar('تمت الاستعادة ✓',
                                  'أُعيدت بيانات $docId بنجاح');
                            } catch (e) {
                              Get.snackbar('تعذرت الاستعادة', '$e');
                            }
                          },
                          icon: const Icon(Icons.restore, size: 15),
                          label: const Text('استعادة السجل',
                              style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AuditLogsList extends StatelessWidget {
  const _AuditLogsList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('audit_logs')
          .orderBy('at', descending: true)
          .limit(80)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text('لا توجد عمليات مسجلة بعد',
                style: TextStyle(fontSize: 13, color: T.muted)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) {
            final m = docs[i].data();
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: T.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: T.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((m['summary'] ?? m['action'] ?? '').toString(),
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: T.text)),
                  const SizedBox(height: 3),
                  Text(
                    '${m['actorEmail'] ?? ''} (${m['actorRole'] ?? ''}) · ${m['collection'] ?? ''}/${m['docId'] ?? ''}',
                    style: TextStyle(fontSize: 10.5, color: T.muted),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
