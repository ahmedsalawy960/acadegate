import 'package:flutter/material.dart';

/// Native logo raster width (do not upscale beyond this for sharpness).
const _logoNativeWidth = 512.0;
const _iconCropFactor = 0.50;

/// AcadeGate brand mark — official PNG asset (512px).
class AcadeGateLogo extends StatelessWidget {
  const AcadeGateLogo({
    super.key,
    this.size = 120,
    this.showShadow = true,
    this.variant = AcadeGateLogoVariant.full,
  });

  final double size;
  final bool showShadow;
  final AcadeGateLogoVariant variant;

  static const assetPath = 'assets/images/acadegate_logo_2x.png';

  static const _navy = Color(0xFF1A237E);
  static const _navyLight = Color(0xFF283593);

  @override
  Widget build(BuildContext context) {
    final markWidth = size.clamp(64.0, _logoNativeWidth);

    final content = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navyLight, _navy],
        ),
      ),
      child: Center(
        child: _LogoMarkImage(
          width: markWidth * 0.9,
          cropFromTop: variant == AcadeGateLogoVariant.compact ? 0.55 : _iconCropFactor,
        ),
      ),
    );

    if (!showShadow) return content;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.18),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.28),
            blurRadius: size * 0.1,
            offset: Offset(0, size * 0.04),
          ),
        ],
      ),
      child: content,
    );
  }
}

enum AcadeGateLogoVariant { full, compact }

class _LogoMarkImage extends StatelessWidget {
  const _LogoMarkImage({
    required this.width,
    required this.cropFromTop,
  });

  final double width;
  final double cropFromTop;

  @override
  Widget build(BuildContext context) {
    // Render at native resolution then downscale only (never upscale).
    final renderWidth = width > _logoNativeWidth ? _logoNativeWidth : width;

    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: cropFromTop,
        child: Image.asset(
          AcadeGateLogo.assetPath,
          width: renderWidth,
          fit: BoxFit.fitWidth,
          filterQuality: FilterQuality.high,
          cacheWidth: _logoNativeWidth.toInt(),
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('AcadeGate logo asset error: $error');
            return Icon(
              Icons.image_not_supported_outlined,
              size: renderWidth * 0.4,
              color: const Color(0xFFD4A853),
            );
          },
        ),
      ),
    );
  }
}

/// Logo + wordmark + tagline for auth screens.
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

  static const _navy = Color(0xFF1A237E);
  static const _gold = Color(0xFFE8C468);

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final resolvedTagline = tagline ?? (isAr ? taglineAr : taglineEn);
    final markWidth = (logoSize * 1.85).clamp(120.0, _logoNativeWidth);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: logoSize * 0.16,
          vertical: logoSize * 0.18,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF283593), _navy],
          ),
          boxShadow: [
            BoxShadow(
              color: _navy.withValues(alpha: 0.22),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LogoMarkImage(
              width: markWidth,
              cropFromTop: _iconCropFactor,
            ),
            SizedBox(height: logoSize * 0.08),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Acade',
                    style: TextStyle(
                      fontSize: logoSize * 0.30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.6,
                      height: 1.1,
                    ),
                  ),
                  TextSpan(
                    text: 'Gate',
                    style: TextStyle(
                      fontSize: logoSize * 0.30,
                      fontWeight: FontWeight.w900,
                      color: _gold,
                      letterSpacing: 0.6,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            if (showTagline) ...[
              SizedBox(height: logoSize * 0.1),
              Text(
                resolvedTagline,
                textAlign: TextAlign.center,
                textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                style: TextStyle(
                  fontSize: logoSize * 0.17,
                  color: Colors.white,
                  height: 1.4,
                  fontWeight: FontWeight.w800,
                  letterSpacing: isAr ? 0.2 : 0.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
