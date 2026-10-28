import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../core/config/seloo_config.dart';
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

  final RxList<CartItem> items = <CartItem>[].obs;
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
  double get commissionTotalSar =>
      commissionPerPiece.value * items.length;

  /// ⭐ إجمالي العمولة بالريال اليمني = العمولة الإجمالية × سعر الصرف
  double get commissionTotalYer {
    final double rate = _exchangeRate;
    return commissionTotalSar * rate;
  }

  /// ⭐ هل هناك عمولة مُدخلة؟
  bool get hasCommission => commissionPerPiece.value > 0;

  /// سعر الصرف الحالي حسب المنطقة
  double get _exchangeRate {
    switch (region.value) {
      case 'south':
        return SelooPricing.southRate;
      case 'saudi':
        return SelooPricing.saudiRate;
      case 'north':
      default:
        return SelooPricing.northRate;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _loadFromStorage();
    _loadLastCommission();
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
  void setRegion(String newRegion) {
    if (region.value == newRegion) return;
    region.value = newRegion;
    refreshQuote();
  }

  // ═══════════════════════════════════════════════════════════════
  // ⭐ آلة حساب عمولة المندوب — الدوال
  // ═══════════════════════════════════════════════════════════════

  /// تعيين عمولة المندوب لكل قطعة (بالريال السعودي)
  /// يحفظ القيمة في GetStorage تلقائياً
  void setCommission(double perPieceSar) {
    if (perPieceSar < 0) perPieceSar = 0;
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

    // رابط المنتج بصيغة المتصفح المحمول التي تعمل فعلا (اختُبرت 200 OK).
    // نبنيها من goodsId لأن الروابط القديمة المحفوظة قد تكون بصيغة لا تعمل.
    final String editUrl = item.goodsId.isNotEmpty
        ? 'https://ar.shein.com/-p-${item.goodsId}.html'
        : item.sourceUrl;

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
