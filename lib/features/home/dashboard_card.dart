import 'package:flutter/material.dart';

/// روابط صور حيّة لكل قسم في الشاشة الرئيسية.
class HomeServiceImages {
  HomeServiceImages._();

  /// المشرفون الأكاديميون — صورة مولَّدة (مشرفون بحثيون)
  static const supervisors = 'assets/images/supervisors_card.png';
  static const ideas =
      'https://images.unsplash.com/photo-1507413245160-754ec704b2d6?auto=format&fit=crop&w=800&h=500&q=80';
  static const labs =
      'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?auto=format&fit=crop&w=800&h=500&q=80';
  static const shop =
      'https://images.unsplash.com/photo-1582719471133-c3967ffa1c42?auto=format&fit=crop&w=800&h=500&q=80';
  static const community =
      'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?auto=format&fit=crop&w=800&h=500&q=80';
  static const aiAdvisor =
      'https://images.unsplash.com/photo-1677442136019-21780ecad995?auto=format&fit=crop&w=800&h=500&q=80';
  static const scienceNews =
      'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=800&h=500&q=80';
  /// صندوق تمويل البحث — استثمار وتمويل أكاديمي
  static const researchFund =
      'https://images.unsplash.com/photo-1579621970563-ebec7560ff3e?auto=format&fit=crop&w=800&h=500&q=80';
  /// خدمات الكتابة — كتابة ومسودة أكاديمية
  static const writingServices =
      'https://images.unsplash.com/photo-1455390582262-044cdead277a?auto=format&fit=crop&w=800&h=500&q=80';
  /// AcadeGate Publish — نشر ومجلات علمية
  static const publish =
      'https://images.unsplash.com/photo-1507842217343-583bb7270b66?auto=format&fit=crop&w=800&h=500&q=80';
  /// مسار البحث الذكي — شبكة مترابطة (تناسب أيقونة account_tree)
  static const researchPath =
      'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?auto=format&fit=crop&w=800&h=500&q=80';
  /// نزاهة أكاديمية — ميزان العدل والأمانة
  static const integrity =
      'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?auto=format&fit=crop&w=800&h=500&q=80';
  static const matchmaking =
      'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?auto=format&fit=crop&w=800&h=500&q=80';
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
          elevation: 1.5,
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
                        Icon(icon, size: 17, color: color),
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
          Image.asset(
            imageUrl,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, _, _) {
              if (assetFallback != null) {
                return Image.asset(
                  assetFallback!,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
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
                return Image.asset(
                  assetFallback!,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
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
      child: Icon(icon, color: color, size: 32),
    );
  }
}
