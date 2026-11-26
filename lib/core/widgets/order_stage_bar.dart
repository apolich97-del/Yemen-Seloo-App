import 'package:flutter/material.dart';
import '../models/order.dart';
import '../theme/app_theme.dart';

class OrderStageBar extends StatelessWidget {
  final OrderStatus status;
  final bool compact;
  final bool whatsappSent;
  final String stageHint;
  final ShippingMilestone? milestone;

  const OrderStageBar({
    super.key,
    required this.status,
    this.compact = false,
    this.whatsappSent = false,
    this.stageHint = '',
    this.milestone,
  });

  static const _stages = [
    'رفع الطلب',
    'السداد',
    'التجهيز',
    'الشحن',
    'التوصيل',
    'التسليم',
  ];

  int get _index => switch (status) {
        OrderStatus.unpaid => 0,
        OrderStatus.verifying => 1,
        OrderStatus.processing => 2,
        OrderStatus.shipped => 3,
        OrderStatus.outForDelivery => 4,
        OrderStatus.delivered => 5,
        OrderStatus.cancelled => -1,
      };

  String _labelAt(int i) {
    if (i == 0 && status == OrderStatus.unpaid && whatsappSent) {
      return 'بانتظار التأكيد';
    }
    if (i == 3 && status == OrderStatus.shipped && milestone != null) {
      return milestone!.shortAr;
    }
    return _stages[i];
  }

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.cancelled) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: T.danger.withOpacity(.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: T.danger.withOpacity(.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.cancel_outlined, size: 16, color: T.danger),
            const SizedBox(width: 6),
            Text(
              'تم إلغاء الطلب',
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w800,
                color: T.danger,
              ),
            ),
          ],
        ),
      );
    }

    final nodeSize = compact ? 18.0 : 24.0;
    final checkSize = compact ? 11.0 : 14.0;
    final dotSize = compact ? 6.0 : 8.0;
    final fontSize = compact ? 8.5 : 10.0;
    final showSubShipping = status == OrderStatus.processing ||
        status == OrderStatus.shipped ||
        status == OrderStatus.outForDelivery ||
        status == OrderStatus.delivered;
    final activeMilestone =
        milestone ?? ShippingMilestoneX.fromKey(null, fallbackStatus: status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        if (showSubShipping) ...[
          SizedBox(height: compact ? 5 : 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: T.cardHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: T.border),
            ),
            child: Row(
              children: [
                for (final ms in const [
                  ShippingMilestone.preparing,
                  ShippingMilestone.chinaWarehouse,
                  ShippingMilestone.uaeTransit,
                  ShippingMilestone.saudiCustoms,
                  ShippingMilestone.yemenArrival,
                ])
                  Expanded(
                    child: Text(
                      '${ms.emoji} ${ms.shortAr}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 8.2 : 9.3,
                        fontWeight: activeMilestone.stepIndex >= ms.stepIndex
                            ? FontWeight.w900
                            : FontWeight.w500,
                        color: activeMilestone.stepIndex >= ms.stepIndex
                            ? T.primary
                            : T.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
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
