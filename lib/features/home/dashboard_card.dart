import 'package:flutter/material.dart';

import '../../core/assets/weekly_image_rotator.dart';
import '../../core/theme/acadegate_theme.dart';
import '../../core/widgets/section_cover_image.dart';

/// صور أقسام الصفحة الرئيسية — أصلية من مجلد التطبيق وتتبدل أسبوعياً.
class HomeServiceImages {
  HomeServiceImages._();

  static String get supervisors => AcadeGateWeeklyImages.service('supervisors');
  static String get matchmaking => AcadeGateWeeklyImages.service('matchmaking');
  static String get ideas => AcadeGateWeeklyImages.service('ideas');
  static String get researchPath =>
      AcadeGateWeeklyImages.service('research_path');
  static String get labs => AcadeGateWeeklyImages.service('labs');
  static String get humanities => AcadeGateWeeklyImages.service('humanities');
  static String get shop => AcadeGateWeeklyImages.service('store');
  static String get community => AcadeGateWeeklyImages.service('community');
  static String get aiAdvisor => AcadeGateWeeklyImages.service('ai');
  static String get writingServices => AcadeGateWeeklyImages.service('writing');
  static String get thesisStudio =>
      AcadeGateWeeklyImages.service('thesis_studio');
  static String get integrity => AcadeGateWeeklyImages.service('integrity');
  static String get publish => AcadeGateWeeklyImages.service('publish');
  static String get researchFund => AcadeGateWeeklyImages.service('fund');
  static String get scienceNews => AcadeGateWeeklyImages.service('news');
}

class DashboardCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final String? assetFallback;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const DashboardCard({
    super.key,
    required this.title,
    required this.imageUrl,
    this.assetFallback,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageHeight = (constraints.maxWidth * 0.62).clamp(96.0, 112.0);

        return Card(
          color: const Color(0xFF12284F),
          surfaceTintColor: Colors.transparent,
          elevation: 1.5,
          shadowColor: const Color(0x1A000000),
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: imageHeight,
                  child: _ServiceImage(
                    imageUrl: imageUrl,
                    assetFallback: assetFallback,
                    icon: icon,
                    color: color,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(icon, size: 17, color: acadegateInk(color)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                              color: Color(0xFFF4F7FB),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ServiceImage extends StatelessWidget {
  final String imageUrl;
  final String? assetFallback;
  final IconData icon;
  final Color color;

  const _ServiceImage({
    required this.imageUrl,
    required this.assetFallback,
    required this.icon,
    required this.color,
  });

  bool get _isAsset => imageUrl.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_isAsset)
          SectionCoverImage(
            imageUrl,
            errorBuilder: (_, _, _) {
              if (assetFallback != null) {
                return SectionCoverImage(
                  assetFallback!,
                  errorBuilder: (_, _, _) => _iconFallback(),
                );
              }
              return _iconFallback();
            },
          )
        else
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                color: color.withValues(alpha: 0.08),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stack) {
              if (assetFallback != null) {
                return SectionCoverImage(
                  assetFallback!,
                  errorBuilder: (_, _, _) => _iconFallback(),
                );
              }
              return _iconFallback();
            },
          ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.22),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _iconFallback() {
    return Container(
      color: color.withValues(alpha: 0.12),
      child: Icon(icon, color: acadegateInk(color), size: 32),
    );
  }
}
