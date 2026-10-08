import 'package:get/get.dart';

import '../../../core/config/seloo_config.dart';
import '../../shein/domain/shein_draft.dart';
import '../data/seloo_cart_service.dart';
import '../domain/cart_item.dart';

/// حالة السلة المشتركة — محلية على الجهاز.
class CartCounter extends GetxService {
  CartCounter({SelooCartService? service})
      : _service = service ?? SelooCartService();

  final SelooCartService _service;

  final RxList<CartItem> items = <CartItem>[].obs;
  final Rx<CartQuote?> quote = Rx<CartQuote?>(null);
  final RxBool busy = false.obs;
  final RxnString lastError = RxnString();

  // ⭐ منطقة التسعير (north افتراضي)
  final RxString region = 'north'.obs;

  // ⭐ حالة التعديل
  final RxnString editingLineId = RxnString();
  final RxnString editingProductUrl = RxnString();

  Stream<int> get stream =>
      items.stream.map((List<CartItem> list) => list.length);
  int get count => items.length;
  bool get isEditing => editingLineId.value != null;
  double get subtotalLocal => items.fold<double>(
      0, (double sum, CartItem item) => sum + item.lineTotalLocal);

  @override
  void onInit() {
    super.onInit();
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      final List<CartItem> loaded = _service.loadItems();
      items.assignAll(loaded);
    } catch (e) {
      lastError.value = 'تعذّر تحميل السلة: $e';
    }
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

  Future<void> refreshQuote() async {
    if (items.isEmpty) {
      quote.value = null;
      return;
    }
    busy.value = true;
    try {
      quote.value = await _service.quoteFor(region.value); // ⭐ يستخدم المنطقة الحالية
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

    Get.toNamed('/shein', arguments: <String, dynamic>{
      'editLineId': item.lineId,
      'editUrl': item.sourceUrl,
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
