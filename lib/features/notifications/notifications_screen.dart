import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../orders/order_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(String type) => switch (type) {
        'shipping' => Icons.local_shipping_outlined,
        'replacement' => Icons.swap_horiz_rounded,
        'receipt' => Icons.receipt_long_outlined,
        'alert' => Icons.campaign_outlined,
        'support' => Icons.support_agent_outlined,
        _ => Icons.notifications_outlined,
      };

  Color _colorFor(String type) => switch (type) {
        'shipping' => T.info,
        'replacement' => T.warning,
        'receipt' => T.success,
        'alert' => T.danger,
        _ => T.primary,
      };

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<NotificationService>();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Obx(() => Scaffold(
            backgroundColor: T.bg,
            appBar: AppBar(
              backgroundColor: T.surface,
              foregroundColor: T.text,
              elevation: 0,
              title: Text(
                'notifications'.tr,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900, color: T.text),
              ),
              actions: [
                if (svc.unreadCount > 0)
                  TextButton.icon(
                    onPressed: svc.markAllRead,
                    icon: const Icon(Icons.done_all, size: 17),
                    label: const Text('قراءة الكل', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            body: svc.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_none_rounded,
                            size: 56, color: T.muted),
                        const SizedBox(height: 10),
                        Text('لا توجد إشعارات حالياً',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: T.muted)),
                        const SizedBox(height: 4),
                        Text(
                          'ستصلك هنا إشعارات الشحن، البدائل، والمدفوعات لحظياً',
                          style: TextStyle(fontSize: 11.5, color: T.muted),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: svc.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final n = svc.items[i];
                      final c = _colorFor(n.type);
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          if (!n.read) svc.markRead(n.id);
                          if (n.orderId.isNotEmpty) {
                            Get.to(() => const OrderDetailScreen(),
                                arguments: n.orderId);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: n.read ? T.card : T.soft,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: n.read ? T.border : T.softBorder,
                              width: n.read ? 1 : 1.4,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: c.withOpacity(.14),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(_iconFor(n.type), size: 20, color: c),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            n.title,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: n.read
                                                  ? FontWeight.w700
                                                  : FontWeight.w900,
                                              color: T.text,
                                            ),
                                          ),
                                        ),
                                        if (!n.read)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: T.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      n.body,
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          height: 1.5,
                                          color: T.muted),
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Text(
                                          '${n.createdAt.day}/${n.createdAt.month} · ${n.createdAt.hour.toString().padLeft(2, "0")}:${n.createdAt.minute.toString().padLeft(2, "0")}',
                                          style: TextStyle(
                                              fontSize: 10, color: T.muted),
                                        ),
                                        if (n.orderId.isNotEmpty) ...[
                                          const Spacer(),
                                          Text('عرض الطلب ←',
                                              style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: T.primary)),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          )),
    );
  }
}
