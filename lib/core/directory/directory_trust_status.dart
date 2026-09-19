import 'package:flutter/material.dart';

import '../locale/app_translate.dart';

/// Directory trust lifecycle for suppliers, labs, and similar listings.
///
/// Unverified → Contacted → Confirmed → Claimed → Managed Verified
///
/// "Verified" wording is reserved for [managedVerified] only (admin-approved
/// claim with representation evidence).
class DirectoryTrustStatus {
  DirectoryTrustStatus._();

  static const unverified = 'unverified';
  static const contacted = 'contacted';
  /// Admin confirmed public data / outreach — not a Verified badge.
  static const verified = 'verified';
  /// Self-asserted or legacy ownership without full evidence approval.
  static const claimed = 'claimed';
  /// Admin-approved claim with representation evidence — only status labeled Verified.
  static const managedVerified = 'managed_verified';

  static const all = <String>[
    unverified,
    contacted,
    verified,
    claimed,
    managedVerified,
  ];

  static bool isValid(String? raw) => all.contains(normalize(raw));

  static String normalize(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (all.contains(s)) return s;
    if (s == 'managed' || s == 'managed-verified') return managedVerified;
    // Legacy booleans / partner flags → confirmed, not verified wording
    if (s == 'true' || s == 'partner' || s == 'approved') return verified;
    return unverified;
  }

  /// Prefer explicit [directoryStatus]; else infer from ownership / partner flags.
  static String resolve({
    String? directoryStatus,
    bool isPartner = false,
    bool isVerifiedSeller = false,
    String? ownerId,
    String? claimedByUid,
  }) {
    final explicit = (directoryStatus ?? '').trim();
    if (explicit.isNotEmpty && all.contains(explicit)) return explicit;

    final owned = (ownerId ?? '').trim().isNotEmpty ||
        (claimedByUid ?? '').trim().isNotEmpty;
    if (owned) return claimed;
    if (isPartner || isVerifiedSeller) return verified;
    return unverified;
  }

  static String label(String status, {bool isAr = true}) {
    switch (normalize(status)) {
      case contacted:
        return isAr ? 'تم التواصل' : 'Contacted';
      case verified:
        // Do not say "Verified" — criteria not met yet.
        return isAr ? 'مؤكد بالتوصل' : 'Confirmed';
      case claimed:
        return isAr ? 'مُطالَب (بانتظار التحقق)' : 'Claimed (pending proof)';
      case managedVerified:
        return isAr ? 'موثّق ومُدار' : 'Managed Verified';
      default:
        return isAr ? 'غير موثّق' : 'Unverified';
    }
  }

  static String labelTr(String status) => appTr(
        label(status, isAr: true),
        label(status, isAr: false),
      );

  static Color color(String status) {
    switch (normalize(status)) {
      case contacted:
        return const Color(0xFFF57F17);
      case verified:
        return const Color(0xFF558B2F);
      case claimed:
        return const Color(0xFF1565C0);
      case managedVerified:
        return const Color(0xFF1B5E20);
      default:
        return const Color(0xFF757575);
    }
  }

  static IconData icon(String status) {
    switch (normalize(status)) {
      case contacted:
        return Icons.phone_in_talk_outlined;
      case verified:
        return Icons.mark_email_read_outlined;
      case claimed:
        return Icons.badge_outlined;
      case managedVerified:
        return Icons.verified;
      default:
        return Icons.help_outline;
    }
  }

  /// Partner / trusted commerce signals — Managed Verified only.
  static bool isTrusted(String status) {
    return normalize(status) == managedVerified;
  }

  static bool isManaged(String status) => isTrusted(status);

  static bool canManageListing(String status, {required bool isOwner}) {
    if (!isOwner) return false;
    final s = normalize(status);
    return s == managedVerified || s == claimed;
  }

  static List<String> adminTargetsFrom(String current) {
    final c = normalize(current);
    return all.where((s) => s != c).toList(growable: false);
  }
}

class DirectoryTrustChip extends StatelessWidget {
  const DirectoryTrustChip({
    super.key,
    required this.status,
    this.compact = false,
    this.lastManagedLabel,
  });

  final String status;
  final bool compact;
  final String? lastManagedLabel;

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final s = DirectoryTrustStatus.normalize(status);
    final c = DirectoryTrustStatus.color(s);
    final label = DirectoryTrustStatus.label(s, isAr: isAr);
    final managed = (lastManagedLabel ?? '').trim();
    return Chip(
      avatar: Icon(DirectoryTrustStatus.icon(s), size: 16, color: c),
      label: Text(
        managed.isEmpty
            ? label
            : (isAr ? '$label · آخر ترتيب $managed' : '$label · Updated $managed'),
        style: TextStyle(fontSize: compact ? 11 : 12, color: c),
      ),
      visualDensity: VisualDensity.compact,
      backgroundColor: c.withValues(alpha: 0.1),
      side: BorderSide(color: c.withValues(alpha: 0.35)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
