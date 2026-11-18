import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../support/presentation/support_screen.dart';

/// الدليل الإرشادي التفاعلي: بطاقة تظهر مرة واحدة لكل صفحة أو زر.
class InteractiveGuideController extends GetxService {
  static const String _enabledKey = 'guideEnabled';
  static const String _seenKey = 'seenGuideKeys';

  final GetStorage _box = GetStorage();
  final RxBool enabled = true.obs;
  final RxSet<String> seen = <String>{}.obs;

  @override
  void onInit() {
    enabled.value = _box.read<bool>(_enabledKey) ?? true;
    final dynamic raw = _box.read(_seenKey);
    if (raw is List) {
      seen.assignAll(raw.map((dynamic e) => '$e').toSet());
    }
    super.onInit();
  }

  void setEnabled(bool value) {
    enabled.value = value;
    _box.write(_enabledKey, value);
  }

  void reset() {
    seen.clear();
    _box.write(_seenKey, <String>[]);
  }

  bool shouldShow(String key) => enabled.value && !seen.contains(key);

  void markSeen(String key) {
    if (seen.contains(key)) return;
    seen.add(key);
    _box.write(_seenKey, seen.toList());
  }

  /// يعرض البطاقة إن كان الإرشاد مطلوباً.
  Future<void> showIfFirst(
    String key, {
    required String title,
    required String body,
    List<String> steps = const <String>[],
  }) async {
    if (!shouldShow(key)) return;
    markSeen(key);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (Get.isDialogOpen == true) return;
    Get.bottomSheet(
      GuideCard(title: title, body: body, steps: steps),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
    );
  }
}

/// محتوى بطاقة الإرشاد العائم.
class GuideCard extends StatelessWidget {
  const GuideCard({
    super.key,
    required this.title,
    required this.body,
    this.steps = const <String>[],
  });

  final String title;
  final String body;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = dark ? AppDark.cardHigh : Colors.white;
    final Color fg = dark ? AppDark.text : AppColors.ink;
    final Color muted = dark ? AppDark.textMuted : AppColors.muted;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: dark ? AppDark.borderSoft : const Color(0xFFE9E4F5)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.tips_and_updates_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: fg)),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: muted),
                onPressed: Get.back,
              ),
            ],
          ),
          Text(body, style: TextStyle(fontSize: 12, height: 1.7, color: fg)),
          if (steps.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            ...List<Widget>.generate(
              steps.length,
              (int i) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    CircleAvatar(
                      radius: 8,
                      backgroundColor: AppColors.accent.withOpacity(.25),
                      child: Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: fg)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(steps[i],
                          style: TextStyle(
                              fontSize: 11.5, height: 1.5, color: muted)),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton(
                  onPressed: Get.back,
                  child: const Text('فهمت'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Get.back();
                    Get.to(() => const SupportScreen());
                  },
                  child: const Text('الدليل الشامل'),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () {
              if (Get.isRegistered<InteractiveGuideController>()) {
                Get.find<InteractiveGuideController>().setEnabled(false);
              }
              Get.back();
            },
            child: Text('إيقاف الإرشادات',
                style: TextStyle(fontSize: 11, color: muted)),
          ),
        ],
      ),
    );
  }
}

/// زر تبديل الثيم السريع (شمس/قمر).
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ThemeController>()) return const SizedBox.shrink();
    final ThemeController tc = Get.find<ThemeController>();
    return Obx(
      () => IconButton(
        tooltip: tc.isDark.value ? 'الثيم النهاري' : 'الثيم الليلي',
        icon: Icon(tc.isDark.value ? Icons.light_mode : Icons.dark_mode),
        onPressed: () {
          tc.toggle();
          if (Get.isRegistered<InteractiveGuideController>()) {
            Get.find<InteractiveGuideController>().showIfFirst(
              'action_theme',
              title: 'الثيم الليلي',
              body:
                  'بدّلت مظهر التطبيق. الاختيار يُحفظ في جهازك ويعود كما تركته.',
            );
          }
        },
      ),
    );
  }
}

/// يعرض إرشاد صفحة عند أول دخول.
void guideForPage(
  InteractiveGuideController c,
  String key,
  String title,
  String body, {
  List<String> steps = const <String>[],
}) {
  c.showIfFirst(key, title: title, body: body, steps: steps);
}
