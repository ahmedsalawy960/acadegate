import 'package:flutter/material.dart';

import '../theme/acadegate_theme.dart';

/// AcadeGate brand mark — graduation cap only, without the disc or wordmark.
class AcadeGateLogo extends StatelessWidget {
  const AcadeGateLogo({
    super.key,
    this.size = 120,
    this.showShadow = false,
    this.variant = AcadeGateLogoVariant.full,
  });

  final double size;

  /// Kept so older call sites still compile. The disc shadow is not drawn.
  final bool showShadow;

  /// Kept for existing call sites. Full and compact both show the cap.
  final AcadeGateLogoVariant variant;

  static const assetPath = 'assets/images/acadegate_logo_mark.png';

  @override
  Widget build(BuildContext context) {
    assert(
      variant == AcadeGateLogoVariant.full ||
          variant == AcadeGateLogoVariant.compact,
    );
    assert(showShadow || !showShadow);
    return Image.asset(
      assetPath,
      width: size,
      height: size * 0.8,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
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
  }
}

enum AcadeGateLogoVariant { full, compact }

/// اسم العلامة: Acade بالأبيض و Gate بالأصفر، كما في تذييل الصفحة.
class AcadeGateWordmark extends StatelessWidget {
  const AcadeGateWordmark({
    super.key,
    this.fontSize = 22,
    this.letterSpacing = 0.4,
    this.fontWeight = FontWeight.w900,
    this.gateColor = AcadeGateColors.gold,
  });

  final double fontSize;
  final double letterSpacing;
  final FontWeight fontWeight;
  final Color gateColor;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: 1,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Acade',
            style: style.copyWith(color: Colors.white),
          ),
          TextSpan(
            text: 'Gate',
            style: style.copyWith(color: gateColor),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

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
        SizedBox(height: logoSize * 0.08),
        AcadeGateWordmark(fontSize: logoSize * 0.2),
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
