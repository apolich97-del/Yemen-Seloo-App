import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

const Color _purple = Color(0xFF7C3AED);

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
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE9D5FF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
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
                      Text(
                        '📅 ${o['createdAt'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          const Text('الإجمالي:',
                              style: TextStyle(fontSize: 13)),
                          const Spacer(),
                          Text(
                            '${(q['grandTotalLocal'] as num?)?.toStringAsFixed(0) ?? '0'} ر.ي',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
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
}
