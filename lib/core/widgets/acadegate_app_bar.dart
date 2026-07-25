import 'package:flutter/material.dart';

import '../locale/locale_extensions.dart';

/// App bar with an explicit back button whenever [Navigator.canPop] is true.
class AcadeGateAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool? centerTitle;
  final PreferredSizeWidget? bottom;
  final double? elevation;
  final double? scrolledUnderElevation;
  final IconThemeData? iconTheme;
  final IconThemeData? actionsIconTheme;
  final TextStyle? titleTextStyle;
  final ShapeBorder? shape;

  const AcadeGateAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.showBackButton = true,
    this.backgroundColor,
    this.foregroundColor,
    this.centerTitle,
    this.bottom,
    this.elevation,
    this.scrolledUnderElevation,
    this.iconTheme,
    this.actionsIconTheme,
    this.titleTextStyle,
    this.shape,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    Widget? effectiveLeading = leading;

    if (effectiveLeading == null && showBackButton && canPop) {
      effectiveLeading = IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: context.t('رجوع', 'Back'),
        onPressed: () => Navigator.maybePop(context),
      );
    }

    return AppBar(
      title: title,
      actions: actions,
      leading: effectiveLeading,
      automaticallyImplyLeading: false,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      centerTitle: centerTitle,
      bottom: bottom,
      elevation: elevation,
      scrolledUnderElevation: scrolledUnderElevation,
      iconTheme: iconTheme,
      actionsIconTheme: actionsIconTheme,
      titleTextStyle: titleTextStyle,
      shape: shape,
    );
  }

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }
}
