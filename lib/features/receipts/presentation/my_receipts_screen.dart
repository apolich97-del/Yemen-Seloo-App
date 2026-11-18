import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/currency.dart';
import '../../../core/models/receipt.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/order_documents.dart';
import '../../../core/services/order_service.dart';
import '../../../core/services/receipt_service.dart';
import '../../../core/theme/app_theme.dart';

/// «إيصالاتي»: كل إيصالات سداد العميل مع حالتها وإمكانية تنزيل PDF.
class MyReceiptsScreen extends StatelessWidget {
  const MyReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<ReceiptService>();
    final uid = Get.find<AuthService>().uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('إيصالات السداد')),
      body: uid.isEmpty
          ? const Center(child: Text('سجّل الدخول لعرض إيصالاتك'))
          : StreamBuilder<List<Receipt>>(
              stream: svc.byCustomer(uid),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text('تعذر تحميل الإيصالات',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, color: T.muted)),
                    ),
                  );
                }
                final list = snap.data ?? const <Receipt>[];
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 54, color: T.muted),
                          const SizedBox(height: 10),
                          Text('لا توجد إيصالات بعد',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: T.text)),
                          const SizedBox(height: 6),
                          Text(
                            'عند رفع صورة حوالة من تفاصيل الطلب يظهر الإيصال هنا '
                            'بحالته: قيد المراجعة أو معتمد أو مرفوض.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11.5, height: 1.6, color: T.muted),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _row(context, list[i]),
                );
              },
            ),
    );
  }

  Widget _row(BuildContext context, Receipt r) {
    final Color color = r.isApproved
        ? AppColors.success
        : r.isRejected
            ? AppColors.danger
            : const Color(0xFFB26A00);

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
          Row(
            children: [
              Expanded(
                child: Text(r.receiptNo,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: T.text)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withOpacity(.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(r.statusAr,
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: color)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'الطلب ${r.orderNo} · ${formatMoney(r.amountLocal, AppCurrency.sar)}',
            style: TextStyle(fontSize: 11.5, color: T.muted),
          ),
          if (r.senderName.isNotEmpty)
            Text('المرسل: ${r.senderName}',
                style: TextStyle(fontSize: 11, color: T.muted)),
          if (r.isApproved)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  try {
                    final order =
                        await Get.find<OrderService>().fetchOrder(r.orderId);
                    if (order == null) {
                      Get.snackbar('غير متاح', 'تعذر جلب الطلب');
                      return;
                    }
                    final f =
                        await ReceiptDocuments.buildReceiptPdf(order, r);
                    await Share.shareXFiles([XFile(f.path)],
                        text: 'إيصال ${r.receiptNo} — يمن سيلو');
                  } catch (e) {
                    Get.snackbar('تعذر إنشاء PDF', '$e');
                  }
                },
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('تنزيل PDF'),
              ),
            ),
        ],
      ),
    );
  }
}
