import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import 'main_tab_controller.dart';
import '../../../core/widgets/brand_logo.dart';

const Color _purple = Color(0xFF7C3AED);

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.card,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 16),
              // شعار في المنتصف: نهاري دائري 128، ليلي بحواف 24 وتوهج بنفسجي
              Builder(builder: (context) {
                final bool dark =
                    Theme.of(context).brightness == Brightness.dark;
                final double size = dark ? 144 : 128;
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF16102E) : T.soft,
                    borderRadius: BorderRadius.circular(dark ? 24 : 999),
                    border: Border.all(
                        color: dark ? const Color(0xFF43337D) : T.softBorder,
                        width: dark ? 1.5 : 2),
                    boxShadow: dark
                        ? <BoxShadow>[
                            BoxShadow(
                              color: const Color(0xFF5B2EFF).withOpacity(.55),
                              blurRadius: 24,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  padding: EdgeInsets.all(dark ? 18 : 10),
                  child: BrandLogo(height: size - (dark ? 36 : 20)),
                );
              }),
              const SizedBox(height: 20),
              const Text(
                'شركة يمن سيلو',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: _purple,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'YEMEN SELOO',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 3.5,
                  color: _purple,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'وسيطك الموثوق للتسوق العالمي',
                style: TextStyle(fontSize: 13, color: T.muted),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: T.soft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: T.softBorder),
                ),
                child: Column(
                  children: <Widget>[
                    const Icon(Icons.info_outline, color: _purple, size: 28),
                    const SizedBox(height: 10),
                    const Text(
                      'تصفّح منتجات SHEIN، أضفها إلى سلتك، وأكّد طلبك بسهولة عبر التطبيق.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, height: 1.6),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Get.toNamed('/shein'),
                            icon: const Icon(Icons.explore_outlined, size: 16),
                            label: const Text('تصفّح المتجر'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Get.toNamed(AppRoutes.cart),
                            icon: const Icon(Icons.shopping_cart_outlined,
                                size: 16),
                            label: const Text('عرض السلة'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _ServiceTile(
                      icon: Icons.shopping_bag_outlined,
                      title: 'تسوّق SHEIN',
                      onTap: () => Get.find<MainTabController>().goTo(1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ServiceTile(
                      icon: Icons.currency_exchange,
                      title: 'تسعير شفاف',
                      onTap: () => Get.toNamed(AppRoutes.profile),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _ServiceTile(
                      icon: Icons.local_shipping_outlined,
                      title: 'شحن موثوق',
                      onTap: () => Get.find<MainTabController>().goTo(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ServiceTile(
                      icon: Icons.support_agent,
                      title: 'دعم مباشر',
                      onTap: () => Get.find<MainTabController>().goTo(4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _purple,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.phone, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'للتواصل: 770518757',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceItem extends StatelessWidget {
  const _ServiceItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: T.soft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: T.softBorder),
            ),
            child: Icon(icon, color: _purple, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                      fontSize: 12, color: T.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// بطاقة خدمة بأسلوب الويب: مربع أيقونة 44×44 وخلفية ناعمة وحد بنفسجي رفيع.
class _ServiceTile extends StatelessWidget {
  const _ServiceTile(
      {required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: T.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: T.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: T.softBorder),
            ),
            child: Icon(icon, size: 22, color: T.primary),
          ),
          const SizedBox(height: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w800, color: T.text)),
        ],
      ),
      ),
    );
  }
}
