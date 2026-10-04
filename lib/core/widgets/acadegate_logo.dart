import 'package:flutter/material.dart';

/// Native logo raster width (do not upscale beyond this for sharpness).
const _logoNativeWidth = 512.0;

/// AcadeGate brand mark — circular badge (icon + wordmark).
class AcadeGateLogo extends StatelessWidget {
  const AcadeGateLogo({
    super.key,
    this.size = 120,
    this.showShadow = true,
    this.variant = AcadeGateLogoVariant.full,
  });

  final double size;
  final bool showShadow;

  /// Kept for existing call sites. Full and compact both show the complete badge.
  final AcadeGateLogoVariant variant;

  static const assetPath = 'assets/images/acadegate_logo_2x.png';

  static const _navy = Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    assert(
      variant == AcadeGateLogoVariant.full ||
          variant == AcadeGateLogoVariant.compact,
    );
    final mark = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      cacheWidth: size >= _logoNativeWidth ? null : _logoNativeWidth.toInt(),
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('AcadeGate logo asset error: $error');
        return Icon(
          Icons.school_outlined,
          size: size * 0.6,
          color: const Color(0xFFC4A35A),
        );
      },
    );

    if (!showShadow) return mark;

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.22),
            blurRadius: size * 0.08,
            offset: Offset(0, size * 0.03),
          ),
        ],
      ),
      child: mark,
    );
  }
}

enum AcadeGateLogoVariant { full, compact }

/// Logo + tagline for auth screens. The badge already includes the wordmark.
class AcadeGateLogoHeader extends StatelessWidget {
  const AcadeGateLogoHeader({
    super.key,
    this.logoSize = 110,
    this.showTagline = true,
    this.tagline,
    this.taglineAr = 'بوابتك للتميز في الدراسات العليا',
    this.taglineEn = 'Your gateway to excellence in postgraduate studies',
  });

  final double logoSize;
  final bool showTagline;
  final String? tagline;
  final String taglineAr;
  final String taglineEn;

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final resolvedTagline = tagline ?? (isAr ? taglineAr : taglineEn);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AcadeGateLogo(size: logoSize),
        if (showTagline) ...[
          SizedBox(height: logoSize * 0.12),
          Text(
            resolvedTagline,
            textAlign: TextAlign.center,
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(
              fontSize: logoSize * 0.15,
              color: const Color(0xFFF4F7FB),
              height: 1.4,
              fontWeight: FontWeight.w800,
              letterSpacing: isAr ? 0.2 : 0.1,
            ),
          ),
        ],
      ],
    );
  }
}
