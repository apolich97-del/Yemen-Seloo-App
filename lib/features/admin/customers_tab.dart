import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/currency.dart';
import '../../core/models/order.dart';
import '../../core/models/receipt.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/customer_accounting_service.dart';
import '../../core/theme/app_theme.dart';

/// تبويب «العملاء»: قاعدة بيانات عملاء يمن سيلو + كشف الحساب المحاسبي + الائتمان الآجل.
class CustomersTab extends StatefulWidget {
  const CustomersTab({super.key});

  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  AppUser _userFromDoc(String uid, Map<String, dynamic> d) {
    DateTime? dt(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return AppUser(
      uid: uid,
      email: d['email'] as String?,
      phone: d['phone'] as String?,
      firstName: (d['firstName'] ?? '') as String,
      lastName: (d['lastName'] ?? '') as String,
      role: (d['role'] ?? 'customer') as String,
      customerCode: (d['customerCode'] ?? '') as String,
      city: (d['city'] ?? '') as String,
      district: (d['district'] ?? '') as String,
      addressLine: (d['addressLine'] ?? '') as String,
      preferredCurrency: (d['preferredCurrency'] ?? 'south') as String,
      staffNotes: (d['staffNotes'] ?? '') as String,
      customerTier: (d['customerTier'] ?? 'normal') as String,
      deferredCreditLimitSar:
          (d['deferredCreditLimitSar'] as num?)?.toDouble(),
      lastOrderAt: dt(d['lastOrderAt']),
      createdAt: dt(d['createdAt']),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('users').limit(300).snapshots(),
      builder: (context, uSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('orders').limit(300).snapshots(),
          builder: (context, oSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db.collectionGroup('receipts').limit(300).snapshots(),
              builder: (context, rSnap) {
                if (uSnap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('تعذر تحميل العملاء: ${uSnap.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, color: T.muted)),
                    ),
                  );
                }
                if (uSnap.connectionState == ConnectionState.waiting &&
                    !uSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = (uSnap.data?.docs ?? const [])
                    .map((d) => _userFromDoc(d.id, d.data()))
                    .toList();
                final allOrders = (oSnap.data?.docs ?? const [])
                    .map((d) => Order.fromDoc(d.id, d.data()))
                    .toList();
                final allReceipts = (rSnap.data?.docs ?? const [])
                    .map((d) => Receipt.fromDoc(d.id, d.data()))
                    .toList();

                final customers = users.where((u) {
                  if (_query.trim().isEmpty) return true;
                  final q = _query.trim().toLowerCase();
                  return u.displayName.toLowerCase().contains(q) ||
                      (u.phone ?? '').toLowerCase().contains(q) ||
                      u.city.toLowerCase().contains(q) ||
                      u.effectiveCode.toLowerCase().contains(q);
                }).toList();

                int vipCount = 0;
                int debtorsCount = 0;
                double totalDebtSar = 0;

                final rows = customers.map((u) {
                  final cOrders = allOrders
                      .where((o) => doesOrderBelongToCustomer(
                            o,
                            uid: u.uid,
                            phone: u.phone,
                          ))
                      .toList();
                  final orderIds = cOrders.map((o) => o.id).toSet();
                  final cReceipts = allReceipts
                      .where((r) => orderIds.contains(r.orderId))
                      .toList();
                  final report = AccountingStatementEngine.build(
                    orders: cOrders,
                    receipts: cReceipts,
                  );
                  if (u.tier == CustomerTier.vip) vipCount++;
                  if (report.remainingDebtSar > 0.5) {
                    debtorsCount++;
                    totalDebtSar += report.remainingDebtSar;
                  }
                  return _CustomerRow(
                    user: u,
                    orders: cOrders,
                    receipts: cReceipts,
                    report: report,
                  );
                }).toList()
                  ..sort((a, b) =>
                      b.report.totalOrdersSar.compareTo(a.report.totalOrdersSar));

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'ابحث بالاسم، الهاتف، المحافظة أو كود العميل...',
                          prefixIcon: const Icon(Icons.search, size: 19),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                          isDense: true,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          _miniKpi('العملاء', '${rows.length}', T.primary),
                          const SizedBox(width: 6),
                          _miniKpi('VIP', '$vipCount', Colors.amber.shade700),
                          const SizedBox(width: 6),
                          _miniKpi('مديونيات الآجل',
                              '$debtorsCount (${totalDebtSar.toStringAsFixed(0)} SAR)',
                              T.danger),
                        ],
                      ),
                    ),
                    Expanded(
                      child: rows.isEmpty
                          ? Center(
                              child: Text('لا يوجد عملاء مطابقون',
                                  style: TextStyle(fontSize: 12, color: T.muted)),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: rows.length,
                              itemBuilder: (_, i) => _customerCard(rows[i]),
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _miniKpi(String title, String val, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: T.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: T.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 9.5, color: T.muted)),
              Text(val,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
        ),
      );

  Widget _customerCard(_CustomerRow row) {
    final u = row.user;
    final tier = u.tier;
    final Color tierColor = switch (tier) {
      CustomerTier.vip => Colors.amber.shade800,
      CustomerTier.blockedDeferred => T.danger,
      CustomerTier.normal => T.primary,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openCustomerSheet(row),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withOpacity(.12),
                    child: Text(
                      u.displayName.isEmpty ? '؟' : u.displayName.characters.first,
                      style: TextStyle(
                          fontWeight: FontWeight.w900, color: T.primary),
                    ),
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
                                u.displayName.isEmpty ? 'عميل بدون اسم' : u.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13.5, fontWeight: FontWeight.w900),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: tierColor.withOpacity(.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                tier.labelAr,
                                style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: tierColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${u.effectiveCode} · ${u.phone ?? 'بدون هاتف'} · ${u.city.isEmpty ? 'غير محدد' : u.city}',
                          style: TextStyle(fontSize: 11, color: T.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _badge('الطلبات: ${row.orders.length}', T.soft, T.text),
                  _badge(
                    'المبيعات: ${row.report.totalOrdersSar.toStringAsFixed(0)} SAR',
                    T.soft,
                    T.primary,
                  ),
                  _badge(
                    'الختامي: ${row.report.closingBalanceSar.toStringAsFixed(1)} SAR',
                    row.report.closingBalanceSar > 0.5
                        ? T.danger.withOpacity(.1)
                        : T.success.withOpacity(.1),
                    row.report.closingBalanceSar > 0.5 ? T.danger : T.success,
                  ),
                  _badge(
                    'صور الحوالات: ${row.report.transferPhotos.length}',
                    T.soft,
                    T.muted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
      );

  void _openCustomerSheet(_CustomerRow row) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: T.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _Customer360Sheet(row: row),
    );
  }
}

class _CustomerRow {
  final AppUser user;
  final List<Order> orders;
  final List<Receipt> receipts;
  final AccountingStatementReport report;
  const _CustomerRow({
    required this.user,
    required this.orders,
    required this.receipts,
    required this.report,
  });
}

class _Customer360Sheet extends StatefulWidget {
  final _CustomerRow row;
  const _Customer360Sheet({required this.row});

  @override
  State<_Customer360Sheet> createState() => _Customer360SheetState();
}

class _Customer360SheetState extends State<_Customer360Sheet> {
  late CustomerTier _tier;
  late TextEditingController _limitCtrl;
  late TextEditingController _notesCtrl;
  bool _savingCredit = false;
  bool _savingNotes = false;

  @override
  void initState() {
    super.initState();
    _tier = widget.row.user.tier;
    _limitCtrl = TextEditingController(
      text: widget.row.user.effectiveCreditLimitSar.toStringAsFixed(0),
    );
    _notesCtrl = TextEditingController(text: widget.row.user.staffNotes);
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveCredit() async {
    setState(() => _savingCredit = true);
    try {
      final limit =
          double.tryParse(_limitCtrl.text.trim()) ?? _tier.defaultCreditLimitSar;
      await Get.find<AuthService>().updateCustomerCreditSettings(
        targetUid: widget.row.user.uid,
        tier: _tier,
        creditLimitSar: _tier == CustomerTier.blockedDeferred ? 0.0 : limit,
      );
      Get.snackbar('تم التحديث ✓', 'تم حفظ فئة العميل والحد الائتماني الآجل');
    } catch (e) {
      Get.snackbar('تعذر الحفظ', '$e');
    } finally {
      if (mounted) setState(() => _savingCredit = false);
    }
  }

  Future<void> _saveNotes() async {
    setState(() => _savingNotes = true);
    try {
      await Get.find<AuthService>().updateCustomerStaffNotes(
        targetUid: widget.row.user.uid,
        notes: _notesCtrl.text,
      );
      Get.snackbar('تم الحفظ ✓', 'تم حفظ ملاحظات الفريق');
    } catch (e) {
      Get.snackbar('تعذر الحفظ', '$e');
    } finally {
      if (mounted) setState(() => _savingNotes = false);
    }
  }

  Future<void> _launchWa(String msg) async {
    final phone = widget.row.user.whatsappNumber;
    final encoded = Uri.encodeComponent(msg);
    final url = phone.isEmpty
        ? 'https://wa.me/?text=$encoded'
        : 'https://wa.me/$phone?text=$encoded';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _sendStatementWa() {
    final r = widget.row.report;
    final u = widget.row.user;
    final msg = 'مرحباً ${u.displayName}،\n'
        'كشف حسابك المختصر لدى يمن سيلو (${u.effectiveCode}):\n'
        '• إجمالي المدين: ${r.periodDebitSar.toStringAsFixed(2)} SAR\n'
        '• إجمالي الدائن: ${r.periodCreditSar.toStringAsFixed(2)} SAR\n'
        '• إجمالي الاستردادات: ${r.totalRefundedSar.toStringAsFixed(2)} SAR\n'
        '• الرصيد الختامي المستحق: ${r.closingBalanceSar.toStringAsFixed(2)} SAR';
    _launchWa(msg);
  }

  void _sendDeferredReminderWa() {
    final u = widget.row.user;
    final r = widget.row.report;
    final deferredOrders = widget.row.orders
        .where((o) => o.hasRemaining && o.status != OrderStatus.cancelled)
        .toList();
    final b = StringBuffer()
      ..writeln('السلام عليكم ورحمة الله وبركاته أ/ ${u.displayName} 🌸')
      ..writeln('تذكير ودي من فريق المحاسبة في *يمن سيلو* بخصوص الأقساط الآجلة المستحقة:');
    for (final o in deferredOrders.take(5)) {
      b.writeln(
          '• طلب ${o.orderNo}: متبقي ${formatMoney(o.remainingLocal, o.currency)} (${o.remainingSar.toStringAsFixed(2)} SAR)');
    }
    b
      ..writeln(
          'إجمالي الرصيد المتبقي: *${r.remainingDebtSar.toStringAsFixed(2)} SAR*')
      ..writeln('شاكرين تعاونكم الدائم ✓');
    _launchWa(b.toString());
  }

  void _zoomPhoto(String url, String title) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(title, style: const TextStyle(fontSize: 13)),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              width: double.infinity,
              child: InteractiveViewer(
                maxScale: 4.5,
                child: url.startsWith('data:')
                    ? Image.memory(
                        base64Decode(url.substring(url.indexOf(',') + 1)),
                        fit: BoxFit.contain,
                      )
                    : Image.network(url, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.row.user;
    final r = widget.row.report;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'ملف العميل 360° — ${u.displayName.isEmpty ? u.effectiveCode : u.displayName}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const Divider(),
        SectionCard(
          title: 'البيانات المسجلة في قاعدة العملاء',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MoneyRow(label: 'الكود', value: u.effectiveCode),
              MoneyRow(label: 'الهاتف', value: u.phone ?? '—'),
              if ((u.email ?? '').isNotEmpty) MoneyRow(label: 'البريد', value: u.email!),
              MoneyRow(label: 'المحافظة / المديرية', value: '${u.city} — ${u.district}'),
              MoneyRow(label: 'العنوان التفصيلي', value: u.addressLine.isEmpty ? '—' : u.addressLine),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SectionCard(
          title: 'الملخص المحاسبي الشامل',
          child: Column(
            children: [
              MoneyRow(label: 'إجمالي المدين (الطلبات)', value: '${r.periodDebitSar.toStringAsFixed(2)} SAR'),
              MoneyRow(label: 'إجمالي الدائن (السداد/الإشعارات)', value: '${r.periodCreditSar.toStringAsFixed(2)} SAR'),
              MoneyRow(label: 'إجمالي الاستردادات', value: '${r.totalRefundedSar.toStringAsFixed(2)} SAR'),
              MoneyRow(
                label: 'الرصيد الختامي المستحق',
                value: '${r.closingBalanceSar.toStringAsFixed(2)} SAR',
                free: r.closingBalanceSar <= 0.5,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _sendStatementWa,
                      icon: const Icon(Icons.chat_outlined, size: 16),
                      label: const Text('إرسال كشف حساب واتساب', style: TextStyle(fontSize: 10.5)),
                    ),
                  ),
                  if (r.remainingDebtSar > 0.5) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _sendDeferredReminderWa,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: T.whatsapp,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.notifications_active_outlined, size: 16),
                        label: const Text('تذكير قسط آجل', style: TextStyle(fontSize: 10.5)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SectionCard(
          title: 'فئة العميل والحد الائتماني الآجل',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                children: CustomerTier.values
                    .map((t) => ChoiceChip(
                          label: Text(t.labelAr, style: const TextStyle(fontSize: 11)),
                          selected: _tier == t,
                          onSelected: (_) {
                            setState(() {
                              _tier = t;
                              _limitCtrl.text = t.defaultCreditLimitSar.toStringAsFixed(0);
                            });
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _limitCtrl,
                enabled: _tier != CustomerTier.blockedDeferred,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الحد الائتماني الآجل (SAR)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _savingCredit ? null : _saveCredit,
                child: Text(_savingCredit ? 'جاري الحفظ...' : 'حفظ الفئة والحد الائتماني'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (r.transferPhotos.isNotEmpty) ...[
          SectionCard(
            title: 'أرشيف صور الحوالات والاستردادات (${r.transferPhotos.length})',
            child: SizedBox(
              height: 115,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: r.transferPhotos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final p = r.transferPhotos[i];
                  return InkWell(
                    onTap: () => _zoomPhoto(p.url, p.title),
                    child: Container(
                      width: 96,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: T.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Expanded(
                            child: p.url.startsWith('data:')
                                ? Image.memory(
                                    base64Decode(p.url.substring(p.url.indexOf(',') + 1)),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  )
                                : Image.network(p.url, fit: BoxFit.cover, width: double.infinity),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              '${p.amountSar.toStringAsFixed(0)} SAR',
                              maxLines: 1,
                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (r.refunds.isNotEmpty) ...[
          SectionCard(
            title: 'عمليات الاسترداد (${r.refunds.length})',
            child: Column(
              children: r.refunds
                  .map((rf) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${rf.refundRefNo} · ${rf.orderNo}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        subtitle: Text('${rf.reasonAr} · ${rf.methodAr} · ${rf.statusAr}',
                            style: const TextStyle(fontSize: 10.5)),
                        trailing: Text('${rf.amountSar.toStringAsFixed(2)} SAR',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: T.primary)),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SectionCard(
          title: 'الطلبات (${widget.row.orders.length})',
          child: widget.row.orders.isEmpty
              ? const Text('لا توجد طلبات', style: TextStyle(fontSize: 11.5))
              : Column(
                  children: widget.row.orders.take(15).map((o) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onTap: () => Get.toNamed(AppRoutes.orderDetail, arguments: o.id),
                      title: Text('${o.orderNo} (${o.isDeferred ? 'آجل' : 'كاش'})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      subtitle: Text('${o.status.labelAr} · ${o.totalPieces} قطعة',
                          style: const TextStyle(fontSize: 10.5)),
                      trailing: Text('${o.totalSar.toStringAsFixed(2)} SAR',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 10),
        SectionCard(
          title: 'ملاحظات الفريق الداخلية',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'أضف ملاحظة داخلية عن العميل أو التزامه بالسداد...',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _savingNotes ? null : _saveNotes,
                child: Text(_savingNotes ? 'جاري الحفظ...' : 'حفظ الملاحظات'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
