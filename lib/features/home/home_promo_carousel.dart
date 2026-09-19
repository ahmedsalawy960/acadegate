import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/widgets/arrow_scroll_view.dart';
import 'home_feed_models.dart';
import 'home_route_navigator.dart';

class HomePromoCarousel extends StatefulWidget {
  final List<HomePromoBanner> banners;
  final HomeRouteResolver? resolveRoute;
  final double height;

  const HomePromoCarousel({
    super.key,
    required this.banners,
    this.resolveRoute,
    this.height = 168,
  });

  @override
  State<HomePromoCarousel> createState() => _HomePromoCarouselState();
}

class _HomePromoCarouselState extends State<HomePromoCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.94);
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant HomePromoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _index = 0;
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.banners.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.banners.length;
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
    if (widget.banners.length < 2 || !_controller.hasClients) return;
    final next =
        (_index + delta + widget.banners.length) % widget.banners.length;
    await _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
    _restartTimer();
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    if (banners.isEmpty) return const SizedBox.shrink();
    final arabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final banner = banners[i];
              final color = Color(banner.accentColor);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => openHomePromoTarget(
                      context,
                      banner,
                      resolveRoute: widget.resolveRoute,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (banner.imageUrl.isNotEmpty)
                            Image.network(
                              banner.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  Container(color: color.withValues(alpha: 0.85)),
                            )
                          else
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    color,
                                    color.withValues(alpha: 0.75),
                                  ],
                                ),
                              ),
                            ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: AlignmentDirectional.centerStart,
                                end: AlignmentDirectional.centerEnd,
                                colors: [
                                  Colors.black.withValues(alpha: 0.72),
                                  Colors.black.withValues(alpha: 0.25),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  banner.title(arabic),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (banner.subtitle(arabic).isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    banner.subtitle(arabic),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.92),
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    banner.cta(arabic),
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
              CarouselNavArrows(
                show: banners.length > 1,
                onPrevious: () => _goPage(-1),
                onNext: () => _goPage(1),
              ),
            ],
          ),
        ),
        if (banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(banners.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 16 : 6,
                height: 6,
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
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            context.t('عروض مميزة تتجدد يومياً', 'Featured offers refresh daily'),
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }
}
