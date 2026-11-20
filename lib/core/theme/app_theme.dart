import 'package:get/get.dart';

import 'theme_controller.dart';
import 'package:flutter/material.dart';

/// هوية «يمن سيلو» — أخضر يمَني غامق + ذهبي، واجهة RTL بالكامل.
class AppColors {
  static const primary = Color(0xFF7C3AED);
  static const primaryDark = Color(0xFF5B21B6);
  static const accent = Color(0xFFC9A227);
  static const surface = Color(0xFFF7F5FB);
  static const ink = Color(0xFF1B1F1D);
  static const muted = Color(0xFF6B7671);
  static const danger = Color(0xFFB3261E);
  static const success = Color(0xFF15803D);
}

/// ألوان مستجيبة للثيم — تُستخدم بدل الألوان الصريحة.
class T {
  /// يعتمد على متحكم الثيم المحفوظ أولاً، ثم على سطوع السياق.
  static bool get dark {
    if (Get.isRegistered<ThemeController>()) {
      return Get.find<ThemeController>().isDark.value;
    }
    return Get.isDarkMode;
  }

  /// خلفية الشاشة.
  static Color get bg => dark ? AppDark.bg : const Color(0xFFF7F5FB);

  /// سطح البطاقات.
  static Color get card => dark ? AppDark.card : const Color(0xFFFFFFFF);

  /// حاوية مميزة (بنفسجي ناعم).
  static Color get soft => dark ? const Color(0xFF16102E) : const Color(0xFFFAF7FF);

  static Color get softBorder =>
      dark ? const Color(0xFF342370) : const Color(0xFFE9D5FF);

  static Color get border =>
      dark ? const Color(0xFF2D2354) : const Color(0xFFE9E4F5);

  static Color get text => dark ? AppDark.text : AppColors.ink;

  static Color get muted => dark ? const Color(0xFFA79CC8) : AppColors.muted;

  static Color get primary =>
      dark ? const Color(0xFFC4B5FD) : AppColors.primary;

  static Color get accent =>
      dark ? const Color(0xFFE0C264) : AppColors.accent;

  /// سطح أعلى قليلاً (حقول، قوائم).
  /// سطح الأشرطة والألواح (الشريط السفلي، التبويبات) — يتبدّل مع الثيم.
  static Color get surface => dark ? const Color(0xFF1A1233) : const Color(0xFFFFFFFF);

  static Color get elevated =>
      dark ? const Color(0xFF1B1536) : const Color(0xFFFFFFFF);
}

class AppDark {
  static const bg = Color(0xFF090714);
  static const card = Color(0xFF130F24);
  static const cardHigh = Color(0xFF1B1536);
  static const border = Color(0xFF2D2354);
  static const borderSoft = Color(0xFF342370);
  static const primary = Color(0xFF5B2EFF);
  static const primarySoft = Color(0xFF7C3AED);
  static const text = Color(0xFFF5F3FF);
  static const textMuted = Color(0xFFC4B5FD);
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: Colors.white,
    );
    final radius = BorderRadius.circular(16);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.surface,
      fontFamily: 'Tajawal',
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: Color(0xFFE6EAE8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDCE3E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDCE3E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFEDF1EF), thickness: 1),
    );
  }

  /// الثيم الليلي بهوية يمن سيلو.
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppDark.primarySoft,
      brightness: Brightness.dark,
      primary: AppDark.primarySoft,
      surface: AppDark.card,
    ).copyWith(
      surface: AppDark.card,
      onSurface: AppDark.text,
      outline: AppDark.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppDark.bg,
      canvasColor: AppDark.bg,
      dividerColor: AppDark.border,
      cardColor: AppDark.card,
      shadowColor: Colors.black54,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppDark.card,
        foregroundColor: AppDark.text,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppDark.card,
        selectedItemColor: AppDark.primarySoft,
        unselectedItemColor: AppDark.textMuted,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppDark.card,
        indicatorColor: AppDark.primarySoft.withOpacity(.25),
        labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 11, color: AppDark.text)),
      ),
      cardTheme: CardTheme(
        color: AppDark.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppDark.border),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppDark.cardHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppDark.cardHigh,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppDark.cardHigh,
        hintStyle: const TextStyle(color: AppDark.textMuted, fontSize: 12),
        labelStyle: const TextStyle(color: AppDark.textMuted, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppDark.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppDark.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppDark.primarySoft, width: 1.4),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppDark.text),
        bodyMedium: TextStyle(color: AppDark.text),
        bodySmall: TextStyle(color: AppDark.textMuted),
        titleLarge: TextStyle(color: AppDark.text, fontWeight: FontWeight.w900),
        titleMedium: TextStyle(color: AppDark.text, fontWeight: FontWeight.w700),
      ),
      iconTheme: const IconThemeData(color: AppDark.textMuted),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppDark.primarySoft,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppDark.text,
          side: const BorderSide(color: AppDark.borderSoft),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppDark.cardHigh,
        selectedColor: AppDark.primarySoft.withOpacity(.28),
        disabledColor: AppDark.card,
        labelStyle: const TextStyle(color: AppDark.text, fontSize: 12),
        secondaryLabelStyle: const TextStyle(color: AppDark.text),
        side: const BorderSide(color: AppDark.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppDark.primarySoft
                : AppDark.textMuted),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppDark.primarySoft.withOpacity(.35)
                : AppDark.cardHigh),
        trackOutlineColor:
            const WidgetStatePropertyAll<Color>(AppDark.border),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppDark.cardHigh,
        surfaceTintColor: Colors.transparent,
        textStyle: const TextStyle(color: AppDark.text, fontSize: 12.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppDark.border),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor:
              const WidgetStatePropertyAll<Color>(AppDark.cardHigh),
          surfaceTintColor:
              const WidgetStatePropertyAll<Color>(Colors.transparent),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppDark.border),
            ),
          ),
        ),
        textStyle: const TextStyle(color: AppDark.text, fontSize: 12.5),
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: AppDark.text,
        unselectedLabelColor: AppDark.textMuted,
      ),
      listTileTheme: const ListTileThemeData(iconColor: AppDark.textMuted),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppDark.cardHigh,
        contentTextStyle: const TextStyle(color: AppDark.text),
        actionTextColor: AppDark.primarySoft,
      ),
    );
  }
}

/// بطاقة قسم موحّدة في شاشات الطلب.
class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: T.text,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// صف «عنوان — قيمة» للملخص المالي.
class MoneyRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool free;
  const MoneyRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
    this.free = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 17 : 14,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: bold ? T.text : T.muted,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: style.copyWith(color: bold ? T.text : T.muted)),
          const Spacer(),
          Text(
            value,
            style: free
                ? style.copyWith(color: AppColors.success, fontWeight: FontWeight.w700)
                : style,
          ),
        ],
      ),
    );
  }
}
