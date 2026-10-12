import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

const Color _purple = Color(0xFF7C3AED);
const Color _green = Color(0xFF25D366);

class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final List<dynamic> orders =
        GetStorage().read<List<dynamic>>('seloo_orders') ?? <dynamic>[];

    return Scaffold(
      backgroundColor: Colors.white,
      body: orders.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.receipt_long_outlined,
                      size: 64, color: _purple),
                  SizedBox(height: 12),
                  Text('لا توجد طلبات سابقة'),
                  SizedBox(height: 6),
                  Text(
                    'ابدأ التسوق من SHEIN وأكمل طلبك',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              itemBuilder: (BuildContext context, int i) {
                final Map<String, dynamic> o =
                    Map<String, dynamic>.from(orders[i] as Map);
                final Map<String, dynamic> q = Map<String, dynamic>.from(
                    (o['quote'] as Map?) ?? <String, dynamic>{});
                final Map<String, dynamic>? commission =
                    o['commission'] != null
                        ? Map<String, dynamic>.from(o['commission'] as Map)
                        : null;
                final double amountDueToAgent =
                    (o['amountDueToAgent'] as num?)?.toDouble() ?? 0.0;
                final double finalTotal =
                    (o['finalTotalLocal'] as num?)?.toDouble() ??
                        (q['grandTotalLocal'] as num?)?.toDouble() ??
                        0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE9D5FF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // رقم الطلب + الحالة
                      Row(
                        children: <Widget>[
                          const Icon(Icons.receipt_long,
                              color: _purple, size: 20),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'رقم الطلب: ${o['orderId'] ?? '—'}',
                              style: const TextStyle(
                                color: _purple,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              o['status'] == 'pending'
                                  ? 'قيد المراجعة'
                                  : '${o['status'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFF97316),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),

                      // التاريخ
                      Text(
                        '📅 ${o['createdAt'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),

                      // تفصيل التسعير الأساسي
                      _row('📦 عدد الأسطر', '${q['linesCount'] ?? 0}'),
                      _row('🔢 عدد القطع', '${q['unitsCount'] ?? 0}'),
                      const SizedBox(height: 6),
                      _row(
                        '💵 قيمة المنتجات',
                        'SAR ${((q['itemsSubtotalLocal'] as num?)?.toDouble() ?? 0) / ((q['exchangeRate'] as num?)?.toDouble() ?? 1)}',
                        isRaw: true,
                      ),

                      // ⭐ العمولة إن وُجدت
                      if (commission != null) ...<Widget>[
                        const SizedBox(height: 6),
                        _row(
                          '🎁 عمولة المندوب',
                          'SAR ${(commission['totalSar'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _green.withOpacity(0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                '🎁 *مستحق المندوب* (بعد خصم قيمة السلة):',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _green,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${amountDueToAgent.toStringAsFixed(0)} ريال يمني',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: _green,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const Divider(height: 16),

                      // الإجمالي
                      Row(
                        children: <Widget>[
                          const Text('الإجمالي:',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text(
                            '${finalTotal.toStringAsFixed(0)} ر.ي',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _purple,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _row(String label, String value, {bool isRaw = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.black87)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
