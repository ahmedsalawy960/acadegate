import 'package:flutter/material.dart';

/// نظام ألوان واجهة المتجر — ماركت بليس محايد (ليس أخضر/أزرق تطبيق).
class StoreTheme {
  StoreTheme._();

  static const Color bg = Color(0xFFF4F4F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF18181B);
  static const Color muted = Color(0xFF71717A);
  static const Color border = Color(0xFFE4E4E7);
  static const Color hairline = Color(0xFFD4D4D8);

  /// لون إجراء الشراء / السعر (كهرماني تجاري).
  static const Color accent = Color(0xFFC2410C);
  static const Color accentHover = Color(0xFF9A3412);
  static const Color accentSoft = Color(0xFFFFF7ED);

  /// شريط علوي فاتح — واجهة متجر نهارية (بدون خلفية سوداء ثقيلة).
  static const Color appBar = Color(0xFFFFFFFF);
  static const Color appBarForeground = ink;

  static const Color verified = Color(0xFF0F766E);
  static const Color danger = Color(0xFFB91C1C);

  static ThemeData overlay(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: ink,
        surface: surface,
        onPrimary: Colors.white,
        onSurface: ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: appBar,
        foregroundColor: appBarForeground,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: accentSoft,
        side: const BorderSide(color: border),
        labelStyle: const TextStyle(color: ink, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: hairline,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: hairline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
      dividerColor: border,
    );
  }

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      );

  static TextStyle get sectionTitle => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: ink,
        letterSpacing: -0.2,
      );

  static TextStyle get sectionSubtitle => const TextStyle(
        fontSize: 12.5,
        color: muted,
        height: 1.35,
      );

  static TextStyle get priceStyle => const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: accent,
      );
}
