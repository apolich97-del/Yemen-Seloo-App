import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/currency.dart';
import '../models/order.dart';
import 'settings_service.dart';

/// مستندات الطلب بهوية «يمن سيلو»: فاتورة PDF عربية + قالب رسالة واتساب.
class OrderDocuments {
  static const _violet = PdfColor.fromInt(0xFF7C3AED);
  static const _violetDark = PdfColor.fromInt(0xFF5B21B6);
  static const _gold = PdfColor.fromInt(0xFFC9A227);
  static const _soft = PdfColor.fromInt(0xFFF7F5FB);
  static const _ink = PdfColor.fromInt(0xFF1B1F1D);
  static const _muted = PdfColor.fromInt(0xFF6B7671);

  /// ينزّل صورة منتج ويحولها لصورة PDF، ويرجع null عند أي فشل.
  static Future<pw.MemoryImage?> _fetch(String url) async {
    if (url.isEmpty) return null;
    try {
      if (url.startsWith('data:')) {
        return pw.MemoryImage(base64Decode(url.substring(url.indexOf(',') + 1)));
      }
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        client.close();
        return null;
      }
      final bytes = await res
          .fold<List<int>>(<int>[], (a, b) => a..addAll(b))
          .timeout(const Duration(seconds: 12));
      client.close();
      if (bytes.isEmpty) return null;
      return pw.MemoryImage(Uint8List.fromList(bytes));
    } catch (_) {
      return null;
    }
  }

  static String _deliveryWindow() {
    try {
      if (!Get.isRegistered<SettingsService>()) return '';
      final sf = Get.find<SettingsService>().settings.value;
      return '${sf.deliveryMinDays}–${sf.deliveryMaxDays} يوماً';
    } catch (_) {
      return '';
    }
  }

  static String _support() {
    try {
      if (!Get.isRegistered<SettingsService>()) return '';
      final sf = Get.find<SettingsService>().settings.value;
      return sf.supportWhatsApp.isNotEmpty ? sf.supportWhatsApp : sf.supportPhone;
    } catch (_) {
      return '';
    }
  }

  static String _variant(OrderItem it) {
    final parts = <String>[
      if (it.color.isNotEmpty) 'اللون: ${it.color}',
      if (it.size.isNotEmpty) 'المقاس: ${it.size}',
    ];
    return parts.join(' · ');
  }

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

  /// يفتح واتساب بنص الملخص.
  static Future<void> shareWhatsApp(Order o) async {
    final text = whatsappText(o);
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

    // تنزيل صور المنتجات وصورة الحوالة (بالتوازي) مع تجاهل أي فشل.
    final itemImages = await Future.wait(o.items.map((it) => _fetch(it.imageUrl)));
    final proofImage = o.payment.proofUrl.isNotEmpty
        ? await _fetch(o.payment.proofUrl)
        : null;

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
          card('بيانات التوصيل', [
            kv('الحالة', o.status.labelAr, strong: true),
            kv('المستلم', o.address.receiverName),
            kv('الهاتف', o.address.phone),
            kv('العنوان', o.address.fullAr),
            kv('نوع العنوان', o.address.label),
            if (o.trackingNo.isNotEmpty) kv('رقم التتبع', o.trackingNo),
            if (o.courierName.isNotEmpty) kv('المندوب', o.courierName),
          ]),
          pw.Text('المنتجات', style: t(12.5, b: true, c: _violetDark)),
          pw.SizedBox(height: 6),
          pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(46),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(2),
            },
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: PdfColor.fromInt(0xFFE4DDF5)),
            ),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _violetDark),
                children: [
                  for (final h in ['', 'المنتج', 'الكمية', 'السعر'])
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(h, style: t(10.5, b: true, c: PdfColors.white)),
                    ),
                ],
              ),
              for (var i = 0; i < o.items.length; i++)
                pw.TableRow(
                  verticalAlignment: pw.TableCellVerticalAlignment.middle,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: itemImages[i] != null
                          ? pw.Container(
                              height: 42,
                              width: 42,
                              decoration: pw.BoxDecoration(
                                borderRadius: pw.BorderRadius.circular(6),
                                image: pw.DecorationImage(
                                  image: itemImages[i]!,
                                  fit: pw.BoxFit.cover,
                                ),
                              ),
                            )
                          : pw.Container(
                              height: 42,
                              width: 42,
                              decoration: pw.BoxDecoration(
                                color: _soft,
                                borderRadius: pw.BorderRadius.circular(6),
                                border: pw.Border.all(
                                    color: PdfColor.fromInt(0xFFE4DDF5)),
                              ),
                              child: pw.Center(
                                  child: pw.Text('—', style: t(10, c: _muted))),
                            ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(o.items[i].title, style: t(10), maxLines: 2),
                          if (_variant(o.items[i]).isNotEmpty)
                            pw.Text(_variant(o.items[i]),
                                style: t(8.5, c: _muted)),
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('${o.items[i].qty}', style: t(10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                          formatMoney(
                              o.items[i].lineTotalSar * o.exchangeRate, o.currency),
                          style: t(10)),
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 14),
          card('بيانات الحوالة', [
            kv('الحساب المستلم', o.payment.accountTitleAr),
            kv('رقم الحساب', o.payment.accountNumber),
            kv('اسم المرسل', o.payment.senderName),
            kv('رقم العملية', o.payment.refNo),
            kv('المبلغ المحوّل', formatMoney(o.payment.amount, o.currency)),
            kv('حالة التأكيد',
                o.payment.confirmedAt == null ? 'بانتظار المراجعة' : 'مؤكدة'),
            if (o.payment.note.isNotEmpty) kv('ملاحظة', o.payment.note),
          ]),
          if (proofImage != null) ...[
            pw.Text('صورة الحوالة المرفقة',
                style: t(12.5, b: true, c: _violetDark)),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                color: _soft,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFE4DDF5)),
              ),
              child: pw.Center(
                child: pw.Image(proofImage,
                    height: 190, fit: pw.BoxFit.contain),
              ),
            ),
            pw.SizedBox(height: 12),
          ],
          card('الملخص المالي', [
            kv('المنتجات', formatMoney(o.subtotalSar * o.exchangeRate, o.currency)),
            kv('الشحن', o.shippingFeeSar == 0
                ? 'مجاني'
                : formatMoney(o.shippingFeeSar * o.exchangeRate, o.currency)),
            kv('التوصيل', formatMoney(o.deliveryFeeSar * o.exchangeRate, o.currency)),
            if (o.discountSar > 0)
              kv('الخصم${o.couponCode.isEmpty ? '' : ' (${o.couponCode})'}',
                  '- ${formatMoney(o.discountSar * o.exchangeRate, o.currency)}'),
            pw.Divider(color: _gold),
            kv('الإجمالي', formatMoney(o.totalLocal, o.currency), strong: true),
          ]),
          if (_deliveryWindow().isNotEmpty || _support().isNotEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _violet,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (_support().isNotEmpty)
                    pw.Text('الدعم: ${_support()}',
                        style: t(10, c: PdfColors.white)),
                  if (_deliveryWindow().isNotEmpty)
                    pw.Text('مدة التوصيل: ${_deliveryWindow()}',
                        style: t(10, c: PdfColors.white)),
                ],
              ),
            ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/Yemen-Seloo-${o.orderNo}.pdf');
    await f.writeAsBytes(await doc.save());
    return f;
  }
}
