import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/currency.dart';
import '../../core/models/order.dart';
import '../../core/models/receipt.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/customer_accounting_service.dart';
import '../../core/services/order_documents.dart';
import '../../core/services/order_service.dart';
import '../../core/services/receipt_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/wallet_service.dart';
import '../../core/theme/app_theme.dart';
import '../guide/interactive_guide.dart';

/// كشف الحساب المحاسبي الكامل للعميل:
/// قيود دفتر الأستاذ (مدين / دائن / رصيد) + عمليات الاسترداد + أرشيف صور الحوالات + تحديد المدة.
class AccountStatementScreen extends StatefulWidget {
  const AccountStatementScreen({super.key});

  @override
  State<AccountStatementScreen> createState() => _AccountStatementScreenState();
}

class _AccountStatementScreenState extends State<AccountStatementScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
  String _tab = 'ledger'; // ledger | photos | refunds | orders | deferred
  bool _exportingPdf = false;
  late AppCurrency _currency;

  @override
  void initState() {
    super.initState();
    _currency = Get.isRegistered<SettingsService>()
        ? Get.find<SettingsService>().displayCurrency.value
        : AppCurrency.south;
  }

  double _convertSar(double sar) {
    final s = Get.isRegistered<SettingsService>()
        ? Get.find<SettingsService>().settings.value
        : null;
    final rate = s?.rateFor(_currency.key) ?? 1.0;
    return sar * rate;
  }

  String _fmt(double sar) =>
      formatMoney(roundMoney(_convertSar(sar), _currency), _currency);

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _applyPreset(String key) {
    final now = DateTime.now();
    setState(() {
      if (key == 'all') {
        _fromDate = null;
        _toDate = null;
      } else if (key == 'month') {
        _fromDate = DateTime(now.year, now.month, 1);
        _toDate = now;
      } else if (key == '30d') {
        _fromDate = now.subtract(const Duration(days: 30));
        _toDate = now;
      } else if (key == '7d') {
        _fromDate = now.subtract(const Duration(days: 7));
        _toDate = now;
      }
    });
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final initial = isFrom ? (_fromDate ?? now.subtract(const Duration(days: 30))) : (_toDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) _toDate = picked;
      } else {
        _toDate = picked;
        if (_fromDate != null && _fromDate!.isAfter(picked)) _fromDate = picked;
      }
    });
  }

  Future<void> _downloadPdf(
    AppUser? u,
    AccountingStatementReport report,
    double walletBalSar,
  ) async {
    setState(() => _exportingPdf = true);
    try {
      final f = await OrderDocuments.buildStatementPdf(
        customer: u,
        report: report,
        walletBalanceSar: walletBalSar,
      );
      await Share.shareXFiles([XFile(f.path)], text: 'كشف الحساب المحاسبي — يمن سيلو');
    } catch (e) {
      Get.snackbar('تعذر تصدير PDF', '$e');
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<void> _sendWhatsApp(
    AppUser? u,
    AccountingStatementReport report,
    double walletBalSar,
  ) async {
    final periodText = (_fromDate != null || _toDate != null)
        ? 'من ${_fromDate != null ? _fmtDate(_fromDate!) : 'البداية'} إلى ${_toDate != null ? _fmtDate(_toDate!) : 'الآن'}'
        : 'كامل الفترة';
    final msg = StringBuffer()
      ..writeln('╔══════════════════════════════╗')
      ..writeln('   *طلب كشف حساب — يمن سيلو*')
      ..writeln('╚══════════════════════════════╝')
      ..writeln('• *العميل:* ${u?.displayName ?? 'عميل'} (${u?.effectiveCode ?? ''})')
      ..writeln('• *الهاتف:* ${u?.phone ?? ''}')
      ..writeln('• *المدة:* $periodText')
      ..writeln('• العملة المختارة: ${_currency.labelAr}')
      ..writeln('──────────────────────────────')
      ..writeln('• عليه (المطلوب): ${_fmt((report.openingBalanceSar > 0 ? report.openingBalanceSar : 0) + report.periodDebitSar)}')
      ..writeln('• له (المدفوع والمسترد): ${_fmt((report.openingBalanceSar < 0 ? -report.openingBalanceSar : 0) + report.periodCreditSar)}')
      ..writeln('• *الصافي (الرصيد الختامي):* ${_fmt(report.closingBalanceSar)}')
      ..writeln('• مستردات الفترة: ${_fmt(report.totalRefundedSar)}')
      ..writeln('• رصيد المحفظة: ${_fmt(walletBalSar)}')
      ..writeln('• عدد القيود: ${report.entries.length} | صور الحوالات: ${report.transferPhotos.length}');

    final phone = Get.isRegistered<SettingsService>()
        ? Get.find<SettingsService>().settings.value.supportWhatsApp.replaceAll(RegExp(r'[^0-9]'), '')
        : '';
    final encoded = Uri.encodeComponent(msg.toString());
    final url = phone.isEmpty ? 'https://wa.me/?text=$encoded' : 'https://wa.me/$phone?text=$encoded';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _zoomPhoto(String url, String title) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(title, style: const TextStyle(fontSize: 13)),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.65,
              width: double.infinity,
              child: InteractiveViewer(
                minScale: 0.7,
                maxScale: 4.5,
                child: _ProofImage(url: url, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final orderSvc = Get.find<OrderService>();
    final receiptSvc = Get.find<ReceiptService>();
    final walletSvc = Get.put(WalletService(), permanent: false);

    final uid = auth.uid ?? '';
    return Scaffold(
      backgroundColor: T.bg,
      appBar: AppBar(
        backgroundColor: T.surface,
        title: const Text('كشف الحساب المحاسبي'),
        actions: const [ThemeToggleButton(), SizedBox(width: 6)],
      ),
      body: uid.isEmpty
          ? Center(
              child: ElevatedButton(
                onPressed: () => Get.toNamed(AppRoutes.login),
                child: const Text('سجّل الدخول لعرض كشف حسابك'),
              ),
            )
          : Obx(() {
              final u = auth.user.value;
              return StreamBuilder<List<Order>>(
                stream: orderSvc.myOrders(),
                builder: (context, oSnap) {
                  return StreamBuilder<List<Receipt>>(
                    stream: receiptSvc.byCustomer(uid),
                    builder: (context, rSnap) {
                      return StreamBuilder<Map<String, dynamic>?>(
                        stream: walletSvc.watch(),
                        builder: (context, wSnap) {
                          if (oSnap.connectionState == ConnectionState.waiting &&
                              !oSnap.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final orders = oSnap.data ?? const <Order>[];
                          final receipts = rSnap.data ?? const <Receipt>[];
                          final walletBal =
                              ((wSnap.data?['balanceSar'] as num?) ?? 0).toDouble();

                          final report = AccountingStatementEngine.build(
                            orders: orders,
                            receipts: receipts,
                            fromDate: _fromDate,
                            toDate: _toDate,
                          );

                          final activeDeferredDebtSar = orders
                              .where((o) =>
                                  o.status != OrderStatus.cancelled && o.hasRemaining)
                              .fold<double>(0, (s, o) => s + o.remainingSar);
                          final creditLimit = u?.effectiveCreditLimitSar ??
                              CustomerTier.normal.defaultCreditLimitSar;
                          final availCredit = (creditLimit - activeDeferredDebtSar)
                              .clamp(0.0, double.infinity);

                          return ListView(
                            padding: const EdgeInsets.all(14),
                            children: [
                              _headerCard(u, creditLimit, availCredit),
                              const SizedBox(height: 12),
                              _dateFilterCard(),
                              const SizedBox(height: 12),
                              _currencySelectorCard(),
                              const SizedBox(height: 12),
                              _simpleSummaryCard(report),
                              const SizedBox(height: 12),
                              _kpiGrid(report, walletBal),
                              const SizedBox(height: 12),
                              _actionsRow(u, report, walletBal),
                              const SizedBox(height: 12),
                              _tabStrip(report),
                              const SizedBox(height: 12),
                              if (_tab == 'ledger') _ledgerView(report),
                              if (_tab == 'photos') _photosView(report),
                              if (_tab == 'refunds') _refundsView(report),
                              if (_tab == 'orders') _ordersView(report.includedOrders),
                              if (_tab == 'deferred')
                                _ordersView(report.includedOrders
                                    .where((o) =>
                                        o.isDeferred &&
                                        o.status != OrderStatus.cancelled)
                                    .toList()),
                              const SizedBox(height: 24),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            }),
    );
  }

  Widget _headerCard(AppUser? u, double limitSar, double availSar) {
    final tier = u?.tier ?? CustomerTier.normal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u?.displayName.isNotEmpty == true ? u!.displayName : 'عميل يمن سيلو',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${u?.effectiveCode ?? ''} · ${u?.phone ?? ''}',
                      style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tier.labelAr,
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.amberAccent),
                ),
              ),
            ],
          ),
          if ((u?.fullAddressAr ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'العنوان: ${u!.fullAddressAr}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الحد الائتماني الآجل: ${limitSar.toStringAsFixed(0)} SAR',
                    style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
                Text(
                  tier == CustomerTier.blockedDeferred
                      ? 'الآجل موقوف'
                      : 'المتاح: ${availSar.toStringAsFixed(0)} SAR',
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.amberAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateFilterCard() {
    return Container(
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
              Icon(Icons.date_range_outlined, size: 17, color: T.primary),
              const SizedBox(width: 6),
              Text('تحديد مدة الكشف المحاسبي',
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w900, color: T.text)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(true),
                  icon: const Icon(Icons.calendar_today_outlined, size: 15),
                  label: Text(
                    _fromDate == null ? 'من: البداية' : 'من: ${_fmtDate(_fromDate!)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(false),
                  icon: const Icon(Icons.event_outlined, size: 15),
                  label: Text(
                    _toDate == null ? 'إلى: الآن' : 'إلى: ${_fmtDate(_toDate!)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _presetChip('كل الفترات', 'all', _fromDate == null && _toDate == null),
              _presetChip('هذا الشهر', 'month', false),
              _presetChip('آخر 30 يوم', '30d', false),
              _presetChip('آخر 7 أيام', '7d', false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, String key, bool selected) => ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 10.5)),
        backgroundColor: selected ? AppColors.primary.withOpacity(.14) : T.soft,
        onPressed: () => _applyPreset(key),
      );

  Widget _currencySelectorCard() {
    const options = <AppCurrency>[
      AppCurrency.south,
      AppCurrency.north,
      AppCurrency.sar,
      AppCurrency.usd,
    ];
    return Container(
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
              Icon(Icons.currency_exchange, size: 16, color: T.primary),
              const SizedBox(width: 6),
              Text('عملة عرض كشف الحساب',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w900, color: T.text)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options.map((c) {
              final active = _currency == c;
              return ChoiceChip(
                selected: active,
                selectedColor: AppColors.primary.withOpacity(.16),
                label: Text(
                  c.labelAr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? AppColors.primary : T.text,
                  ),
                ),
                onSelected: (_) => setState(() => _currency = c),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _simpleSummaryCard(AccountingStatementReport report) {
    final owedSar = (report.openingBalanceSar > 0 ? report.openingBalanceSar : 0.0) +
        report.periodDebitSar;
    final paidSar = (report.openingBalanceSar < 0 ? -report.openingBalanceSar : 0.0) +
        report.periodCreditSar;
    final netSar = report.closingBalanceSar;
    final netLabel = netSar > 0.05
        ? 'متبقي عليه'
        : (netSar < -0.05 ? 'رصيد له' : 'مسدّد بالكامل');
    final netColor = netSar > 0.05 ? T.danger : T.success;

    Widget box(String title, String val, String sub, Color c) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.withOpacity(.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.withOpacity(.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w800, color: c)),
                const SizedBox(height: 4),
                Text(val,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w900, color: T.text)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 9.5, color: T.muted)),
              ],
            ),
          ),
        );

    return Row(
      children: [
        box('عليه (المطلوب)', _fmt(owedSar), 'إجمالي الفواتير', T.danger),
        const SizedBox(width: 6),
        box('له (المدفوع)', _fmt(paidSar), 'سداد + استرداد', T.success),
        const SizedBox(width: 6),
        box('الصافي', _fmt(netSar.abs()), netLabel, netColor),
      ],
    );
  }

  Widget _kpiGrid(AccountingStatementReport report, double walletBal) {
    Widget cell(String title, String value, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: T.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: T.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 10, color: T.muted)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: color)),
              ],
            ),
          ),
        );

    return Column(
      children: [
        Row(
          children: [
            cell('الرصيد الافتتاحي', _fmt(report.openingBalanceSar), T.text),
            const SizedBox(width: 8),
            cell('إجمالي المدين (عليه)', _fmt(report.periodDebitSar), T.danger),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            cell('إجمالي الدائن (له)', _fmt(report.periodCreditSar), T.success),
            const SizedBox(width: 8),
            cell(
              'الصافي الختامي',
              _fmt(report.closingBalanceSar),
              report.closingBalanceSar > 0.5 ? T.danger : T.success,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            cell('مستردات الفترة', _fmt(report.totalRefundedSar), T.primary),
            const SizedBox(width: 8),
            cell('رصيد المحفظة', _fmt(walletBal), T.info),
          ],
        ),
      ],
    );
  }

  Widget _actionsRow(
    AppUser? u,
    AccountingStatementReport report,
    double walletBal,
  ) =>
      Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _exportingPdf ? null : () => _downloadPdf(u, report, walletBal),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
              label: Text(_exportingPdf ? 'جاري التجهيز...' : 'PDF الكشف المحاسبي',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _sendWhatsApp(u, report, walletBal),
              style: ElevatedButton.styleFrom(
                backgroundColor: T.whatsapp,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.chat, size: 17),
              label: const Text('طلب / إرسال لواتساب',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      );

  Widget _tabStrip(AccountingStatementReport report) {
    final defs = [
      ('ledger', 'القيد المحاسبي (${report.entries.length})'),
      ('photos', 'صور الحوالات (${report.transferPhotos.length})'),
      ('refunds', 'الاستردادات (${report.refunds.length})'),
      ('orders', 'الطلبات (${report.includedOrders.length})'),
      ('deferred', 'الآجل (${report.deferredOrdersCount})'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: defs.map((d) {
          final active = _tab == d.$1;
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: ChoiceChip(
              label: Text(d.$2, style: const TextStyle(fontSize: 11)),
              selected: active,
              onSelected: (_) => setState(() => _tab = d.$1),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _ledgerView(AccountingStatementReport report) {
    return Container(
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: T.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          headingRowColor: WidgetStatePropertyAll(AppColors.primary.withOpacity(.08)),
          columns: const [
            DataColumn(label: Text('م', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11))),
            DataColumn(label: Text('التاريخ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11))),
            DataColumn(label: Text('المستند', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11))),
            DataColumn(label: Text('البيان', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11))),
            DataColumn(label: Text('مدين', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11))),
            DataColumn(label: Text('دائن', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11))),
            DataColumn(label: Text('الرصيد', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11))),
            DataColumn(label: Text('إثبات', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11))),
          ],
          rows: [
            DataRow(
              color: WidgetStatePropertyAll(T.soft),
              cells: [
                const DataCell(Text('0', style: TextStyle(fontSize: 11))),
                DataCell(Text(_fromDate != null ? _fmtDate(_fromDate!) : '—',
                    style: const TextStyle(fontSize: 11))),
                const DataCell(Text('OPEN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                const DataCell(Text('الرصيد الافتتاحي المرحّل',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                const DataCell(Text('—', style: TextStyle(fontSize: 11))),
                const DataCell(Text('—', style: TextStyle(fontSize: 11))),
                DataCell(Text(_fmt(report.openingBalanceSar),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
                const DataCell(Text('—')),
              ],
            ),
            ...report.entries.map((e) => DataRow(cells: [
                  DataCell(Text('${e.seq}', style: const TextStyle(fontSize: 11))),
                  DataCell(Text(_fmtDate(e.date), style: const TextStyle(fontSize: 11))),
                  DataCell(Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.entryTypeLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                      Text(e.docNo, style: TextStyle(fontSize: 9.5, color: T.muted)),
                    ],
                  )),
                  DataCell(ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 210),
                    child: Text(e.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5)),
                  )),
                  DataCell(Text(
                    e.debitSar > 0 ? _fmt(e.debitSar) : '—',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: e.debitSar > 0 ? T.danger : T.muted),
                  )),
                  DataCell(Text(
                    e.creditSar > 0 ? _fmt(e.creditSar) : '—',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: e.creditSar > 0 ? T.success : T.muted),
                  )),
                  DataCell(Text(
                    _fmt(e.runningBalanceSar),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  )),
                  DataCell(e.proofUrl.isEmpty
                      ? const Text('—')
                      : IconButton(
                          icon: Icon(Icons.image_outlined, size: 18, color: T.primary),
                          onPressed: () => _zoomPhoto(e.proofUrl, 'إثبات ${e.docNo}'),
                        )),
                ])),
          ],
        ),
      ),
    );
  }

  Widget _photosView(AccountingStatementReport report) {
    if (report.transferPhotos.isEmpty) {
      return _emptyBox('لا توجد صور حوالات أو إثباتات في هذه الفترة');
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: report.transferPhotos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (_, i) {
        final p = report.transferPhotos[i];
        return InkWell(
          onTap: () => _zoomPhoto(p.url, p.title),
          child: Container(
            decoration: BoxDecoration(
              color: T.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: T.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _ProofImage(url: p.url, fit: BoxFit.cover)),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      Text(
                        '${_fmt(p.amountSar)} · ${p.statusAr}',
                        style: TextStyle(fontSize: 10, color: T.primary),
                      ),
                      if (p.refNo.isNotEmpty)
                        Text('مرجع: ${p.refNo}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 9.5, color: T.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _refundsView(AccountingStatementReport report) {
    if (report.refunds.isEmpty) {
      return _emptyBox('لا توجد عمليات استرداد في هذه الفترة');
    }
    return Column(
      children: report.refunds
          .map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: T.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: T.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${r.refundRefNo} · طلب ${r.orderNo}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (r.status == 'completed' ? T.success : T.warning).withOpacity(.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(r.statusAr,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: r.status == 'completed' ? T.success : T.warning)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${r.reasonAr} · ${r.methodAr}',
                        style: TextStyle(fontSize: 11, color: T.muted)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_fmt(r.amountSar)} · ${_fmtDate(r.date)}',
                            style: TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.w800, color: T.primary)),
                        if (r.transferProofUrl.isNotEmpty)
                          TextButton.icon(
                            onPressed: () =>
                                _zoomPhoto(r.transferProofUrl, 'إثبات استرداد ${r.refundRefNo}'),
                            icon: const Icon(Icons.image_outlined, size: 16),
                            label: const Text('صورة التحويل', style: TextStyle(fontSize: 11)),
                          ),
                      ],
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _ordersView(List<Order> list) {
    if (list.isEmpty) return _emptyBox('لا توجد طلبات مطابقة في هذه الفترة');
    return Column(
      children: list
          .map((o) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => Get.toNamed(AppRoutes.orderDetail, arguments: o.id),
                  title: Text('${o.orderNo} (${o.isDeferred ? 'آجل 50%' : 'كاش'})',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
                  subtitle: Text(
                    '${_fmtDate(o.createdAt)} · ${o.status.labelAr}'
                    '${o.hasRemaining ? ' · متبقي: ${formatMoney(o.remainingLocal, o.currency)}' : ''}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Text(formatMoney(o.totalLocal, o.currency),
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w900, color: T.primary)),
                ),
              ))
          .toList(),
    );
  }

  Widget _emptyBox(String msg) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: T.border),
        ),
        child: Center(
          child: Text(msg, style: TextStyle(fontSize: 12, color: T.muted)),
        ),
      );
}

class _ProofImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  const _ProofImage({required this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('data:')) {
      try {
        final idx = url.indexOf(',');
        final bytes = base64Decode(idx >= 0 ? url.substring(idx + 1) : url);
        return Image.memory(bytes, fit: fit);
      } catch (_) {
        return const Center(child: Icon(Icons.broken_image_outlined));
      }
    }
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}
