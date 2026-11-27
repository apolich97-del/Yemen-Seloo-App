import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/config/payment_accounts.dart';
import '../../core/models/currency.dart';
import '../../core/models/order.dart';
import '../../core/services/order_service.dart';
import '../../core/theme/app_theme.dart';
import '../orders/order_detail_screen.dart';
import 'role_guard.dart';

/// التقارير المالية للحوالات حسب الحساب البنكي واليوم والفترة + تصدير PDF.
class FinancialReportsTab extends StatefulWidget {
  const FinancialReportsTab({super.key});

  @override
  State<FinancialReportsTab> createState() => _FinancialReportsTabState();
}

class _FinancialReportsTabState extends State<FinancialReportsTab> {
  String _period = 'all'; // today | 7d | 30d | all | custom
  DateTime? _fromDate;
  DateTime? _toDate;
  String _accountFilter = 'all';
  bool _exportingPdf = false;

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _setPeriod(String key) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    setState(() {
      _period = key;
      if (key == 'today') {
        _fromDate = todayStart;
        _toDate = now;
      } else if (key == '7d') {
        _fromDate = todayStart.subtract(const Duration(days: 6));
        _toDate = now;
      } else if (key == '30d') {
        _fromDate = todayStart.subtract(const Duration(days: 29));
        _toDate = now;
      } else if (key == 'all') {
        _fromDate = null;
        _toDate = null;
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 7)),
              end: now,
            ),
    );
    if (picked == null) return;
    setState(() {
      _period = 'custom';
      _fromDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _toDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
    });
  }

  String _accountKeyFor(Order o) {
    if (o.payment.accountId.trim().isNotEmpty) return o.payment.accountId.trim();
    for (final a in kPaymentAccounts) {
      if (a.titleAr == o.payment.accountTitleAr ||
          a.numbers.contains(o.payment.accountNumber)) {
        return a.id;
      }
    }
    return o.payment.accountTitleAr.isNotEmpty
        ? o.payment.accountTitleAr
        : (o.payment.accountNumber.isNotEmpty ? o.payment.accountNumber : 'other');
  }

  String _accountTitleFor(String key, List<Order> orders) {
    final known = accountById(key);
    if (known != null) return '${known.titleAr} (${known.primaryNumber})';
    for (final o in orders) {
      if (_accountKeyFor(o) == key && o.payment.accountTitleAr.isNotEmpty) {
        return o.payment.accountTitleAr;
      }
    }
    return key == 'other' ? 'حساب غير محدد' : key;
  }

  double _amountSar(Order o) {
    if (o.payment.amount <= 0) return 0;
    if (o.currency == AppCurrency.sar) return o.payment.amount;
    if (o.exchangeRate > 0) return o.payment.amount / o.exchangeRate;
    return o.payment.amount;
  }

  bool _isConfirmed(Order o) =>
      o.payment.confirmedAt != null ||
      (o.status != OrderStatus.unpaid &&
          o.status != OrderStatus.verifying &&
          o.status != OrderStatus.cancelled);

  Future<void> _exportPdf(
    List<Order> filtered,
    Map<String, List<Order>> byAccount,
    List<Order> allSource,
  ) async {
    setState(() => _exportingPdf = true);
    try {
      final reg = pw.Font.ttf(
          await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
      final bold = pw.Font.ttf(
          await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
      pw.TextStyle t(double size, {bool b = false, PdfColor? c}) =>
          pw.TextStyle(
              font: b ? bold : reg,
              fontSize: size,
              color: c ?? PdfColor.fromInt(0xFF1F2937));

      final periodLabel = _fromDate != null && _toDate != null
          ? '${_fmtDate(_fromDate!)} إلى ${_fmtDate(_toDate!)}'
          : 'جميع الفترات';
      final totalSar =
          filtered.fold<double>(0, (s, o) => s + _amountSar(o));

      final doc = pw.Document(
        title: 'التقرير المالي للحوالات — يمن سيلو',
        author: 'يمن سيلو',
      );
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: reg, bold: bold),
          build: (_) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF5B21B6),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('التقرير المالي للحوالات البنكية — يمن سيلو',
                      style: t(15, b: true, c: PdfColors.white)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'الفترة: $periodLabel  |  الحساب: ${_accountFilter == 'all' ? 'جميع الحسابات' : _accountTitleFor(_accountFilter, allSource)}',
                    style: t(10, c: PdfColors.white),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'عدد الحوالات: ${filtered.length}  |  الإجمالي التقريبي بالريال السعودي: ${totalSar.toStringAsFixed(2)} ر.س',
                    style: t(10.5, b: true, c: PdfColor.fromInt(0xFFFDE68A)),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text('ملخص الحوالات لكل حساب',
                style: t(12, b: true, c: PdfColor.fromInt(0xFF5B21B6))),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFD1D5DB)),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE5E7EB)),
                  children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('الحساب', style: t(9.5, b: true))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('العدد', style: t(9.5, b: true))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('الإجمالي (ر.س)', style: t(9.5, b: true))),
                  ],
                ),
                ...byAccount.entries.map((e) {
                  final sum =
                      e.value.fold<double>(0, (s, o) => s + _amountSar(o));
                  return pw.TableRow(children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(_accountTitleFor(e.key, allSource),
                            style: t(9))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${e.value.length}', style: t(9))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${sum.toStringAsFixed(2)} SAR',
                            style: t(9, b: true))),
                  ]);
                }),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Text('تفاصيل الحوالات',
                style: t(12, b: true, c: PdfColor.fromInt(0xFF5B21B6))),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFD1D5DB)),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE5E7EB)),
                  children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('الطلب', style: t(9, b: true))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('المرسل / المرجع', style: t(9, b: true))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('الحساب', style: t(9, b: true))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('المبلغ', style: t(9, b: true))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('الحالة', style: t(9, b: true))),
                  ],
                ),
                ...filtered.map((o) => pw.TableRow(children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                              '${o.orderNo}\n${_fmtDate(o.payment.submittedAt ?? o.createdAt)}',
                              style: t(8.5))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                              '${o.payment.senderName}\n${o.payment.refNo}',
                              style: t(8.5))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(o.payment.accountTitleAr,
                              style: t(8.5))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                              '${formatMoney(o.payment.amount, o.currency)}\n(${_amountSar(o).toStringAsFixed(2)} SAR)',
                              style: t(8.5))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                              _isConfirmed(o) ? 'مؤكدة' : 'قيد المراجعة',
                              style: t(8.5))),
                    ])),
              ],
            ),
          ],
        ),
      );
      final dir = await getTemporaryDirectory();
      final f = File(
          '${dir.path}/Yemen-Seloo-Financial-Report-${DateTime.now().millisecondsSinceEpoch}.pdf');
      await f.writeAsBytes(await doc.save());
      await Share.shareXFiles([XFile(f.path)],
          text: 'التقرير المالي للحوالات — يمن سيلو');
    } catch (e) {
      Get.snackbar('تعذر تصدير التقرير', '$e');
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  void _zoomProof(String url, String title) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
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
              height: MediaQuery.of(context).size.height * 0.7,
              width: double.infinity,
              child: InteractiveViewer(
                minScale: 0.7,
                maxScale: 5.0,
                child: _ReportProofImage(url: url, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allow: ['accounting'],
      child: StreamBuilder<List<Order>>(
        stream: allOrdersStream(limit: 400),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('تعذر تحميل التقرير المالي: ${snap.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: T.muted)),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final withPayment = snap.data!
              .where((o) =>
                  !o.payment.isEmpty && o.status != OrderStatus.cancelled)
              .toList();

          final inDate = withPayment.where((o) {
            final dt = o.payment.submittedAt ?? o.createdAt;
            if (_fromDate != null && dt.isBefore(_fromDate!)) return false;
            if (_toDate != null && dt.isAfter(_toDate!)) return false;
            return true;
          }).toList();

          final byAccountAll = <String, List<Order>>{};
          for (final o in inDate) {
            final k = _accountKeyFor(o);
            byAccountAll.putIfAbsent(k, () => <Order>[]).add(o);
          }

          final filtered = _accountFilter == 'all'
              ? inDate
              : inDate
                  .where((o) => _accountKeyFor(o) == _accountFilter)
                  .toList();

          final confirmedCount = filtered.where(_isConfirmed).length;
          final pendingCount = filtered.length - confirmedCount;
          final totalSar =
              filtered.fold<double>(0, (s, o) => s + _amountSar(o));

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              // شريط الفلاتر الزمنية وتصدير PDF
              Container(
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
                        Icon(Icons.analytics_outlined,
                            size: 18, color: T.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('التقرير المالي للحوالات البنكية',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: T.text)),
                        ),
                        FilledButton.icon(
                          onPressed: _exportingPdf || filtered.isEmpty
                              ? null
                              : () => _exportPdf(
                                  filtered, byAccountAll, withPayment),
                          icon: const Icon(Icons.picture_as_pdf_outlined,
                              size: 16),
                          label: Text(
                            _exportingPdf ? 'تجهيز...' : 'تصدير PDF',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _pChip('اليوم', 'today'),
                        _pChip('آخر 7 أيام', '7d'),
                        _pChip('آخر 30 يوماً', '30d'),
                        _pChip('الكل', 'all'),
                        ActionChip(
                          avatar: const Icon(Icons.date_range, size: 15),
                          label: Text(
                            _period == 'custom' &&
                                    _fromDate != null &&
                                    _toDate != null
                                ? '${_fmtDate(_fromDate!)} → ${_fmtDate(_toDate!)}'
                                : 'نطاق مخصص',
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: _period == 'custom'
                              ? AppColors.primary.withOpacity(.16)
                              : T.soft,
                          onPressed: _pickCustomRange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Builder(builder: (_) {
                      final extraKeys = byAccountAll.keys
                          .where((k) => !kPaymentAccounts.any((a) => a.id == k))
                          .toList();
                      final validIds = <String>{
                        'all',
                        ...kPaymentAccounts.map((a) => a.id),
                        ...extraKeys,
                      };
                      final safeValue =
                          validIds.contains(_accountFilter) ? _accountFilter : 'all';
                      return DropdownButtonFormField<String>(
                        value: safeValue,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'تصفية حسب الحساب المستلم',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('جميع الحسابات (تقرير عام)',
                                style: TextStyle(fontSize: 12)),
                          ),
                          ...kPaymentAccounts.map((a) => DropdownMenuItem(
                                value: a.id,
                                child: Text('${a.titleAr} (${a.primaryNumber})',
                                    style: const TextStyle(fontSize: 12)),
                              )),
                          ...extraKeys.map((k) => DropdownMenuItem(
                                value: k,
                                child: Text(_accountTitleFor(k, withPayment),
                                    style: const TextStyle(fontSize: 12)),
                              )),
                        ],
                        onChanged: (v) =>
                            setState(() => _accountFilter = v ?? 'all'),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // مؤشرات التقرير العام / المصفى
              Row(
                children: [
                  _kpiCard('عدد الحوالات', '${filtered.length}', T.primary),
                  const SizedBox(width: 8),
                  _kpiCard('مؤكدة', '$confirmedCount', T.success),
                  const SizedBox(width: 8),
                  _kpiCard('معلقة', '$pendingCount', T.warning),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('إجمالي المبالغ المحوّلة (المعادل بالر.س)',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70)),
                    Text('${totalSar.toStringAsFixed(2)} ر.س',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.amberAccent)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // تقرير كل حساب بمفرده
              Text('تقرير الحوالات لكل حساب بمفرده',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w900, color: T.text)),
              const SizedBox(height: 8),
              if (byAccountAll.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: T.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: T.border),
                  ),
                  child: Center(
                    child: Text('لا توجد حوالات في هذه الفترة',
                        style: TextStyle(fontSize: 12, color: T.muted)),
                  ),
                )
              else
                ...byAccountAll.entries.map((entry) {
                  final list = entry.value;
                  final sumSar =
                      list.fold<double>(0, (s, o) => s + _amountSar(o));
                  final selected = _accountFilter == entry.key;
                  final byCurr = <AppCurrency, double>{};
                  for (final o in list) {
                    byCurr[o.currency] =
                        (byCurr[o.currency] ?? 0) + o.payment.amount;
                  }
                  final currSummary = byCurr.entries
                      .map((e) => formatMoney(e.value, e.key))
                      .join(' · ');

                  return InkWell(
                    onTap: () => setState(() =>
                        _accountFilter = selected ? 'all' : entry.key),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withOpacity(.09)
                            : T.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: selected ? AppColors.primary : T.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_accountTitleFor(entry.key, withPayment),
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: T.text)),
                                const SizedBox(height: 3),
                                Text('${list.length} حوالة · $currSummary',
                                    style: TextStyle(
                                        fontSize: 10.5, color: T.muted)),
                              ],
                            ),
                          ),
                          Text('${sumSar.toStringAsFixed(2)} ر.س',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  color: T.primary)),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 14),
              Text('سجل الحوالات (${filtered.length})',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w900, color: T.text)),
              const SizedBox(height: 8),
              ...filtered.map((o) {
                final ok = _isConfirmed(o);
                final dt = o.payment.submittedAt ?? o.createdAt;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            InkWell(
                              onTap: () => Get.to(
                                  () => const OrderDetailScreen(),
                                  arguments: o.id),
                              child: Text(o.orderNo,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: T.primary)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (ok ? T.success : T.warning)
                                    .withOpacity(.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                ok ? 'مؤكدة' : 'قيد المراجعة',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: ok ? T.success : T.warning),
                              ),
                            ),
                            const Spacer(),
                            Text(formatMoney(o.payment.amount, o.currency),
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: T.text)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${o.payment.accountTitleAr} · المرسل: ${o.payment.senderName}'
                          '${o.payment.refNo.isNotEmpty ? ' · مرجع: ${o.payment.refNo}' : ''}',
                          style: TextStyle(fontSize: 11, color: T.muted),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_fmtDate(dt)} · المعادل: ${_amountSar(o).toStringAsFixed(2)} ر.س',
                              style: TextStyle(fontSize: 10.5, color: T.muted),
                            ),
                            if (o.payment.proofUrl.isNotEmpty)
                              TextButton.icon(
                                onPressed: () => _zoomProof(o.payment.proofUrl,
                                    'إثبات حوالة ${o.orderNo}'),
                                icon: const Icon(Icons.image_outlined, size: 15),
                                label: const Text('صورة الحوالة',
                                    style: TextStyle(fontSize: 11)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _pChip(String label, String key) {
    final active = _period == key;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: active,
      selectedColor: AppColors.primary.withOpacity(.16),
      onSelected: (_) => _setPeriod(key),
    );
  }

  Widget _kpiCard(String title, String val, Color c) => Expanded(
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
              const SizedBox(height: 3),
              Text(val,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900, color: c)),
            ],
          ),
        ),
      );
}

class _ReportProofImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  const _ReportProofImage({required this.url, this.fit = BoxFit.contain});

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
      errorBuilder: (_, __, ___) =>
          const Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}
