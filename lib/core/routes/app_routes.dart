import 'package:get/get.dart';

import '../../features/auth/login_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/orders/my_orders_screen.dart';
import '../../features/orders/order_detail_screen.dart';
import '../../features/payment/payment_screen.dart';
import '../../features/profile/address_form_screen.dart';
import '../../features/profile/account_statement_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/receipts/presentation/my_receipts_screen.dart';
import '../../features/admin/admin_shell.dart';
import '../controllers/checkout_controller.dart';
import '../controllers/orders_controller.dart';
import '../controllers/payment_controller.dart';
import '../controllers/profile_controller.dart';
import '../services/auth_service.dart';
import '../models/cart.dart';
import '../services/order_service.dart';
import '../services/receipt_service.dart';
import '../../features/support/data/support_service.dart';
import '../../features/guide/interactive_guide.dart';
import '../theme/theme_controller.dart';
import '../services/pricing_service.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../services/audit_service.dart';
import '../services/saved_accounts_service.dart';
import '../../features/notifications/notifications_screen.dart';
import '../services/push_service.dart';

class AppRoutes {
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const payment = '/payment';
  static const orders = '/orders';
  static const orderDetail = '/order';
  static const profile = '/profile';
  static const accountStatement = '/account-statement';
  static const addressForm = '/address-form';
  static const login = '/login';
  static const myReceipts = '/my-receipts';
  static const admin = '/admin';
  static const notifications = '/notifications';
}

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<CartRepository>(CartRepository(), permanent: true);
    if (!Get.isRegistered<SavedAccountsService>()) Get.put<SavedAccountsService>(SavedAccountsService(), permanent: true);
    if (!Get.isRegistered<SettingsService>()) Get.put<SettingsService>(SettingsService(), permanent: true);
    if (!Get.isRegistered<NotificationService>()) Get.put<NotificationService>(NotificationService(), permanent: true);
    if (!Get.isRegistered<AuditService>()) Get.put<AuditService>(AuditService(), permanent: true);
    Get.put<PricingService>(PricingService(), permanent: true);
    Get.put<AuthService>(AuthService(), permanent: true);
    Get.put<OrderService>(OrderService(), permanent: true);
    Get.put<ReceiptService>(ReceiptService(), permanent: true);
    Get.put<SupportService>(SupportService(), permanent: true);
    Get.put<ThemeController>(ThemeController(), permanent: true);
    Get.put<InteractiveGuideController>(InteractiveGuideController(),
        permanent: true);
    if (!Get.isRegistered<PushService>()) {
      Get.put<PushService>(PushService(), permanent: true).init();
    }
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
    GetPage(name: AppRoutes.accountStatement, page: () => const AccountStatementScreen()),
    GetPage(name: AppRoutes.login, page: () => const LoginScreen()),
    GetPage(
      name: AppRoutes.myReceipts,
      page: () => const MyReceiptsScreen(),
    ),
    GetPage(name: AppRoutes.admin, page: () => const AdminShell()),
    GetPage(name: AppRoutes.notifications, page: () => const NotificationsScreen()),
  ];
}
