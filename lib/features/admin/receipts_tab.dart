import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/currency.dart';
import '../../core/models/order.dart';
import '../../core/models/receipt.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/order_documents.dart';
import '../../core/services/order_service.dart';
import '../../core/services/receipt_service.dart';
import '../../core/theme/app_theme.dart';

/// تبويب «إيصال»: مراجعة إيصالات العملاء وإصدار إيصالات مباشرة.
class ReceiptsTab extends StatefulWidget {
  const ReceiptsTab({super.key});

  @override
  State<ReceiptsTab> createState() => _ReceiptsTabState();
}

class _ReceiptsTabState extends State<ReceiptsTab> {
  final _svc = Get.find<ReceiptService>();
  final _orders = Get.find<OrderService>();
  final _amount = TextEditingController();
  final _ref = TextEditingController();
  final _sender = TextEditingController();
  final _note = TextEditingController();
  Order? _picked;

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    _sender.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _card('إيصالات العملاء بانتظار المراجعة', _pendingList()),
        const SizedBox(height: 14),
        _card('إصدار إيصال مباشر من الإدارة', _issueForm()),
        const SizedBox(height: 14),
        _card('آخر الإيصالات المعتمدة', _approvedList()),
      ],
    );
  }

  Widget _card(String title, Widget child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: T.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );

  Widget _pendingList() => StreamBuilder<List<Receipt>>(
        stream: _svc.pending(),
        builder: (context, snap) {
          final list = snap.data ?? const <Receipt>[];
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (list.isEmpty) {
            return const Text('لا توجد إيصالات بانتظار المراجعة',
                style: TextStyle(fontSize: 12, color: AppColors.muted));
          }
          return Column(
            children: list.map((r) => _pendingRow(r)).toList(),
          );
        },
      );

  Widget _pendingRow(Receipt r) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${r.receiptNo} · ${r.orderNo}',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text(formatMoney(r.amountLocal, AppCurrency.north),
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark)),
              ],
            ),
            const SizedBox(height: 4),
            Text('المرسل: ${r.senderName} · المرجع: ${r.refNo}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
            if (r.proofUrl.isNotEmpty) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                    base64Decode(r.proofUrl.substring(r.proofUrl.indexOf(',') + 1)),
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approve(r),
                    child: const Text('مطابق — اعتماد وخصم'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _reject(r),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger),
                    child: const Text('رفض'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _issueForm() => StreamBuilder<List<Order>>(
        stream: allOrdersStream(),
        builder: (context, snap) {
          final list = (snap.data ?? const <Order>[])
              .where((o) => o.remainingLocal > 0.5)
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<Order>(
                value: _picked,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الطلب'),
                items: list
                    .map((o) => DropdownMenuItem(
                          value: o,
                          child: Text(
                              '${o.orderNo} · متبقٍ ${formatMoney(o.remainingLocal, o.currency)}',
                              style: const TextStyle(fontSize: 12)),
                        ))
                    .toList(),
                onChanged: (o) => setState(() => _picked = o),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المبلغ المستلم'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _sender,
                decoration: const InputDecoration(labelText: 'اسم المحوِّل'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ref,
                decoration:
                    const InputDecoration(labelText: 'رقم العملية (اختياري)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'ملاحظة'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _issueAdmin,
                icon: const Icon(Icons.receipt_long),
                label: const Text('اعتماد الإيصال وخصم المبلغ'),
              ),
            ],
          );
        },
      );

  Widget _approvedList() => StreamBuilder<List<Receipt>>(
        stream: _svc.approved(),
        builder: (context, snap) {
          final list = snap.data ?? const <Receipt>[];
          if (list.isEmpty) {
            return const Text('لا توجد إيصالات معتمدة بعد',
                style: TextStyle(fontSize: 12, color: AppColors.muted));
          }
          return Column(
            children: list.take(20).map((r) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${r.receiptNo} · ${r.orderNo}',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${formatMoney(r.amountLocal, AppCurrency.north)} · متبقٍ ${formatMoney(r.remainingAfterLocal, AppCurrency.north)}',
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'إيصال PDF',
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      onPressed: () async {
                        final order = await _orders.fetchOrder(r.orderId);
                        if (order == null) return;
                        final f = await ReceiptDocuments.buildReceiptPdf(order, r);
                        await Share.shareXFiles([XFile(f.path)],
                            text: 'إيصال ${r.receiptNo} — يمن سيلو');
                      },
                    ),
                    IconButton(
                      tooltip: 'مشاركة واتساب',
                      icon: const Icon(Icons.share_outlined, size: 18),
                      onPressed: () async {
                        final order = await _orders.fetchOrder(r.orderId);
                        if (order == null) return;
                        await OrderDocuments.shareWhatsApp(order);
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      );

  Future<void> _approve(Receipt r) async {
    final order = await _orders.fetchOrder(r.orderId);
    if (order == null) return;
    try {
      await _svc.approve(
        order: order,
        receipt: r,
        reviewer: Get.find<AuthService>().uid ?? '',
      );
      Get.snackbar('تم الاعتماد', 'خُصم المبلغ من المتبقي وأُشعر العميل');
    } catch (e) {
      Get.snackbar('تعذر الاعتماد', '$e');
    }
  }

  Future<void> _reject(Receipt r) async {
    final reason = TextEditingController();
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('سبب الرفض'),
        content: TextField(controller: reason, maxLines: 2),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Get.back(result: true), child: const Text('رفض')),
        ],
      ),
    );
    if (ok != true) return;
    final order = await _orders.fetchOrder(r.orderId);
    if (order == null) return;
    await _svc.reject(
      order: order,
      receipt: r,
      reason: reason.text.trim(),
      reviewer: Get.find<AuthService>().uid ?? '',
    );
    Get.snackbar('تم الرفض', 'لم يُعدّل رصيد الطلب');
  }

  Future<void> _issueAdmin() async {
    final o = _picked;
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (o == null || amount <= 0) {
      Get.snackbar('بيانات ناقصة', 'اختر الطلب وأدخل المبلغ المستلم');
      return;
    }
    try {
      final no = await _svc.create(
        order: o,
        amountLocal: amount,
        refNo: _ref.text.trim(),
        senderName: _sender.text.trim(),
        note: _note.text.trim().isEmpty ? 'إيصال من المحاسبة' : _note.text.trim(),
        proofUrl: '',
        source: 'admin',
      );
      final fresh = await _orders.fetchOrder(o.id);
      if (fresh != null) {
        final created = await _svc.byReceiptNo(o.id, no);
        if (created != null) await _svc.approve(order: fresh, receipt: created);
      }
      _amount.clear();
      _ref.clear();
      _sender.clear();
      _note.clear();
      setState(() => _picked = null);
      Get.snackbar('تم', 'أُصدر الإيصال $no وتم الخصم من المتبقي');
    } catch (e) {
      Get.snackbar('تعذر الإصدار', '$e');
    }
  }
}
