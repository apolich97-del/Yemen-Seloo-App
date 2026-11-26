import 'package:get/get.dart';
import '../../support/presentation/support_screen.dart';

/// يتحكم في التبويب الحالي للـ MainShell:
///   0 = الرئيسية
///   1 = كتالوج يمن سيلو (مستقل وسريع)
///   2 = تصفح SHEIN (مستقل)
///   3 = السلة
///   4 = طلباتي
///   5 = أنا (الحساب والواجهة والإعدادات واللغة والعملة والموقع)
class MainTabController extends GetxController {
  final RxInt index = 0.obs;

  /// الفلتر المطلوب فتحه داخل تبويب «طلباتي»
  final RxString ordersFilter = 'all'.obs;
  final RxInt ordersFilterTick = 0.obs;

  void goTo(int i) {
    if (i < 0 || i > 5) return;
    index.value = i;
  }

  void goToHome() => goTo(0);
  void goToCatalog() => goTo(1);
  void goToShein() => goTo(2);
  void goToCart() => goTo(3);

  void goToOrders([String filter = 'all']) {
    ordersFilter.value = filter;
    ordersFilterTick.value++;
    goTo(4);
  }

  void goToMe() => goTo(5);

  void goToSupport() => Get.to(() => const SupportScreen());
}
