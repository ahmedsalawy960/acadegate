import 'package:flutter/material.dart';

/// Cover raster with the same filter settings on Windows and Chrome.
class SectionCoverImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final double? width;
  final double? height;
  final ImageErrorWidgetBuilder? errorBuilder;

  const SectionCoverImage(
    this.path, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      filterQuality: FilterQuality.medium,
      isAntiAlias: true,
      gaplessPlayback: true,
      errorBuilder: (context, error, stack) {
        final alt = _altCasing(path);
        if (alt != null) {
          return Image.asset(
            alt,
            fit: fit,
            alignment: alignment,
            width: width,
            height: height,
            filterQuality: FilterQuality.medium,
            isAntiAlias: true,
            gaplessPlayback: true,
            errorBuilder: errorBuilder,
          );
        }
        return errorBuilder?.call(context, error, stack) ??
            const SizedBox.shrink();
      },
    );
  }

  /// Windows is case-insensitive; Chrome/web asset URLs are not.
  static String? _altCasing(String path) {
    if (path.startsWith('assets/')) {
      return 'Assets/${path.substring(7)}';
    }
    if (path.startsWith('Assets/')) {
      return 'assets/${path.substring(7)}';
    }
    return null;
  }
}
