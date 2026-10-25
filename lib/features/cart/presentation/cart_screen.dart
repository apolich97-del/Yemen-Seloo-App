
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/seloo_config.dart';
import '../../shein/application/shein_cart_importer.dart';
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
  final TextEditingController _shareCartController =
      TextEditingController();

  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _cart.refreshQuote();
  }

  @override
  void dispose() {
    _shareCartController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    final String? error = await action();
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  // استيراد سلة SHEIN المشتركة عبر واجهة المستورد الحالية.
  Future<void> _importSharedCart() async {
    if (_importing) return;

    final String text = _shareCartController.text.trim();

    if (text.isEmpty) {
      _snack('الصق رابط السلة المشتركة أولاً');
      return;
    }

    setState(() => _importing = true);

    try {
      final SheinCartImportResult result =
          await SheinCartImporter().importSharedCart(text);

      if (!mounted) return;

      setState(() => _importing = false);

           if (!result.success) {
        _snack(result.message);
        await Get.toNamed('/shein', arguments: {'shareCartUrl': text});
        return;
           }
        // المسار المضمون: فتح الرابط داخل متصفح التطبيق (زر الزحف الأخضر)
        await Get.toNamed('/shein', arguments: {'shareCartUrl': text});
        return;
      }

      _shareCartController.clear();
      await _cart.refreshQuote();

      _snack(result.message);
    } catch (_) {
      if (!mounted) return;

      setState(() => _importing = false);
      _snack(
        'فشل استيراد السلة. تحقق من الرابط والاتصال ثم أعد المحاولة.',
      );
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
        final double totalSar =
            (q.grandTotalLocal / rate) + commissionSar;
        final double totalYer =
            q.grandTotalLocal + commissionYer;

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
                    '${(q.itemsSubtotalLocal / rate).toStringAsFixed(2)} SAR',
                  ),
                  _summaryRow(
                    '🛠️ رسوم الخدمة',
                    '${(q.serviceFeeLocal / rate).toStringAsFixed(2)} SAR',
                  ),
                  _summaryRow(
                    '🚚 الشحن',
                    '${(q.shippingLocal / rate).toStringAsFixed(2)} SAR',
                  ),
                  _summaryRow(
                    '🎁 العمولة (${_cart.commissionPerPiece.value.toStringAsFixed(2)} × ${_cart.items.length})',
                    '${commissionSar.toStringAsFixed(2)} SAR',
                  ),
                  const Divider(height: 20),
                  _summaryRow(
                    '💰 الإجمالي المطلوب',
                    '${totalSar.toStringAsFixed(2)} SAR',
                    emphasize: true,
                  ),
                  _summaryRow(
                    '🇾🇪 بالريال اليمني',
                    '${totalYer.toStringAsFixed(0)} ريال',
                    emphasize: true,
                  ),
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
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                ),
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

      if (item.color.isNotEmpty) {
        b.writeln('   اللون: ${item.color}');
      }

      if (item.size.isNotEmpty) {
        b.writeln('   المقاس: ${item.size}');
      }

      if (item.options.isNotEmpty) {
        item.options.forEach((String k, String v) {
          b.writeln('   $k: $v');
        });
      }

      b.writeln('   الكمية: ${item.quantity}');
      b.writeln(
        '   السعر: ${item.sourcePrice.toStringAsFixed(2)} SAR',
      );

      if (item.goodsId.isNotEmpty) {
        b.writeln(
          '   الرابط: https://m.shein.com/ar/p-${item.goodsId}.html',
        );
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

    b.writeln(
      '💵 قيمة السلة: ${subtotalSar.toStringAsFixed(2)} SAR',
    );
    b.writeln(
      '🛠️ رسوم الخدمة: ${serviceFeeSar.toStringAsFixed(2)} SAR',
    );
    b.writeln(
      '🚚 الشحن: ${shippingSar.toStringAsFixed(2)} SAR',
    );

    if (includeCommission) {
      final double commissionSar = _cart.commissionTotalSar;
      final double commissionYer = _cart.commissionTotalYer;

      final double totalSar =
          subtotalSar + serviceFeeSar + shippingSar + commissionSar;

      final double totalYer = q.grandTotalLocal + commissionYer;

      b.writeln(
        '🎁 عمولة المندوب: ${commissionSar.toStringAsFixed(2)} SAR',
      );
      b.writeln('━━━━━━━━━━━━━━━━━━━━━━━');
      b.writeln(
        '💰 الإجمالي المطلوب: ${totalSar.toStringAsFixed(2)} SAR',
      );
      b.writeln(
        '🇾🇪 بالريال اليمني: ${totalYer.toStringAsFixed(0)} ريال',
      );
      b.writeln('📊 سعر الصرف: ${rate.toStringAsFixed(0)}');

      final String regionName =
          _cart.region.value == 'south' ? 'الجنوب' : 'الشمال';

      b.writeln('📍 المنطقة: $regionName');
      b.writeln('━━━━━━━━━━━━━━━━━━━━━━━');
      b.writeln('🎁 *المستحق للمندوب* (بعد خصم قيمة السلة):');
      b.writeln(
        '   العمولة = *${commissionYer.toStringAsFixed(0)} ريال يمني*',
      );
    } else {
      b.writeln('━━━━━━━━━━━━━━━━━━━━━━━');
      b.writeln(
        '💰 الإجمالي: ${(subtotalSar + serviceFeeSar + shippingSar).toStringAsFixed(2)} SAR',
      );
      b.writeln(
        '🇾🇪 بالريال اليمني: ${q.grandTotalLocal.toStringAsFixed(0)} ريال',
      );
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
      final bool ok = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
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
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: 'مبلغ العمولة لكل قطعة',
                        hintText: 'مثال: 5.00',
                        prefixIcon: const Icon(
                          Icons.attach_money,
                          color: _purple,
                        ),
                        suffixText: 'SAR',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _purple,
                            width: 2,
                          ),
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

                        final double rate = totalSar > 0
                            ? totalYer / totalSar
                            : _cart.quote.value?.exchangeRate ?? 140;

                        return Column(
                          children: <Widget>[
                            _summaryRow('📦 عدد القطع', '$count'),
                            const SizedBox(height: 6),
                            _summaryRow(
                              '🎁 العمولة لكل قطعة',
                              '${perPiece.toStringAsFixed(2)} SAR',
                            ),
                            const Divider(height: 16),
                            _summaryRow(
                              '💰 إجمالي العمولة',
                              '${totalSar.toStringAsFixed(2)} SAR',
                              emphasize: true,
                            ),
                            const SizedBox(height: 6),
                            _summaryRow(
                              '🇾🇪 بالريال اليمني',
                              '${totalYer.toStringAsFixed(0)} ريال',
                              emphasize: true,
                            ),
                            const SizedBox(height: 6),
                            _summaryRow(
                              '📊 سعر الصرف',
                              rate.toStringAsFixed(0),
                            ),
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
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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

    controller.dispose();
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasize ? _purple : const Color(0xFF374151),
              fontWeight:
                  emphasize ? FontWeight.w900 : FontWeight.w500,
              fontSize: emphasize ? 14 : 13,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: emphasize ? _purple : const Color(0xFF374151),
            fontWeight:
                emphasize ? FontWeight.w900 : FontWeight.w600,
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

  Widget _buildImportSheinCartButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _purpleLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _orange.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.download_outlined, color: _orange, size: 20),
                SizedBox(width: 8),
                Text(
                  'استيراد سلة شي ان',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'الصق رابط السلة المشتركة من شي إن (أو نص المشاركة الكامل):',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _shareCartController,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'https://m.shein.com/ar/cart/share/landing?...',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _importing ? null : _importSharedCart,
                style: FilledButton.styleFrom(
                  backgroundColor: _orange,
                ),
                child: _importing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'بدء الاستيراد',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
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
                              color: _purple,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
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
                            padding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
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
}

// Header
class _Header extends StatelessWidget {
  const _Header({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF3F4F6)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _purpleLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  color: _purple,
                  size: 22,
                ),
              ),
              if (count > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const <Widget>[
              Text(
                'يمن سيلو',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: _purple,
                ),
              ),
              Text(
                'YEMEN SELOO',
                style: TextStyle(
                  fontSize: 8,
                  letterSpacing: 2,
                  color: _purple,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _purpleLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.storefront,
              color: _purple,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

// Cart line
class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.item,
    required this.onQuantity,
    required this.onRemove,
    required this.onEdit,
  });

  final CartItem item;
  final ValueChanged<int> onQuantity;
  final VoidCallback onRemove;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1.2),
      ),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              GestureDetector(
                onTap: onEdit,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: _ProductImage(url: item.imageUrl),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: onRemove,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFEF4444),
                            size: 20,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'SAR ${item.sourcePrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: _purple,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: Color(0xFF1F2937),
                        height: 1.4,
                      ),
                    ),
                    if (item.color.isNotEmpty || item.size.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: <Widget>[
                            if (item.color.isNotEmpty)
                              _InfoChip(
                                label: 'اللون',
                                value: item.color,
                                color: _purple,
                              ),
                            if (item.size.isNotEmpty)
                              _InfoChip(
                                label: 'المقاس',
                                value: item.size,
                                color: _orange,
                              ),
                          ],
                        ),
                      ),
                    if (item.options.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: item.options.entries
                              .map(
                                (MapEntry<String, String> e) => _InfoChip(
                                  label: e.key,
                                  value: e.value,
                                  color: const Color(0xFF10B981),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _QuantityButton(
                icon: Icons.remove,
                enabled: item.quantity > 1,
                onTap: () => onQuantity(item.quantity - 1),
              ),
              const SizedBox(width: 12),
              Text(
                '${item.quantity}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 12),
              _QuantityButton(
                icon: Icons.add,
                enabled:
                    item.quantity < SelooConfig.maxQuantityPerLine,
                onTap: () => onQuantity(item.quantity + 1),
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit_outlined,
                  color: _orange,
                  size: 20,
                ),
                tooltip: 'تعديل',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10.5,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder();

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: _purpleLight,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _purple,
            ),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        color: _purpleLight,
        child: const Icon(
          Icons.image_outlined,
          color: _purple,
          size: 32,
        ),
      );
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? _purpleLight : const Color(0xFFF3F4F6),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? _purple : const Color(0xFFD1D5DB),
        ),
      ),
    );
  }
}

class _RegionSelector extends StatelessWidget {
  const _RegionSelector({required this.cart});

  final CartCounter cart;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final String current = cart.region.value;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _purpleLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.public, color: _purple, size: 18),
                SizedBox(width: 6),
                Text(
                  'منطقة التسعير',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _purple,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _RegionButton(
                    label: 'الشمال · 140',
                    active: current == 'north',
                    onTap: () => cart.setRegion('north'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RegionButton(
                    label: 'الجنوب · 413',
                    active: current == 'south',
                    onTap: () => cart.setRegion('south'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _RegionButton extends StatelessWidget {
  const _RegionButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? _purple : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? _purple : _border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? Colors.white : _purple,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _QuoteSummary extends StatelessWidget {
  const _QuoteSummary({required this.cart});

  final CartCounter cart;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final CartQuote? q = cart.quote.value;

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _purpleLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: q == null
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(color: _purple),
              )
            : Column(
                children: <Widget>[
                  _row('📦 عدد الأسطر', '${q.linesCount}'),
                  const SizedBox(height: 8),
                  _row('🔢 عدد القطع', '${q.unitsCount}'),
                  const Divider(height: 20),
                  _row(
                    'إجمالي المنتجات',
                    'SAR ${(q.itemsSubtotalLocal / q.exchangeRate).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _row(
                    'رسوم الخدمة',
                    'SAR ${(q.serviceFeeLocal / q.exchangeRate).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _row(
                    'الشحن',
                    'SAR ${(q.shippingLocal / q.exchangeRate).toStringAsFixed(2)}',
                  ),
                  const Divider(height: 20),
                  _row(
                    'سعر الصرف',
                    'YER / SAR ${q.exchangeRate.toStringAsFixed(0)}',
                  ),
                  const SizedBox(height: 8),
                  _row(
                    'الإجمالي بالريال اليمني',
                    '${q.grandTotalLocal.toStringAsFixed(0)} ر.ي',
                    emphasize: true,
                  ),
                ],
              ),
      );
    });
  }

  Widget _row(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasize ? _purple : const Color(0xFF374151),
              fontWeight:
                  emphasize ? FontWeight.w900 : FontWeight.w500,
              fontSize: emphasize ? 15 : 13,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: emphasize ? _purple : const Color(0xFF374151),
            fontWeight:
                emphasize ? FontWeight.w900 : FontWeight.w600,
            fontSize: emphasize ? 15 : 13,
          ),
        ),
      ],
    );
  }
}

class _CheckoutButton extends StatelessWidget {
  const _CheckoutButton({required this.cart});

  final CartCounter cart;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool enabled =
          cart.quote.value != null && cart.items.isNotEmpty;

      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed:
              enabled ? () => Get.toNamed('/checkoutScreen') : null,
          style: FilledButton.styleFrom(
            backgroundColor: _purple,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'الانتقال لتأكيد الطلب',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      );
    });
  }
}

class _ContactBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _purpleLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: <Widget>[
          Text(
            '📞 للتواصل معنا',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _purple,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'الأساسي: $_primaryPhone',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'البديل: $_backupPhone',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: _purple,
          ),
          const SizedBox(height: 12),
          const Text('سلتك فارغة. تصفّح SHEIN وأضف ما يعجبك.'),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _purple),
            onPressed: () => Get.offNamed('/shein'),
            child: const Text('تصفّح SHEIN'),
          ),
        ],
      ),
    );
  }
}
