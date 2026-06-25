import 'package:flutter/material.dart';

/// صورة توضيحية للقسم مع أيقونة صغيرة — للمتجر وخدمات الكتابة.
class CategoryVisual extends StatelessWidget {
  final String imageUrl;
  final IconData icon;
  final Color color;
  final double height;
  final BorderRadius borderRadius;

  const CategoryVisual({
    super.key,
    required this.imageUrl,
    required this.icon,
    required this.color,
    this.height = 72,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(16)),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: color.withValues(alpha: 0.08),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (_, _, _) => _tintedFallback(),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            PositionedDirectional(
              end: 8,
              bottom: 8,
              child: _iconBadge(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tintedFallback() {
    return Container(
      color: color.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _iconBadge() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }
}
