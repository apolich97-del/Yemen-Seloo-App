import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/seloo_config.dart';
import '../application/cart_counter.dart';
import '../domain/cart_item.dart';

const Color _purple = Color(0xFF7C3AED);
const Color _purpleLight = Color(0xFFFAF7FF);
const Color _border = Color(0xFFE9D5FF);

const String _orderWhatsApp = '967775727928';
const String _supportWhatsApp = '967737383637';

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

  Future<void> _shareCartToWhatsApp(String phone) async {
    if (_cart.items.isEmpty) {
      _snack('السلة فارغة');
      return;
    }
    final CartQuote? q = _cart.quote.value;
    if (q == null) {
      _snack('جارٍ حساب الإجمالي، حاول مرة أخرى.');
      return;
    }

    final StringBuffer b = StringBuffer();
    b.writeln('🛍️ *طلب جديد من يمن سيلو*');
    b.writeln('');
    b.writeln('━━━━━━━━━━━━━━');
    b.writeln('');

    for (int i = 0; i < _cart.items.length; i++) {
      final CartItem item = _cart.items[i];
      b.writeln('${i + 1}. ${item.title}');
      if (item.color.isNotEmpty) b.writeln('اللون: ${item.color}');
      if (item.size.isNotEmpty) b.writeln('المقاس: ${item.size}');
      b.writeln('الكمية: ${item.quantity}');
      b.writeln('السعر: ${item.sourcePrice.toStringAsFixed(2)} SAR');
      if (item.goodsId.isNotEmpty) b.writeln('رقم المنتج: ${item.goodsId}');
      if (item.sourceUrl.isNotEmpty) b.writeln('رابط SHEIN: ${item.sourceUrl}');
      b.writeln('');
    }

    b.writeln('━━━━━━━━━━━━━━');

    final double subtotalSar = q.itemsSubtotalLocal / q.exchangeRate;
    final double serviceFeeSar = q.serviceFeeLocal / q.exchangeRate;
    final double shippingSar = q.shippingLocal / q.exchangeRate;
    final double grandTotalSar = q.grandTotalLocal / q.exchangeRate;

    b.writeln('💵 قيمة المنتجات: ${subtotalSar.toStringAsFixed(2)} SAR');
    b.writeln('🛠️ رسوم الخدمة: ${serviceFeeSar.toStringAsFixed(2)} SAR');
    b.writeln('🚚 الشحن: ${shippingSar.toStringAsFixed(2)} SAR');
    b.writeln('━━━━━━━━━━━━━━');
    b.writeln('💰 الإجمالي: ${grandTotalSar.toStringAsFixed(2)} SAR');
    b.writeln('🇾🇪 بالريال اليمني: ${q.grandTotalLocal.toStringAsFixed(0)} ريال');
    b.writeln('📊 سعر الصرف: ${q.exchangeRate.toStringAsFixed(0)}');
    final String regionName =
        _cart.region.value == 'south' ? 'الجنوب' : 'الشمال';
    b.writeln('📍 المنطقة: $regionName');
    b.writeln('');
    b.writeln('خدمتكم غايتنا وثقتكم هدفنا');

    final Uri url = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(b.toString())}',
    );
    try {
      final bool ok =
          await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok) _snack('تعذّر فتح الواتساب');
    } catch (e) {
      _snack('تعذّر فتح الواتساب: $e');
    }
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
            if (_cart.items.isEmpty) return const _EmptyCart();
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
                      _ShareButtons(
                        onOrderShare: () =>
                            _shareCartToWhatsApp(_orderWhatsApp),
                        onSupportShare: () =>
                            _shareCartToWhatsApp(_supportWhatsApp),
                        orderPhone: '775727928',
                        supportPhone: '737383637',
                      ),
                      const SizedBox(height: 12),
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

// ═══════════════════════════════════════════════════════════════
// الرأس
// ═══════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  const _Header({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
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
                child: const Icon(Icons.shopping_cart_outlined,
                    color: _purple, size: 22),
              ),
              if (count > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
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
                style: TextStyle(fontSize: 8, letterSpacing: 2, color: _purple),
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
            child: const Icon(Icons.storefront, color: _purple, size: 20),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// بطاقة المنتج مع الصورة
// ═══════════════════════════════════════════════════════════════
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
    final String variant = <String>[
      if (item.color.isNotEmpty) 'اللون: ${item.color}',
      if (item.size.isNotEmpty) item.size,
    ].join(' · ');

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
              // ⭐ الصورة
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: _ProductImage(url: item.imageUrl),
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
                          icon: const Icon(Icons.delete_outline,
                              color: Color(0xFFEF4444), size: 20),
                        ),
                        const Spacer(),
                        Text(
                          'SAR ${item.sourcePrice.toStringAsFixed(0)}',
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
                    if (variant.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          variant,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF6B7280),
                          ),
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
                enabled: item.quantity < SelooConfig.maxQuantityPerLine,
                onTap: () => onQuantity(item.quantity + 1),
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined,
                    color: Color(0xFFF97316), size: 20),
                tooltip: 'تعديل',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ⭐ ويدجت الصورة مع Fallback
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
            child: CircularProgressIndicator(strokeWidth: 2, color: _purple),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        color: _purpleLight,
        child: const Icon(Icons.image_outlined, color: _purple, size: 32),
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

// ═══════════════════════════════════════════════════════════════
// ⭐ خيارات المنطقة (أزرار واضحة)
// ═══════════════════════════════════════════════════════════════
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

// ═══════════════════════════════════════════════════════════════
// ملخص التسعير
// ═══════════════════════════════════════════════════════════════
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
                  _Row(
                    label: 'إجمالي المنتجات',
                    value:
                        'SAR ${(q.itemsSubtotalLocal / q.exchangeRate).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _Row(
                    label: 'رسوم الخدمة',
                    value:
                        'SAR ${(q.serviceFeeLocal / q.exchangeRate).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _Row(
                    label: 'الشحن',
                    value:
                        'SAR ${(q.shippingLocal / q.exchangeRate).toStringAsFixed(2)}',
                  ),
                  const Divider(height: 20),
                  _Row(
                    label: 'سعر الصرف',
                    value: 'YER / SAR ${q.exchangeRate.toStringAsFixed(0)}',
                  ),
                  const SizedBox(height: 8),
                  _Row(
                    label: 'الإجمالي بالريال اليمني',
                    value: '${q.grandTotalLocal.toStringAsFixed(0)} ر.ي',
                    emphasize: true,
                  ),
                ],
              ),
      );
    });
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: emphasize ? _purple : const Color(0xFF374151),
            fontWeight: emphasize ? FontWeight.w900 : FontWeight.w500,
            fontSize: emphasize ? 15 : 13,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: emphasize ? _purple : const Color(0xFF374151),
            fontWeight: emphasize ? FontWeight.w900 : FontWeight.w600,
            fontSize: emphasize ? 15 : 13,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// أزرار المشاركة
// ═══════════════════════════════════════════════════════════════
class _ShareButtons extends StatelessWidget {
  const _ShareButtons({
    required this.onOrderShare,
    required this.onSupportShare,
    required this.orderPhone,
    required this.supportPhone,
  });

  final VoidCallback onOrderShare;
  final VoidCallback onSupportShare;
  final String orderPhone;
  final String supportPhone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onSupportShare,
            style: OutlinedButton.styleFrom(
              foregroundColor: _purple,
              side: const BorderSide(color: _purple),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.share, size: 16),
            label: Text(
              'مشاركة $supportPhone',
              style: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: onOrderShare,
            style: FilledButton.styleFrom(
              backgroundColor: _purple,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.share, size: 16),
            label: Text(
              'مشاركة $orderPhone',
              style: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
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
      final bool enabled = cart.quote.value != null && cart.items.isNotEmpty;
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: enabled ? () => Get.toNamed('/checkoutScreen') : null,
          style: FilledButton.styleFrom(
            backgroundColor: _purple,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text(
            'الانتقال لتأكيد الطلب',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      );
    });
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
          const Icon(Icons.shopping_bag_outlined, size: 64, color: _purple),
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
