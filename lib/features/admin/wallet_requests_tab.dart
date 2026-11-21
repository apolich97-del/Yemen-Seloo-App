import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/wallet_service.dart';
import '../../core/theme/app_theme.dart';

/// طلبات سحب رصيد المحفظة — للمحاسبة والمدير.
class WalletRequestsTab extends StatelessWidget {
  const WalletRequestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = Get.put(WalletService(), permanent: false);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: svc.requests(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return Center(
              child: Text('لا توجد طلبات سحب',
                  style: TextStyle(fontSize: 12, color: T.muted)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data();
            final id = docs[i].id;
            final status = (d['status'] ?? 'pending') as String;
            final amount = ((d['amountSar'] as num?) ?? 0).toDouble();
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
                    Text('${amount.toStringAsFixed(2)} ر.س',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: T.primary)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: T.soft,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: T.softBorder),
                      ),
                      child: Text(
                          status == 'pending'
                              ? 'بانتظار التحويل'
                              : status == 'done'
                                  ? 'مكتمل'
                                  : 'مرفوض',
                          style: TextStyle(fontSize: 9.5, color: T.muted)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                      '${d['method'] == 'bank' ? 'حوالة بنكية' : 'محفظة إلكترونية'} · ${d['accountName']} · ${d['accountNumber']} · ${d['holderName']}',
                      style: TextStyle(fontSize: 11, color: T.text)),
                  if (status == 'pending')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _complete(svc, id),
                            style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 32)),
                            child: const Text('تأكيد التحويل',
                                style: TextStyle(fontSize: 10.5)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          onPressed: () => svc.rejectRequest(id),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: T.danger,
                              minimumSize: const Size(0, 32)),
                          child: const Text('رفض',
                              style: TextStyle(fontSize: 10.5)),
                        ),
                      ]),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _complete(WalletService svc, String id) {
    final ref = TextEditingController();
    Get.dialog(AlertDialog(
      title: const Text('تأكيد التحويل', style: TextStyle(fontSize: 14)),
      content: TextField(
          controller: ref,
          decoration: const InputDecoration(labelText: 'رقم مرجع الحوالة')),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () async {
            await svc.completeRequest(id, transferRefNo: ref.text.trim());
            Get.back();
            Get.snackbar('تم', 'خُصم الرصيد وسُجّلت الحوالة');
          },
          child: const Text('تأكيد'),
        ),
      ],
    ));
  }
}
