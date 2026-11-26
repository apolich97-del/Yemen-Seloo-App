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

import '../models/cart.dart';
import '../models/currency.dart';
import 'auth_service.dart';
import 'cart_share.dart';
import 'customer_accounting_service.dart';
import '../models/order.dart';
import '../models/receipt.dart';
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
  static Future<pw.MemoryImage?> fetchImage(String url) async => _fetch(url);

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

  /// بطاقة «رابط السلة كاملة» قابلة للنقر داخل PDF.
  static pw.Widget _cartLinkCard(
      String url, pw.TextStyle Function(double, bool, PdfColor) t) {
    if (url.isEmpty) return pw.SizedBox();
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.all(11),
      decoration: pw.BoxDecoration(
        color: _soft,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _gold),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text('🛒 رابط السلة كاملة',
              style: t(11.5, true, _violetDark)),
          pw.SizedBox(height: 5),
          pw.UrlLink(
            destination: url,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: pw.BoxDecoration(
                color: _violet,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text('افتح السلة كاملة بكل المنتجات',
                      style: t(10, true, PdfColors.white)),
                  pw.SizedBox(height: 3),
                  pw.Text(url,
                      style: t(7.5, false, PdfColors.white),
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ترويسة موحّدة للـ PDF: تدرّج + دوائر + شعار في مربع أبيض + شارة حالة.
  static pw.Widget _decorHeader({
    required pw.MemoryImage logo,
    required String title,
    required String subtitle,
    required String badge,
    required pw.TextStyle Function(double, bool, PdfColor?) t,
  }) {
    return pw.Stack(
      children: [
        pw.Container(
          height: 110,
          decoration: pw.BoxDecoration(
            gradient: const pw.LinearGradient(
              colors: [PdfColor.fromInt(0xFF5B21B6), PdfColor.fromInt(0xFF7C3AED)],
              begin: pw.Alignment.centerLeft,
              end: pw.Alignment.centerRight,
            ),
            borderRadius: pw.BorderRadius.circular(14),
          ),
        ),
        // دوائر زخرفية شفافة
        pw.Positioned(
          right: -20,
          top: -30,
          child: pw.Opacity(
            opacity: 0.08,
            child: pw.Container(
              width: 120,
              height: 120,
              decoration: const pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                color: PdfColors.white,
              ),
            ),
          ),
        ),
        pw.Positioned(
          right: 70,
          bottom: -40,
          child: pw.Opacity(
            opacity: 0.06,
            child: pw.Container(
              width: 90,
              height: 90,
              decoration: const pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                color: PdfColors.white,
              ),
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(14),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // الشارة (Pill)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(badge,
                    style: t(9, true, PdfColor.fromInt(0xFF5B21B6))),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(title, style: t(17, true, PdfColors.white)),
                  pw.Text(subtitle, style: t(9, false, PdfColors.white)),
                ],
              ),
              // الشعار في مربع أبيض
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Image(logo, width: 40, height: 40),
              ),
            ],
          ),
        ),
      ],
    );
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
      b.writeln('▫️ ${it.title} × ${it.qty}${it.isNonRefundable ? ' [غير قابل للاسترداد]' : ''}');
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
      ..writeln('شكراً لثقتكم بـ يمن سيلو 💜')
      ..writeln(CartShare.whatsappSection(CartShare.fromOrderItems(o)));
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
            kv('طريقة التوصيل', o.shippingModeAr),
            if (o.shippingMode == 'governorate') ...[
              kv('المحافظة', o.shippingGovernorate),
              kv('مكتب النقل',
                  o.shippingOffice.isEmpty ? 'يمن سيلو يختار' : o.shippingOffice),
              if (o.receiverName.isNotEmpty)
                kv('المستلم بالمكتب', '${o.receiverName} — ${o.receiverPhone}'),
              kv('أجور النقل',
                  o.transportFeeLocal > 0
                      ? '${o.transportFeeLocal.toStringAsFixed(0)} — '
                          '${o.transportFeeCollect == 'office' ? 'عند الاستلام لمكتب النقل' : 'على المتبقي'}'
                      : 'بالاتفاق مع مكتب الشحن'),
            ],
            if (o.shippingMode == 'driver') ...[
              kv('السائق', o.driverName),
              kv('هاتف السائق', o.driverPhone),
              kv('نقطة الالتقاء', o.driverMeetPoint),
            ],
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
                          if (o.items[i].isNonRefundable)
                            pw.Text('غير قابل للاسترداد',
                                style: t(8, b: true, c: PdfColor.fromInt(0xFFB45309))),
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
          OrderDocuments._cartLinkCard(CartShare.fromOrderItems(o),
              (double sz, bool bl, PdfColor cl) => t(sz, b: bl, c: cl)),
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

  /// استمارة تأكيد طلب رسمية عبر واتساب بهوية يمن سيلو (كاش أو آجل) —
  /// موجزة واحترافية برابط السلة الكامل دون إغراق الرسالة بقائمة المنتجات النصية،
  /// مع إشعار بإرفاق لقطة شاشة من ملخص الطلب ورقمي التواصل الرسميين.
  static String officialWhatsAppForm({
    required String orderNo,
    required String customerName,
    required String customerPhone,
    required String addressAr,
    required String shippingSummary,
    required List<CartLine> lines,
    required AppCurrency currency,
    required double totalLocal,
    String paymentPlan = 'full',
    double upfrontDueLocal = 0,
    double paidLocal = 0,
    double remainingLocal = 0,
    String accountTitleAr = '',
    String refNo = '',
    String? overrideShareLink,
  }) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final isDeferred = paymentPlan == 'half_deferred';
    final planLabel = isDeferred ? 'طلب آجل (السداد بالنصف 50%)' : 'دفع كامل (كاش 100%)';
    final totalPieces = lines.fold<int>(0, (s, l) => s + l.qty);
    final shareLink = (overrideShareLink != null && overrideShareLink.isNotEmpty)
        ? overrideShareLink
        : CartShare.buildFromLines(lines);

    final b = StringBuffer()
      ..writeln('╔══════════════════════════════╗')
      ..writeln('   *استمارة تأكيد طلب — يمن سيلو*')
      ..writeln('   Yemen Seloo Official Order Form')
      ..writeln('╚══════════════════════════════╝')
      ..writeln('🔖 *رقم الطلب:* $orderNo')
      ..writeln('📅 *التاريخ:* $dateStr')
      ..writeln('💳 *خطة السداد:* $planLabel')
      ..writeln('──────────────────────────────')
      ..writeln('👤 *بيانات العميل والتوصيل:*')
      ..writeln('• الاسم: $customerName')
      ..writeln('• الهاتف: $customerPhone')
      ..writeln('• العنوان: $addressAr')
      ..writeln('• طريقة التوصيل: $shippingSummary')
      ..writeln('• عدد القطع: $totalPieces قطعة')
      ..writeln('──────────────────────────────')
      ..writeln('💰 *الملخص المالي:*')
      ..writeln('• الإجمالي النهائي: ${formatMoney(totalLocal, currency)}');
    if (isDeferred) {
      b.writeln('• الدفعة الأولى المطلوبة: ${formatMoney(upfrontDueLocal, currency)}');
    }
    if (paidLocal > 0) {
      b.writeln('• المدفوع المرسل: ${formatMoney(paidLocal, currency)}');
    } else if (isDeferred) {
      b.writeln('• حالة الآجل: مسجّل في نظام الطلبات الآجلة (بانتظار السداد)');
    }
    if (remainingLocal > 0.5) {
      b.writeln('• المتبقي في ذمة العميل: ${formatMoney(remainingLocal, currency)}');
    }
    if (accountTitleAr.isNotEmpty) {
      b.writeln('• الحساب المحوَّل إليه: $accountTitleAr');
    }
    if (refNo.isNotEmpty) {
      b.writeln('• رقم مرجع الحوالة: $refNo');
    }
    if (shareLink.isNotEmpty) {
      b
        ..writeln('──────────────────────────────')
        ..writeln('🛒 *رابط السلة كاملة (استيراد فوري):*')
        ..writeln(shareLink);
    }
    b
      ..writeln('──────────────────────────────')
      ..writeln('📸 *ملاحظة:* مرفق مع هذه الاستمارة لقطة شاشة من ملخص الطلب الكامل.')
      ..writeln('📞 *أرقام يمن سيلو الرسمية:*')
      ..writeln('• الرئيسي: 770518757')
      ..writeln('• الثانوي: 737383637')
      ..writeln('══════════════════════════════')
      ..writeln('يمن سيلو · وسيطك الموثوق للتسوق العالمي ✓');
    return b.toString();
  }

  static Future<String> officialWhatsAppFormAsync({
    required String orderNo,
    required String customerName,
    required String customerPhone,
    required String addressAr,
    required String shippingSummary,
    required List<CartLine> lines,
    required AppCurrency currency,
    required double totalLocal,
    String paymentPlan = 'full',
    double upfrontDueLocal = 0,
    double paidLocal = 0,
    double remainingLocal = 0,
    String accountTitleAr = '',
    String refNo = '',
  }) async {
    String shortLink = '';
    try {
      shortLink = await CartShare.shortFromLines(lines);
    } catch (_) {}
    return officialWhatsAppForm(
      orderNo: orderNo,
      customerName: customerName,
      customerPhone: customerPhone,
      addressAr: addressAr,
      shippingSummary: shippingSummary,
      lines: lines,
      currency: currency,
      totalLocal: totalLocal,
      paymentPlan: paymentPlan,
      upfrontDueLocal: upfrontDueLocal,
      paidLocal: paidLocal,
      remainingLocal: remainingLocal,
      accountTitleAr: accountTitleAr,
      refNo: refNo,
      overrideShareLink: shortLink,
    );
  }

  /// بوليصة شحن المحافظات (PDF A4 RTL) — مطابقة لتصميم الويب مع صور القطع وخالية من بيانات الحوالات.
  static Future<File> buildShippingWaybillPdf(Order o) async {
    final reg = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    final logo = pw.MemoryImage(
        (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List());
    pw.TextStyle t(double size, {bool b = false, PdfColor? c}) =>
        pw.TextStyle(font: b ? bold : reg, fontSize: size, color: c ?? _ink);

    final sw = o.shippingWaybill;
    final sender = '${sw['senderName'] ?? ''}'.trim().isNotEmpty
        ? '${sw['senderName']}'
        : (Get.isRegistered<SettingsService>() &&
                Get.find<SettingsService>().settings.value.senderName.isNotEmpty
            ? Get.find<SettingsService>().settings.value.senderName
            : 'يمن سيلو');
    final companyPhone = '${sw['companyPhone'] ?? ''}'.trim().isNotEmpty
        ? '${sw['companyPhone']}'
        : '770518757 · 737383637';
    final gov = '${sw['governorate'] ?? ''}'.trim().isNotEmpty
        ? '${sw['governorate']}'
        : (o.shippingGovernorate.isNotEmpty ? o.shippingGovernorate : o.address.city);
    final office = '${sw['officeName'] ?? ''}'.trim().isNotEmpty
        ? '${sw['officeName']}'
        : (o.shippingOffice.isNotEmpty ? o.shippingOffice : 'مكتب نقل يمن سيلو المعتمد');
    final receiver = '${sw['receiverName'] ?? ''}'.trim().isNotEmpty
        ? '${sw['receiverName']}'
        : (o.receiverName.isNotEmpty ? o.receiverName : o.address.receiverName);
    final receiverPhone = '${sw['receiverPhone'] ?? ''}'.trim().isNotEmpty
        ? '${sw['receiverPhone']}'
        : (o.receiverPhone.isNotEmpty ? o.receiverPhone : o.address.phone);
    final voucherUrl = '${sw['voucherUrl'] ?? ''}'.trim();
    final notes = '${sw['notes'] ?? ''}'.trim();

    final itemSubset = o.items.take(12).toList();
    final fetchedImgs = await Future.wait<pw.MemoryImage?>([
      if (voucherUrl.isNotEmpty) _fetch(voucherUrl) else Future.value(null),
      for (final it in itemSubset) _fetch(it.imageUrl),
    ]);
    final voucherImg = fetchedImgs[0];
    final itemImgs = fetchedImgs.sublist(1);

    pw.Widget kv(String k, String v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(child: pw.Text(v, style: t(9.5, b: true))),
              pw.SizedBox(width: 8),
              pw.Text(k, style: t(9.5, c: _muted)),
            ],
          ),
        );

    final doc = pw.Document(title: 'بوليصة شحن ${o.orderNo}', author: 'يمن سيلو');
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(22),
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: reg, bold: bold),
        ),
        build: (_) => [
          _decorHeader(
            logo: logo,
            title: 'بوليصة شحن للمحافظات',
            subtitle: 'وثيقة تسليم ومراجعة لوجستية رسمية — يمن سيلو',
            badge: o.orderNo,
            t: (sz, bl, cl) => t(sz, b: bl, c: cl),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFFFFBEB),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: _gold),
            ),
            child: pw.Text(
              'مستند شحن لوجستي معتمد — خالية تماماً من بيانات الحوالات البنكية والأرصدة المالية',
              style: t(9.2, b: true, c: PdfColor.fromInt(0xFF92400E)),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: _soft,
                    borderRadius: pw.BorderRadius.circular(10),
                    border: pw.Border.all(color: PdfColor.fromInt(0xFFE4DDF5)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Text('بيانات المستلم والوجهة', style: t(10.5, b: true, c: _violetDark)),
                      pw.SizedBox(height: 5),
                      kv('المستلم', receiver),
                      kv('هاتف المستلم', receiverPhone),
                      kv('المحافظة', gov),
                      kv('العنوان', o.address.fullAr),
                      if (o.trackingNo.isNotEmpty) kv('التتبع', o.trackingNo),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: _soft,
                    borderRadius: pw.BorderRadius.circular(10),
                    border: pw.Border.all(color: PdfColor.fromInt(0xFFE4DDF5)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Text('بيانات المرسل والنقل', style: t(10.5, b: true, c: _violetDark)),
                      pw.SizedBox(height: 5),
                      kv('المرسل', sender),
                      kv('هاتف الشركة', companyPhone),
                      kv('مكتب النقل', office),
                      kv('إجمالي القطع', '${o.totalPieces} قطعة'),
                      if (notes.isNotEmpty) kv('ملاحظات', notes),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: PdfColor.fromInt(0xFFE4DDF5)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text('محتويات الطرد (${o.items.length} صنف · ${o.totalPieces} قطعة)',
                    style: t(11, b: true, c: _violetDark)),
                pw.SizedBox(height: 6),
                for (var i = 0; i < o.items.length; i++) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                    margin: const pw.EdgeInsets.only(bottom: 4),
                    decoration: pw.BoxDecoration(
                      color: i % 2 == 0 ? _soft : PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: pw.BoxDecoration(
                            color: _violet,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Text('× ${o.items[i].qty}',
                              style: t(9, b: true, c: PdfColors.white)),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text('${i + 1}. ${o.items[i].title}', style: t(9.5, b: true)),
                              if (_variant(o.items[i]).isNotEmpty)
                                pw.Text(_variant(o.items[i]), style: t(8.2, c: _muted)),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        if (i < itemImgs.length && itemImgs[i] != null)
                          pw.ClipRRect(
                            horizontalRadius: 6,
                            verticalRadius: 6,
                            child: pw.Image(itemImgs[i]!,
                                width: 38, height: 38, fit: pw.BoxFit.cover),
                          )
                        else
                          pw.Container(
                            width: 38,
                            height: 38,
                            alignment: pw.Alignment.center,
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFFEDE9FE),
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                            child: pw.Text('#${i + 1}', style: t(8.5, b: true, c: _violetDark)),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (voucherImg != null) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _soft,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: _violet, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text('سند مكتب النقل / صورة الطرد',
                      style: t(10.5, b: true, c: _violetDark)),
                  pw.SizedBox(height: 6),
                  pw.Center(
                    child: pw.Image(voucherImg, height: 185, fit: pw.BoxFit.contain),
                  ),
                ],
              ),
            ),
          ],
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _violetDark,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('يمن سيلو · خدمة الشحن للمحافظات (${o.totalPieces} قطعة)',
                    style: t(9.5, c: PdfColors.white)),
                pw.Text('770518757 · 737383637', style: t(9.5, b: true, c: PdfColors.white)),
              ],
            ),
          ),
        ],
      ),
    );
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/Shipping-Waybill-${o.orderNo}.pdf');
    await f.writeAsBytes(await doc.save());
    return f;
  }

  /// بوليصة إثبات التسليم (PDF A4 RTL) — تتضمن صور القطع، خط الزمن، المندوب، صورة التسليم، وختم يمن سيلو.
  static Future<File> buildDeliveryWaybillPdf(Order o) async {
    final reg = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    final logo = pw.MemoryImage(
        (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List());
    pw.TextStyle t(double size, {bool b = false, PdfColor? c}) =>
        pw.TextStyle(font: b ? bold : reg, fontSize: size, color: c ?? _ink);

    final dw = o.deliveryWaybill;
    final courierName = '${dw['courierName'] ?? ''}'.trim().isNotEmpty
        ? '${dw['courierName']}'
        : (o.courierName.isNotEmpty ? o.courierName : 'مندوب يمن سيلو');
    final courierPhone = '${dw['courierPhone'] ?? ''}'.trim();
    final collectedLocal = (dw['collectedLocal'] as num?)?.toDouble() ?? 0;
    final proofSrc = '${dw['proofUrl'] ?? ''}'.trim().isNotEmpty
        ? '${dw['proofUrl']}'
        : o.proofImageUrl;
    final deliveryNote = '${dw['note'] ?? ''}'.trim();

    final itemSubset = o.items.take(8).toList();
    final fetchedImgs = await Future.wait<pw.MemoryImage?>([
      if (proofSrc.isNotEmpty) _fetch(proofSrc) else Future.value(null),
      for (final it in itemSubset) _fetch(it.imageUrl),
    ]);
    final proofImg = fetchedImgs[0];
    final itemImgs = fetchedImgs.sublist(1);

    pw.Widget kv(String k, String v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(child: pw.Text(v, style: t(10, b: true))),
              pw.SizedBox(width: 8),
              pw.Text(k, style: t(10, c: _muted)),
            ],
          ),
        );

    final doc = pw.Document(title: 'بوليصة تسليم ${o.orderNo}', author: 'يمن سيلو');
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(22),
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: reg, bold: bold),
        ),
        build: (_) => [
          _decorHeader(
            logo: logo,
            title: 'بوليصة إثبات التسليم',
            subtitle: 'توثيق تسليم الشحنة للعميل — يمن سيلو',
            badge: o.status.labelAr,
            t: (sz, bl, cl) => t(sz, b: bl, c: cl),
          ),
          pw.SizedBox(height: 10),
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
                kv('رقم الطلب', o.orderNo),
                kv('المستلم', o.address.receiverName),
                kv('هاتف المستلم', o.address.phone),
                kv('عنوان التسليم', o.address.fullAr),
                kv('اسم المندوب', courierName),
                if (courierPhone.isNotEmpty) kv('هاتف المندوب', courierPhone),
                kv('عدد القطع', '${o.totalPieces} قطعة'),
                if (collectedLocal > 0)
                  kv('المبلغ المحصّل عند التسليم', formatMoney(collectedLocal, o.currency)),
                if (deliveryNote.isNotEmpty) kv('ملاحظة التسليم', deliveryNote),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: PdfColor.fromInt(0xFFE4DDF5)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text('القطع المسلّمة (${o.items.length})',
                    style: t(10.5, b: true, c: _violetDark)),
                pw.SizedBox(height: 6),
                for (var i = 0; i < itemSubset.length; i++)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Row(
                      children: [
                        pw.Text('× ${itemSubset[i].qty}', style: t(9.5, b: true, c: _violetDark)),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.Text(
                            '${i + 1}. ${itemSubset[i].title}${_variant(itemSubset[i]).isEmpty ? '' : ' (${_variant(itemSubset[i])})'}',
                            style: t(9.2),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        if (i < itemImgs.length && itemImgs[i] != null)
                          pw.ClipRRect(
                            horizontalRadius: 5,
                            verticalRadius: 5,
                            child: pw.Image(itemImgs[i]!,
                                width: 34, height: 34, fit: pw.BoxFit.cover),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (o.timeline.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFE4DDF5)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text('الخط الزمني للشحنة', style: t(10.5, b: true, c: _violetDark)),
                  pw.SizedBox(height: 5),
                  for (final ev in o.timeline)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Text(
                        '• ${ev.status.labelAr} — ${_date(ev.at)}${ev.note.isEmpty ? '' : ' (${ev.note})'}',
                        style: t(9.2),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (proofImg != null) ...[
            pw.SizedBox(height: 10),
            pw.Text('صورة إثبات التسليم الميداني', style: t(10.5, b: true, c: _violetDark)),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                color: _soft,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Center(
                child: pw.Image(proofImg, height: 185, fit: pw.BoxFit.contain),
              ),
            ),
          ],
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  height: 60,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColor.fromInt(0xFFE4DDF5)),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text('توقيع المستلم بالاستلام الفعلي:', style: t(9.5, c: _muted)),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Container(
                  height: 60,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: _soft,
                    border: pw.Border.all(color: _violet),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('اعتماد يمن سيلو للتوصيل',
                          style: t(9.5, b: true, c: _violetDark)),
                      pw.Text('770518757 · 737383637', style: t(8.5, c: _muted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/Delivery-Waybill-${o.orderNo}.pdf');
    await f.writeAsBytes(await doc.save());
    return f;
  }

  /// كشف حساب العميل المحاسبي الكامل (PDF A4 RTL).
  static Future<File> buildStatementPdf({
    required AppUser? customer,
    required AccountingStatementReport report,
    double walletBalanceSar = 0,
  }) async {
    final reg = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    final logo = pw.MemoryImage(
        (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List());

    pw.TextStyle t(double size, {bool b = false, PdfColor? c}) => pw.TextStyle(
          font: b ? bold : reg,
          fontSize: size,
          color: c ?? _ink,
        );

    String fmtDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    String fmtSar(double v) => '${v.toStringAsFixed(2)} SAR';

    final periodLabel = report.periodStart != null || report.periodEnd != null
        ? 'من ${report.periodStart != null ? fmtDate(report.periodStart!) : 'البداية'} إلى ${report.periodEnd != null ? fmtDate(report.periodEnd!) : 'الآن'}'
        : 'كامل السجل المالي';

    // جلب أول 6 صور حوالات (إن وجدت) بشكل آمن
    final List<MapEntry<StatementTransferPhoto, pw.MemoryImage>> fetchedPhotos = [];
    for (final p in report.transferPhotos.take(6)) {
      final img = await fetchImage(p.url);
      if (img != null) fetchedPhotos.add(MapEntry(p, img));
    }

    final doc = pw.Document(
      title: 'كشف حساب العميل — يمن سيلو',
      author: 'يمن سيلو',
    );

    pw.Widget kpiBox(String title, String val, {PdfColor? color}) => pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: _soft,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColor.fromInt(0xFFE4DDF5)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(title, style: t(8.5, c: _muted)),
                pw.SizedBox(height: 3),
                pw.Text(val, style: t(10.5, b: true, c: color ?? _violetDark)),
              ],
            ),
          ),
        );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(22),
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: reg, bold: bold),
        ),
        build: (ctx) => [
          _decorHeader(
            logo: logo,
            title: 'كشف الحساب المحاسبي للعميل',
            subtitle: 'المدة: $periodLabel',
            badge: customer?.effectiveCode ?? 'عميل يمن سيلو',
            t: (sz, bl, cl) => t(sz, b: bl, c: cl),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _soft,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: _gold),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'المحفظة: ${fmtSar(walletBalanceSar)} · مستردات الفترة: ${fmtSar(report.totalRefundedSar)}',
                  style: t(9.5, b: true, c: _violetDark),
                ),
                pw.Text(
                  '${customer?.displayName.isNotEmpty == true ? customer!.displayName : 'عميل يمن سيلو'} · ${customer?.phone ?? ''} · ${customer?.fullAddressAr ?? ''}',
                  style: t(9.5, c: _ink),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              kpiBox('الرصيد الختامي', fmtSar(report.closingBalanceSar),
                  color: report.closingBalanceSar > 0.5
                      ? PdfColor.fromInt(0xFFB3261E)
                      : PdfColor.fromInt(0xFF15803D)),
              pw.SizedBox(width: 6),
              kpiBox('إجمالي الدائن', fmtSar(report.periodCreditSar),
                  color: PdfColor.fromInt(0xFF15803D)),
              pw.SizedBox(width: 6),
              kpiBox('إجمالي المدين', fmtSar(report.periodDebitSar)),
              pw.SizedBox(width: 6),
              kpiBox('الرصيد الافتتاحي', fmtSar(report.openingBalanceSar)),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text('دفتر الأستاذ — القيود المحاسبية',
              style: t(12, b: true, c: _violetDark)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFDCD5EE), width: 0.6),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.3),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(3.0),
              4: pw.FlexColumnWidth(1.5),
              5: pw.FlexColumnWidth(1.4),
              6: pw.FlexColumnWidth(0.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _violetDark),
                children: [
                  'الرصيد',
                  'دائن',
                  'مدين',
                  'البيان',
                  'المستند',
                  'التاريخ',
                  'م',
                ]
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(h,
                              textAlign: pw.TextAlign.center,
                              style: t(8.5, b: true, c: PdfColors.white)),
                        ))
                    .toList(),
              ),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _soft),
                children: [
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(fmtSar(report.openingBalanceSar),
                          style: t(8.5, b: true))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('—', style: t(8.5))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('—', style: t(8.5))),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('الرصيد الافتتاحي المرحّل', style: t(8.5, b: true))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('OPEN', style: t(8.5))),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                          report.periodStart != null ? fmtDate(report.periodStart!) : '—',
                          style: t(8.5))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('0', style: t(8.5))),
                ],
              ),
              ...report.entries.map((e) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4.5),
                        child: pw.Text(fmtSar(e.runningBalanceSar), style: t(8, b: true)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4.5),
                        child: pw.Text(
                            e.creditSar > 0 ? e.creditSar.toStringAsFixed(2) : '—',
                            style: t(8,
                                c: e.creditSar > 0
                                    ? PdfColor.fromInt(0xFF15803D)
                                    : _muted)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4.5),
                        child: pw.Text(
                            e.debitSar > 0 ? e.debitSar.toStringAsFixed(2) : '—',
                            style: t(8,
                                c: e.debitSar > 0
                                    ? PdfColor.fromInt(0xFFB3261E)
                                    : _muted)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4.5),
                        child: pw.Text(e.description, style: t(8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4.5),
                        child: pw.Text('${e.entryTypeLabel}\n${e.docNo}', style: t(7.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4.5),
                        child: pw.Text(fmtDate(e.date), style: t(8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4.5),
                        child: pw.Text('${e.seq}', style: t(8)),
                      ),
                    ],
                  )),
            ],
          ),
          if (report.refunds.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('سجل عمليات الاسترداد (${report.refunds.length})',
                style: t(11.5, b: true, c: _violetDark)),
            pw.SizedBox(height: 6),
            ...report.refunds.map((r) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 5),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: _soft,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${fmtSar(r.amountSar)} (${r.statusAr})',
                        style: t(9, b: true, c: _violetDark),
                      ),
                      pw.Text(
                        'طلب ${r.orderNo} · ${r.refundRefNo} · ${r.reasonAr} · ${r.methodAr}',
                        style: t(9),
                      ),
                    ],
                  ),
                )),
          ],
          if (fetchedPhotos.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('أرشيف صور الحوالات وإثباتات التحويل',
                style: t(11.5, b: true, c: _violetDark)),
            pw.SizedBox(height: 6),
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: fetchedPhotos
                  .map((pair) => pw.Container(
                        width: 155,
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColor.fromInt(0xFFDCD5EE)),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Image(pair.value, height: 110, fit: pw.BoxFit.cover),
                            pw.SizedBox(height: 4),
                            pw.Text(pair.key.title, style: t(8, b: true)),
                            pw.Text(
                              '${fmtSar(pair.key.amountSar)} · ${pair.key.refNo}',
                              style: t(7.5, c: _muted),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _violet,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('يمن سيلو · كشف حساب معتمد', style: t(9.5, b: true, c: PdfColors.white)),
                pw.Text('تاريخ الإصدار: ${fmtDate(DateTime.now())}',
                    style: t(9, c: PdfColors.white)),
              ],
            ),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/Yemen-Seloo-Statement-${DateTime.now().millisecondsSinceEpoch}.pdf');
    await f.writeAsBytes(await doc.save());
    return f;
  }
}


extension ReceiptDocuments on OrderDocuments {
  static Future<File> buildReceiptPdf(Order o, Receipt r) async {
    final reg = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    final logo = pw.MemoryImage(
        (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List());

    final violet = PdfColor.fromInt(0xFF7C3AED);
    final violetDark = PdfColor.fromInt(0xFF5B21B6);
    final gold = PdfColor.fromInt(0xFFC9A227);
    final soft = PdfColor.fromInt(0xFFF7F5FB);
    final ink = PdfColor.fromInt(0xFF1B1F1D);
    final muted = PdfColor.fromInt(0xFF6B7671);

    pw.TextStyle t(double size, {bool b = false, PdfColor? c}) => pw.TextStyle(
        font: b ? bold : reg, fontSize: size, color: c ?? ink);

    pw.Widget kv(String k, String v, {bool strong = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [pw.Text(v, style: t(10.5, b: strong)), pw.Text(k, style: t(10.5, c: muted))],
          ),
        );

    pw.Widget box(String title, List<pw.Widget> kids) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 10),
          padding: const pw.EdgeInsets.all(11),
          decoration: pw.BoxDecoration(
            color: soft,
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: PdfColor.fromInt(0xFFE4DDF5)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(title, style: t(12, b: true, c: violetDark)),
              pw.SizedBox(height: 5),
              ...kids,
            ],
          ),
        );

    final proof = r.proofUrl.isNotEmpty ? await OrderDocuments.fetchImage(r.proofUrl) : null;
    final doc = pw.Document(title: 'إيصال ${r.receiptNo}', author: 'يمن سيلو');
    final remaining = r.remainingAfterLocal;

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(26),
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: reg, bold: bold),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
                color: violet, borderRadius: pw.BorderRadius.circular(12)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(r.statusAr, style: t(11, b: true, c: PdfColors.white)),
                  pw.SizedBox(height: 4),
                  pw.Text('إيصال قبض رسمي', style: t(9.5, c: gold)),
                ]),
                pw.Row(children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text('يمن سيلو', style: t(18, b: true, c: PdfColors.white)),
                    pw.Text('وسيطك الموثوق للتسوق العالمي', style: t(9, c: gold)),
                  ]),
                  pw.SizedBox(width: 10),
                  pw.ClipRRect(
                      horizontalRadius: 8,
                      verticalRadius: 8,
                      child: pw.Image(logo, width: 42, height: 42)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              color: violetDark,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('الإيصال: ${r.receiptNo}', style: t(10.5, c: PdfColors.white)),
                pw.Text('الطلب: ${r.orderNo}', style: t(10.5, c: PdfColors.white)),
                pw.Text(
                    'التاريخ: ${(r.createdAt ?? DateTime.now()).toString().substring(0, 10)}',
                    style: t(10.5, c: PdfColors.white)),
                pw.Text(o.isDeferred ? 'آجل 50%' : 'كاش',
                    style: t(10.5, c: gold)),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: gold, width: 1.4),
            ),
            child: pw.Column(children: [
              pw.Text('المبلغ المستلم', style: t(10.5, c: muted)),
              pw.SizedBox(height: 4),
              pw.Text(formatMoney(r.amountLocal, o.currency),
                  style: t(26, b: true, c: violetDark)),
              pw.SizedBox(height: 4),
              pw.Text(
                  remaining <= 0.5
                      ? 'تم سداد كامل المبلغ المستحق ✓'
                      : 'المتبقي على العميل: ${formatMoney(remaining, o.currency)}',
                  style: t(10.5, b: true, c: remaining <= 0.5
                      ? PdfColor.fromInt(0xFF15803D)
                      : PdfColor.fromInt(0xFFB3261E))),
            ]),
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: box('بيانات العميل والتوصيل', [
                  kv('الاسم', o.address.receiverName),
                  kv('الهاتف', o.address.phone),
                  kv('العنوان', o.address.fullAr),
                ]),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: box('تفاصيل الحوالة والاعتماد', [
                  kv('اسم المحوِّل', r.senderName),
                  kv('رقم العملية', r.refNo.isEmpty ? '—' : r.refNo),
                  kv('المصدر', r.source == 'admin' ? 'إدارة' : 'العميل'),
                  kv('المراجع', r.reviewedBy.isEmpty ? '—' : r.reviewedBy),
                ]),
              ),
            ],
          ),
          OrderDocuments._cartLinkCard(CartShare.fromOrderItems(o),
              (double sz, bool bl, PdfColor cl) => t(sz, b: bl, c: cl)),
          box('البيان المالي للطلب', [
            kv('إجمالي الطلب', formatMoney(o.totalLocal, o.currency)),
            kv('هذا الإيصال', formatMoney(r.amountLocal, o.currency)),
            kv('الرصيد المتبقي بعد الإيصال', formatMoney(remaining, o.currency), strong: true),
          ]),
          if (proof != null) ...[
            pw.SizedBox(height: 10),
            pw.Text('صورة إشعار الحوالة', style: t(11, b: true, c: violetDark)),
            pw.SizedBox(height: 5),
            pw.Center(child: pw.Image(proof, height: 170, fit: pw.BoxFit.contain)),
          ],
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                  'هذا الإيصال صادر إلكترونياً من تطبيق يمن سيلو\n'
                  'ويعتبر سنداً للمبالغ الموضحة أعلاه.',
                  style: t(9, c: muted)),
              pw.Container(
                width: 92,
                height: 92,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: violet, width: 2),
                ),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('يمن سيلو', style: t(10, b: true, c: violetDark)),
                    pw.Text('إيصال معتمد', style: t(8, c: muted)),
                    pw.Text(r.receiptNo, style: t(8, b: true, c: violet)),
                  ],
                ),
              ),
            ],
          ),
          pw.Divider(color: gold),
          pw.Text('خدمة العملاء: يمن سيلو · yemenseloo.shop',
              style: t(9, c: muted), textAlign: pw.TextAlign.center),
        ],
      ),
    ));

    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/Receipt-${r.receiptNo}.pdf');
    await f.writeAsBytes(await doc.save());
    return f;
  }
}


/// ملخص PDF للسلة قبل إنشاء الطلب (شاشة الملخص).
class CartPdf {
  static Future<File> build({
    required List<dynamic> lines,
    required String addressAr,
    required String totalLabel,
    required String currencyNote,
  }) async {
    final reg = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    final logo = pw.MemoryImage(
        (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List());
    const violet = PdfColor.fromInt(0xFF7C3AED);
    const violetDark = PdfColor.fromInt(0xFF5B21B6);
    const gold = PdfColor.fromInt(0xFFC9A227);
    const soft = PdfColor.fromInt(0xFFF7F5FB);
    const ink = PdfColor.fromInt(0xFF1B1F1D);

    pw.TextStyle t(double size, bool b, PdfColor? c) =>
        pw.TextStyle(font: b ? bold : reg, fontSize: size, color: c ?? ink);

    final List<pw.TableRow> rows = [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: violetDark),
        children: [
          for (final h in ['المنتج', 'الكمية', 'سعر الوحدة'])
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(h, style: t(10, true, PdfColors.white)),
            ),
        ],
      ),
      for (final l in lines)
        pw.TableRow(children: [
          pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('${l.titleAr}', style: t(9.5, false, null))),
          pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('${l.qty}', style: t(9.5, false, null))),
          pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('${l.unitPriceSar}', style: t(9.5, false, null))),
        ]),
    ];

    final doc = pw.Document(title: 'ملخص السلة', author: 'يمن سيلو');
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(26),
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: reg, bold: bold),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
                color: violet, borderRadius: pw.BorderRadius.circular(12)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ملخص السلة', style: t(14, true, PdfColors.white)),
                      pw.Text(addressAr, style: t(9.5, false, gold)),
                    ]),
                pw.Row(children: [
                  pw.Text('يمن سيلو', style: t(17, true, PdfColors.white)),
                  pw.SizedBox(width: 8),
                  pw.ClipRRect(
                      horizontalRadius: 8,
                      verticalRadius: 8,
                      child: pw.Image(logo, width: 40, height: 40)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.4),
            },
            border: pw.TableBorder(
                horizontalInside:
                    pw.BorderSide(color: PdfColor.fromInt(0xFFE4DDF5))),
            children: rows,
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(11),
            decoration: pw.BoxDecoration(
                color: soft,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFE4DDF5))),
            child: pw.Column(children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(totalLabel, style: t(12, true, null)),
                  pw.Text(currencyNote, style: t(9, false, null)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text('الأسعار تقديرية بالريال السعودي وتُثبَّت عند إنشاء الطلب.',
                  style: t(8.5, false, gold)),
            ]),
          ),
          OrderDocuments._cartLinkCard(
              CartShare.buildFromLines(lines),
              (double sz, bool bl, PdfColor? cl) => t(sz, bl, cl)),
        ],
      ),
    ));

    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/Yemen-Seloo-Cart.pdf');
    await f.writeAsBytes(await doc.save());
    return f;
  }
}
