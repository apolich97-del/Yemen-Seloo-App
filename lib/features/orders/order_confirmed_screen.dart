import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/currency.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/order_documents.dart';
import '../../core/services/order_service.dart';
import '../../core/services/settings_service.dart';
import '../home/presentation/main_tab_controller.dart';
import '../../core/theme/app_theme.dart';

/// شاشة ما بعد تأكيد الطلب: مسار واتساب الإجباري باستمارة تأكيد رسمية بهوية يمن سيلو.
class OrderConfirmedScreen extends StatefulWidget {
  const OrderConfirmedScreen({
    super.key,
    required this.orderNo,
    required this.summary,
    this.orderId = '',
    this.totalLocal = 0,
    this.currencyKey = 'south',
    this.paymentPlan = 'full',
    this.upfrontDueLocal = 0,
    this.paidLocal = 0,
    this.remainingLocal = 0,
    this.customerName = '',
    this.customerPhone = '',
    this.addressAr = '',
    this.itemsCount = 0,
  });

  final String orderNo;
  final String orderId;
  final String summary;
  final double totalLocal;
  final String currencyKey;
  final String paymentPlan;
  final double upfrontDueLocal;
  final double paidLocal;
  final double remainingLocal;
  final String customerName;
  final String customerPhone;
  final String addressAr;
  final int itemsCount;

  @override
  State<OrderConfirmedScreen> createState() => _OrderConfirmedScreenState();
}

class _OrderConfirmedScreenState extends State<OrderConfirmedScreen> {
  bool _sent = false;
  bool _confirmedSent = false;
  bool _exportingPdf = false;

  AppCurrency get _currency => AppCurrency.values.firstWhere(
        (c) => c.key == widget.currencyKey,
        orElse: () => AppCurrency.south,
      );

  bool get _canProceed => _confirmedSent;

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

  void _copyForm() {
    Clipboard.setData(ClipboardData(text: widget.summary));
    Get.snackbar('تم النسخ', 'تم نسخ استمارة تأكيد الطلب الرسمية');
  }

  void _confirmSentGate() {
    setState(() => _confirmedSent = true);
    Get.snackbar('تم التأكيد ✓', 'شكراً لك — تم فتح التتبع والخدمات الكاملة لطلبك');
  }

  Future<void> _shareOrderPdf() async {
    if (widget.orderId.isEmpty) {
      Get.toNamed(AppRoutes.myReceipts);
      return;
    }
    setState(() => _exportingPdf = true);
    try {
      final ord = await Get.find<OrderService>().fetchOrder(widget.orderId);
      if (ord == null) {
        Get.toNamed(AppRoutes.myReceipts);
        return;
      }
      final file = await OrderDocuments.buildPdf(ord);
      await Share.shareXFiles([XFile(file.path)],
          text: 'استمارة طلب ${ord.orderNo} — يمن سيلو');
    } catch (e) {
      Get.snackbar('تعذر تجهيز PDF', '$e');
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDeferred = widget.paymentPlan == 'half_deferred';
    return PopScope(
      canPop: _canProceed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_canProceed) {
          Get.snackbar(
            'مسار واتساب إجباري',
            'أرسل استمارة تأكيد الطلب عبر واتساب ثم اضغط «أكدت إرسال الاستمارة لواتساب ✓» للمتابعة.',
            duration: const Duration(seconds: 4),
          );
        }
      },
      child: Scaffold(
        backgroundColor: T.bg,
        appBar: AppBar(
          backgroundColor: T.surface,
          automaticallyImplyLeading: false,
          title: Text('استمارة تأكيد الطلب الرسمية',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: T.text)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ═══ بطاقة الاستمارة الاحترافية بهوية يمن سيلو ═══
            Container(
              decoration: BoxDecoration(
                color: T.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: T.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isDeferred ? 'طلب آجل 50%' : 'طلب مؤكد',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white),
                              ),
                            ),
                            Text(
                              widget.orderNo,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.amberAccent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Icon(Icons.verified_outlined,
                            size: 46, color: Colors.white),
                        const SizedBox(height: 6),
                        const Text('استمارة تأكيد طلب — يمن سيلو',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        const Text(
                          'الخطوة الإلزامية الأخيرة: أرسل الاستمارة إلى واتساب الشركة لاعتماد التنفيذ.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.customerName.isNotEmpty) ...[
                          _infoRow('العميل', '${widget.customerName} (${widget.customerPhone})'),
                          if (widget.addressAr.isNotEmpty)
                            _infoRow('العنوان', widget.addressAr),
                          if (widget.itemsCount > 0)
                            _infoRow('عدد القطع', '${widget.itemsCount} قطعة'),
                          const Divider(height: 16),
                        ],
                        if (widget.totalLocal > 0)
                          _infoRow('إجمالي الطلب', formatMoney(widget.totalLocal, _currency), strong: true),
                        if (isDeferred && widget.upfrontDueLocal > 0)
                          _infoRow('الدفعة الأولى (العربون)',
                              formatMoney(widget.upfrontDueLocal, _currency)),
                        if (widget.paidLocal > 0)
                          _infoRow('المبلغ المحوّل الآن',
                              formatMoney(widget.paidLocal, _currency),
                              color: T.success),
                        if (widget.remainingLocal > 0.5)
                          _infoRow('المتبقي في الذمة',
                              formatMoney(widget.remainingLocal, _currency),
                              color: T.danger,
                              strong: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ═══ معاينة نص الاستمارة الرسمية لواتساب ═══
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: T.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _confirmedSent
                      ? T.success.withOpacity(.6)
                      : (_sent ? T.primary.withOpacity(.5) : T.warning.withOpacity(.6)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _confirmedSent
                            ? Icons.check_circle
                            : (_sent ? Icons.chat : Icons.lock_clock),
                        size: 17,
                        color: _confirmedSent
                            ? T.success
                            : (_sent ? T.primary : T.warning),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _confirmedSent
                              ? 'تم تأكيد إرسال الاستمارة عبر واتساب ✓'
                              : (_sent
                                  ? 'تم فتح واتساب — اضغط «أكدت الإرسال» أدناه للمتابعة'
                                  : 'مسار واتساب إجباري — أرسل هذه الاستمارة أولاً'),
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: _confirmedSent
                                  ? T.success
                                  : (_sent ? T.primary : T.warning)),
                        ),
                      ),
                      IconButton(
                        tooltip: 'نسخ الاستمارة',
                        icon: const Icon(Icons.copy, size: 17),
                        onPressed: _copyForm,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    widget.summary,
                    style: TextStyle(fontSize: 10.5, height: 1.65, color: T.muted),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _openWhatsApp,
              style: ElevatedButton.styleFrom(
                backgroundColor: T.whatsapp,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.chat, size: 19),
              label: Text(
                _sent
                    ? 'إعادة إرسال الاستمارة عبر واتساب'
                    : 'فتح واتساب وإرسال الاستمارة الرسمية',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),

            if (!_confirmedSent) ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _confirmSentGate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 19),
                label: const Text('أكدت إرسال الاستمارة لواتساب ✓',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],

            if (_confirmedSent) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _exportingPdf ? null : _shareOrderPdf,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: BorderSide(color: T.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: Icon(Icons.picture_as_pdf_outlined, size: 18, color: T.text),
                label: Text(_exportingPdf ? 'جاري تجهيز PDF...' : 'تنزيل / مشاركة PDF الطلب',
                    style: TextStyle(fontSize: 12.5, color: T.text)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (Get.isRegistered<MainTabController>()) {
                          Get.find<MainTabController>().goToOrders('all');
                        }
                        Get.offAllNamed('/main');
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: T.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: Icon(Icons.local_shipping_outlined, size: 18, color: T.text),
                      label: Text('تتبع الطلب',
                          style: TextStyle(fontSize: 12, color: T.text)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Get.toNamed(AppRoutes.accountStatement),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: T.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: Icon(Icons.account_balance_outlined, size: 18, color: T.text),
                      label: Text('كشف الحساب',
                          style: TextStyle(fontSize: 12, color: T.text)),
                    ),
                  ),
                ],
              ),
            ],

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
      ),
    );
  }

  Widget _infoRow(String k, String v, {bool strong = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: TextStyle(fontSize: 11.5, color: T.muted)),
            Flexible(
              child: Text(
                v,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: strong ? 13 : 11.5,
                  fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
                  color: color ?? T.text,
                ),
              ),
            ),
          ],
        ),
      );
}
