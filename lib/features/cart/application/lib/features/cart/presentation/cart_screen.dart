import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/seloo_config.dart';
import '../application/cart_counter.dart';
import '../domain/cart_item.dart';

/// شاشة سلة سيلو: سطور المنتجات + ملخّص التسعير من الخادم.
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

  void _openCheckout(BuildContext context) {
    Get.toNamed('/checkoutScreen');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        title: const Text('سلة يمن سيلو'),
        actions: <Widget>[
          Obx(
            () => TextButton(
              onPressed: _cart.items.isEmpty ? null : () => _run(_cart.clear),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('تفريغ'),
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (_cart.items.isEmpty) {
          return const _EmptyCart();
        }
        return Column(
          children: <Widget>[
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _cart.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int index) => _CartLineTile(
                  item: _cart.items[index],
                  onQuantity: (int value) =>
                      _run(() => _cart.updateQuantity(_cart.items[index], value)),
                  onRemove: () => _run(() => _cart.remove(_cart.items[index])),
                ),
              ),
            ),
            _QuoteSummary(cart: _cart),
          ],
        );
      }),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.item,
    required this.onQuantity,
    required this.onRemove,
  });

  final CartItem item;
  final ValueChanged<int> onQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final String variant = <String>[item.color, item.size]
        .where((String s) => s.isNotEmpty)
        .join(' • ');
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 72,
                height: 92,
                child: item.imageUrl.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFFE5E7EB),
                        child: Icon(Icons.image_not_supported_outlined),
                      )
                    : CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(item.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (variant.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(variant,
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    '${item.unitPriceLocal.toStringAsFixed(0)} ر.ي للوحدة',
                    style: const TextStyle(
                      color: Color(0xFF7C3AED),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${item.priceOriginal.toStringAsFixed(2)} ${item.currency} × صرف ${item.exchangeRate}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      _QuantityStepper(
                          quantity: item.quantity, onChanged: onQuantity),
                      const Spacer(),
                      IconButton(
                        tooltip: 'حذف',
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline,
                            color: Color(0xFF7C3AED)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$quantity',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        IconButton(
          onPressed: quantity < SelooConfig.maxQuantityPerLine
              ? () => onChanged(quantity + 1)
              : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class _QuoteSummary extends StatelessWidget {
  const _QuoteSummary({required this.cart});

  final CartCounter cart;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final CartQuote? quote = cart.quote.value;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFFFAF7FF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          children: <Widget>[
            if (quote == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(color: Color(0xFF7C3AED)),
              )
            else ...<Widget>[
              _Row(label: 'قيمة المنتجات', value: quote.itemsSubtotalLocal),
              _Row(label: 'رسوم الخدمة', value: quote.serviceFeeLocal),
              _Row(label: 'الشحن', value: quote.shippingLocal),
              if (quote.discountLocal > 0)
                _Row(label: 'الخصم', value: -quote.discountLocal),
              const Divider(),
              _Row(
                  label: 'الإجمالي',
                  value: quote.grandTotalLocal,
                  emphasize: true),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: quote == null || cart.items.isEmpty
                    ? null
                    : () => Get.toNamed('/checkoutScreen'),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('متابعة الطلب',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              SelooConfig.priceDisclaimer,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    });
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.emphasize = false});

  final String label;
  final double value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = emphasize
        ? const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF7C3AED),
          )
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Text(label, style: style),
          const Spacer(),
          Text('${value.toStringAsFixed(0)} ر.ي', style: style),
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
          const Icon(Icons.shopping_bag_outlined,
              size: 64, color: Color(0xFF7C3AED)),
          const SizedBox(height: 12),
          const Text('سلتك فارغة. تصفّح SHEIN وأضف ما يعجبك.'),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED)),
            onPressed: () => Get.offNamed('/shein'),
            child: const Text('تصفّح SHEIN'),
          ),
        ],
      ),
    );
  }
}
