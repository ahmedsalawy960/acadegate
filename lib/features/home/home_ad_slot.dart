import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/theme/acadegate_theme.dart';
import 'home_feed_models.dart';
import 'home_route_navigator.dart';

/// خانة إعلان وسط الشبكة — تختار بنراً حسب الترتيب اليومي.
class HomeAdSlot extends StatelessWidget {
  final List<HomePromoBanner> banners;
  final HomeRouteResolver? resolveRoute;
  final String placementLabel;

  const HomeAdSlot({
    super.key,
    required this.banners,
    this.resolveRoute,
    this.placementLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) return const SizedBox.shrink();
    final banner = banners.first;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: AcadeGateColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => openHomePromoTarget(
            context,
            banner,
            resolveRoute: resolveRoute,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AcadeGateColors.line),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: banner.imageUrl.isEmpty
                        ? ColoredBox(
                            color: AcadeGateColors.gold.withValues(alpha: 0.16),
                            child: const Icon(
                              Icons.campaign_rounded,
                              color: AcadeGateColors.gold,
                            ),
                          )
                        : Image.network(
                            banner.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: AcadeGateColors.gold.withValues(alpha: 0.16),
                              child: const Icon(
                                Icons.campaign_rounded,
                                color: AcadeGateColors.gold,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AcadeGateColors.gold.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              context.t('إعلان', 'Ad'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AcadeGateColors.gold,
                              ),
                            ),
                          ),
                          if (placementLabel.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              placementLabel,
                              style: TextStyle(
                                fontSize: 10,
                                color: const Color(0xFFB7C3D6),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        banner.title(arabic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AcadeGateColors.text,
                          fontSize: 15,
                        ),
                      ),
                      if (banner.subtitle(arabic).isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          banner.subtitle(arabic),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFFB7C3D6),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AcadeGateColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
