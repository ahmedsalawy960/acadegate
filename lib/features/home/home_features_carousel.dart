import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/widgets/arrow_scroll_view.dart';
import '../../core/widgets/section_cover_image.dart';
import 'home_feature_highlights.dart';
import 'home_route_navigator.dart';

/// كاروسيل علوي: أهم مزايا التطبيق — صورة + عنوان أسفلها، مع تمرير تلقائي.
class HomeFeaturesCarousel extends StatefulWidget {
  final List<HomeFeatureHighlight> features;
  final HomeRouteResolver? resolveRoute;

  const HomeFeaturesCarousel({
    super.key,
    required this.features,
    this.resolveRoute,
  });

  @override
  State<HomeFeaturesCarousel> createState() => _HomeFeaturesCarouselState();
}

class _HomeFeaturesCarouselState extends State<HomeFeaturesCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.58);
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant HomeFeaturesCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.features.length != widget.features.length) {
      _index = 0;
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.features.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.features.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _goPage(int delta) async {
    if (widget.features.length < 2 || !_controller.hasClients) return;
    final next =
        (_index + delta + widget.features.length) % widget.features.length;
    await _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
    _restartTimer();
  }

  Future<void> _open(HomeFeatureHighlight feature) async {
    final screen =
        widget.resolveRoute?.call(feature.linkTarget) ??
        screenForHomeRoute(feature.linkTarget);
    if (screen == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final features = widget.features;
    if (features.isEmpty) return const SizedBox.shrink();
    final arabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('أبرز مزايا AcadeGate', 'AcadeGate highlights'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFF4F7FB),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.t(
            'استخدم الأسهم يميناً ويساراً لاكتشاف أهم إمكانيات المنصة',
            'Use the left and right arrows to explore the top capabilities',
          ),
          style: TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 188,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
            controller: _controller,
            itemCount: features.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final feature = features[i];
              final active = i == _index;
              return AnimatedScale(
                scale: active ? 1.0 : 0.94,
                duration: const Duration(milliseconds: 220),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _open(feature),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: _FeatureImage(url: feature.imageUrl),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            feature.title(arabic),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                              color: const Color(0xFFB7C3D6),
                            ),
                          ),
                          if (feature.subtitle(arabic).isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              feature.subtitle(arabic),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(0xFFB7C3D6),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
              CarouselNavArrows(
                show: features.length > 1,
                onPrevious: () => _goPage(-1),
                onNext: () => _goPage(1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(features.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: active ? 14 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF1A237E)
                    : Colors.grey.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _FeatureImage extends StatelessWidget {
  final String url;

  const _FeatureImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('assets/')) {
      return SectionCoverImage(
        url,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => _fallback(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFFE8EAF6),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFF1A237E).withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: const Color(0xFFF4F7FB)),
    );
  }
}
