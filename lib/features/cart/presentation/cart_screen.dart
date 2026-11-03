import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/seloo_config.dart';
import '../../shein/application/shein_cart_importer.dart';
import '../application/cart_counter.dart';
import '../data/seloo_cart_link.dart';
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
  final TextEditingController _shareCartController = TextEditingController();
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _cart.refreshQuote();
  }

  Future<void> _run(Future<String?> Function() action) async {
    final String? error = await action();
    if (!mounted) return;
    if (error != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  void _browseProduct(CartItem item) {
    final String browseUrl = item.goodsId.isNotEmpty ? 'https://m.shein.com/ar/pdsearch/${item.goodsId}/' : item.sourceUrl;
    if (browseUrl.isEmpty) return;
    Get.toNamed('/shein', arguments: <String, dynamic>{'editUrl': browseUrl});
  }

  Future<void> _importSharedCart() async {
    if (_importing) return;
    final String text = _shareCartController.text.trim();
    if (text.isEmpty) { _snack('الصق الرابط أولاً'); return; }
    setState(() => _importing = true);
    try {
      final result = await SheinCartImporter().importSharedCart(text);
      if (!mounted) return;
      setState(() => _importing = false);
      if (!result.success) {
        _snack(result.message);
        await Get.toNamed('/shein', arguments: {'shareCartUrl': text});
        return;
      }
      _shareCartController.clear();
      await _cart.refreshQuote();
      _snack(result.message);
    } catch (_) { if (mounted) setState(() => _importing = false); }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Obx(() {
            if (_cart.items.isEmpty) {
              return Column(children: [
                _Header(count: 0, onRefresh: _cart.refreshQuote),
                const SizedBox(height: 8),
                _importBox(),
                const Expanded(child: Center(child: Text('السلة فارغة'))),
              ]);
            }
            return Column(
              children: <Widget>[
                _Header(count: _cart.items.length, onRefresh: _cart.refreshQuote),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: <Widget>[
                      // ⭐ القائمة المنسدلة للعملة في الأعلى
                      _CurrencyDropdown(cart: _cart),
                      const SizedBox(height: 10),
                      _importBox(),
                      const SizedBox(height: 10),
                      ..._cart.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CartLineTile(
                          item: item, cart: _cart,
                          onQuantity: (v) => _run(() => _cart.updateQuantity(item, v)),
                          onRemove: () => _run(() => _cart.remove(item)),
                          onEdit: () => _cart.startEditing(item),
                          onBrowse: () => _browseProduct(item),
                        ),
                      )),
                      const SizedBox(height: 10),
                      _QuoteSummary(cart: _cart),
                      const SizedBox(height: 10),
                      SizedBox(width: double.infinity, child: OutlinedButton.icon(
                        onPressed: _openCommissionCalculator,
                        icon: const Icon(Icons.calculate, color: _purple),
                        label: const Text('آلة حساب عمولة المندوب', style: TextStyle(color: _purple, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                      )),
                      const SizedBox(height: 10),
                      SizedBox(width: double.infinity, child: FilledButton.icon(
                        onPressed: _shareCartToWhatsApp,
                        icon: const Icon(Icons.share),
                        label: const Text('مشاركة السلة عبر واتساب'),
                        style: FilledButton.styleFrom(backgroundColor: _green, padding: const EdgeInsets.symmetric(vertical: 13)),
                      )),
                      const SizedBox(height: 10),
                      _CheckoutButton(cart: _cart),
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

  Widget _importBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _purpleLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: _orange.withOpacity(0.5))),
      child: Column(
        children: <Widget>[
          const Text('استيراد سلة شي ان', style: TextStyle(fontWeight: FontWeight.bold, color: _orange)),
          const SizedBox(height: 8),
          TextField(controller: _shareCartController, decoration: const InputDecoration(hintText: 'الصق رابط السلة هنا', border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _importing ? null : _importSharedCart, style: FilledButton.styleFrom(backgroundColor: _orange), child: _importing ? const CircularProgressIndicator(color: Colors.white) : const Text('بدء الاستيراد'))),
        ],
      ),
    );
  }

  Future<void> _shareCartToWhatsApp() async {
    if (_cart.items.isEmpty) return;
    await _cart.refreshQuote();
    final q = _cart.quote.value;
    if (q == null) return;
    final b = StringBuffer();
    b.writeln('🛍️ طلب جديد من يمن سيلو');
    for (int i = 0; i < _cart.items.length; i++) {
      final it = _cart.items[i];
      b.writeln('${i + 1}. ${it.title} | الكمية: ${it.quantity} | السعر: ${it.sourcePrice} SAR');
      if (it.color.isNotEmpty) b.writeln('   اللون: ${it.color}');
      if (it.size.isNotEmpty) b.writeln('   المقاس: ${it.size}');
    }
    b.writeln('---');
    b.writeln('عدد الأسطر: ${q.linesCount} | القطع: ${q.unitsCount}');
    b.writeln('سعر الصرف: ${q.exchangeRate}');
    b.writeln('الإجمالي بالريال اليمني: ${q.grandTotalLocal.toStringAsFixed(0)}');
    b.writeln(SelooCartLink.webLink(_cart.items));
    final uri = Uri.parse('https://wa.me/$_primaryWhatsApp?text=${Uri.encodeComponent(b.toString())}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openCommissionCalculator() async {
    if (_cart.items.isEmpty) return;
    final ctrl = TextEditingController(text: _cart.commissionPerPiece.value.toStringAsFixed(2));
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true,
      builder: (_) => Directionality(textDirection: TextDirection.rtl, child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('حاسبة العمولة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _purple)),
          const SizedBox(height: 10),
          TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'العمولة لكل قطعة (SAR)', border: OutlineInputBorder()), onChanged: (v) => _cart.setCommission(double.tryParse(v) ?? 0)),
          const SizedBox(height: 16),
          Obx(() => Text('الإجمالي: ${_cart.commissionTotalSar.toStringAsFixed(2)} SAR / ${_cart.commissionTotalYer.toStringAsFixed(0)} ريال', style: const TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ]),
      )),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count, required this.onRefresh});
  final int count;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(12), child: Row(children: [
      const Icon(Icons.shopping_cart, color: _purple), const SizedBox(width: 8), Text('$count منتج', style: const TextStyle(fontWeight: FontWeight.bold)),
      const Spacer(), IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh, color: _purple)),
    ]));
  }
}

// ⭐ القائمة المنسدلة للعملة (سعودي، شمال، جنوب)
class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown({required this.cart});
  final CartCounter cart;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      String currentVal = cart.region.value;
      // التأكد من أن القيمة موجودة في القائمة
      if (!['saudi', 'north', 'south'].contains(currentVal)) {
        currentVal = 'north';
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: _purpleLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _purple, width: 1.5),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: currentVal,
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down, color: _purple),
            style: const TextStyle(fontWeight: FontWeight.bold, color: _purple, fontSize: 15),
            items: const [
              DropdownMenuItem(
                value: 'saudi',
                child: Text('🇸🇦 ريال سعودي (SAR)'),
              ),
              DropdownMenuItem(
                value: 'north',
                child: Text('🇾🇪 ريال يمني - شمال (140)'),
              ),
              DropdownMenuItem(
                value: 'south',
                child: Text('🇾🇪 ريال يمني - جنوب (413)'),
              ),
            ],
            onChanged: (String? val) {
              if (val != null) {
                cart.setRegion(val);
              }
            },
          ),
        ),
      );
    });
  }
}

// ⭐ السعر يتحدث فوراً مع كل تغيير
class _CartLineTile extends StatelessWidget {
  const _CartLineTile({required this.item, required this.cart, required this.onQuantity, required this.onRemove, required this.onEdit, required this.onBrowse});
  final CartItem item; final CartCounter cart;
  final ValueChanged<int> onQuantity; final VoidCallback onRemove; final VoidCallback onEdit; final VoidCallback onBrowse;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(children: [
        Row(children: [
          GestureDetector(onTap: onBrowse, child: SizedBox(width: 76, height: 76, child: _ProductImage(url: item.imageUrl))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline, color: Colors.red)),
              const Spacer(),
              Obx(() {
                final double rate = cart.region.value == 'south' ? 413.0 : (cart.region.value == 'saudi' ? 1.0 : 140.0);
                final double localPrice = item.sourcePrice * rate;
                final String curSymbol = cart.region.value == 'saudi' ? 'SAR' : 'ر.ي';
                return Text('${localPrice.toStringAsFixed(0)} $curSymbol', style: const TextStyle(color: _purple, fontWeight: FontWeight.bold, fontSize: 14));
              }),
            ]),
            Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
            Wrap(spacing: 4, children: [
              if (item.color.isNotEmpty) Chip(label: Text(item.color)),
              if (item.size.isNotEmpty) Chip(label: Text(item.size)),
            ]),
          ])),
        ]),
        Row(children: [
          IconButton(onPressed: () => onQuantity(item.quantity - 1), icon: const Icon(Icons.remove)),
          Text('${item.quantity}'),
          IconButton(onPressed: () => onQuantity(item.quantity + 1), icon: const Icon(Icons.add)),
          const Spacer(),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit, color: _orange)),
        ]),
      ]),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return Container(color: _purpleLight, child: const Icon(Icons.image));
    return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (_,__,___) => Container(color: _purpleLight, child: const Icon(Icons.image)));
  }
}

class _QuoteSummary extends StatelessWidget {
  const _QuoteSummary({required this.cart});
  final CartCounter cart;
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final q = cart.quote.value;
      if (q == null) return const SizedBox();
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _purpleLight, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Text('عدد الأسطر: ${q.linesCount} | عدد القطع: ${q.unitsCount}'),
          const Divider(),
          Text('الإجمالي: ${q.grandTotalLocal.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _purple)),
        ]),
      );
    });
  }
}

class _CheckoutButton extends StatelessWidget {
  const _CheckoutButton({required this.cart});
  final CartCounter cart;
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Get.toNamed('/checkoutScreen'), child: const Text('تأكيد الطلب')));
  }
}
