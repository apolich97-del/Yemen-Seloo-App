import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/cart.dart';
import '../../../core/models/currency.dart';
import '../../../core/models/order.dart';
import '../../../core/models/refund.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/review_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../orders/refund_detail_screen.dart';
import '../../reviews/review_dialog.dart';
import 'main_tab_controller.dart';

/// تبويب «طلباتي» للعميل:
/// بحث + 7 تبويبات بنمط SHEIN (الكل، الطلبات الآجلة، غير مدفوع،
/// قيد التجهيز، تم الشحن، تعليق، إرجاع / استرداد الأموال) + إيصال.
class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab>
    with SingleTickerProviderStateMixin {
  static const List<String> _filters = <String>[
    'all',
    'deferred',
    'unpaid',
    'processing',
    'shipped',
    'reviews',
    'refunds',
  ];

  late final TabController _tab =
      TabController(length: _filters.length, vsync: this);
  final _search = TextEditingController();
  String _q = '';
  Worker? _filterWorker;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<MainTabController>()) {
      final ctrl = Get.find<MainTabController>();
      _applyFilter(ctrl.ordersFilter.value, animate: false);
      _filterWorker = ever(ctrl.ordersFilterTick, (_) {
        if (mounted) _applyFilter(ctrl.ordersFilter.value);
      });
    }
  }

  void _applyFilter(String key, {bool animate = true}) {
    final idx = _filters.indexOf(key);
    if (idx < 0 || idx >= _tab.length || _tab.index == idx) return;
    if (animate) {
      _tab.animateTo(idx);
    } else {
      _tab.index = idx;
    }
  }

  @override
  void dispose() {
    _filterWorker?.dispose();
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

  void _goSupport() {
    if (Get.isRegistered<MainTabController>()) {
      Get.find<MainTabController>().goToSupport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewSvc = Get.put(ReviewService(), permanent: false);
    return Scaffold(
      backgroundColor: T.bg,
      appBar: AppBar(
        backgroundColor: T.surface,
        foregroundColor: T.text,
        elevation: 0,
        title: Text('طلباتي',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w900, color: T.text)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: TextButton.icon(
              onPressed: () => Get.toNamed(AppRoutes.myReceipts),
              style: TextButton.styleFrom(
                foregroundColor: T.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              icon: const Icon(Icons.receipt_outlined, size: 17),
              label: const Text('إيصال',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: T.primary,
          unselectedLabelColor: T.muted,
          indicatorColor: T.primary,
          dividerColor: T.border,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          unselectedLabelStyle:
              const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'الكل'),
            Tab(text: 'الطلبات الآجلة'),
            Tab(text: 'غير مدفوع'),
            Tab(text: 'قيد التجهيز'),
            Tab(text: 'تم الشحن'),
            Tab(text: 'تعليق'),
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
                hintText: 'ابحث عن طلباتي: اسم المنتج / رقم الطلب',
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
                    const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                filled: true,
                fillColor: T.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: T.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
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
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: reviewSvc.mine(),
                  builder: (context, rSnap) {
                    final myReviewDocs = rSnap.data?.docs ?? const [];
                    final reviewedIds = myReviewDocs
                        .map((d) => (d.data()['orderId'] ?? '') as String)
                        .toSet();
                    return TabBarView(
                      controller: _tab,
                      children: [
                        _list(rows,
                            reviewedIds: reviewedIds,
                            emptyTitle: 'لا توجد طلبات حتى الآن'),
                        _list(
                          rows
                              .where((r) =>
                                  r.order.isDeferred ||
                                  r.order.paymentPlan == 'deferred' ||
                                  r.order.hasRemaining)
                              .toList(),
                          reviewedIds: reviewedIds,
                          emptyTitle: 'لا توجد طلبات آجلة',
                        ),
                        _list(
                          rows
                              .where((r) =>
                                  r.order.status == OrderStatus.unpaid ||
                                  r.order.status == OrderStatus.verifying)
                              .toList(),
                          reviewedIds: reviewedIds,
                          emptyTitle: 'لا توجد طلبات غير مدفوعة',
                        ),
                        _list(
                          rows
                              .where((r) =>
                                  r.order.status == OrderStatus.processing)
                              .toList(),
                          reviewedIds: reviewedIds,
                          emptyTitle: 'لا توجد طلبات قيد التجهيز',
                        ),
                        _list(
                          rows
                              .where((r) =>
                                  r.order.status == OrderStatus.shipped ||
                                  r.order.status == OrderStatus.outForDelivery)
                              .toList(),
                          reviewedIds: reviewedIds,
                          emptyTitle: 'لا توجد طلبات مشحونة حالياً',
                        ),
                        _pendingReview(rows, reviewedIds, myReviewDocs),
                        _list(
                          rows.where((r) => r.refunds.isNotEmpty).toList(),
                          reviewedIds: reviewedIds,
                          emptyIcon: Icons.assignment_return_outlined,
                          emptyTitle: 'لا توجد مبالغ مستردة',
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// تبويب «تعليق»: طلبات سُلّمت ولم تُقيّم بعد + حالة تقييمات العميل السابقة.
  Widget _pendingReview(
    List<_Row> rows,
    Set<String> reviewedIds,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> myReviewDocs,
  ) {
    final pending = rows
        .where((r) =>
            r.order.status == OrderStatus.delivered &&
            !reviewedIds.contains(r.order.id))
        .toList();

    if (pending.isEmpty && myReviewDocs.isEmpty) {
      return _sheinEmptyState(
        icon: Icons.rate_review_outlined,
        subtitle: 'لا توجد طلبات بانتظار تعليقك وتقييمك',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
      children: [
        if (pending.isEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: T.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: T.border),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 20, color: T.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('تم تقييم جميع طلباتك المستلمة',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: T.text)),
                ),
              ],
            ),
          )
        else
          ...pending.map((r) {
            final o = r.order;
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
                  Row(children: [
                    Icon(Icons.check_circle_outline,
                        size: 16, color: T.success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(o.orderNo,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: T.primary)),
                    ),
                    Text('تم التسليم',
                        style: TextStyle(fontSize: 10, color: T.success)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                      '${o.items.length} قطعة · اكتب تعليقك وأرفق صورة الاستلام (يُنشر بعد مراجعة الإدارة)',
                      style: TextStyle(
                          fontSize: 10.5, height: 1.5, color: T.muted)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => showReviewDialog(o),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 36)),
                      icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                      label: const Text('إضافة تعليق وصورة الاستلام',
                          style: TextStyle(fontSize: 11.5)),
                    ),
                  ),
                ],
              ),
            );
          }),
        if (myReviewDocs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8, right: 4),
            child: Text('تعليقاتي المرسلة (${myReviewDocs.length})',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w900, color: T.text)),
          ),
          ...myReviewDocs.map((doc) {
            final d = doc.data();
            final status = (d['status'] ?? 'pending') as String;
            final rating = ((d['rating'] as num?) ?? 5).toInt();
            final reply = (d['reply'] ?? '') as String;
            final (statusLabel, statusColor) = switch (status) {
              'approved' => ('معتمد ومنشور', T.success),
              'rejected' => ('مرفوض من الإدارة', T.danger),
              _ => ('بانتظار مراجعة الإدارة', T.warning),
            };
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
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
                      Text('${d['orderNo'] ?? ''}',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: T.primary)),
                      const SizedBox(width: 8),
                      ...List.generate(
                          5,
                          (s) => Icon(
                              s < rating ? Icons.star : Icons.star_border,
                              size: 12,
                              color: T.warning)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(statusLabel,
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: statusColor)),
                      ),
                    ],
                  ),
                  if (((d['text'] ?? '') as String).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(d['text'] as String,
                        style: TextStyle(fontSize: 11, color: T.text)),
                  ],
                  if (reply.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: T.soft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('رد الإدارة: $reply',
                          style: TextStyle(fontSize: 10.5, color: T.primary)),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _list(
    List<_Row> list, {
    required Set<String> reviewedIds,
    IconData emptyIcon = Icons.receipt_long_outlined,
    String emptyTitle = 'لا توجد طلبات مطابقة',
  }) {
    if (list.isEmpty) {
      return _sheinEmptyState(icon: emptyIcon, subtitle: emptyTitle);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
      itemCount: list.length,
      itemBuilder: (_, i) => _card(list[i], reviewedIds),
    );
  }

  Widget _sheinEmptyState({
    required IconData icon,
    required String subtitle,
  }) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: T.soft,
                  shape: BoxShape.circle,
                  border: Border.all(color: T.softBorder),
                ),
                child: Icon(icon, size: 34, color: T.muted),
              ),
              const SizedBox(height: 12),
              Text('فارغ هنا',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: T.text)),
              const SizedBox(height: 4),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: T.muted)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Divider(color: T.border, height: 1),
        const SizedBox(height: 20),
        Center(
          child: Text('لا يمكنك العثور على طلبك؟',
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w900, color: T.text)),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _goSupport,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: T.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: T.border),
            ),
            child: Row(
              children: [
                Icon(Icons.support_agent_outlined,
                    size: 19, color: T.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('الخدمة الذاتية للعثور على الطلب',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: T.text)),
                ),
                Icon(Icons.chevron_left, size: 20, color: T.muted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(_Row r, Set<String> reviewedIds) {
    final o = r.order;
    final refundedSar =
        r.refunds.fold<double>(0, (a, e) => a + e.amountSar);
    final refundedLocal =
        r.refunds.fold<double>(0, (a, e) => a + e.amountLocal);
    final needsReview =
        o.status == OrderStatus.delivered && !reviewedIds.contains(o.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Get.toNamed(AppRoutes.orderDetail, arguments: o.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final count = await Get.find<CartRepository>().reorderOrderItems(o.items);
                      Get.snackbar('أُعيدت للسلة ✓', 'تمت إضافة $count منتجاً إلى سلة التسوق');
                      if (Get.isRegistered<MainTabController>()) {
                        Get.find<MainTabController>().goToCart();
                      }
                    } catch (e) {
                      Get.snackbar('تعذر إعادة الطلب', '$e');
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                  ),
                  icon: const Icon(Icons.replay_outlined, size: 15),
                  label: const Text('إعادة الطلب للسلة', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                ),
              ),
              // زر «إيصال» للطلبات الآجلة — متابعة الدفعات بضغطة واحدة
              if (o.isDeferred ||
                  o.paymentPlan == 'deferred' ||
                  o.hasRemaining) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Get.toNamed(AppRoutes.myReceipts),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: T.primary,
                      side: BorderSide(color: T.primary.withOpacity(.4)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 34),
                    ),
                    icon: const Icon(Icons.receipt_outlined, size: 15),
                    label: Text(
                      o.hasRemaining
                          ? 'إيصال · متبقي ${formatMoney(o.remainingLocal, o.currency)}'
                          : 'إيصال',
                      style: const TextStyle(fontSize: 10.5),
                    ),
                  ),
                ),
              ],
              if (needsReview) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => showReviewDialog(o),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 34)),
                    icon: const Icon(Icons.rate_review_outlined, size: 15),
                    label: const Text('تعليق وإضافة صورة الاستلام',
                        style: TextStyle(fontSize: 10.5)),
                  ),
                ),
              ],
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
        ),
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
