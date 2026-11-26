import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/refund_policy.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../cart/data/seloo_cart_service.dart';
import '../../cart/domain/cart_item.dart';
import '../../shein/data/shein_product_scraper.dart';
import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';

Widget _studioThumb(String src, double w, double h) {
  if (src.isEmpty) {
    return Container(
      width: w,
      height: h,
      color: T.soft,
      child: Icon(Icons.image_outlined, size: 20, color: T.muted),
    );
  }
  if (src.startsWith('data:')) {
    try {
      final b64 = src.substring(src.indexOf(',') + 1);
      return Image.memory(
        base64Decode(b64),
        width: w,
        height: h,
        fit: BoxFit.cover,
      );
    } catch (_) {}
  }
  return Image.network(
    src,
    width: w,
    height: h,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => Container(
      width: w,
      height: h,
      color: T.soft,
      child: Icon(Icons.broken_image_outlined, size: 20, color: T.muted),
    ),
  );
}

/// نافذة موحّدة لنشر أو تعديل قطعة في كتالوج يمن سيلو (من الاستوديو أو من متصفح شي إن).
Future<bool> openQuickCatalogPublish({
  CatalogItem? existing,
  CatalogItem? prefill,
}) async {
  final repo = Get.isRegistered<CatalogRepository>()
      ? Get.find<CatalogRepository>()
      : Get.put(CatalogRepository(), permanent: false);
  final settingsSvc =
      Get.isRegistered<SettingsService>() ? Get.find<SettingsService>() : null;
  final double rateSouth = settingsSvc?.settings.value.rateSouth ?? 413;
  final double rateNorth = settingsSvc?.settings.value.rateNorth ?? 140;

  final seed = existing ?? prefill;
  final link = TextEditingController(text: seed?.sourceUrl ?? '');
  final title = TextEditingController(text: seed?.title ?? '');
  final image = TextEditingController(text: seed?.imageUrl ?? '');
  final category = TextEditingController(
      text: (seed?.category ?? '').isEmpty ? 'نساء' : seed!.category);
  final colors = TextEditingController(text: seed?.colors.join(', ') ?? '');
  final sizes = TextEditingController(text: seed?.sizes.join(', ') ?? '');
  final base = TextEditingController(
      text: (seed?.basePriceSar ?? 0).toStringAsFixed(2));
  final margin = TextEditingController(
      text: (seed?.marginSar ?? 0).toStringAsFixed(2));
  final nonRefundReason =
      TextEditingController(text: seed?.nonRefundableReason ?? '');

  var region = seed?.region ?? 'south';
  var badge = seed?.badge ?? '';
  var nonRefundable = seed != null
      ? seed.isNonRefundable
      : SelooRefundPolicy.detectNonRefundable(title.text, category.text);
  var manualNonRefundOverride = existing != null;
  var scraping = false;
  final List<CartItem> cartItems = SelooCartService().loadItems();

  final ok = await Get.dialog<bool>(
    AlertDialog(
      title: Text(
        existing == null ? 'نشر قطعة في الكتالوج' : 'تعديل القطعة',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 460,
        child: StatefulBuilder(
          builder: (context, setLocal) {
            final priceSar = (double.tryParse(base.text) ?? 0) +
                (double.tryParse(margin.text) ?? 0);

            void syncAutoRefundPolicy() {
              if (manualNonRefundOverride) return;
              nonRefundable = SelooRefundPolicy.detectNonRefundable(
                title.text,
                category.text,
              );
            }

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
                  if (scraped.priceSar > 0) {
                    base.text = scraped.priceSar.toStringAsFixed(2);
                  }
                  if (colors.text.trim().isEmpty && scraped.colors.isNotEmpty) {
                    colors.text = scraped.colors.join(', ');
                  }
                  if (sizes.text.trim().isEmpty && scraped.sizes.isNotEmpty) {
                    sizes.text = scraped.sizes.join(', ');
                  }
                  syncAutoRefundPolicy();
                  Get.snackbar('تم الجلب ✓', 'جُلبت بيانات القطعة من شي إن بنجاح');
                } else {
                  final shareTitle =
                      SheinProductScraper.extractShareTextTitle(raw);
                  final urlOnly = SheinProductScraper.extractFirstUrl(raw);
                  if (shareTitle.isNotEmpty && title.text.trim().isEmpty) {
                    title.text = shareTitle;
                  }
                  if (urlOnly.isNotEmpty) link.text = urlOnly;
                  syncAutoRefundPolicy();
                  Get.snackbar(
                    shareTitle.isNotEmpty
                        ? 'تم استخراج الوصف ✓'
                        : 'تعذر الجلب التلقائي',
                    shareTitle.isNotEmpty
                        ? 'أدخل السعر وأرفق الصورة أو اختر القطعة من السلة'
                        : 'أضف القطعة إلى السلة ثم اخترها من السلة أو ارفع صورتها يدوياً',
                  );
                }
              } catch (_) {
                Get.snackbar('تعذر الجلب', 'تحقق من الرابط أو استورد من السلة');
              } finally {
                setLocal(() => scraping = false);
              }
            }

            Future<void> pickPhoto() async {
              final x = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                imageQuality: 45,
                maxWidth: 800,
                maxHeight: 800,
              );
              if (x == null) return;
              final bytes = await x.readAsBytes();
              final mime = x.path.toLowerCase().endsWith('.png')
                  ? 'image/png'
                  : 'image/jpeg';
              image.text = 'data:$mime;base64,${base64Encode(bytes)}';
              setLocal(() {});
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (cartItems.isNotEmpty) ...[
                    Text(
                      'استيراد فوري من السلة الحالية (${cartItems.length})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: T.primary,
                      ),
                    ),
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
                              ci.title.length > 22
                                  ? '${ci.title.substring(0, 22)}…'
                                  : ci.title,
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
                              syncAutoRefundPolicy();
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
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'رابط أو نص مشاركة SHEIN أو الكود',
                            hintText: 'الصق نص المشاركة كاملاً أو رابط شي إن...',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      FilledButton.icon(
                        onPressed: scraping ? null : runScrape,
                        icon: scraping
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_fix_high, size: 15),
                        label: const Text('جلب', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'العنوان',
                      isDense: true,
                    ),
                    onChanged: (_) => setLocal(syncAutoRefundPolicy),
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
                            labelText: 'رابط الصورة أو مرفوعة',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: pickPhoto,
                        icon: const Icon(Icons.photo_library_outlined,
                            size: 15),
                        label:
                            const Text('صورة', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  if (image.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _studioThumb(image.text.trim(), 70, 70),
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
                            labelText: 'التصنيف',
                            isDense: true,
                          ),
                          onChanged: (_) => setLocal(syncAutoRefundPolicy),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: colors,
                          decoration: const InputDecoration(
                            labelText: 'الألوان (بفاصلة)',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: sizes,
                    decoration: const InputDecoration(
                      labelText: 'المقاسات (بفاصلة)',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: base,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'السعر الأساسي (ر.س)',
                            isDense: true,
                          ),
                          onChanged: (_) => setLocal(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: margin,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'هامش الربح (ر.س)',
                            isDense: true,
                          ),
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
                      labelText: 'منطقة التسعير',
                      isDense: true,
                    ),
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
                      labelText: 'شارة ترويجية (اختياري)',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('بدون')),
                      DropdownMenuItem(
                          value: 'new', child: Text('وصل حديثاً')),
                      DropdownMenuItem(
                          value: 'best', child: Text('الأكثر مبيعاً')),
                      DropdownMenuItem(
                          value: 'offer', child: Text('عرض خاص')),
                    ],
                    onChanged: (v) => setLocal(() => badge = v ?? ''),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'قطعة غير قابلة للاسترداد / الاستبدال',
                      style:
                          TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'مثل الملابس الداخلية، السباحة، الإكسسوارات أو العطور',
                      style: TextStyle(fontSize: 10),
                    ),
                    value: nonRefundable,
                    onChanged: (v) => setLocal(() {
                      manualNonRefundOverride = true;
                      nonRefundable = v;
                    }),
                  ),
                  if (nonRefundable) ...[
                    const SizedBox(height: 4),
                    TextField(
                      controller: nonRefundReason,
                      decoration: InputDecoration(
                        labelText: 'سبب عدم الاسترداد (اختياري)',
                        hintText: SelooRefundPolicy.reasonFor(
                          title.text,
                          category.text,
                        ),
                        isDense: true,
                      ),
                    ),
                  ],
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
                        Text(
                          'معاينة الأسعار الثلاثة',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: T.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'جنوب: ${(priceSar * rateSouth).toStringAsFixed(0)} ر.ي'
                          ' · شمال: ${(priceSar * rateNorth).toStringAsFixed(0)} ر.ي'
                          ' · سعودي: ${priceSar.toStringAsFixed(2)} ر.س',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.5,
                            color: T.text,
                          ),
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
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () => Get.back(result: true),
          child: Text(existing == null ? 'نشر' : 'حفظ'),
        ),
      ],
    ),
  );
  if (ok != true) return false;

  final goodsId = CatalogItem.extractGoodsId(link.text);
  if (goodsId.isEmpty && existing == null) {
    Get.snackbar('رابط غير صحيح', 'ألصق رابط SHEIN أو كود المنتج الرقمي');
    return false;
  }
  final effectiveTitle = title.text.trim();
  final effectiveCat =
      category.text.trim().isEmpty ? 'عام' : category.text.trim();
  final item = CatalogItem(
    id: existing?.id ?? '',
    title: effectiveTitle,
    goodsId: goodsId.isEmpty ? (existing?.goodsId ?? '') : goodsId,
    sourceUrl: link.text.trim(),
    imageUrl: image.text.trim(),
    category: effectiveCat,
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
    nonRefundable: nonRefundable,
    nonRefundableReason: nonRefundable ? nonRefundReason.text.trim() : '',
    createdAt: existing?.createdAt,
  );
  try {
    if (existing == null) {
      await repo.create(item);
      Get.snackbar('تم النشر', 'أُضيفت القطعة إلى كتالوج يمن سيلو');
    } else {
      await repo.update(item);
      Get.snackbar('تم الحفظ', 'حُدّثت القطعة');
    }
    return true;
  } catch (e) {
    Get.snackbar('تعذر الحفظ', '$e');
    return false;
  }
}

/// استوديو المسوّق: استيراد قطع SHEIN، استيراد جماعي، تسعير تلقائي، نشر وإيقاف.
class CatalogStudioTab extends StatefulWidget {
  const CatalogStudioTab({super.key});

  @override
  State<CatalogStudioTab> createState() => _CatalogStudioTabState();
}

class _CatalogStudioTabState extends State<CatalogStudioTab> {
  final _repo = Get.isRegistered<CatalogRepository>()
      ? Get.find<CatalogRepository>()
      : Get.put(CatalogRepository(), permanent: false);
  final _settings =
      Get.isRegistered<SettingsService>() ? Get.find<SettingsService>() : null;

  double get _rateSouth => _settings?.settings.value.rateSouth ?? 413;
  double get _rateNorth => _settings?.settings.value.rateNorth ?? 140;

  Widget _catThumb(String src, double w, double h) => _studioThumb(src, w, h);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استوديو كتالوج يمن سيلو'),
        actions: [
          IconButton(
            tooltip: 'استيراد جماعي (عدة روابط)',
            icon: Icon(Icons.playlist_add, color: T.primary),
            onPressed: _openBatchImport,
          ),
          IconButton(
            tooltip: 'استيراد قطعة',
            icon: Icon(Icons.add_link, color: T.primary),
            onPressed: () => openQuickCatalogPublish(),
          ),
        ],
      ),
      body: StreamBuilder<List<CatalogItem>>(
        stream: _repo.allItems(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                'تعذر تحميل الكتالوج\n${snap.error}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: T.muted),
              ),
            );
          }
          final items = snap.data ?? const <CatalogItem>[];
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _ratesBar(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => openQuickCatalogPublish(),
                      icon: const Icon(Icons.content_paste_go, size: 17),
                      label: const Text(
                        'استيراد قطعة',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openBatchImport,
                      icon: const Icon(Icons.playlist_add, size: 17),
                      label: const Text(
                        'استيراد عدة روابط',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      'الكتالوج فارغ — ابدأ باستيراد قطعة',
                      style: TextStyle(fontSize: 12, color: T.muted),
                    ),
                  ),
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
                  Text(
                    it.title.isEmpty ? 'قطعة بدون عنوان' : it.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: T.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${it.priceSar.toStringAsFixed(2)} ر.س · ${it.regionAr} · '
                    '${it.active ? 'منشور' : 'موقوف'}',
                    style: TextStyle(fontSize: 10.5, color: T.muted),
                  ),
                  if (it.isNonRefundable) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'غير قابل للاسترداد',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: T.muted),
              onSelected: (v) async {
                if (v == 'edit') {
                  await openQuickCatalogPublish(existing: it);
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
                  child: Text(it.active ? 'إيقاف مؤقت' : 'تفعيل ونشر'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('حذف')),
              ],
            ),
          ],
        ),
      );

  Future<void> _openBatchImport() async {
    final linksCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'نساء');
    final marginCtrl = TextEditingController(text: '0');
    var region = 'south';
    var running = false;
    var done = 0;
    var total = 0;
    var succeeded = 0;

    await Get.dialog<void>(
      StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> runBatch() async {
            final lines = linksCtrl.text
                .split('\n')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
            if (lines.isEmpty || running) return;
            setLocal(() {
              running = true;
              done = 0;
              succeeded = 0;
              total = lines.length;
            });
            final marginVal = double.tryParse(marginCtrl.text.trim()) ?? 0;
            final catVal = categoryCtrl.text.trim().isEmpty
                ? 'عام'
                : categoryCtrl.text.trim();
            for (final line in lines) {
              try {
                final scraped = await SheinProductScraper.fetchFromInput(line);
                if (scraped != null && scraped.goodsId.isNotEmpty) {
                  final autoNonRefund = SelooRefundPolicy.detectNonRefundable(
                    scraped.title,
                    catVal,
                  );
                  await _repo.create(
                    CatalogItem(
                      id: '',
                      title: scraped.title,
                      goodsId: scraped.goodsId,
                      sourceUrl: scraped.productUrl,
                      imageUrl: scraped.imageUrl,
                      category: catVal,
                      colors: scraped.colors,
                      sizes: scraped.sizes,
                      basePriceSar: scraped.priceSar,
                      marginSar: marginVal,
                      region: region,
                      badge: 'new',
                      active: true,
                      nonRefundable: autoNonRefund,
                    ),
                  );
                  succeeded++;
                }
              } catch (_) {}
              done++;
              setLocal(() {});
            }
            if (context.mounted) Get.back();
            Get.snackbar(
              'اكتمل الاستيراد الجماعي',
              'تم نشر $succeeded من أصل $total رابط بنجاح',
            );
          }

          return AlertDialog(
            title: const Text(
              'استيراد عدة روابط من SHEIN',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'ألصق كل رابط منتج (أو رابط onelink.shein.com أو رقم المنتج) في سطر مستقل:',
                      style: TextStyle(fontSize: 11.5),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: linksCtrl,
                      minLines: 5,
                      maxLines: 9,
                      enabled: !running,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        hintText:
                            'https://onelink.shein.com/...\nhttps://ar.shein.com/...-p-123456.html',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: categoryCtrl,
                            enabled: !running,
                            decoration: const InputDecoration(
                              labelText: 'التصنيف الافتراضي',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: marginCtrl,
                            enabled: !running,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'هامش الربح (ر.س)',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: region,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'منطقة التسعير',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'south', child: Text('جنوب')),
                        DropdownMenuItem(value: 'north', child: Text('شمال')),
                        DropdownMenuItem(value: 'sar', child: Text('سعودي')),
                      ],
                      onChanged: running
                          ? null
                          : (v) => setLocal(() => region = v ?? region),
                    ),
                    if (running) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: total > 0 ? done / total : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'جاري الاستيراد: $done / $total (نجح: $succeeded)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: running ? null : () => Get.back(),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                onPressed: running ? null : runBatch,
                icon: const Icon(Icons.playlist_add_check, size: 16),
                label: Text(running ? 'جاري النشر...' : 'استيراد ونشر الكل'),
              ),
            ],
          );
        },
      ),
      barrierDismissible: false,
    );
  }
}
