import 'package:get/get.dart';

/// ⭐ يتحكم في التبويب الحالي للـ MainShell من خارج الشاشة.
/// يُستخدم عندما يُطلب من SHEIN (WebView) الانتقال إلى سلة يمن سيلو.
///
/// التبويبات:
///   0 = الرئيسية
///   1 = تصفح SHEIN
///   2 = سلة التسوق
///   3 = طلباتي
///   4 = الدعم
class MainTabController extends GetxController {
  /// التبويب الحالي — SHEIN افتراضي (1)
  final RxInt index = 1.obs;

  /// الانتقال إلى تبويب محدد
  void goTo(int i) {
    if (i < 0 || i > 4) return;
    index.value = i;
  }

  /// اختصارات جاهزة
  void goToCart() => goTo(2);
  void goToHome() => goTo(0);
  void goToShein() => goTo(1);
  void goToOrders() => goTo(3);
  void goToSupport() => goTo(4);
}
