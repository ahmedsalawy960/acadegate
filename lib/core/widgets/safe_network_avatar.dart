import 'package:flutter/material.dart';

/// Circle photo that does not dump a red NetworkImage exception on Chrome
/// when Firebase Storage CORS blocks CanvasKit fetches (statusCode 0).
class SafeNetworkAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Widget fallback;

  const SafeNetworkAvatar({
    super.key,
    required this.imageUrl,
    required this.fallback,
    this.radius = 16,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.white.withValues(alpha: 0.2),
      child: url.isEmpty
          ? fallback
          : ClipOval(
              child: Image.network(
                url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                errorBuilder: (_, _, _) => Center(child: fallback),
              ),
            ),
    );
  }
}
