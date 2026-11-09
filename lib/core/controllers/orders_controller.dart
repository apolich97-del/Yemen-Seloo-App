import 'package:get/get.dart';

import '../models/order.dart';
import '../services/order_service.dart';

class OrdersController extends GetxController {
  final _orders = Get.find<OrderService>();

  /// null = تبويب «الكل»
  final selectedTab = Rxn<OrderStatus>();
  final orders = <Order>[].obs;
  final loading = true.obs;
  final error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _bind();
  }

  void _bind() {
    loading.value = true;
    error.value = '';
    _orders.myOrders(status: selectedTab.value).listen(
      (list) {
        orders.assignAll(list);
        loading.value = false;
      },
      onError: (e) {
        // غالباً يحتاج فهرس Firestore (userId + status + createdAt).
        error.value = 'تعذر تحميل الطلبات: $e';
        loading.value = false;
      },
    );
  }

  void selectTab(OrderStatus? s) {
    if (selectedTab.value == s) return;
    selectedTab.value = s;
    _bind();
  }

  int countFor(OrderStatus? s) => orders.where((o) => s == null || o.status == s).length;

  Future<void> requestExpedite(Order o) async {
    try {
      await _orders.requestExpedite(o.id);
      Get.snackbar('تم الإرسال', 'أُرسل تنبيه تسريع الشحن لفريق التجهيز');
    } catch (e) {
      Get.snackbar('تعذر الإرسال', '$e');
    }
  }

  void open(Order o) => Get.toNamed('/order', arguments: o.id);
}
