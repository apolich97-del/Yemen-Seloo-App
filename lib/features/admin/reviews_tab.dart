import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/review_service.dart';
import '../../core/theme/app_theme.dart';

/// «آراء العملاء»: مراجعة التقييمات قبل نشرها.
class AdminReviewsTab extends StatelessWidget {
  const AdminReviewsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = Get.put(ReviewService(), permanent: false);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: svc.pending(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return Center(
              child: Text('لا توجد تقييمات بانتظار المراجعة',
                  style: TextStyle(fontSize: 12, color: T.muted)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data();
            final id = docs[i].id;
            final photo = (d['photoUrl'] ?? '') as String;
            final rating = ((d['rating'] as num?) ?? 0).toInt();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: T.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: T.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('${d['orderNo'] ?? ''}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: T.primary)),
                    const Spacer(),
                    Row(
                      children: List.generate(
                          5,
                          (s) => Icon(
                              s < rating ? Icons.star : Icons.star_border,
                              size: 13,
                              color: T.warning)),
                    ),
                  ]),
                  if (((d['text'] ?? '') as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(d['text'] as String,
                          style: TextStyle(fontSize: 11.5, color: T.text)),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        '${d['governorate'] ?? ''} · ${d['customerName'] ?? ''}',
                        style: TextStyle(fontSize: 10, color: T.muted)),
                  ),
                  if (photo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: InkWell(
                        onTap: () => Get.dialog(Dialog(
                          child: InteractiveViewer(
                            child: Image.memory(
                                base64Decode(photo.split(',').last)),
                          ),
                        )),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                              base64Decode(photo.split(',').last),
                              height: 90,
                              width: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox()),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _reply(svc, id),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 32)),
                        child: const Text('رد واعتماد',
                            style: TextStyle(fontSize: 10.5)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      onPressed: () => svc.moderate(id, 'rejected'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: T.danger,
                          minimumSize: const Size(0, 32)),
                      child: const Text('رفض',
                          style: TextStyle(fontSize: 10.5)),
                    ),
                  ]),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _reply(ReviewService svc, String id) {
    final c = TextEditingController();
    Get.dialog(AlertDialog(
      title: const Text('رد الإدارة', style: TextStyle(fontSize: 14)),
      content: TextField(
          controller: c,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'نص الرد (اختياري)')),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () async {
            await svc.moderate(id, 'approved', reply: c.text.trim());
            Get.back();
            Get.snackbar('تم', 'نُشر التقييم في الصفحة الرئيسية');
          },
          child: const Text('اعتماد النشر'),
        ),
      ],
    ));
  }
}
