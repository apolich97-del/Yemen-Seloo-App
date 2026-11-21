import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/order.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/review_service.dart';
import '../../core/theme/app_theme.dart';

/// نموذج تقييم الطلب بعد الاستلام — بصورة استلام إلزامية.
Future<void> showReviewDialog(Order order) async {
  final rating = 5.obs;
  final text = TextEditingController();
  final gov = TextEditingController(text: order.address.city);
  final tags = <String>{}.obs;
  var photo = '';
  const quickTags = <String>[
    'وصل بسرعة',
    'جودة ممتازة',
    'مطابق للوصف',
    'تغليف جيد',
    'خدمة راقية',
    'السعر مناسب',
  ];

  await Get.dialog(
    StatefulBuilder(builder: (context, setLocal) {
      return AlertDialog(
        backgroundColor: T.card,
        title: Text('قيّم طلبك ${order.orderNo}',
            style: TextStyle(fontSize: 14, color: T.text)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return IconButton(
                        onPressed: () => rating.value = i + 1,
                        icon: Icon(
                            i < rating.value ? Icons.star : Icons.star_border,
                            color: T.warning,
                            size: 26),
                      );
                    }),
                  )),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: quickTags
                    .map((t) => FilterChip(
                          label: Text(t, style: const TextStyle(fontSize: 10.5)),
                          selected: tags.contains(t),
                          onSelected: (v) =>
                              v ? tags.add(t) : tags.remove(t),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: text,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'اكتب تجربتك', hintText: 'ما أعجبك وما يمكن تحسينه؟'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: gov,
                decoration: const InputDecoration(labelText: 'المحافظة'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final x = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 40,
                      maxWidth: 900);
                  if (x == null) return;
                  final bytes = await x.readAsBytes();
                  final mime = x.path.toLowerCase().endsWith('.png')
                      ? 'image/png'
                      : 'image/jpeg';
                  photo = 'data:$mime;base64,${base64Encode(bytes)}';
                  setLocal(() {});
                },
                icon: Icon(
                    photo.isEmpty
                        ? Icons.add_photo_alternate_outlined
                        : Icons.check_circle_outline,
                    size: 16),
                label: Text(
                    photo.isEmpty
                        ? 'إرفاق صورة الاستلام (إلزامي)'
                        : 'تم إرفاق صورة الاستلام',
                    style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (photo.isEmpty) {
                Get.snackbar('صورة مطلوبة', 'أرفق صورة الاستلام قبل الإرسال');
                return;
              }
              final name = Get.isRegistered<AuthService>()
                  ? (Get.find<AuthService>().user.value?.displayName ?? '')
                  : '';
              await Get.put(ReviewService(), permanent: false).submit(
                orderId: order.id,
                orderNo: order.orderNo,
                rating: rating.value,
                tags: tags.toList(),
                text: text.text.trim(),
                governorate: gov.text.trim(),
                photoData: photo,
                customerName: name,
              );
              Get.back();
              Get.snackbar('شكراً لك',
                  'تقييمك وصل وسيُنشر بعد مراجعة الإدارة');
            },
            child: const Text('إرسال التقييم'),
          ),
        ],
      );
    }),
  );
}
