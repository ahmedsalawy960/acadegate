import 'package:flutter/material.dart';

/// تخطيط متجاوب — هاتف / تابلت / سطح مكتب.
class ResponsiveLayout {
  ResponsiveLayout._();

  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 600 && w < 1100;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1100;

  /// أعمدة شبكة الخدمات على الرئيسية.
  static int homeGridColumns(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1200) return 4;
    if (w >= 800) return 3;
    return 2;
  }

  static double homeCardExtent(BuildContext context) {
    if (isDesktop(context)) return 172;
    if (isTablet(context)) return 168;
    return 164;
  }

  /// عرض أقصى للمحتوى على الشاشات العريضة (يبقى مريحاً على iPad/Mac).
  static double contentMaxWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1400) return 1200;
    if (w >= 900) return 960;
    return w;
  }

  static Widget constrainContent(BuildContext context, Widget child) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: contentMaxWidth(context),
        ),
        child: child,
      ),
    );
  }
}
