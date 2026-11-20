import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/order.dart';
import '../models/refund.dart';

/// استرداد الأموال: الإنشاء، بيانات الحساب، الإتمام، الإلغاء، وسند PDF.
class RefundService extends GetxService {
  final _db = FirebaseFirestore.instance;

  Stream<List<RefundRecord>> forOrder(String orderId) => _db
      .collection('orders')
      .doc(orderId)
      .snapshots()
      .map((d) => (((d.data()?['refunds'] as List?) ?? const []))
          .map((e) => RefundRecord.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList());

  Future<List<RefundRecord>> _load(String orderId) async {
    final d = await _db.collection('orders').doc(orderId).get();
    return (((d.data()?['refunds'] as List?) ?? const []))
        .map((e) => RefundRecord.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _save(String orderId, List<RefundRecord> list,
      {Map<String, dynamic>? extra}) async {
    await _db.collection('orders').doc(orderId).update({
      'refunds': list.map((e) => e.toMap()).toList(),
      'refundedTotalSar':
          list.where((e) => e.status != 'cancelled').fold<double>(0, (a, b) => a + b.amountSar),
      'updatedAt': FieldValue.serverTimestamp(),
      if (extra != null) ...extra,
    });
  }

  /// رقم مرجعي تسلسلي: RF-YYYY-0001
  Future<String> _nextRefNo() async {
    final year = DateTime.now().year;
    final ref = _db.collection('counters').doc('refunds_$year');
    final no = await _db.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      final cur = (snap.data()?['value'] as num?)?.toInt() ?? 0;
      tx.set(ref, {'value': cur + 1}, SetOptions(merge: true));
      return cur + 1;
    });
    return 'RF-$year-${no.toString().padLeft(4, '0')}';
  }

  Future<RefundRecord> create({
    required Order order,
    required List<Map<String, dynamic>> items,
    required double amountSar,
    required String reason,
    String reasonNote = '',
    required String settlementMethod,
    required String byName,
  }) async {
    final list = await _load(order.id);
    final record = RefundRecord(
      id: 'rf-${DateTime.now().millisecondsSinceEpoch}',
      refundRefNo: await _nextRefNo(),
      reason: reason,
      reasonNote: reasonNote,
      items: items,
      amountSar: amountSar,
      amountLocal: amountSar * order.exchangeRate,
      currency: order.currency.name.toUpperCase(),
      exchangeRate: order.exchangeRate,
      settlementMethod: settlementMethod,
      status: settlementMethod == 'deduct_remaining'
          ? 'ready_to_transfer'
          : 'pending_account',
      createdBy: byName,
      deductedFromRemainingLocal:
          settlementMethod == 'deduct_remaining' ? amountSar * order.exchangeRate : 0,
      createdAt: DateTime.now(),
    );
    list.add(record);

    final extra = <String, dynamic>{};
    if (settlementMethod == 'deduct_remaining') {
      extra['remainingLocal'] =
          (order.remainingLocal - record.amountLocal).clamp(0, 1e12);
      extra['paidTotalLocal'] = order.paidTotalLocal + record.amountLocal;
    }
    await _save(order.id, list, extra: extra);

    await _db.collection('staff_alerts').add({
      'type': 'refund_created',
      'target': 'accounting',
      'orderId': order.id,
      'orderNo': order.orderNo,
      'refundRefNo': record.refundRefNo,
      'amountSar': record.amountSar,
      'settlementMethod': settlementMethod,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
    return record;
  }

  /// العميل يزوّد بيانات حسابه.
  Future<void> setPayoutAccount({
    required String orderId,
    required String refundId,
    required String bank,
    required String accountNumber,
    required String holder,
  }) async {
    final list = await _load(orderId);
    final i = list.indexWhere((e) => e.id == refundId);
    if (i < 0) return;
    list[i] = list[i].copyWith(
      bankOrWalletName: bank,
      payoutAccountNumber: accountNumber,
      payoutAccountHolder: holder,
      status: 'ready_to_transfer',
    );
    await _save(orderId, list);
    await _db.collection('staff_alerts').add({
      'type': 'refund_ready',
      'target': 'accounting',
      'orderId': orderId,
      'refundRefNo': list[i].refundRefNo,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  /// إتمام الاسترداد بإثبات التحويل.
  Future<void> complete({
    required String orderId,
    required String refundId,
    required String transferRefNo,
    String proofUrl = '',
    required String byName,
  }) async {
    final list = await _load(orderId);
    final i = list.indexWhere((e) => e.id == refundId);
    if (i < 0) return;
    list[i] = list[i].copyWith(
      status: 'completed',
      transferRefNo: transferRefNo,
      transferProofUrl: proofUrl,
      completedBy: byName,
      completedAt: DateTime.now(),
    );
    await _save(orderId, list);
  }

  /// إلغاء أو حذف سجل (المدير الرئيسي فقط).
  Future<void> cancelOrDelete({
    required String orderId,
    required String refundId,
    required bool delete,
  }) async {
    final list = await _load(orderId);
    final i = list.indexWhere((e) => e.id == refundId);
    if (i < 0) return;
    final rec = list[i];
    final extra = <String, dynamic>{};
    if (rec.settlementMethod == 'deduct_remaining' && rec.status != 'cancelled') {
      final doc = await _db.collection('orders').doc(orderId).get();
      final remaining = ((doc.data()?['remainingLocal'] as num?) ?? 0).toDouble();
      final paid = ((doc.data()?['paidTotalLocal'] as num?) ?? 0).toDouble();
      extra['remainingLocal'] = remaining + rec.amountLocal;
      extra['paidTotalLocal'] = (paid - rec.amountLocal).clamp(0, 1e12);
    }
    if (delete) {
      list.removeAt(i);
    } else {
      list[i] = rec.copyWith(status: 'cancelled');
    }
    await _save(orderId, list, extra: extra.isEmpty ? null : extra);
  }

  // ═════════════ سند الاسترداد PDF ═════════════

  static const PdfColor _violet = PdfColor.fromInt(0xFF7C3AED);
  static const PdfColor _violetDark = PdfColor.fromInt(0xFF5B21B6);
  static const PdfColor _gold = PdfColor.fromInt(0xFFC9A227);
  static const PdfColor _ink = PdfColor.fromInt(0xFF1B1F1D);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B7671);
  static const PdfColor _soft = PdfColor.fromInt(0xFFF7F5FB);

  Future<File> buildPdf(Order order, RefundRecord r) async {
    final reg = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    final logo = pw.MemoryImage(
        (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List());

    pw.TextStyle t(double size, {bool b = false, PdfColor c = _ink}) =>
        pw.TextStyle(font: b ? bold : reg, fontSize: size, color: c);

    pw.Widget kv(String k, String v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(v.isEmpty ? '—' : v, style: t(10.5, b: true)),
              pw.Text(k, style: t(10.5, c: _muted)),
            ],
          ),
        );

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              gradient: const pw.LinearGradient(
                  colors: [_violetDark, _violet]),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 52,
                  height: 52,
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(10),
                    border: pw.Border.all(color: _gold, width: 1.5),
                  ),
                  child: pw.Image(logo),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('يمن سيلو — Yemen Seloo',
                          style: t(15, b: true, c: PdfColors.white)),
                      pw.SizedBox(height: 3),
                      pw.Text('سند استرداد أموال',
                          style: t(11, c: PdfColors.white)),
                    ],
                  ),
                ),
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: _gold,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(r.refundRefNo, style: t(11, b: true)),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _soft,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: PdfColor.fromInt(0xFFE4DDF5)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text('بيانات السند', style: t(12, b: true, c: _violetDark)),
                pw.SizedBox(height: 6),
                kv('رقم المرجع', r.refundRefNo),
                kv('رقم الطلب', order.orderNo),
                kv('العميل', order.address.receiverName),
                kv('الهاتف', order.address.phone),
                kv('الحالة', r.statusAr),
                kv('السبب', r.reasonNote.isEmpty
                    ? r.reasonAr
                    : '${r.reasonAr} — ${r.reasonNote}'),
                kv('طريقة التسوية', r.methodAr),
                if (r.bankOrWalletName.isNotEmpty)
                  kv('الحساب', '${r.bankOrWalletName} · ${r.payoutAccountNumber}'),
                if (r.payoutAccountHolder.isNotEmpty)
                  kv('اسم المستلم', r.payoutAccountHolder),
                if (r.transferRefNo.isNotEmpty)
                  kv('مرجع التحويل', r.transferRefNo),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text('القطع المستردة', style: t(12, b: true, c: _violetDark)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['القطعة', 'اللون', 'المقاس', 'الكمية', 'القيمة (ر.س)'],
            data: r.items
                .map((e) => [
                      '${e['title'] ?? ''}',
                      '${e['color'] ?? ''}',
                      '${e['size'] ?? ''}',
                      '${e['qty'] ?? 1}',
                      ((e['unitPriceSar'] as num? ?? 0) * ((e['qty'] as num? ?? 1)))
                          .toStringAsFixed(2),
                    ])
                .toList(),
            headerStyle: t(10, b: true, c: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _violet),
            cellStyle: t(9.5),
            cellAlignments: {
              0: pw.Alignment.centerRight,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
            },
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _gold, width: 1.2),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('المبلغ المسترد', style: t(12, b: true, c: _violetDark)),
                pw.Text(
                    '${r.amountSar.toStringAsFixed(2)} ر.س  ·  '
                    '${r.amountLocal.toStringAsFixed(2)} ${r.currency}',
                    style: t(12, b: true)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
              'سعر الصرف المثبّت: 1 ر.س = ${r.exchangeRate.toStringAsFixed(2)} ${r.currency}',
              style: t(9, c: _muted)),
          pw.SizedBox(height: 4),
          pw.Text(
              'هذا السند صادر إلكترونياً من تطبيق يمن سيلو ولا يحتاج توقيعاً.',
              style: t(9, c: _muted)),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/refund-${r.refundRefNo}.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }
}
