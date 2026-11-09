import 'dart:math' as math;

import 'package:get/get.dart';

import '../../../core/config/seloo_config.dart';
import '../application/cart_counter.dart';
import '../domain/cart_item.dart';
import 'seloo_cart_service.dart';

/// سطر سلة مُطَبَّع — وحدة القراءة الوحيدة التي يعتمدها مسار الاستيراد.
///
/// المصدر الحقيقي للبيانات هو [SelooCartService.loadItems] (GetStorage).
/// لا شبكة هنا إطلاقاً، ولا حقول مُختَرَعة: كل حقل مأخوذ من [CartItem].
class CartLine {
  const CartLine({
    required this.goodsId,
    required this.variantKey,
    required this.titleAr,
    required this.imageUrl,
    required this.color,
    required this.size,
    required this.qty,
    required this.unitPriceSar,
  });

  /// معرّف منتج شي إن الرقمي.
  final String goodsId;

  /// مفتاح التمييز: المنتج + اللون + المقاس. المعرّف وحده يدمج المقاسات.
  final String variantKey;

  /// اسم المنتج كما وصل من شي إن ([CartItem.title]).
  final String titleAr;

  /// رابط الصورة بعد التنظيف في [SelooCartService].
  final String imageUrl;

  final String color;
  final String size;

  /// الكمية بعد الدمج، بين 1 و[SelooConfig.maxQuantityPerLine].
  final int qty;

  /// سعر شي إن بالريال السعودي ([CartItem.sourcePrice]) — سيُتحقق منه على
  /// السيرفر من products/{goodsId}، وقيمته هنا للعرض فقط.
  final double unitPriceSar;

  /// إجمالي السطر بالريال السعودي.
  double get lineTotalSar => unitPriceSar * qty;

  /// الحمولة التي يتوقعها `submitOrder` على السيرفر.
  ///
  /// السعر يُرسل للعرض فقط: السيرفر يقرأه من `products/{goodsId}` ويتجاهل
  /// هذه القيمة إلا إذا كان المنتج `isManual`. لا تُرسل [variantKey] ولا
  /// [titleAr] لأن السيرفر يأخذ العنوان من الكتالوج ويثق به.
  Map<String, dynamic> toServer() => <String, dynamic>{
        'goodsId': goodsId,
        'qty': qty,
        'color': color,
        'size': size,
        'unitPriceSar': unitPriceSar,
      };

  Map<String, dynamic> toJson() => <String, dynamic>{
        'goodsId': goodsId,
        'variantKey': variantKey,
        'titleAr': titleAr,
        'imageUrl': imageUrl,
        'color': color,
        'size': size,
        'qty': qty,
        'unitPriceSar': unitPriceSar,
      };

  @override
  String toString() =>
      'CartLine($goodsId, "$color"/"$size", qty=$qty, $unitPriceSar SAR)';
}

/// قراءة السلة المحلية بشكل ثابت ومُطَبَّع.
class CartRepository {
  CartRepository({SelooCartService? service})
      : _service = service ?? SelooCartService();

  final SelooCartService _service;

  /// سقف الكمية في السطر الواحد — [SelooConfig.maxQuantityPerLine] = 99.
  static const int maxQtyPerLine = SelooConfig.maxQuantityPerLine;

  /// المفتاح: معرّف المنتج + اللون + المقاس.
  /// المعرّف وحده يدمج المقاسات ويُسقطها، لذلك اللون والمقاس إلزاميان هنا.
  static String variantKey(String goodsId, String color, String size) =>
      '$goodsId|${color.trim()}|${size.trim()}';

  /// هل المعرّف رقمي؟ (عقد الجسر: id معرّف شي إن الرقمي)
  static bool _isNumericId(String value) => RegExp(r'^\d+$').hasMatch(value);

  /// الكمية: غير الصالح ← 1، السالب أو الصفر ← 0 (يُحذف السطر).
  static int _normalizeQty(int raw) {
    if (raw < 0) return 0;
    if (raw == 0) return 0;
    if (raw > maxQtyPerLine) return maxQtyPerLine;
    return raw;
  }

  /// يقرأ السلة المحلية ويُعيد أسطراً مُدمَجة بلا أي وصول شبكي.
  ///
  /// القواعد المطبَّقة:
  /// - الأسطر التي لها نفس [variantKey] تُدمج والكمية تُجمع بحد أقصى 99.
  /// - qty غير صالح يُصحّح إلى 1، والسالب/الصفر يُحذف السطر.
  /// - السطر بلا goodsId رقمي أو بلا سعر موجب يُستبعد.
  /// - تُعاد قائمة ثابتة (غير قابلة للتعديل).
  List<CartLine> read() {
    List<CartItem> items;
    try {
      items = _service.loadItems();
    } catch (_) {
      // تخزين تالف أو غير مهيأ: سلة فارغة أفضل من انفجار الشاشة.
      return const <CartLine>[];
    }

    // الترتيب محفوظ: أول ظهور للسطر هو موضعه في النتيجة.
    final Map<String, _Acc> merged = <String, _Acc>{};

    for (final CartItem item in items) {
      final String goodsId = item.goodsId.trim();

      // 1) معرّف رقمي غير فارغ.
      if (!_isNumericId(goodsId)) continue;

      // 2) سعر موجب. sourcePrice هو سعر شي إن بالريال السعودي.
      final double price = item.sourcePrice;
      if (!price.isFinite || price <= 0) continue;

      // 3) الكمية: الأصلية قد تكون 0 أو سالبة أو مفقودة.
      final int qty = _normalizeQty(item.quantity);
      if (qty <= 0) continue;

      final String color = item.color.trim();
      final String size = item.size.trim();
      final String key = variantKey(goodsId, color, size);

      final _Acc? existing = merged[key];
      if (existing == null) {
        merged[key] = _Acc(
          goodsId: goodsId,
          variantKey: key,
          titleAr: item.title.trim(),
          imageUrl: item.imageUrl.trim(),
          color: color,
          size: size,
          qty: qty,
          unitPriceSar: price,
        );
        continue;
      }

      // دمج: الكمية تُجمع بحد أقصى 99، والسعر الأحدث يفوز
      // (السيرفر هو من يعتمد السعر النهائي في كل الأحوال).
      existing.qty = math.min(maxQtyPerLine, existing.qty + qty);
      if (price > 0) existing.unitPriceSar = price;
      if (existing.titleAr.isEmpty) existing.titleAr = item.title.trim();
      if (existing.imageUrl.isEmpty) existing.imageUrl = item.imageUrl.trim();
    }

    final List<CartLine> lines = merged.values
        .where((_Acc a) => a.qty > 0)
        .map(
          (_Acc a) => CartLine(
            goodsId: a.goodsId,
            variantKey: a.variantKey,
            titleAr: a.titleAr,
            imageUrl: a.imageUrl,
            color: a.color,
            size: a.size,
            qty: a.qty,
            unitPriceSar: a.unitPriceSar,
          ),
        )
        .toList(growable: false);

    return List<CartLine>.unmodifiable(lines);
  }

  /// إجمالي السلة بالريال السعودي من السطور المُطَبَّعة.
  double subtotalSar(List<CartLine> lines) =>
      lines.fold<double>(0, (double sum, CartLine l) => sum + l.lineTotalSar);

  /// عدد الوحدات (مجموع الكميات) — للعرض في الملخص.
  int pieces(List<CartLine> lines) =>
      lines.fold<int>(0, (int sum, CartLine l) => sum + l.qty);

  /// عدد الأسطر المميّزة.
  int count(List<CartLine> lines) => lines.length;

  /// تفريغ السلة الحقيقية (التخزين + الذاكرة إن كان CartCounter مسجّلاً).
  Future<void> clear() async {
    await _service.clear();
    try {
      final CartCounter cart = Get.find<CartCounter>();
      cart.items.clear();
      cart.quote.value = null;
    } catch (_) {
      // CartCounter غير مسجّل (اختبارات مثلاً): التخزين وحده يكفي.
    }
  }
}

/// مُراكم داخلي للدمج — قابل للتعديل ثم يُحوَّل إلى [CartLine] ثابت.
class _Acc {
  _Acc({
    required this.goodsId,
    required this.variantKey,
    required this.titleAr,
    required this.imageUrl,
    required this.color,
    required this.size,
    required this.qty,
    required this.unitPriceSar,
  });

  final String goodsId;
  final String variantKey;
  final String color;
  final String size;
  String titleAr;
  String imageUrl;
  int qty;
  double unitPriceSar;
}
