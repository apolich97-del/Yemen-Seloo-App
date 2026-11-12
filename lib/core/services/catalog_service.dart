import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../features/cart/domain/cart_item.dart';

/// تسجيل المنتجات المستوردة في كتالوج السيرفر `products/{goodsId}`.
/// بدونه يرفض السيرفر تسعير الطلب («منتج غير مسجّل»).
class CatalogService {
  final FirebaseFunctions _fn = FirebaseFunctions.instance;

  Future<int> registerImported(List<CartItem> lines) async {
    if (lines.isEmpty) return 0;

    final Map<String, Map<String, dynamic>> byId = <String, Map<String, dynamic>>{};
    for (final CartItem l in lines) {
      final String id = l.goodsId.trim();
      if (id.isEmpty || l.sourcePrice <= 0) continue;
      byId.putIfAbsent(
        id,
        () => <String, dynamic>{
          'goodsId': id,
          'sku': l.sku,
          'titleAr': l.title,
          'imageUrl': l.imageUrl,
          'productUrl': l.sourceUrl,
          'priceSar': l.sourcePrice,
          'color': l.color,
          'size': l.size,
        },
      );
    }
    if (byId.isEmpty) return 0;

    try {
      final HttpsCallableResult<dynamic> res = await _fn
          .httpsCallable('registerImportedProducts')
          .call(<String, dynamic>{'items': byId.values.toList()});
      final Map<String, dynamic> data =
          Map<String, dynamic>.from((res.data as Map?) ?? <String, dynamic>{});
      return (data['registered'] as num?)?.toInt() ?? 0;
    } catch (_) {
      // لا نُفشل الاستيراد بسبب الكتالوج: العميل يرى منتجاته،
      // والمحاولة القادمة (أو عند الدفع) ستكرّر التسجيل.
      await _registerLocally(byId.values.toList());
      return 0;
    }
  }

  /// مسار احتياطي: كتابة مباشرة للمنتج من جهاز العميل
  /// (تُقبل فقط إذا كانت قواعد Firestore تسمح بالكتابة).
  Future<void> _registerLocally(List<Map<String, dynamic>> items) async {
    try {
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      for (final Map<String, dynamic> it in items) {
        final String id = (it['goodsId'] ?? '').toString();
        if (id.isEmpty) continue;
        batch.set(
          FirebaseFirestore.instance.collection('products').doc(id),
          <String, dynamic>{
            'titleAr': it['titleAr'],
            'priceSar': it['priceSar'],
            'imageUrl': it['imageUrl'],
            'productUrl': it['productUrl'],
            'source': 'shein-import',
            'active': true,
            'registeredAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    } catch (_) {
      // صامت: لا نُزعج العميل بمشكلة كتالوج داخلية.
    }
  }
}
