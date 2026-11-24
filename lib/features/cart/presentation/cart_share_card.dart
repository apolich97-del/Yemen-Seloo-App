import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/services/cart_share.dart';
import '../../../core/theme/app_theme.dart';

/// بطاقة «رابط السلة كاملة»: نسخ الرابط أو فتح السلة.
class CartShareCard extends StatelessWidget {
  const CartShareCard({super.key, required this.url, this.title = 'رابط السلة كاملة'});

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: T.primary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: T.muted)),
          if (CartShare.tokenFromUrl(url).isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'الرمز: ${CartShare.tokenFromUrl(url)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9.5, color: T.muted),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.copy, size: 15),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(
                        text: CartShare.tokenFromUrl(url)));
                    Get.snackbar('تم النسخ',
                        'الصق الرمز في نافذة «استيراد سلة شي ان»');
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    Get.snackbar('تم النسخ', 'رابط السلة كاملة جاهز للمشاركة');
                  },
                  icon: const Icon(Icons.copy_all_outlined, size: 16),
                  label: const Text('نسخ رابط السلة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Get.toNamed(AppRoutes.cart),
                  icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                  label: const Text('فتح السلة كاملة'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
