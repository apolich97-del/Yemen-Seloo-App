import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/seloo_config.dart';
import '../application/cart_counter.dart';
import '../domain/cart_item.dart';

const Color _purple = Color(0xFF7C3AED);
const Color _purpleLight = Color(0xFFFAF7FF);
const Color _border = Color(0xFFE9D5FF);
const Color _green = Color(0xFF25D366);
const Color _orange = Color(0xFFF97316);

const String _primaryWhatsApp = '967770518757';
const String _primaryPhone = '770518757';
const String _backupWhatsApp = '967737383637';
const String _backupPhone = '737383637';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartCounter _cart = Get.find<CartCounter>();

  @override
  void initState() {
    super.initState();
    _cart.refreshQuote();
  }

  Future<void> _run(Future<String?> Function() action) async {
    final String? error = await action();
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _shareCartToWhatsApp() async {
    if (_cart.items.isEmpty) {
      _snack('السلة فارغة');
      return;
    }

    await _cart.refreshQuote();
    final CartQuote? q = _cart.quote.value;
    if (q == null) {
      _snack('تعذّر حساب الإجمالي، حاول مرة أخرى.');
      return;
    }

    final String message = _buildWhatsAppMessage(
      q: q,
      includeCommission: false,
    );
    await _sendWhatsApp(message);
  }

  Future<void> _shareCartWithCommission() async {
    if (_cart.items.isEmpty) {
      _snack('السلة فارغة');
      return;
    }

    if (!_cart.hasCommission) {
      _snack('أدخل مبلغ العمولة أولاً');
      return;
    }

    await _cart.refreshQuote();
    final CartQuote? q = _cart.quote.value;
    if (q == null) {
      _snack('تعذّر حساب الإجمالي.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final double commissionSar = _cart.commissionTotalSar;
        final double commissionYer = _cart.commissionTotalYer;
        final double rate = q.exchangeRate;
        final double totalSar = (q.grandTotalLocal / rate) + commissionSar;
        final double totalYer = q.grandTotalLocal + commissionYer;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('⚠️ تأكيد مشاركة العمولة'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'سيتم إرسال السلة مع العمولة للشركة، وسيدفع العميل:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  _summaryRow(
                      '💵 قيمة السلة',
                      '${(q.itemsSubtotalLocal / rate).toStringAsFixed(2)} SAR'),
                  _summaryRow(
                      '🛠️ رسوم الخدمة',
                      '${(q.serviceFeeLocal / rate).toStringAsFixed(2)} SAR'),
                  _summaryRow(
                      '🚚 الشحن',
                      '${(q.shippingLocal / rate).toStringAsFixed(2)} SAR'),
                  _summaryRow(
                      '🎁 العمولة (${_cart.commissionPerPiece.value.toStringAsFixed(2)} × ${_cart.items.length})',
                      '${commissionSar.toStringAsFixed(2)} SAR'),
                  const Divider(height: 20),
                  _summaryRow(
                      '💰 الإجمالي المطلوب',
                      '${totalSar.toStringAsFixed(2)} SAR',
                      emphasize: true),
                  _summaryRow(
                      '🇾🇪 بالريال اليمني',
                      '${totalYer.toStringAsFixed(0)} ريال',
                      emphasize: true),
                  const Divider(height: 20),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _purpleLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          '🎁 *المستحق لك* (بعد خصم قيمة السلة):',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _purple,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'العمولة = ${commissionYer.toStringAsFixed(0)} ريال يمني',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _purple,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '(${commissionSar.toStringAsFixed(2)} SAR × $rate)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('إلغاء',
                    style: TextStyle(color: Color(0xFF6B7280))),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(backgroundColor: _green),
                child: const Text('موافق ✓'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    _cart.approveCommission();
    final String message = _buildWhatsAppMessage(
      q: q,
      includeCommission: true,
    );
    await _sendWhatsApp(message);
  }

  String _buildWhatsAppMessage({
    required CartQuote q,
    required bool includeCommission,
  }) {
    final StringBuffer b = StringBuffer();
    b.writeln('🛍️ *طلب جديد من يمن سيلو*');
    b.writeln('━━━━━━━━━━━━━━━━━━━━━━━');
    b.writeln('');

    for (int i = 0; i < _cart.items.length; i++) {
      final CartItem item = _cart.items[i];
      b.writeln('${i + 1}. ${item.title}');
      if (item.color.isNotEmpty) b.writeln('   اللون: ${item.color}');
      if (item.size.isNotEmpty) b.writeln('   المقاس: ${item.size}');
      if (item.options.isNotEmpty) {
        item.options.forEach((String k, String v) {
          b.writeln('   $k: $v');
        });
      }
      b.writeln('   الكمية: ${item.quantity}');
      b.writeln('   السعر: ${item.sourcePrice.toStringAsFixed(2)} SAR');
      if (item.goodsId.isNotEmpty) {
        b.writeln('   الرابط: https://m.shein.com/ar/p-${item.goodsId}.html');
      } else if (item.sourceUrl.isNotEmpty) {
        b.writeln('   الرابط: ${item.sourceUrl}');
      }
      b.writeln('');
    }

    b.writeln('━━━━━━━━━━━━━━━━━━━━━━━');
    b.writeln('📦 عدد الأسطر: ${q.linesCount}');
    b.writeln('🔢 عدد القطع: ${q.unitsCount}');
    b.writeln('');

    final double rate = q.exchangeRate;
    final double subtotalSar = q.itemsSubtotalLocal / rate;
    final double serviceFeeSar = q.serviceFeeLocal / rate;
    final double shippingSar = q.shippingLocal / rate;

    b.writeln('💵 قيمة السلة: ${subtotalSar.toStringAsFixed(2)} SAR');
    b.writeln('🛠️ رسوم الخدمة: ${serviceFeeSar.toStringAsFixed(2)} SAR');
    b.writeln('🚚 الشحن: ${shippingSar.toStringAsFixed(2)} SAR');

    if (includeCommission) {
      final double commissionSar = _cart.commissionTotalSar;
      final double commissionYer = _cart.commissionTotalYer;
      final double totalSar =
          subtotalSar + serviceFeeSar + shippingSar + commissionSar;
      final double totalYer = q.grandTotalLocal + commissionYer;

      b.writeln(
          '🎁 عمولة المندوب: ${commissionSar.toStringAsFixed(2)} SAR');
      b.writeln('━━━━━━━━━━━━━━━━━━━━━━━');
      b.writeln('💰 الإجمالي المطلوب: ${totalSar.toStringAsFixed(2)} SAR');
      b.writeln(
          '🇾🇪 بالريال اليمني: ${totalYer.toStringAsFixed(0)} ريال');
      b.writeln('📊 سعر الصرف: ${rate.toStringAsFixed(0)}');
      final String regionName =
          _cart.region.value == 'south' ? 'الجنوب' : 'الشمال';
      b.writeln('📍 المنطقة: $regionName');
      b.writeln('━━━━━━━━━━━━━━━━━━━━━━━');
      b.writeln('🎁 *المستحق للمندوب* (بعد خصم قيمة السلة):');
      b.writeln(
          '   العمولة = *${commissionYer.toStringAsFixed(0)} ريال يمني*');
    } else {
      b.writeln('━━━━━━━━━━━━━━━━━━━━━━━');
      b.writeln(
          '💰 الإجمالي: ${(subtotalSar + serviceFeeSar + shippingSar).toStringAsFixed(2)} SAR');
      b.writeln(
          '🇾🇪 بالريال اليمني: ${q.grandTotalLocal.toStringAsFixed(0)} ريال');
      b.writeln('📊 سعر الصرف: ${rate.toStringAsFixed(0)}');
      final String regionName =
          _cart.region.value == 'south' ? 'الجنوب' : 'الشمال';
      b.writeln('📍 المنطقة: $regionName');
    }

    b.writeln('━━━━━━━━━━━━━━━━━━━━━━━');
    b.writeln('📞 للتواصل: $_primaryPhone');
    b.writeln('📞 البديل: $_backupPhone');
    b.writeln('');
    b.writeln('خدمتكم غايتنا وثقتكم هدفنا');

    return b.toString();
  }

  Future<void> _sendWhatsApp(String message) async {
    final Uri url = Uri.parse(
      'https://wa.me/$_primaryWhatsApp?text=${Uri.encodeComponent(message)}',
    );
    try {
      final bool ok =
          await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok) _snack('تعذّر فتح الواتساب');
    } catch (e) {
      _snack('تعذّر فتح الواتساب: $e');
    }
  }

  Future<void> _openCommissionCalculator() async {
    if (_cart.items.isEmpty) {
      _snack('السلة فارغة');
      return;
    }

    final TextEditingController controller = TextEditingController(
      text: _cart.commissionPerPiece.value > 0
          ? _cart.commissionPerPiece.value.toStringAsFixed(2)
          : '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (BuildContext ctx, StateSetter setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                  top: 20,
                  left: 20,
                  right: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(Icons.calculate, color: _purple, size: 24),
                        SizedBox(width: 8),
                        Text(
                          '🧮 آلة حساب عمولة المندوب',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: _purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'مبلغ العمولة لكل قطعة',
                        hintText: 'مثال: 5.00',
                        prefixIcon:
                            const Icon(Icons.attach_money, color: _purple),
                        suffixText: 'SAR',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _purple, width: 2),
                        ),
                      ),
                      onChanged: (String v) {
                        final double value = double.tryParse(v) ?? 0;
                        _cart.setCommission(value);
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _purpleLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: Obx(() {
                        final double perPiece =
                            _cart.commissionPerPiece.value;
                        final double totalSar = _cart.commissionTotalSar;
                        final double totalYer = _cart.commissionTotalYer;
                        final int count = _cart.items.length;
                        final double rate = _cart.commissionTotalSar > 0
                            ? totalYer / totalSar
                            : _cart.quote.value?.exchangeRate ?? 140;

                        return Column(
                          children: <Widget>[
                            _summaryRow('📦 عدد القطع', '$count'),
                            const SizedBox(height: 6),
                            _summaryRow('🎁 العمولة لكل قطعة',
                                '${perPiece.toStringAsFixed(2)} SAR'),
                            const Divider(height: 16),
                            _summaryRow('💰 إجمالي العمولة',
                                '${totalSar.toStringAsFixed(2)} SAR',
                                emphasize: true),
                            const SizedBox(height: 6),
                            _summaryRow('🇾🇪 بالريال اليمني',
                                '${totalYer.toStringAsFixed(0)} ريال',
                                emphasize: true),
                            const SizedBox(height: 6),
                            _summaryRow('📊 سعر الصرف',
                                '${rate.toStringAsFixed(0)}'),
                          ],
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    Obx(() {
                      final bool hasCom = _cart.hasCommission;
                      return Column(
                        children: <Widget>[
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: hasCom
                                  ? () async {
                                      Navigator.of(ctx).pop();
                                      await _shareCartWithCommission();
                                    }
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: _green,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 13),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.share),
                              label: const Text(
                                'مشاركة مع الشركة',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                Navigator.of(ctx).pop();
                                await _shareCartToWhatsApp();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _purple,
                                side: const BorderSide(color: _purple),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 13),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.share),
                              label: const Text(
                                'مشاركة عادية (بدون عمولة)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('إغلاق'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _summaryRow(String label, String value, {bool emphasize = false}) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasize ? _purple : const Color(0xFF374151),
              fontWeight: emphasize ? FontWeight.w900 : FontWeight.w500,
              fontSize: emphasize ? 14 : 13,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: emphasize ? _purple : const Color(0xFF374151),
            fontWeight: emphasize ? FontWeight.w900 : FontWeight.w600,
            fontSize: emphasize ? 14 : 13,
          ),
        ),
      ],
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Obx(() {
            if (_cart.items.isEmpty) {
              return Column(
                children: <Widget>[
                  _Header(count: _cart.items.length),
                  const SizedBox(height: 8),
                  _buildImportSheinCartButton(),
                  const Expanded(child: _EmptyCart()),
                ],
              );
            }
            return Column(
              children: <Widget>[
                _Header(count: _cart.items.length),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    children: <Widget>[
                      const Text(
                        'سلة التسوق',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'اختر منطقة التسعير، ثم شارك سلتك أو أكّد طلبك.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildImportSheinCartButton(),
                      const SizedBox(height: 10),
                      ..._cart.items.map(
                        (CartItem item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CartLineTile(
                            item: item,
                            onQuantity: (int v) =>
                                _run(() => _cart.updateQuantity(item, v)),
                            onRemove: () => _run(() => _cart.remove(item)),
                            onEdit: () => _cart.startEditing(item),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _RegionSelector(cart: _cart),
                      const SizedBox(height: 10),
                      _QuoteSummary(cart: _cart),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openCommissionCalculator,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _purple,
                            side: const BorderSide(
                                color: _purple, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.calculate, size: 20),
                          label: const Text(
                            '🧮 آلة حساب عمولة المندوب',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _shareCartToWhatsApp,
                          style: FilledButton.styleFrom(
                            backgroundColor: _green,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.share),
                          label: const Text(
                            'مشاركة السلة عبر واتساب',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _CheckoutButton(cart: _cart),
                      const SizedBox(height: 8),
                      Text(
                        SelooConfig.priceDisclaimer,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ContactBox(),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildImportSheinCartButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Get.toNamed('/shein', arguments: <String, dynamic>{
            'openUrl': 'https://ar.shein.com/cart', // ⭐ رجوع للنطاق العام
          }),
          style: OutlinedButton.styleFrom(
            foregroundColor: _orange,
            side: const BorderSide(color: _orange, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.download_outlined, size: 20),
          label: const Text(
            '📥 استيراد سلة شي ان',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══ (بقية الـ widgets: _Header, _CartLineTile, _InfoChip, _ProductImage, _QuantityButton, _RegionSelector, _RegionButton, _QuoteSummary, _CheckoutButton, _ContactBox, _EmptyCart) ═══
