import 'package:flutter/material.dart';
import '../models/order.dart';
import '../theme/app_theme.dart';

/// شريط المراحل الست الأفقي الدائري المتصل مع علامات الصح،
/// مع إبراز مرحلة إرسال استمارة واتساب قبل اعتماد الإدارة.
class OrderStageBar extends StatelessWidget {
  const OrderStageBar({
    super.key,
    required this.status,
    this.whatsappSent = false,
    this.compact = false,
    this.stageHint = '',
  });

  final OrderStatus status;
  final bool whatsappSent;
  final bool compact;
  final String stageHint;

  static const List<OrderStatus> _stages = <OrderStatus>[
    OrderStatus.unpaid,
    OrderStatus.verifying,
    OrderStatus.processing,
    OrderStatus.shipped,
    OrderStatus.outForDelivery,
    OrderStatus.delivered,
  ];

  int get _index {
    if (status == OrderStatus.cancelled) return -1;
    final i = _stages.indexOf(status);
    return i < 0 ? 0 : i;
  }

  String _labelAt(int i) {
    if (i == 0 && status == OrderStatus.unpaid) {
      return whatsappSent ? 'أُرسلت
واتساب' : 'رفع
الطلب';
    }
    return _stages[i].labelAr;
  }

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.cancelled) {
      return Container(
        padding: EdgeInsets.all(compact ? 7 : 10),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger.withOpacity(.4)),
        ),
        child: const Row(
          children: <Widget>[
            Icon(Icons.cancel_outlined, size: 15, color: AppColors.danger),
            SizedBox(width: 6),
            Text(
              'تم إلغاء هذا الطلب',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
      );
    }

    final nodeSize = compact ? 19.0 : 26.0;
    final checkSize = compact ? 11.0 : 14.0;
    final dotSize = compact ? 5.0 : 6.0;
    final fontSize = compact ? 7.5 : 8.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: List<Widget>.generate(_stages.length, (i) {
            final done = i <= _index;
            final current = i == _index;
            final isWaWaiting =
                i == 0 && status == OrderStatus.unpaid && whatsappSent;
            final nodeColor = isWaWaiting
                ? AppColors.success
                : (done ? T.primary : T.card);
            final borderColor = isWaWaiting
                ? AppColors.success
                : (done ? T.primary : T.border);
            return Expanded(
              child: Row(
                children: <Widget>[
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2.5,
                        color: done ? T.primary : T.border,
                      ),
                    ),
                  Container(
                    width: nodeSize,
                    height: nodeSize,
                    decoration: BoxDecoration(
                      color: nodeColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: borderColor,
                        width: current ? (compact ? 2.2 : 3) : 1.5,
                      ),
                    ),
                    child: Icon(
                      done ? Icons.check : Icons.circle,
                      size: done ? checkSize : dotSize,
                      color: done ? Colors.white : T.muted,
                    ),
                  ),
                  if (i < _stages.length - 1)
                    Expanded(
                      child: Container(
                        height: 2.5,
                        color: i < _index ? T.primary : T.border,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        SizedBox(height: compact ? 4 : 6),
        Row(
          children: List<Widget>.generate(_stages.length, (i) {
            final isWaWaiting =
                i == 0 && status == OrderStatus.unpaid && whatsappSent;
            return Expanded(
              child: Text(
                _labelAt(i),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.25,
                  fontWeight: i == _index ? FontWeight.w900 : FontWeight.w500,
                  color: isWaWaiting
                      ? T.success
                      : (i <= _index ? T.primary : T.muted),
                ),
              ),
            );
          }),
        ),
        if (stageHint.isNotEmpty ||
            (status == OrderStatus.unpaid && whatsappSent)) ...[
          SizedBox(height: compact ? 5 : 8),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: (whatsappSent && status == OrderStatus.unpaid)
                  ? T.success.withOpacity(.1)
                  : T.soft,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: (whatsappSent && status == OrderStatus.unpaid)
                    ? T.success.withOpacity(.35)
                    : T.softBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  whatsappSent && status == OrderStatus.unpaid
                      ? Icons.mark_chat_read_outlined
                      : Icons.info_outline,
                  size: compact ? 12 : 14,
                  color: (whatsappSent && status == OrderStatus.unpaid)
                      ? T.success
                      : T.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    stageHint.isNotEmpty
                        ? stageHint
                        : 'تم إرسال الاستمارة لواتساب — بانتظار المراجعة وتأكيد الإدارة',
                    style: TextStyle(
                      fontSize: compact ? 9.5 : 10.5,
                      fontWeight: FontWeight.w700,
                      color: (whatsappSent && status == OrderStatus.unpaid)
                          ? T.success
                          : T.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
