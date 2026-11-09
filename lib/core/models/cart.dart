/// نقطة الربط الوحيدة بين شاشات المراحل الجديدة وسلة يمن سيلو الحقيقية.
///
/// المصدر الفعلي هو `SelooCartService.loadItems()` (GetStorage:
/// `seloo_cart_items`)، وكل الحقول مأخوذة من `CartItem` بلا اختراع.
/// هذا الملف يُصدّر التنفيذ الحقيقي فقط، ولا يملك مخزناً خاصاً به.
export '../../features/cart/data/cart_repository.dart';
