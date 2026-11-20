import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/currency.dart';
import '../../../core/models/order.dart';
import '../../../core/models/refund.dart';
import '../../../core/theme/app_theme.dart';
import '../../orders/refund_detail_screen.dart';

/// تبويب «طلباتي» للعميل: بحث + طلبات + إرجاع/استرداد الأموال.
class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _tab.dispose();
    _search.dispose();
    super.dispose();
  }

  Stream<List<_Row>> _stream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const <_Row>[]);
    return FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(120)
        .snapshots()
        .map((s) => s.docs.map((d) {
              final data = d.data();
              return _Row(
                Order.fromDoc(d.id, data),
                (((data['refunds'] as List?) ?? const []))
                    .map((e) =>
                        RefundRecord.fromMap(Map<String, dynamic>.from(e as Map)))
                    .toList(),
              );
            }).toList());
  }

  bool _match(_Row r) {
    if (_q.trim().isEmpty) return true;
    final q = _q.trim().toLowerCase();
    if (r.order.orderNo.toLowerCase().contains(q)) return true;
    return r.order.items.any((i) => i.title.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      appBar: AppBar(
        backgroundColor: T.surface,
        foregroundColor: T.text,
        elevation: 0,
        title: Text('طلباتي',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w900, color: T.text)),
        bottom: TabBar(
          controller: _tab,
          labelColor: T.primary,
          unselectedLabelColor: T.muted,
          indicatorColor: T.primary,
          dividerColor: T.border,
          labelStyle:
              const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
          tabs: const [
            Tab(text: 'طلباتي'),
            Tab(text: 'إرجاع / استرداد الأموال'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'ابحث باسم المنتج أو رقم الطلب',
                prefixIcon: const Icon(Icons.search, size: 19),
                suffixIcon: _q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 17),
                        onPressed: () {
                          _search.clear();
                          setState(() => _q = '');
                        },
                      ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                filled: true,
                fillColor: T.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: T.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: T.border),
                ),
              ),
              style: TextStyle(fontSize: 12.5, color: T.text),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<_Row>>(
              stream: _stream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(color: T.primary));
                }
                final rows = (snap.data ?? const <_Row>[])
                    .where(_match)
                    .toList();
                return TabBarView(
                  controller: _tab,
                  children: [
                    _list(rows, onlyWithRefunds: false),
                    _list(rows, onlyWithRefunds: true),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<_Row> rows, {required bool onlyWithRefunds}) {
    final list = onlyWithRefunds
        ? rows.where((r) => r.refunds.isNotEmpty).toList()
        : rows;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                  onlyWithRefunds
                      ? Icons.assignment_return_outlined
                      : Icons.receipt_long_outlined,
                  size: 54,
                  color: T.muted),
              const SizedBox(height: 10),
              Text(
                  onlyWithRefunds
                      ? 'لا توجد مبالغ مستردة'
                      : 'لا توجد طلبات مطابقة',
                  style: TextStyle(fontSize: 12.5, color: T.muted)),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
      itemCount: list.length,
      itemBuilder: (_, i) => _card(list[i]),
    );
  }

  Widget _card(_Row r) {
    final o = r.order;
    final refundedSar =
        r.refunds.fold<double>(0, (a, e) => a + e.amountSar);
    final refundedLocal =
        r.refunds.fold<double>(0, (a, e) => a + e.amountLocal);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, size: 17, color: T.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(o.orderNo,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: T.primary)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: T.soft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: T.softBorder),
                ),
                child: Text(o.status.labelAr,
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: T.text)),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ...o.items.take(2).map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('• ${i.title} × ${i.qty}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: T.text)),
              )),
          if (o.items.length > 2)
            Text('+ ${o.items.length - 2} منتجات أخرى',
                style: TextStyle(fontSize: 9.5, color: T.muted)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(formatMoney(o.totalSar, AppCurrency.sar),
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: T.text)),
              const SizedBox(width: 6),
              Text('≈ ${formatMoney(o.totalLocal, o.currency)}',
                  style: TextStyle(fontSize: 10, color: T.muted)),
              const Spacer(),
              Text('${o.items.length} قطعة',
                  style: TextStyle(fontSize: 10, color: T.muted)),
            ],
          ),
          if (r.refunds.isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openRefund(r, r.refunds.last),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: T.soft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: T.softBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.assignment_return_outlined,
                        size: 16, color: AppColors.success),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تمت معالجة مبالغ الاسترداد',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: T.text)),
                          const SizedBox(height: 2),
                          Text(
                              '${formatMoney(refundedSar, AppCurrency.sar)} · '
                              '${formatMoney(refundedLocal, o.currency)}',
                              style: TextStyle(
                                  fontSize: 10, color: T.muted)),
                        ],
                      ),
                    ),
                    Text('التفاصيل',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: T.primary)),
                    Icon(Icons.chevron_left, size: 16, color: T.primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openRefund(_Row r, RefundRecord refund) {
    Get.to(() => RefundDetailScreen(order: r.order, refund: refund));
  }
}

class _Row {
  final Order order;
  final List<RefundRecord> refunds;
  const _Row(this.order, this.refunds);
}
