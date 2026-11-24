import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/settings_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../cart/data/seloo_cart_service.dart';
import '../../cart/domain/cart_item.dart';
import '../../shein/data/shein_product_scraper.dart';
import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';

/// استوديو المسوّق: استيراد قطع SHEIN، تسعير تلقائي حسب المنطقة، نشر وإيقاف.
class CatalogStudioTab extends StatefulWidget {
  const CatalogStudioTab({super.key});

  @override
  State<CatalogStudioTab> createState() => _CatalogStudioTabState();
}

class _CatalogStudioTabState extends State<CatalogStudioTab> {
  final _repo = Get.put(CatalogRepository(), permanent: false);
  final _settings = Get.isRegistered<SettingsService>()
      ? Get.find<SettingsService>()
      : null;

  double get _rateSouth => _settings?.settings.value.rateSouth ?? 413;
  double get _rateNorth => _settings?.settings.value.rateNorth ?? 140;

  Widget _catThumb(String src, double w, double h) {
    if (src.isEmpty) {
      return Container(
          width: w, height: h, color: T.soft,
          child: Icon(Icons.image_outlined, size: 20, color: T.muted));
    }
    if (src.startsWith('data:')) {
      try {
        final b64 = src.substring(src.indexOf(',') + 1);
        return Image.memory(base64Decode(b64), width: w, height: h, fit: BoxFit.cover);
      } catch (_) {}
    }
    return Image.network(src, width: w, height: h, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
            width: w, height: h, color: T.soft,
            child: Icon(Icons.broken_image_outlined, size: 20, color: T.muted)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استوديو كتالوج يمن سيلو'),
        actions: [
          IconButton(
            tooltip: 'استيراد قطعة',
            icon: Icon(Icons.add_link, color: T.primary),
            onPressed: () => _openEditor(null),
          ),
        ],
      ),
      body: StreamBuilder<List<CatalogItem>>(
        stream: _repo.allItems(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
                child: Text('تعذر تحميل الكتالوج\n${snap.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: T.muted)));
          }
          final items = snap.data ?? const <CatalogItem>[];
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _ratesBar(),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openEditor(null),
                  icon: const Icon(Icons.content_paste_go, size: 18),
                  label: const Text('استيراد قطعة من SHEIN'),
                ),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                      child: Text('الكتالوج فارغ — ابدأ باستيراد قطعة',
                          style:
                              TextStyle(fontSize: 12, color: T.muted))),
                )
              else
                ...items.map(_row),
            ],
          );
        },
      ),
    );
  }

  Widget _ratesBar() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: T.soft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: T.softBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.currency_exchange, size: 15, color: T.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'أسعار الصرف النشطة: جنوب ${_rateSouth.toStringAsFixed(0)} · '
                'شمال ${_rateNorth.toStringAsFixed(0)} ر.ي لكل ريال سعودي',
                style: TextStyle(fontSize: 10.5, height: 1.5, color: T.text),
              ),
            ),
          ],
        ),
      );

  Widget _row(CatalogItem it) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: T.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _catThumb(it.imageUrl, 58, 58),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.title.isEmpty ? 'قطعة بدون عنوان' : it.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: T.text)),
                  const SizedBox(height: 3),
                  Text(
                    '${it.priceSar.toStringAsFixed(2)} ر.س · ${it.regionAr} · '
                    '${it.active ? 'منشور' : 'موقوف'}',
                    style: TextStyle(fontSize: 10.5, color: T.muted),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: T.muted),
              onSelected: (v) async {
                if (v == 'edit') {
                  await _openEditor(it);
                } else if (v == 'toggle') {
                  await _repo.setActive(it.id, !it.active);
                } else if (v == 'delete') {
                  await _repo.remove(it.id);
                  Get.snackbar('تم الحذف', 'أُزيلت القطعة من الكتالوج');
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                PopupMenuItem(
                    value: 'toggle',
                    child: Text(it.active ? 'إيقاف مؤقت' : 'تفعيل ونشر')),
                const PopupMenuItem(value: 'delete', child: Text('حذف')),
              ],
            ),
          ],
        ),
      );

  Future<void> _openEditor(CatalogItem? existing) async {
    final link = TextEditingController(text: existing?.sourceUrl ?? '');
    final title = TextEditingController(text: existing?.title ?? '');
    final image = TextEditingController(text: existing?.imageUrl ?? '');
    final category = TextEditingController(text: existing?.category ?? 'نساء');
    final colors =
        TextEditingController(text: existing?.colors.join(', ') ?? '');
    final sizes = TextEditingController(text: existing?.sizes.join(', ') ?? '');
    final base = TextEditingController(
        text: (existing?.basePriceSar ?? 0).toStringAsFixed(2));
    final margin = TextEditingController(
        text: (existing?.marginSar ?? 0).toStringAsFixed(2));
    var region = existing?.region ?? 'south';
    var badge = existing?.badge ?? '';
    var scraping = false;
    final List<CartItem> cartItems = SelooCartService().loadItems();

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text(existing == null ? 'استيراد قطعة' : 'تعديل القطعة',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: 460,
          child: StatefulBuilder(
            builder: (context, setLocal) {
              final priceSar =
                  (double.tryParse(base.text) ?? 0) + (double.tryParse(margin.text) ?? 0);

              Future<void> runScrape() async {
                final raw = link.text.trim();
                if (raw.isEmpty || scraping) return;
                setLocal(() => scraping = true);
                try {
                  final scraped = await SheinProductScraper.fetchFromInput(raw);
                  if (scraped != null) {
                    link.text = scraped.productUrl;
                    if (scraped.title.isNotEmpty) title.text = scraped.title;
                    if (scraped.imageUrl.isNotEmpty) image.text = scraped.imageUrl;
                    if (scraped.priceSar > 0) base.text = scraped.priceSar.toStringAsFixed(2);
                    if (colors.text.trim().isEmpty && scraped.colors.isNotEmpty) {
                      colors.text = scraped.colors.join(', ');
                    }
                    if (sizes.text.trim().isEmpty && scraped.sizes.isNotEmpty) {
                      sizes.text = scraped.sizes.join(', ');
                    }
                    Get.snackbar('تم الجلب ✓', 'جُلبت بيانات القطعة من شي إن بنجاح');
                  } else {
                    Get.snackbar('تعذر الجلب التلقائي',
                        'أضف القطعة إلى السلة ثم اخترها من السلة أو ارفع صورتها يدوياً');
                  }
                } catch (_) {
                  Get.snackbar('تعذر الجلب', 'تحقق من الرابط أو استورد من السلة');
                } finally {
                  setLocal(() => scraping = false);
                }
              }

              Future<void> pickPhoto() async {
                final x = await ImagePicker().pickImage(
                    source: ImageSource.gallery, imageQuality: 45, maxWidth: 800, maxHeight: 800);
                if (x == null) return;
                final bytes = await x.readAsBytes();
                final mime = x.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
                image.text = 'data:$mime;base64,${base64Encode(bytes)}';
                setLocal(() {});
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (cartItems.isNotEmpty) ...[
                      Text('استيراد فوري من السلة الحالية (${cartItems.length})',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: T.primary)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: cartItems.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (_, idx) {
                            final ci = cartItems[idx];
                            return ActionChip(
                              label: Text(
                                ci.title.length > 22 ? '${ci.title.substring(0, 22)}…' : ci.title,
                                style: const TextStyle(fontSize: 10.5),
                              ),
                              onPressed: () {
                                link.text = ci.sourceUrl.isNotEmpty
                                    ? ci.sourceUrl
                                    : 'https://ar.shein.com/-p-${ci.goodsId}.html';
                                title.text = ci.title;
                                image.text = ci.imageUrl;
                                base.text = ci.sourcePrice.toStringAsFixed(2);
                                if (ci.color.isNotEmpty) colors.text = ci.color;
                                if (ci.size.isNotEmpty) sizes.text = ci.size;
                                setLocal(() {});
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: link,
                            textDirection: TextDirection.ltr,
                            decoration: const InputDecoration(
                                labelText: 'رابط أو كود منتج SHEIN', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 6),
                        FilledButton.icon(
                          onPressed: scraping ? null : runScrape,
                          icon: scraping
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.auto_fix_high, size: 15),
                          label: const Text('جلب', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(
                          labelText: 'العنوان', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: image,
                            textDirection: TextDirection.ltr,
                            onChanged: (_) => setLocal(() {}),
                            decoration: const InputDecoration(
                                labelText: 'رابط الصورة أو مرفوعة', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          onPressed: pickPhoto,
                          icon: const Icon(Icons.photo_library_outlined, size: 15),
                          label: const Text('صورة', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                    if (image.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _catThumb(image.text.trim(), 70, 70),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: category,
                            decoration: const InputDecoration(
                                labelText: 'التصنيف', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: colors,
                            decoration: const InputDecoration(
                                labelText: 'الألوان (بفاصلة)', isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: sizes,
                      decoration: const InputDecoration(
                          labelText: 'المقاسات (بفاصلة)', isDense: true),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: base,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'السعر الأساسي (ر.س)', isDense: true),
                            onChanged: (_) => setLocal(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: margin,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'هامش الربح (ر.س)', isDense: true),
                            onChanged: (_) => setLocal(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: region,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'منطقة التسعير', isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'south', child: Text('جنوب')),
                        DropdownMenuItem(value: 'north', child: Text('شمال')),
                        DropdownMenuItem(value: 'sar', child: Text('سعودي')),
                      ],
                      onChanged: (v) => setLocal(() => region = v ?? region),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: badge,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'شارة ترويجية (اختياري)', isDense: true),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('بدون')),
                        DropdownMenuItem(value: 'new', child: Text('وصل حديثاً')),
                        DropdownMenuItem(value: 'best', child: Text('الأكثر مبيعاً')),
                        DropdownMenuItem(value: 'offer', child: Text('عرض خاص')),
                      ],
                      onChanged: (v) => setLocal(() => badge = v ?? ''),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: T.soft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: T.softBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('معاينة الأسعار الثلاثة',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: T.primary)),
                          const SizedBox(height: 6),
                          Text(
                            'جنوب: ${(priceSar * _rateSouth).toStringAsFixed(0)} ر.ي'
                            ' · شمال: ${(priceSar * _rateNorth).toStringAsFixed(0)} ر.ي'
                            ' · سعودي: ${priceSar.toStringAsFixed(2)} ر.س',
                            style: TextStyle(
                                fontSize: 11, height: 1.5, color: T.text),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Get.back(result: true),
              child: Text(existing == null ? 'نشر' : 'حفظ')),
        ],
      ),
    );
    if (ok != true) return;

    final goodsId = CatalogItem.extractGoodsId(link.text);
    if (goodsId.isEmpty && existing == null) {
      Get.snackbar('رابط غير صحيح', 'ألصق رابط SHEIN أو كود المنتج الرقمي');
      return;
    }
    final item = CatalogItem(
      id: existing?.id ?? '',
      title: title.text.trim(),
      goodsId: goodsId.isEmpty ? (existing?.goodsId ?? '') : goodsId,
      sourceUrl: link.text.trim(),
      imageUrl: image.text.trim(),
      category: category.text.trim().isEmpty ? 'عام' : category.text.trim(),
      colors: colors.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      sizes: sizes.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      basePriceSar: double.tryParse(base.text) ?? 0,
      marginSar: double.tryParse(margin.text) ?? 0,
      region: region,
      badge: badge,
      active: existing?.active ?? true,
      createdAt: existing?.createdAt,
    );
    try {
      if (existing == null) {
        await _repo.create(item);
        Get.snackbar('تم النشر', 'أُضيفت القطعة إلى كتالوج يمن سيلو');
      } else {
        await _repo.update(item);
        Get.snackbar('تم الحفظ', 'حُدّثت القطعة');
      }
    } catch (e) {
      Get.snackbar('تعذر الحفظ', '$e');
    }
  }
}
