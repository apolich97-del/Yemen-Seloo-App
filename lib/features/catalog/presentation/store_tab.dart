import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/settings_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../cart/data/seloo_cart_service.dart';
import '../../cart/domain/cart_item.dart';
import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';

/// كتالوج يمن سيلو للعملاء: تصنيفات، بحث، ألوان ومقاسات، وأسعار حسب العملة.
class StoreTab extends StatefulWidget {
  const StoreTab({super.key});

  @override
  State<StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<StoreTab> {
  final _repo = Get.put(CatalogRepository(), permanent: false);
  final _cart = SelooCartService();
  final _settings = Get.isRegistered<SettingsService>()
      ? Get.find<SettingsService>()
      : null;

  final _search = TextEditingController();
  String _category = 'الكل';
  String _region = 'south';

  double get _rateSouth => _settings?.settings.value.rateSouth ?? 413;
  double get _rateNorth => _settings?.settings.value.rateNorth ?? 140;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CatalogItem>>(
      stream: _repo.activeItems(),
      builder: (context, snap) {
        final all = snap.data ?? const <CatalogItem>[];
        final cats = <String>{
          'الكل',
          ...all.map((e) => e.category.isEmpty ? 'عام' : e.category),
        }.toList();
        final q = _search.text.trim();
        final list = all.where((e) {
          final okCat = _category == 'الكل' || e.category == _category;
          final okQ = q.isEmpty ||
              e.title.contains(q) ||
              e.category.contains(q) ||
              e.goodsId.contains(q);
          return okCat && okQ;
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _regionBar(),
            const SizedBox(height: 10),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ابحث في كتالوج يمن سيلو…',
                prefixIcon: Icon(Icons.search, size: 18, color: T.muted),
                filled: true,
                fillColor: T.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: T.border),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: cats
                    .map((c) => Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            label: Text(c,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: _category == c
                                        ? Colors.white
                                        : T.text)),
                            selected: _category == c,
                            selectedColor: T.primary,
                            backgroundColor: T.card,
                            side: BorderSide(color: T.border),
                            onSelected: (_) =>
                                setState(() => _category = c),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                    child: Text('لا توجد قطع منشورة بعد',
                        style: TextStyle(fontSize: 12, color: T.muted))),
              )
            else
              ...list.map(_card),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _pill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: T.soft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: T.softBorder),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 9.5, color: T.text)),
      );

  static String _thousands(String digits) {
    final clean = digits.replaceAll(RegExp(r'[^0-9.]'), '');
    final parts = clean.split('.');
    final buf = StringBuffer();
    final intPart = parts.first;
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    return parts.length > 1 ? '$buf.${parts[1]}' : '$buf';
  }

  Widget _regionBar() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: T.soft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: T.softBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.public, size: 15, color: T.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text('عملة العرض',
                  style: TextStyle(fontSize: 10.5, color: T.text)),
            ),
            Wrap(
              spacing: 6,
              children: const [
                _RegionChip(key: 'south', label: 'جنوب'),
                _RegionChip(key: 'north', label: 'شمال'),
                _RegionChip(key: 'sar', label: 'سعودي'),
              ]
                  .map((c) => ChoiceChip(
                        label: Text(c.label,
                            style: TextStyle(
                                fontSize: 10.5,
                                color: _region == c.key
                                    ? Colors.white
                                    : T.text)),
                        selected: _region == c.key,
                        selectedColor: T.primary,
                        backgroundColor: T.card,
                        side: BorderSide(color: T.border),
                        onSelected: (_) => setState(() => _region = c.key),
                      ))
                  .toList(),
            ),
          ],
        ),
      );

  Widget _card(CatalogItem it) {
    final price = it.priceIn(_region,
        rateSouth: _rateSouth, rateNorth: _rateNorth);
    final cur = it.currencyLabel(_region);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: it.imageUrl.isEmpty
                    ? Container(
                        height: 170,
                        width: double.infinity,
                        color: T.soft,
                        child: Icon(Icons.image_outlined,
                            size: 30, color: T.muted))
                    : Image.network(it.imageUrl,
                        height: 170,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                              height: 170,
                              width: double.infinity,
                              color: T.soft,
                              child: Icon(Icons.broken_image_outlined,
                                  size: 30, color: T.muted),
                            )),
              ),
              if (it.badgeAr.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(it.badgeAr,
                        style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF3B2A00))),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.title.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: T.text)),
                const SizedBox(height: 4),
                Text('${_thousands(price.toStringAsFixed(0))} $cur',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: T.primary)),
                if (it.colors.isNotEmpty || it.sizes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      ...it.colors
                          .where((e) => e.trim().isNotEmpty)
                          .take(6)
                          .map((e) => _pill('لون: ${e.trim()}')),
                      ...it.sizes
                          .where((e) => e.trim().isNotEmpty)
                          .take(6)
                          .map((e) => _pill('مقاس: ${e.trim()}')),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _addToCart(it, price, cur),
                        icon: const Icon(Icons.add_shopping_cart, size: 16),
                        label: const Text('أضف إلى السلة',
                            style: TextStyle(fontSize: 11.5)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'مشاركة القطعة',
                      icon: Icon(Icons.share_outlined,
                          size: 18, color: T.primary),
                      onPressed: () => Share.share(
                        '${it.title}\n'
                        '${it.priceSar.toStringAsFixed(2)} ر.س — يمن سيلو\n'
                        '${it.sourceUrl}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart(CatalogItem it, double price, String cur) async {
    final items = _cart.loadItems();
    final rate = _region == 'south'
        ? _rateSouth
        : _region == 'north'
            ? _rateNorth
            : 1.0;
    items.add(CartItem(
      lineId: 'cat-${it.id}-${DateTime.now().millisecondsSinceEpoch}',
      goodsId: it.goodsId.isEmpty ? it.id : it.goodsId,
      title: it.title,
      imageUrl: it.imageUrl,
      sourceUrl: it.sourceUrl,
      sourcePrice: it.priceSar,
      sourceCurrency: 'SAR',
      exchangeRate: rate,
      quantity: 1,
      color: it.colors.isNotEmpty ? it.colors.first : '',
      size: it.sizes.isNotEmpty ? it.sizes.first : '',
      sourceStore: 'يمن سيلو',
    ));
    await _cart.saveItems(items);
    Get.snackbar('أُضيفت للسلة', '${it.title} · ${price.toStringAsFixed(0)} $cur');
  }
}

class _RegionChip {
  const _RegionChip({required this.key, required this.label});
  final String key;
  final String label;
}
