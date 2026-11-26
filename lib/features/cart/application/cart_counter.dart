import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/config/seloo_config.dart';
import '../../../core/models/currency.dart';
import '../../../core/services/settings_service.dart';
import '../../shein/domain/shein_draft.dart';
import '../data/seloo_cart_service.dart';
import '../domain/cart_item.dart';

/// حالة السلة المشتركة — محلية على الجهاز.
class CartCounter extends GetxService {
  CartCounter({SelooCartService? service})
      : _service = service ?? SelooCartService();

  final SelooCartService _service;
  final GetStorage _box = GetStorage();

  // ثوابت مفاتيح التخزين
  static const String _kLastCommission = 'seloo_last_commission';
  static const String _kRegion = 'seloo_region';

  final RxList<CartItem> items = <CartItem>[].obs;

  /// الأسطر المحددة للفاتورة/المشاركة/الحذف (lineId).
  final RxSet<String> selected = <String>{}.obs;

  /// القطع المحددة فقط — هي ما يدخل في الفاتورة والتقدم نحو الشحن المجاني.
  List<CartItem> get selectedItems =>
      items.where((e) => selected.contains(e.lineId)).toList();

  /// مفاتيح المحدد بصيغة goodsId|color|size لمطابقة أسطر الفاتورة.
  Set<String> get selectedVariantKeys => selectedItems
      .map((e) => '${e.goodsId.trim()}|${e.color.trim()}|${e.size.trim()}')
      .toSet();

  /// تغيير اللون أو المقاس داخل السلة دون مغادرتها.
  Future<void> updateVariant(CartItem item,
      {String? color, String? size}) async {
    final list = _service.loadItems();
    final i = list.indexWhere((e) => e.lineId == item.lineId);
    if (i < 0) return;
    final old = list[i];
    list[i] = CartItem(
      lineId: old.lineId,
      goodsId: old.goodsId,
      title: old.title,
      imageUrl: old.imageUrl,
      sourceUrl: old.sourceUrl,
      sourcePrice: old.sourcePrice,
      sourceCurrency: old.sourceCurrency,
      exchangeRate: old.exchangeRate,
      quantity: old.quantity,
      color: color ?? old.color,
      size: size ?? old.size,
      options: old.options,
      sourceStore: old.sourceStore,
      deliveryLocal: old.deliveryLocal,
      sku: old.sku,
      variantId: old.variantId,
      nonRefundable: old.nonRefundable,
      nonRefundableReason: old.nonRefundableReason,
    );
    await _service.saveItems(list);
    items.assignAll(list);
    await _reload();
  }
  final Rx<CartQuote?> quote = Rx<CartQuote?>(null);
  final RxBool busy = false.obs;
  final RxnString lastError = RxnString();

  // ⭐ منطقة التسعير (north افتراضي)
  final RxString region = 'north'.obs;

  // ⭐ حالة التعديل
  final RxnString editingLineId = RxnString();
  final RxnString editingProductUrl = RxnString();

  // ⭐ آلة حساب عمولة المندوب
  /// العمولة لكل قطعة بالريال السعودي
  final RxDouble commissionPerPiece = 0.0.obs;

  /// هل وافق المندوب على مشاركة عمولته مع الشركة؟
  final RxBool commissionApproved = false.obs;

  Stream<int> get stream =>
      items.stream.map((List<CartItem> list) => list.length);
  int get count => items.length;
  bool get isEditing => editingLineId.value != null;
  double get subtotalLocal => items.fold<double>(
      0, (double sum, CartItem item) => sum + item.lineTotalLocal);

  /// ⭐ إجمالي العمولة بالريال السعودي = العمولة × عدد القطع
  /// مجموع القطع (لا الأسطر) — العمولة تُحسب لكل قطعة.
  int get totalPieces =>
      items.fold<int>(0, (int sum, CartItem item) => sum + item.quantity);

  /// العمولة إجمالاً: لكل قطعة × عدد القطع. بند داخلي للمندوب ولا يدخل
  /// في إجمالي العميل.
  double get commissionTotalSar => commissionPerPiece.value * totalPieces;

  /// ⭐ إجمالي العمولة بالريال اليمني = العمولة الإجمالية × سعر الصرف
  double get commissionTotalYer {
    final double rate = _exchangeRate;
    return commissionTotalSar * rate;
  }

  /// ⭐ هل هناك عمولة مُدخلة؟
  bool get hasCommission => commissionPerPiece.value > 0;

  /// سعر الصرف الحالي حسب المنطقة
  double get _exchangeRate {
    final s = Get.isRegistered<SettingsService>()
        ? Get.find<SettingsService>().settings.value
        : null;
    switch (region.value) {
      case 'south':
        return s?.rateSouth ?? SelooPricing.southRate;
      case 'saudi':
      case 'sar':
        return 1.0;
      case 'usd':
        return 1.0 / ((s?.sarPerUsd ?? 3.75) > 0 ? (s?.sarPerUsd ?? 3.75) : 3.75);
      case 'north':
      default:
        return s?.rateNorth ?? SelooPricing.northRate;
    }
  }

  Worker? _settingsWorker;

  @override
  void onInit() {
    super.onInit();
    _loadRegion();
    _loadFromStorage();
    _loadLastCommission();
    if (Get.isRegistered<SettingsService>()) {
      _settingsWorker = ever(Get.find<SettingsService>().settings, (_) {
        applyRegionRate();
        refreshQuote();
      });
    }
    // إعادة حساب الإجمالي بعد استرجاع السلة من التخزين
    refreshQuote();
  }

  @override
  void onClose() {
    _settingsWorker?.dispose();
    super.onClose();
  }

  /// مزامنة أسعار وتوفر قطع السلة مع الكتالوج وذاكرة شي إن.
  Future<int> syncCartWithCatalog() async {
    if (items.isEmpty) return 0;
    try {
      final snap = await FirebaseFirestore.instance.collection('catalog').get();
      final byGoodsId = <String, Map<String, dynamic>>{};
      for (final d in snap.docs) {
        final m = d.data();
        final gid = (m['goodsId'] ?? '').toString().trim();
        if (gid.isNotEmpty) byGoodsId[gid] = m;
        byGoodsId[d.id] = m;
      }
      int changes = 0;
      final updated = <CartItem>[];
      for (final item in items) {
        final match = byGoodsId[item.goodsId.trim()];
        if (match == null) {
          // محاولة التحقق من ذاكرة أسعار شي إن إن وُجدت
          if (item.goodsId.trim().isNotEmpty) {
            try {
              final sc = await FirebaseFirestore.instance
                  .collection('shein_cache')
                  .doc(item.goodsId.trim())
                  .get();
              final sm = sc.data();
              if (sm != null) {
                final cachedSar = ((sm['priceSar'] as num?) ?? (sm['retailPriceSar'] as num?) ?? 0).toDouble();
                if (cachedSar > 0 && (cachedSar - item.sourcePrice).abs() > 0.01) {
                  updated.add(item.copyWith(sourcePrice: cachedSar));
                  changes++;
                  continue;
                }
              }
            } catch (_) {}
          }
          updated.add(item);
          continue;
        }
        final active = (match['active'] ?? true) as bool;
        if (!active && item.sourceStore == 'يمن سيلو') {
          changes++;
          continue; // استبعاد غير المتوفر من الكتالوج
        }
        final base = ((match['basePriceSar'] as num?) ?? 0).toDouble();
        final margin = ((match['marginSar'] as num?) ?? 0).toDouble();
        final newSar = base + margin;
        final nr = (match['nonRefundable'] as bool?) ?? item.nonRefundable;
        final nrReason = (match['nonRefundableReason'] ?? item.nonRefundableReason).toString();
        if (item.sourceStore == 'يمن سيلو' && newSar > 0 &&
            ((newSar - item.sourcePrice).abs() > 0.01 || nr != item.nonRefundable)) {
          updated.add(item.copyWith(
            sourcePrice: newSar,
            nonRefundable: nr,
            nonRefundableReason: nrReason,
          ));
          changes++;
        } else {
          updated.add(item);
        }
      }
      if (changes > 0) {
        await _service.saveItems(updated);
        items.assignAll(updated);
        await refreshQuote();
      }
      return changes;
    } catch (_) {
      return 0;
    }
  }

  void _loadFromStorage() {
    try {
      final List<CartItem> loaded = _service.loadItems();
      items.assignAll(loaded);
    } catch (e) {
      lastError.value = 'تعذّر تحميل السلة: $e';
    }
  }

  /// ⭐ استرجاع آخر عمولة محفوظة
  void _loadLastCommission() {
    try {
      final double? saved = _box.read<double>(_kLastCommission);
      if (saved != null && saved > 0) {
        commissionPerPiece.value = saved;
      }
    } catch (_) {}
  }

  Future<void> _reload() async {
    try {
      final List<CartItem> loaded = _service.loadItems();
      items.assignAll(loaded);
      // الأسطر الجديدة تُحفظ بسعر صرف ثابت، فنوحّدها على المنطقة الحالية
      await applyRegionRate();
      if (items.isNotEmpty) {
        await refreshQuote();
      } else {
        quote.value = null;
      }
    } catch (e) {
      lastError.value = 'تعذّر تحميل السلة: $e';
    }
  }

  /// حساب الإجمالي مباشرة من الذاكرة (بدون قراءة التخزين)
  Future<void> refreshQuote() async {
    if (items.isEmpty) {
      quote.value = null;
      return;
    }
    busy.value = true;
    try {
      quote.value = _service.calculateQuote(items.toList(), region.value);
      lastError.value = null;
    } catch (error) {
      lastError.value = 'تعذّر حساب الإجمالي: $error';
    } finally {
      busy.value = false;
    }
  }

  // ⭐ تغيير المنطقة وإعادة حساب الإجمالي
  /// يوحّد سعر الصرف على كل أسطر السلة حسب المنطقة المختارة
  Future<void> applyRegionRate() async {
    final double rate = _exchangeRate;
    bool changed = false;
    final List<CartItem> updated = <CartItem>[];
    for (final CartItem e in items) {
      if (e.exchangeRate == rate) {
        updated.add(e);
      } else {
        updated.add(e.copyWith(exchangeRate: rate));
        changed = true;
      }
    }
    if (!changed) return;
    items.assignAll(updated);
    try {
      await _service.saveItems(updated);
    } catch (_) {}
  }

  /// تحديث صورة سطر جاهز (بعد جلب الصورة الصحيحة من شي إن)
  Future<bool> patchImage(String goodsId, String imageUrl) async {
    if (goodsId.isEmpty || imageUrl.trim().isEmpty) return false;
    try {
      final bool ok = await _service.patchImage(goodsId, imageUrl.trim());
      if (!ok) return false;
      final int index =
          items.lastIndexWhere((CartItem e) => e.goodsId == goodsId);
      if (index != -1) {
        items[index] = items[index].copyWith(imageUrl: imageUrl.trim());
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void setRegion(String newRegion) {
    if (region.value == newRegion) return;
    if (!_validRegions.contains(newRegion)) return;
    region.value = newRegion;
    _saveRegion(newRegion);
    applyRegionRate();
    refreshQuote();
  }

  static const Set<String> _validRegions = <String>{'north', 'south', 'saudi', 'usd'};

  /// استرجاع المنطقة المختارة — بدونها كان سعر الصرف يرجع إلى الشمال
  /// عند كل إعادة تشغيل، فتتغير أسعار السلة ثلاثة أضعاف.
  void _loadRegion() {
    try {
      if (Get.isRegistered<SettingsService>()) {
        final dc = Get.find<SettingsService>().displayCurrency.value.key;
        final mapped = dc == 'sar' ? 'saudi' : dc;
        if (_validRegions.contains(mapped)) {
          region.value = mapped;
          return;
        }
      }
      final String? saved = _box.read<String>(_kRegion);
      if (saved != null && _validRegions.contains(saved)) {
        region.value = saved;
      }
    } catch (_) {}
  }

  void _saveRegion(String value) {
    try {
      _box.write(_kRegion, value);
      final cKey = value == 'saudi' ? 'sar' : value;
      _box.write('display_currency', cKey);
      _box.write('seloo_cart_region', value);
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════
  // ⭐ آلة حساب عمولة المندوب — الدوال
  // ═══════════════════════════════════════════════════════════════

  /// تعيين عمولة المندوب لكل قطعة (بالريال السعودي)
  /// يحفظ القيمة في GetStorage تلقائياً
  void setCommission(double perPieceSar) {
    if (perPieceSar < 0) perPieceSar = 0;
    // أي تغيير في المبلغ يُلغي الموافقة السابقة
    if (perPieceSar != commissionPerPiece.value) {
      commissionApproved.value = false;
    }
    commissionPerPiece.value = perPieceSar;
    try {
      _box.write(_kLastCommission, perPieceSar);
    } catch (_) {}
  }

  /// الموافقة على مشاركة العمولة مع الشركة
  void approveCommission() {
    if (hasCommission) {
      commissionApproved.value = true;
    }
  }

  /// إلغاء الموافقة (عند التراجع)
  void unapproveCommission() {
    commissionApproved.value = false;
  }

  /// مسح العمولة بالكامل (مع الاحتفاظ بآخر قيمة في التخزين)
  void clearCommission() {
    commissionPerPiece.value = 0.0;
    commissionApproved.value = false;
  }

  // ═══════════════════════════════════════════════════════════════
  // عمليات السلة
  // ═══════════════════════════════════════════════════════════════

  Future<String?> updateQuantity(CartItem item, int quantity) async {
    if (quantity < 1 || quantity > SelooConfig.maxQuantityPerLine) {
      return 'الكمية يجب أن تكون بين 1 و ${SelooConfig.maxQuantityPerLine}';
    }
    busy.value = true;
    try {
      final BridgeResult result =
          await _service.updateLine(item.lineId, quantity);
      if (result.isOk) await _reload();
      return result.isOk ? null : result.message;
    } catch (error) {
      return 'تعذّر تحديث الكمية: $error';
    } finally {
      busy.value = false;
    }
  }

  Future<String?> remove(CartItem item) async {
    busy.value = true;
    try {
      final BridgeResult result = await _service.removeLine(item.lineId);
      if (result.isOk) await _reload();
      return result.isOk ? null : result.message;
    } catch (error) {
      return 'تعذّر حذف المنتج: $error';
    } finally {
      busy.value = false;
    }
  }

  Future<String?> clear() async {
    busy.value = true;
    try {
      final BridgeResult result = await _service.clear();
      if (result.isOk) {
        items.clear();
        quote.value = null;
        // ⭐ لا نمسح العمولة عند تفريغ السلة — المندوب قد يحتاجها
      }
      return result.isOk ? null : result.message;
    } catch (error) {
      return 'تعذّر تفريغ السلة: $error';
    } finally {
      busy.value = false;
    }
  }

  void startEditing(CartItem item) {
    editingLineId.value = item.lineId;

    // شي إن تمنع فتح صفحة المنتج مباشرة برابط، لكن صفحة البحث بالرمز
    // تُفتح بلا خطأ (اختُبرت 200 OK). المستخدم يضغط نتيجة البحث ثم الزر الأرجواني.
    final String editUrl = item.goodsId.isNotEmpty
        ? 'https://m.shein.com/ar/pdsearch/${item.goodsId}/?seloo_edit=1'
        : item.sourceUrl;

    editingProductUrl.value = editUrl;

    Get.toNamed('/shein', arguments: <String, dynamic>{
      'editLineId': item.lineId,
      'editUrl': editUrl,
    });
  }

  /// تُستدعى بعد كل إضافة ناجحة من الجسر.
  Future<void> onItemAdded() async {
    await _reload();
  }

  void clearEditing() {
    editingLineId.value = null;
    editingProductUrl.value = null;
  }
}
