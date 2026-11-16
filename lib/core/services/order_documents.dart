import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/currency.dart';
import '../models/order.dart';

/// مستندات الطلب بهوية «يمن سيلو»: فاتورة PDF عربية + قالب رسالة واتساب.
class OrderDocuments {
  static const _violet = PdfColor.fromInt(0xFF7C3AED);
  static const _violetDark = PdfColor.fromInt(0xFF5B21B6);
  static const _gold = PdfColor.fromInt(0xFFC9A227);
  static const _soft = PdfColor.fromInt(0xFFF7F5FB);
  static const _ink = PdfColor.fromInt(0xFF1B1F1D);
  static const _muted = PdfColor.fromInt(0xFF6B7671);

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ───────────────────────── قالب واتساب ─────────────────────────
  static String whatsappText(Order o) {
    final b = StringBuffer()
      ..writeln('🛍️ *يمن سيلو* — ملخص طلبك')
      ..writeln('━━━━━━━━━━━━━━')
      ..writeln('🔖 رقم الطلب: *${o.orderNo}*')
      ..writeln('📅 التاريخ: ${_date(o.createdAt)}')
      ..writeln('📦 الحالة: ${o.status.labelAr}')
      ..writeln('📍 التوصيل إلى: ${o.address.fullAr}')
      ..writeln()
      ..writeln('*المنتجات (${o.items.length})*');
    for (final it in o.items) {
      b.writeln('▫️ ${it.title} × ${it.qty}');
    }
    b
      ..writeln()
      ..writeln('*الحوالة*')
      ..writeln('👤 المرسل: ${o.payment.senderName}')
      ..writeln('🔢 رقم العملية: ${o.payment.refNo}')
      ..writeln('💳 الحساب: ${o.payment.accountNumber}')
      ..writeln()
      ..writeln('*الملخص المالي*')
      ..writeln('المنتجات: ${formatMoney(o.subtotalSar * o.exchangeRate, o.currency)}')
      ..writeln('التوصيل: ${formatMoney(o.deliveryFeeSar * o.exchangeRate, o.currency)}')
      ..writeln('━━━━━━━━━━━━━━')
      ..writeln('💰 *الإجمالي: ${formatMoney(o.totalLocal, o.currency)}*')
      ..writeln()
      ..writeln('شكراً لثقتكم بـ يمن سيلو 💜');
    return b.toString();
  }

  // ───────────────────────── فاتورة PDF ─────────────────────────
  static Future<File> buildPdf(Order o) async {
    final reg = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    final logoBytes = (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List();
    final logo = pw.MemoryImage(logoBytes);

    pw.TextStyle t(double size, {bool b = false, PdfColor c = _ink}) =>
        pw.TextStyle(font: b ? bold : reg, fontSize: size, color: c);

    pw.Widget kv(String k, String v, {bool strong = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(v, style: t(11, b: strong)),
              pw.Text(k, style: t(11, c: _muted)),
            ],
          ),
        );

    pw.Widget card(String title, List<pw.Widget> children) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: _soft,
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: PdfColor.fromInt(0xFFE4DDF5)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(title, style: t(12.5, b: true, c: _violetDark)),
              pw.SizedBox(height: 6),
              ...children,
            ],
          ),
        );

    final doc = pw.Document(title: 'طلب ${o.orderNo}', author: 'يمن سيلو');
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: reg, bold: bold),
        ),
        header: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: _violet,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(o.orderNo, style: t(15, b: true, c: PdfColors.white)),
                  pw.SizedBox(height: 3),
                  pw.Text(_date(o.createdAt), style: t(10.5, c: PdfColors.white)),
                ],
              ),
              pw.Row(children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('يمن سيلو', style: t(19, b: true, c: PdfColors.white)),
                    pw.Text('وسيطك الموثوق للتسوق العالمي',
                        style: t(9.5, c: _gold)),
                  ],
                ),
                pw.SizedBox(width: 10),
                pw.ClipRRect(
                  horizontalRadius: 8,
                  verticalRadius: 8,
                  child: pw.Image(logo, width: 44, height: 44),
                ),
              ]),
            ],
          ),
        ),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _gold, width: 1))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
                  style: t(9, c: _muted)),
              pw.Text('شكراً لثقتكم بـ يمن سيلو', style: t(9.5, c: _violetDark)),
            ],
          ),
        ),
        build: (ctx) => [
          pw.SizedBox(height: 14),
          card('حالة الطلب', [
            kv('الحالة', o.status.labelAr, strong: true),
            kv('العنوان', o.address.fullAr),
          ]),
          pw.Text('المنتجات', style: t(12.5, b: true, c: _violetDark)),
          pw.SizedBox(height: 6),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(5),
            },
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: PdfColor.fromInt(0xFFE4DDF5)),
            ),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _violetDark),
                children: [
                  for (final h in ['السعر', 'الكمية', 'المنتج'])
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(h, style: t(10.5, b: true, c: PdfColors.white)),
                    ),
                ],
              ),
              for (final it in o.items)
                pw.TableRow(children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                        formatMoney(it.lineTotalSar * o.exchangeRate, o.currency),
                        style: t(10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('${it.qty}', style: t(10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(it.title, style: t(10), maxLines: 2),
                  ),
                ]),
            ],
          ),
          pw.SizedBox(height: 14),
          card('بيانات الحوالة', [
            kv('اسم المرسل', o.payment.senderName),
            kv('رقم العملية', o.payment.refNo),
            kv('الحساب المستلم', o.payment.accountNumber),
            kv('المبلغ المحوّل', formatMoney(o.payment.amount, o.currency)),
          ]),
          card('الملخص المالي', [
            kv('المنتجات', formatMoney(o.subtotalSar * o.exchangeRate, o.currency)),
            kv('الشحن', o.shippingFeeSar == 0
                ? 'مجاني'
                : formatMoney(o.shippingFeeSar * o.exchangeRate, o.currency)),
            kv('التوصيل', formatMoney(o.deliveryFeeSar * o.exchangeRate, o.currency)),
            pw.Divider(color: _gold),
            kv('الإجمالي', formatMoney(o.totalLocal, o.currency), strong: true),
          ]),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/Yemen-Seloo-${o.orderNo}.pdf');
    await f.writeAsBytes(await doc.save());
    return f;
  }
}
