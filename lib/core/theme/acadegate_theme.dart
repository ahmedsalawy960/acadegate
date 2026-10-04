import 'package:flutter/material.dart';

/// Navy shell. Page is the cover blue; cards sit one step lighter so
/// photos, icons, and text stay separate from the background.
class AcadeGateColors {
  AcadeGateColors._();

  static const page = Color(0xFF071433);
  static const card = Color(0xFF12284F);
  static const appBar = Color(0xFF0B1F4D);
  static const text = Color(0xFFF4F7FB);
  static const muted = Color(0xFFB7C3D6);
  static const gold = Color(0xFFFBBF24);
  static const action = Color(0xFF3949AB);
  static const line = Color(0xFF2A3F6E);
}

/// Dark accent colors disappear on the navy page. Lift them toward the text color.
Color acadegateInk(Color color) {
  if (color.computeLuminance() >= 0.45) return color;
  return Color.lerp(color, AcadeGateColors.text, 0.72)!;
}

ThemeData acadegateTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    visualDensity: VisualDensity.standard,
  );
  return base.copyWith(
    scaffoldBackgroundColor: AcadeGateColors.page,
    canvasColor: AcadeGateColors.page,
    dividerColor: AcadeGateColors.line,
    iconTheme: const IconThemeData(color: AcadeGateColors.text),
    colorScheme: const ColorScheme.dark(
      primary: AcadeGateColors.action,
      onPrimary: AcadeGateColors.text,
      secondary: AcadeGateColors.gold,
      onSecondary: AcadeGateColors.page,
      surface: AcadeGateColors.card,
      onSurface: AcadeGateColors.text,
      surfaceTint: Colors.transparent,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AcadeGateColors.text,
      displayColor: AcadeGateColors.text,
    ),
    cardTheme: const CardThemeData(
      color: AcadeGateColors.card,
      surfaceTintColor: Colors.transparent,
      shadowColor: Color(0x66000000),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AcadeGateColors.appBar,
      foregroundColor: AcadeGateColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: AcadeGateColors.text),
      actionsIconTheme: IconThemeData(color: AcadeGateColors.text),
      titleTextStyle: TextStyle(
        color: AcadeGateColors.text,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AcadeGateColors.card,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AcadeGateColors.card,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AcadeGateColors.card,
      hintStyle: const TextStyle(color: AcadeGateColors.muted),
      labelStyle: const TextStyle(color: AcadeGateColors.muted),
      prefixIconColor: AcadeGateColors.muted,
      suffixIconColor: AcadeGateColors.muted,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AcadeGateColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AcadeGateColors.gold, width: 1.4),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AcadeGateColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AcadeGateColors.action,
        foregroundColor: AcadeGateColors.text,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AcadeGateColors.text,
        side: const BorderSide(color: AcadeGateColors.text),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AcadeGateColors.text),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AcadeGateColors.gold;
        return AcadeGateColors.muted;
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AcadeGateColors.action;
        return Colors.transparent;
      }),
      checkColor: const WidgetStatePropertyAll(AcadeGateColors.text),
      side: const BorderSide(color: AcadeGateColors.muted),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: AcadeGateColors.text,
      iconColor: AcadeGateColors.text,
      titleTextStyle: TextStyle(
        color: AcadeGateColors.text,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      subtitleTextStyle: TextStyle(color: AcadeGateColors.muted, fontSize: 13),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AcadeGateColors.card,
      disabledColor: AcadeGateColors.card,
      selectedColor: AcadeGateColors.action,
      labelStyle: const TextStyle(color: AcadeGateColors.text, fontSize: 13),
      secondaryLabelStyle: const TextStyle(color: AcadeGateColors.text),
      side: const BorderSide(color: AcadeGateColors.line),
      brightness: Brightness.dark,
    ),
  );
}
