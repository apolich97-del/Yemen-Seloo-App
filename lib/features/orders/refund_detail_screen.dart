import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/models/currency.dart';
import '../../core/models/order.dart';
import '../../core/models/refund.dart';
import '../../core/theme/app_theme.dart';
import '../home/presentation/main_tab_controller.dart';

/// شاشة تفاصيل استرداد مبلغ المنتج — تصميم مرجعي بألوان الثيم فقط.
class RefundDetailScreen extends StatelessWidget {
  const RefundDetailScreen({
    super.key,
    required this.order,
    required this.refund,
  });

  final Order order;
  final RefundRecord refund;

  static String _fmt(DateTime? d) {
    if (d == null) return '—';
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$day/$m/$y · $h:$mi';
  }

  bool get _stage2 => refund.status == 'ready_to_transfer' ||
      refund.status == 'completed';
  bool get _stage3 => refund.isCompleted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      appBar: AppBar(
        backgroundColor: T.surface,
        foregroundColor: T.text,
        elevation: 0,
        title: Text('تفاصيل الاسترداد',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w900, color: T.text)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _header(),
          const SizedBox(height: 12),
          _timeline(),
          const SizedBox(height: 12),
          _items(),
          const SizedBox(height: 12),
          _footer(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ═══ رأس الحالة ═══
  Widget _header() {
    final color = refund.isCompleted
        ? AppColors.success
        : refund.status == 'ready_to_transfer'
            ? AppColors.primary
            : const Color(0xFFB26A00);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(.45)),
                ),
                child: Text(refund.statusAr,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: color)),
              ),
              const Spacer(),
              Text(refund.refundRefNo,
                  style: TextStyle(
                      fontSize: 10.5,
                      color: T.muted,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Text('مبلغ الاسترداد',
              style: TextStyle(fontSize: 11.5, color: T.muted)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatMoney(refund.amountSar, AppCurrency.sar),
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: T.text)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                    '≈ ${formatMoney(refund.amountLocal, order.currency)}',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: T.primary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  size: 14, color: T.muted),
              const SizedBox(width: 5),
              Expanded(
                child: Text('طريقة التسوية: ${refund.methodAr}',
                    style: TextStyle(fontSize: 11.5, color: T.text)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showBreakdown,
              icon: const Icon(Icons.receipt_long_outlined, size: 16),
              label: const Text('عرض تفاصيل استرداد الأموال',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(
                foregroundColor: T.primary,
                side: BorderSide(color: T.primary.withOpacity(.5)),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBreakdown() {
    Get.dialog(
      AlertDialog(
        backgroundColor: T.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('تفصيل مبلغ الاسترداد',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w900, color: T.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('قيمة القطع', formatMoney(refund.amountSar, AppCurrency.sar)),
            _row('سعر الصرف',
                '1 ر.س = ${refund.exchangeRate.toStringAsFixed(0)} ${refund.currency}'),
            _row('المبلغ المحلي',
                formatMoney(refund.amountLocal, order.currency)),
            _row('طريقة التسوية', refund.methodAr),
            if (refund.deductedFromRemainingLocal > 0)
              _row('خُصم من المتبقي',
                  formatMoney(refund.deductedFromRemainingLocal, order.currency)),
            _row('السبب', refund.reasonAr),
            if (refund.reasonNote.trim().isNotEmpty)
              _row('ملاحظة', refund.reasonNote.trim()),
            if (refund.transferRefNo.trim().isNotEmpty)
              _row('مرجع التحويل', refund.transferRefNo.trim()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('إغلاق', style: TextStyle(color: T.primary)),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            Expanded(
                child: Text(k,
                    style: TextStyle(fontSize: 11.5, color: T.muted))),
            Flexible(
              child: Text(v,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: T.text)),
            ),
          ],
        ),
      );

  // ═══ المسار الأفقي: 3 مراحل ═══
  Widget _timeline() {
    final stages = <_Stage>[
      _Stage('تم قبول طلب الاسترداد', _fmt(refund.createdAt), true),
      _Stage('معالجة الاسترداد',
          _stage2 ? _fmt(refund.createdAt) : 'قيد الانتظار', _stage2),
      _Stage('تم الاسترداد بنجاح',
          _stage3 ? _fmt(refund.completedAt) : 'قيد الانتظار', _stage3),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: T.border),
      ),
      child: Row(
        children: List.generate(stages.length, (i) {
          final s = stages[i];
          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == 0
                            ? Colors.transparent
                            : (s.done ? AppColors.success : T.border),
                      ),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: s.done
                            ? AppColors.success.withOpacity(.16)
                            : T.soft,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: s.done ? AppColors.success : T.border,
                            width: 1.4),
                      ),
                      child: Icon(
                        s.done ? Icons.check : Icons.circle_outlined,
                        size: 14,
                        color: s.done ? AppColors.success : T.muted,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == stages.length - 1
                            ? Colors.transparent
                            : (stages[i + 1].done
                                ? AppColors.success
                                : T.border),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(s.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 9.5,
                        height: 1.4,
                        fontWeight:
                            s.done ? FontWeight.w900 : FontWeight.w600,
                        color: s.done ? T.text : T.muted)),
                const SizedBox(height: 2),
                Text(s.date,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 8.5, color: T.muted)),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ═══ القطع المستردة ═══
  Widget _items() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 15, color: T.primary),
              const SizedBox(width: 6),
              Text('القطع المستردة (${refund.items.length})',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: T.text)),
            ],
          ),
          const SizedBox(height: 8),
          ...refund.items.map((it) {
            final title = (it['title'] ?? '').toString();
            final sku = (it['sku'] ?? it['goodsId'] ?? '').toString();
            final color = (it['color'] ?? '').toString();
            final size = (it['size'] ?? '').toString();
            final qty = (it['qty'] as num?)?.toInt() ?? 1;
            final unit = (it['unitPriceSar'] as num?)?.toDouble() ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: T.soft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: T.softBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: T.card,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: T.border),
                    ),
                    child: Icon(Icons.checkroom_outlined,
                        size: 17, color: T.muted),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title.isEmpty ? 'منتج' : title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: T.text)),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (sku.isNotEmpty) 'SKU: $sku',
                            if (color.isNotEmpty) color,
                            if (size.isNotEmpty) size,
                            '× $qty',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 9.5, color: T.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(formatMoney(unit * qty, AppCurrency.sar),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: T.primary)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═══ التذييل ═══
  Widget _footer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: T.soft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: T.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tag, size: 14, color: T.muted),
              const SizedBox(width: 5),
              Expanded(
                child: Text('رقم تعريف الإرجاع: ${refund.refundRefNo}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: T.text)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: T.muted),
              const SizedBox(width: 5),
              Expanded(
                child: Text('وقت التقديم: ${_fmt(refund.createdAt)}',
                    style: TextStyle(fontSize: 11, color: T.text)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.receipt_long_outlined, size: 14, color: T.muted),
              const SizedBox(width: 5),
              Expanded(
                child: Text('رقم الطلب: ${order.orderNo}',
                    style: TextStyle(fontSize: 11, color: T.text)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                Get.back();
                if (Get.isRegistered<MainTabController>()) {
                  Get.find<MainTabController>().goTo(4);
                }
              },
              icon: Icon(Icons.support_agent, size: 17, color: T.primary),
              label: Text('التواصل مع خدمة العملاء',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: T.primary)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stage {
  final String label;
  final String date;
  final bool done;
  const _Stage(this.label, this.date, this.done);
}
