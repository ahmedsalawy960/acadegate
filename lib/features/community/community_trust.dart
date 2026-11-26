import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';

/// Badge values written by the server for platform roles.
class CommunityBadge {
  CommunityBadge._();

  static const team = 'team';
  static const supervisor = 'supervisor';

  /// Unknown values show nothing, so a forged value never reaches the screen.
  static String? label(BuildContext context, String badge) {
    switch (badge) {
      case team:
        return context.t('فريق AcadeGate', 'AcadeGate team');
      case supervisor:
        return context.t('مشرف أكاديمي', 'Academic supervisor');
      default:
        return null;
    }
  }
}

/// Author name with the server-set badge next to it.
class CommunityAuthorLine extends StatelessWidget {
  const CommunityAuthorLine({
    super.key,
    required this.name,
    required this.badge,
    this.style,
  });

  final String name;
  final String badge;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final label = CommunityBadge.label(context, badge);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(name, style: style, overflow: TextOverflow.ellipsis),
        ),
        if (label != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF00695C).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF00695C)),
            ),
          ),
        ],
      ],
    );
  }
}
