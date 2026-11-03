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
    if (text.isEmpty) return;
    setState(() => _importing = true);
    try {
      final result = await SheinCartImporter().importSharedCart(text);
      if (!mounted) return;
      setState(() => _importing = false);
      if (!result.success) { await Get.toNamed('/shein', arguments: {'shareCartUrl': text}); return; }
      _shareCartController.clear();
      await _cart.refreshQuote();
    } catch (_) { if (mounted) setState(() => _importing = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Obx(() {
            if (_cart.items.isEmpty) return const Center(child: Text('السلة فارغة'));
            return Column(
              children: <Widget>[
                _Header(count: _cart.items.length, onRefresh: _cart.refreshQuote),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: <Widget>[
                      _buildImportSheinCartButton(),
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
                      const SizedBox(height: 6),
                      _RegionSelector(cart: _cart),
                      const SizedBox(height: 10),
                      _QuoteSummary(cart: _cart),
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

  Widget _buildImportSheinCartButton() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _purpleLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: _orange.withOpacity(0.5))),
      child: Column(
        children: <Widget>[
          const Text('استيراد سلة شي ان', style: TextStyle(fontWeight: FontWeight.bold, color: _orange)),
          const SizedBox(height: 8),
          TextField(controller: _shareCartController, decoration: const InputDecoration(hintText: 'الصق رابط السلة هنا', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _importing ? null : _importSharedCart, child: const Text('بدء الاستيراد'))),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count, required this.onRefresh});
  final int count;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart, color: _purple),
          const SizedBox(width: 8),
          Text('$count منتج', style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh, color: _purple)),
        ],
      ),
    );
  }
}

// ⭐ تم لف السعر داخل Obx ليتحدث فورياً عند تغيير العملة
class _CartLineTile extends StatelessWidget {
  const _CartLineTile({required this.item, required this.cart, required this.onQuantity, required this.onRemove, required this.onEdit, required this.onBrowse});
  final CartItem item;
  final CartCounter cart;
  final ValueChanged<int> onQuantity;
  final VoidCallback onRemove;
  final VoidCallback onEdit;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              GestureDetector(onTap: onBrowse, child: SizedBox(width: 76, height: 76, child: _ProductImage(url: item.imageUrl))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: [
                        IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline, color: Colors.red)),
                        const Spacer(),
                        // ⭐ السعر داخل Obx ليتحدث فوراً
                        Obx(() {
                          final double rate = cart.region.value == 'south' ? 413.0 : (cart.region.value == 'saudi' ? 1.0 : 140.0);
                          final double localPrice = item.sourcePrice * rate;
                          final String curSymbol = cart.region.value == 'saudi' ? 'SAR' : 'ر.ي';
                          return Text('${localPrice.toStringAsFixed(0)} $curSymbol', style: const TextStyle(color: _purple, fontWeight: FontWeight.bold, fontSize: 14));
                        }),
                      ],
                    ),
                    Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(spacing: 4, children: [
                      if (item.color.isNotEmpty) Chip(label: Text(item.color), padding: EdgeInsets.zero),
                      if (item.size.isNotEmpty) Chip(label: Text(item.size), padding: EdgeInsets.zero),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(onPressed: () => onQuantity(item.quantity - 1), icon: const Icon(Icons.remove)),
              Text('${item.quantity}'),
              IconButton(onPressed: () => onQuantity(item.quantity + 1), icon: const Icon(Icons.add)),
              const Spacer(),
              IconButton(onPressed: onEdit, icon: const Icon(Icons.edit, color: _orange)),
            ],
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
    if (url.isEmpty) return Container(color: _purpleLight, child: const Icon(Icons.image));
    return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (_,__,___) => Container(color: _purpleLight, child: const Icon(Icons.image)));
  }
}

// ⭐ إضافة خيار الريال السعودي
class _RegionSelector extends StatelessWidget {
  const _RegionSelector({required this.cart});
  final CartCounter cart;
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final String current = cart.region.value;
      return Row(
        children: [
          Expanded(child: _RegionButton(label: 'شمال (140)', active: current == 'north', onTap: () => cart.setRegion('north'))),
          const SizedBox(width: 8),
          Expanded(child: _RegionButton(label: 'جنوب (413)', active: current == 'south', onTap: () => cart.setRegion('south'))),
          const SizedBox(width: 8),
          Expanded(child: _RegionButton(label: 'سعودي (1)', active: current == 'saudi', onTap: () => cart.setRegion('saudi'))),
        ],
      );
    });
  }
}

class _RegionButton extends StatelessWidget {
  const _RegionButton({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: active ? _purple : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _purple)),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: active ? Colors.white : _purple, fontWeight: FontWeight.bold)),
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
      final q = cart.quote.value;
      if (q == null) return const CircularProgressIndicator();
      return Column(
        children: [
          Text('الإجمالي: ${q.grandTotalLocal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _purple)),
        ],
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
