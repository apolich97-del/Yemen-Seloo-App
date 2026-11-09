import 'package:get/get.dart';

import '../../features/auth/login_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/orders/my_orders_screen.dart';
import '../../features/orders/order_detail_screen.dart';
import '../../features/payment/payment_screen.dart';
import '../../features/profile/address_form_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/admin/admin_shell.dart';
import '../controllers/checkout_controller.dart';
import '../controllers/orders_controller.dart';
import '../controllers/payment_controller.dart';
import '../controllers/profile_controller.dart';
import '../services/auth_service.dart';
import '../models/cart.dart';
import '../services/order_service.dart';
import '../services/pricing_service.dart';
import '../services/settings_service.dart';

class AppRoutes {
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const payment = '/payment';
  static const orders = '/orders';
  static const orderDetail = '/order';
  static const profile = '/profile';
  static const addressForm = '/address-form';
  static const login = '/login';
  static const admin = '/admin';
}

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<CartRepository>(CartRepository(), permanent: true);
    Get.put<SettingsService>(SettingsService(), permanent: true);
    Get.put<PricingService>(PricingService(), permanent: true);
    Get.put<AuthService>(AuthService(), permanent: true);
    Get.put<OrderService>(OrderService(), permanent: true);
  }
}

class AppPages {
  static final pages = <GetPage>[
    GetPage(name: AppRoutes.cart, page: () => const CartScreen()),
    GetPage(
      name: AppRoutes.checkout,
      page: () => const CheckoutScreen(),
      binding: BindingsBuilder(() => Get.lazyPut(() => CheckoutController())),
    ),
    GetPage(
      name: AppRoutes.payment,
      page: () => const PaymentScreen(),
      binding: BindingsBuilder(() => Get.lazyPut(() => PaymentController())),
    ),
    GetPage(
      name: AppRoutes.orders,
      page: () => const MyOrdersScreen(),
      binding: BindingsBuilder(() => Get.lazyPut(() => OrdersController())),
    ),
    GetPage(name: AppRoutes.orderDetail, page: () => const OrderDetailScreen()),
    GetPage(
      name: AppRoutes.profile,
      page: () => const ProfileScreen(),
      binding: BindingsBuilder(() => Get.lazyPut(() => ProfileController())),
    ),
    GetPage(name: AppRoutes.addressForm, page: () => const AddressFormScreen()),
    GetPage(name: AppRoutes.login, page: () => const LoginScreen()),
    GetPage(name: AppRoutes.admin, page: () => const AdminShell()),
  ];
}
