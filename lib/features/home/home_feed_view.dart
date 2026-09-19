import 'package:flutter/material.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/locale/l10n_lookup.dart';
import '../../core/widgets/app_site_footer.dart';
import '../../core/widgets/arrow_scroll_view.dart';
import '../research_journey/thesis_progress_home_card.dart';
import 'dashboard_card.dart';
import 'home_ad_slot.dart';
import 'home_feed_models.dart';
import 'home_feed_seed.dart';
import 'home_feed_service.dart';
import 'home_feature_highlights.dart';
import 'home_features_carousel.dart';
import 'home_for_you_strip.dart';
import 'home_route_navigator.dart';

/// يبني الـ Feed المرن للصفحة الرئيسية حسب أقسام Firestore.
class HomeFeedView extends StatelessWidget {
  final List<Map<String, dynamic>> services;
  final HomeFeedSnapshot feed;

  const HomeFeedView({
    super.key,
    required this.services,
    required this.feed,
  });

  HomeRouteResolver get _resolver {
    final byId = <String, Widget>{};
    for (final s in services) {
      final id = s['id']?.toString();
      final screen = s['screen'];
      if (id != null && screen is Widget) {
        byId[id] = screen;
      }
    }
    return (key) {
      final k = key.trim().toLowerCase();
      if (k == 'supervisors' || k == 'faculties') {
        return byId['supervisors'];
      }
      return byId[k] ?? screenForHomeRoute(k);
    };
  }

  List<HomeSection> get _sections {
    final raw = feed.sections;
    if (HomeFeedSeed.looksChunked(raw)) {
      return HomeFeedSeed.defaultSections();
    }
    return raw;
  }

  List<Map<String, dynamic>> _sliceServices(HomeSection section) {
    var list = List<Map<String, dynamic>>.from(services);
    if (section.serviceKeys.isNotEmpty) {
      final byId = {
        for (final s in services) s['id']?.toString() ?? '': s,
      };
      list = [
        for (final key in section.serviceKeys)
          if (byId[key] != null) byId[key]!,
      ];
    }
    final offset = section.offset ?? 0;
    if (offset > 0) {
      list = offset >= list.length
          ? <Map<String, dynamic>>[]
          : list.sublist(offset);
    }
    final limit = section.limit;
    if (limit != null && limit > 0 && list.length > limit) {
      list = list.take(limit).toList();
    }
    return list;
  }

  static const _legacyServiceMirrorAdIds = {
    'ad_writing',
    'ad_store',
    'ad_community',
    'ad_fund',
  };

  List<HomePromoBanner> _adsForPlacement(String placement) {
    final feedService = HomeFeedService.instance;
    var ads = feed.bannersFor(placement);
    // خانات الوسط: إعلان مستقل فقط — ليس نسخة من بطاقة قسم.
    if (placement.startsWith('mid')) {
      ads = ads
          .where((b) => b.isSponsoredAd)
          .where((b) => !_legacyServiceMirrorAdIds.contains(b.id))
          .toList();
      if (ads.isEmpty) {
        ads = HomeFeedSeed.defaultBanners()
            .where((b) => b.placement == placement && b.isSponsoredAd)
            .toList();
      }
    }
    return feedService.rotateForDisplay(ads);
  }

  void _appendServiceGrid(
    List<Widget> slivers,
    HomeSection section,
    HomeRouteResolver resolver,
    int columns,
    double extent,
  ) {
    final slice = _sliceServices(section);
    if (slice.isEmpty) return;

    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            L10nLookup.availableServices,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
        ),
      ),
    );

    final breaks = section.adBreaks.isNotEmpty
        ? section.adBreaks
        : const <int>[4, 8];
    final placements = section.adPlacements.isNotEmpty
        ? section.adPlacements
        : const <String>['mid_1', 'mid_2'];

    var start = 0;
    for (var i = 0; i <= breaks.length; i++) {
      final end = i < breaks.length
          ? breaks[i].clamp(0, slice.length)
          : slice.length;
      if (end > start) {
        final batch = slice.sublist(start, end);
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 8),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: extent,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = batch[index];
                  return DashboardCard(
                    title: item['title'] as String,
                    imageUrl: item['imageUrl'] as String? ?? '',
                    assetFallback: item['assetFallback'] as String?,
                    icon: item['icon'] as IconData,
                    color: item['color'] as Color,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => item['screen'] as Widget,
                      ),
                    ),
                  );
                },
                childCount: batch.length,
              ),
            ),
          ),
        );
      }

      if (i < breaks.length && i < placements.length) {
        final ads = _adsForPlacement(placements[i]);
        if (ads.isNotEmpty) {
          slivers.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: HomeAdSlot(
                  banners: ads.take(1).toList(),
                  resolveRoute: resolver,
                ),
              ),
            ),
          );
        }
      }
      start = end;
    }
  }

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveLayout.homeGridColumns(context);
    final extent = ResponsiveLayout.homeCardExtent(context);
    final resolver = _resolver;
    final slivers = <Widget>[];

    for (final section in _sections) {
      switch (section.type) {
        case HomeSectionType.heroCarousel:
          // أبرز مزايا المنصة (صور + عناوين) — ليست تكراراً لأيقونات الأقسام.
          slivers.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: HomeFeaturesCarousel(
                  features: HomeFeatureHighlights.topTen(),
                  resolveRoute: resolver,
                ),
              ),
            ),
          );
          break;
        case HomeSectionType.journey:
          slivers.add(
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: ThesisProgressHomeCard(),
              ),
            ),
          );
          break;
        case HomeSectionType.forYou:
          slivers.add(
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: HomeForYouStrip(),
              ),
            ),
          );
          break;
        case HomeSectionType.servicesGrid:
          _appendServiceGrid(slivers, section, resolver, columns, extent);
          break;
        case HomeSectionType.adSlot:
          // تجاهل خانات الإعلان المنفصلة القديمة — الإعلان يُدرج داخل شبكة الخدمات.
          break;
        case HomeSectionType.matchPromo:
          // أُزيلت شريحة المطابقة الذكية من الصفحة الرئيسية — غير ضرورية.
          break;
        case HomeSectionType.footer:
          slivers.add(const SliverToBoxAdapter(child: AppSiteFooter()));
          break;
        case HomeSectionType.unknown:
          break;
      }
    }

    if (!_sections.any((s) => s.type == HomeSectionType.footer)) {
      slivers.add(const SliverToBoxAdapter(child: AppSiteFooter()));
    }

    return ArrowOverlayScroller(
      builder: (context, controller) => CustomScrollView(
        controller: controller,
        slivers: slivers,
      ),
    );
  }
}
