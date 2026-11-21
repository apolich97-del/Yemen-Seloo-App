import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/currency.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/settings_service.dart';
import '../home/presentation/main_tab_controller.dart';
import '../../core/theme/app_theme.dart';

/// شاشة ما بعد تأكيد الطلب: فتح واتساب الشركة بنسخة كاملة من الطلب.
class OrderConfirmedScreen extends StatefulWidget {
  const OrderConfirmedScreen({
    super.key,
    required this.orderNo,
    required this.summary,
    this.totalLocal = 0,
    this.currencyKey = 'south',
  });

  final String orderNo;
  final String summary;
  final double totalLocal;
  final String currencyKey;

  @override
  State<OrderConfirmedScreen> createState() => _OrderConfirmedScreenState();
}

class _OrderConfirmedScreenState extends State<OrderConfirmedScreen> {
  bool _sent = false;

  String get _companyPhone {
    if (Get.isRegistered<SettingsService>()) {
      final s = Get.find<SettingsService>().settings.value;
      return s.supportWhatsApp.replaceAll(RegExp(r'[^0-9]'), '');
    }
    return '';
  }

  Future<void> _openWhatsApp() async {
    final phone = _companyPhone;
    final text = Uri.encodeComponent(widget.summary);
    final url = phone.isEmpty
        ? 'https://wa.me/?text=$text'
        : 'https://wa.me/$phone?text=$text';
    final ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    if (ok && mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      appBar: AppBar(
        backgroundColor: T.surface,
        automaticallyImplyLeading: false,
        title: Text('تم إنشاء الطلب',
            style: TextStyle(fontSize: 15, color: T.text)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: T.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: T.border),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle, size: 54, color: T.success),
                const SizedBox(height: 10),
                Text('رقم طلبك ${widget.orderNo}',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: T.text)),
                const SizedBox(height: 6),
                Text(
                  'أرسل نسخة الطلب إلى واتساب الشركة لتأكيده وبدء التنفيذ.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 1.6, color: T.muted),
                ),
                const SizedBox(height: 8),
                if (widget.totalLocal > 0)
                  Text(
                    formatMoney(widget.totalLocal,
                        AppCurrency.values.firstWhere(
                          (c) => c.key == widget.currencyKey,
                          orElse: () => AppCurrency.values.first,
                        )),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: T.primary),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                    Icon(_sent ? Icons.check_circle : Icons.info_outline,
                        size: 16, color: _sent ? T.success : T.warning),
                    const SizedBox(width: 6),
                    Text(_sent ? 'تم فتح واتساب وإرسال النسخة' : 'بانتظار إرسال النسخة',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: _sent ? T.success : T.warning)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(widget.summary,
                    style: TextStyle(
                        fontSize: 10.5, height: 1.7, color: T.muted)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _openWhatsApp,
            style: ElevatedButton.styleFrom(
              backgroundColor: T.whatsapp,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.chat, size: 18),
            label: Text(_sent ? 'إعادة فتح واتساب' : 'إرسال نسخة الطلب لواتساب',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Get.toNamed(AppRoutes.myReceipts),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: BorderSide(color: T.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: Icon(Icons.picture_as_pdf_outlined, size: 18, color: T.text),
            label: Text('عرض إيصال / ملخص PDF',
                style: TextStyle(fontSize: 12.5, color: T.text)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Get.find<MainTabController>().goTo(3),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: BorderSide(color: T.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: Icon(Icons.local_shipping_outlined, size: 18, color: T.text),
            label: Text('تتبع الطلب',
                style: TextStyle(fontSize: 12.5, color: T.text)),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: T.soft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: T.softBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 16, color: T.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('الإلغاء المجاني خلال 24 ساعة من إنشاء الطلب.',
                      style: TextStyle(fontSize: 11, color: T.text)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
