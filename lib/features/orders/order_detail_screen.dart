import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/currency.dart';
import '../../core/models/order.dart';
import '../../core/services/order_service.dart';
import '../../core/theme/app_theme.dart';

/// تفاصيل الطلب: الخط الزمني + المنتجات + إثبات التسليم + تسريع الشحن.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final id = Get.arguments as String? ?? '';
    final svc = Get.find<OrderService>();
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الطلب')),
      body: StreamBuilder<Order?>(
        stream: svc.watchOrder(id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final o = snap.data;
          if (o == null) {
            return const Center(child: Text('الطلب غير موجود'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(o),
              const SizedBox(height: 12),
              _timeline(o),
              const SizedBox(height: 12),
              _items(o),
              const SizedBox(height: 12),
              _payment(o),
              if (o.proofImageUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                _proof(o),
              ],
              const SizedBox(height: 12),
              _totals(o),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareWhatsApp(o),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('مشاركة واتساب'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _sharePdf(o),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('ملخص PDF'),
                    ),
                  ),
                ],
              ),
              if (!o.status.isTerminal) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: o.expediteRequestedAt != null
                      ? null
                      : () async {
                          try {
                            await svc.requestExpedite(id);
                            Get.snackbar('تم', 'أُرسل تنبيه تسريع الشحن للموظف');
                          } catch (e) {
                            Get.snackbar('تعذر الإرسال', '$e');
                          }
                        },
                  icon: const Icon(Icons.bolt),
                  label: Text(o.expediteRequestedAt != null
                      ? 'طلب التسريع مُرسل'
                      : 'طلب تسريع الشحن'),
                ),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _header(Order o) {
    final c = Color(o.status.colorValue);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(o.orderNo,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(o.status.labelAr,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'تاريخ الطلب: ${o.createdAt.day}/${o.createdAt.month}/${o.createdAt.year}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            if (o.trackingNo.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('رقم التتبع: ${o.trackingNo}${o.courierName.isEmpty ? '' : ' · ${o.courierName}'}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 6),
            Text(o.address.fullAr,
                style: const TextStyle(fontSize: 12, height: 1.6, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _timeline(Order o) {
    return SectionCard(
      title: 'حالة الطلب',
      child: Column(
        children: List.generate(kTimelineStages.length, (i) {
          final stage = kTimelineStages[i];
          final done = o.stageReached(stage);
          final event = o.timeline.where((e) => stage.reachedBy.contains(e.status)).toList();
          final at = event.isEmpty ? null : event.last.at;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? AppColors.primary : Colors.white,
                      border: Border.all(
                        color: done ? AppColors.primary : const Color(0xFFDCE3E0),
                        width: 2,
                      ),
                    ),
                    child: done
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : null,
                  ),
                  if (i != kTimelineStages.length - 1)
                    Container(
                      width: 2,
                      height: 34,
                      color: done ? AppColors.primary.withOpacity(.35) : const Color(0xFFEDF1EF),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.labelAr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                        color: done ? AppColors.ink : AppColors.muted,
                      ),
                    ),
                    if (at != null)
                      Text(
                        '${at.day}/${at.month} · ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _items(Order o) => SectionCard(
        title: 'المنتجات (${o.totalPieces})',
        child: Column(
          children: o.items.map((it) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      it.imageUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 52,
                        height: 52,
                        color: const Color(0xFFEDF1EF),
                        child: const Icon(Icons.image_outlined, size: 18, color: AppColors.muted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        if (it.size.isNotEmpty || it.color.isNotEmpty)
                          Text(
                            [if (it.size.isNotEmpty) 'مقاس ${it.size}',
                             if (it.color.isNotEmpty) 'لون ${it.color}'].join(' · '),
                            style: const TextStyle(fontSize: 11, color: AppColors.muted),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('× ${it.qty}', style: const TextStyle(fontSize: 12)),
                      Text(
                        formatMoney(it.lineTotalSar * o.exchangeRate, o.currency),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );

  Widget _payment(Order o) {
    final p = o.payment;
    if (p.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'بيانات الحوالة',
      child: Column(
        children: [
          MoneyRow(label: 'اسم المرسل', value: p.senderName),
          MoneyRow(label: 'رقم العملية', value: p.refNo),
          MoneyRow(label: 'الحساب المستلم', value: p.accountNumber),
          MoneyRow(
            label: 'حالة التأكيد',
            value: p.confirmedAt == null ? 'بانتظار مراجعة المحاسبة' : 'مؤكدة',
            free: p.confirmedAt != null,
          ),
          if (p.proofUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('صورة الحوالة المرفقة',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _proofImage(p.proofUrl),
            ),
          ],
        ],
      ),
    );
  }

  /// الصورة قد تكون مخزّنة داخل Firestore (data:) أو رابطاً خارجياً.
  Widget _proofImage(String src) {
    if (src.startsWith('data:')) {
      try {
        final b64 = src.substring(src.indexOf(',') + 1);
        return Image.memory(base64Decode(b64),
            height: 220,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(
                height: 60,
                child: Center(child: Text('تعذر عرض صورة الحوالة'))));
      } catch (_) {
        return const SizedBox(
            height: 60, child: Center(child: Text('تعذر عرض صورة الحوالة')));
      }
    }
    return Image.network(src,
        height: 220,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox(
            height: 60,
            child: Center(child: Text('تعذر تحميل صورة الحوالة'))));
  }

  /// مشاركة ملخص الطلب على واتساب.
  Future<void> _shareWhatsApp(Order o) async {
    final text = _summaryText(o);
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await Share.share(text);
    }
  }

  /// تنزيل/مشاركة الملخص بصيغة PDF.
  Future<void> _sharePdf(Order o) async {
    try {
      final doc = pw.Document();
      pw.TextStyle arabic(double size, {bool bold = false}) => pw.TextStyle(
          fontSize: size,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (ctx) => [
          pw.Header(level: 0, text: 'ملخص الطلب ${o.orderNo}'),
          pw.Text('التاريخ: ${_fmtDate(o.createdAt)} · الحالة: ${o.status.labelAr}',
              style: arabic(11)),
          pw.SizedBox(height: 10),
          pw.Text('الموقع: ${o.address.fullAr}', style: arabic(11)),
          pw.SizedBox(height: 10),
          pw.Text('المنتجات', style: arabic(13, bold: true)),
          pw.SizedBox(height: 4),
          ...o.items.map((it) => pw.Bullet(
              text: '${it.title} × ${it.qty} — ${formatMoney(it.lineTotalSar * o.exchangeRate, o.currency)}',
              style: arabic(11))),
          pw.SizedBox(height: 10),
          pw.Text('بيانات الحوالة', style: arabic(13, bold: true)),
          pw.Text('اسم المرسل: ${o.payment.senderName}', style: arabic(11)),
          pw.Text('رقم العملية: ${o.payment.refNo}', style: arabic(11)),
          pw.Text('الحساب المستلم: ${o.payment.accountNumber}', style: arabic(11)),
          pw.Text('المبلغ المحوّل: ${formatMoney(o.payment.amount, o.currency)}',
              style: arabic(11)),
          pw.SizedBox(height: 10),
          pw.Text('الملخص المالي', style: arabic(13, bold: true)),
          pw.Text('المنتجات: ${formatMoney(o.subtotalSar * o.exchangeRate, o.currency)}',
              style: arabic(11)),
          pw.Text('الشحن: ${o.shippingFeeSar == 0 ? 'مجاني' : formatMoney(o.shippingFeeSar * o.exchangeRate, o.currency)}',
              style: arabic(11)),
          pw.Text('التوصيل: ${formatMoney(o.deliveryFeeSar * o.exchangeRate, o.currency)}',
              style: arabic(11)),
          pw.Divider(),
          pw.Text('الإجمالي: ${formatMoney(o.totalLocal, o.currency)}',
              style: arabic(13, bold: true)),
          pw.SizedBox(height: 14),
          pw.Text('يمن سيلو — وسيطك الموثوق للتسوق العالمي', style: arabic(10)),
        ],
      ));
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/order_${o.orderNo}.pdf');
      await f.writeAsBytes(await doc.save());
      await Share.shareXFiles([XFile(f.path)],
          text: 'ملخص الطلب ${o.orderNo}');
    } catch (e) {
      Get.snackbar('تعذر إنشاء PDF', '$e');
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _summaryText(Order o) {
    final b = StringBuffer()
      ..writeln('ملخص الطلب ${o.orderNo}')
      ..writeln('الحالة: ${o.status.labelAr}')
      ..writeln('الموقع: ${o.address.fullAr}')
      ..writeln('— المنتجات —');
    for (final it in o.items) {
      b.writeln('• ${it.title} × ${it.qty}');
    }
    b
      ..writeln('— الحوالة —')
      ..writeln('المرسل: ${o.payment.senderName}')
      ..writeln('رقم العملية: ${o.payment.refNo}')
      ..writeln('المبلغ المحوّل: ${formatMoney(o.payment.amount, o.currency)}')
      ..writeln('— الإجمالي: ${formatMoney(o.totalLocal, o.currency)} —')
      ..writeln('يمن سيلو');
    return b.toString();
  }

  Widget _proof(Order o) => SectionCard(
        title: 'إثبات التسليم',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            o.proofImageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(
              height: 80,
              child: Center(child: Text('تعذر تحميل صورة الإثبات')),
            ),
          ),
        ),
      );

  Widget _totals(Order o) {
    return SectionCard(
      title: 'الملخص المالي',
      child: Column(
        children: [
          MoneyRow(
            label: 'المنتجات',
            value: formatMoney(o.subtotalSar * o.exchangeRate, o.currency),
          ),
          MoneyRow(
            label: 'الشحن',
            value: o.shippingFeeSar == 0
                ? 'مجاني'
                : formatMoney(o.shippingFeeSar * o.exchangeRate, o.currency),
            free: o.shippingFeeSar == 0,
          ),
          MoneyRow(
            label: 'التوصيل',
            value: formatMoney(o.deliveryFeeSar * o.exchangeRate, o.currency),
          ),
          if (o.discountSar > 0)
            MoneyRow(
              label: 'الخصم (${o.couponCode})',
              value: '- ${formatMoney(o.discountSar * o.exchangeRate, o.currency)}',
              free: true,
            ),
          const Divider(height: 20),
          MoneyRow(
            label: 'الإجمالي',
            value: formatMoney(o.totalLocal, o.currency),
            bold: true,
          ),
        ],
      ),
    );
  }
}
