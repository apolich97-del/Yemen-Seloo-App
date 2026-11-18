import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_theme.dart';

/// شريط المراحل الست الأفقي الدائري المتصل مع علامات الصح.
class OrderStageBar extends StatelessWidget {
  const OrderStageBar({super.key, required this.status});

  final OrderStatus status;

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

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.cancelled) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger.withOpacity(.4)),
        ),
        child: const Row(
          children: <Widget>[
            Icon(Icons.cancel_outlined, size: 16, color: AppColors.danger),
            SizedBox(width: 6),
            Text('تم إلغاء هذا الطلب',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger)),
          ],
        ),
      );
    }

    return Column(
      children: <Widget>[
        Row(
          children: List<Widget>.generate(_stages.length, (i) {
            final done = i <= _index;
            final current = i == _index;
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
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: done ? T.primary : T.card,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: done ? T.primary : T.border,
                        width: current ? 3 : 1.5,
                      ),
                    ),
                    child: Icon(
                      done ? Icons.check : Icons.circle,
                      size: done ? 14 : 6,
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
        const SizedBox(height: 6),
        Row(
          children: List<Widget>.generate(_stages.length, (i) {
            return Expanded(
              child: Text(
                _stages[i].labelAr,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 8,
                  height: 1.3,
                  fontWeight: i == _index ? FontWeight.w900 : FontWeight.w500,
                  color: i <= _index ? T.primary : T.muted,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
