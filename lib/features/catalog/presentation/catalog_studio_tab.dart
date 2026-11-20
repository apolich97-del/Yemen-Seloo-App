import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/settings_service.dart';
import '../../../core/theme/app_theme.dart';
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
              child: it.imageUrl.isEmpty
                  ? Container(
                      width: 58,
                      height: 58,
                      color: T.soft,
                      child: Icon(Icons.image_outlined,
                          size: 20, color: T.muted))
                  : Image.network(it.imageUrl,
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                            width: 58,
                            height: 58,
                            color: T.soft,
                            child: Icon(Icons.broken_image_outlined,
                                size: 20, color: T.muted),
                          )),
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
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: link,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                          labelText: 'رابط أو كود منتج SHEIN', isDense: true),
                      onChanged: (v) {
                        final id = CatalogItem.extractGoodsId(v);
                        if (id.isNotEmpty) {
                          if (title.text.trim().isEmpty) {
                            title.text = 'قطعة SHEIN $id';
                          }
                          if (image.text.trim().isEmpty) {
                            image.text = CatalogItem.imageFromGoodsId(id);
                          }
                          setLocal(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(
                          labelText: 'العنوان', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: image,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                          labelText: 'رابط الصورة', isDense: true),
                    ),
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
