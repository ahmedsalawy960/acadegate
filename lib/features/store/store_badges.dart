import 'package:flutter/material.dart';

import '../../core/locale/app_translate.dart';

/// شارات تخصصية للمتجر الأكاديمي.
class StoreBadge {
  final String id;
  final IconData icon;
  final Color color;

  const StoreBadge({
    required this.id,
    required this.icon,
    required this.color,
  });

  String labelAr() {
    switch (id) {
      case verified:
        return 'موثّق ومُدار';
      case officialImporter:
        return 'مستورد رسمي';
      case uniLabFit:
        return 'يناسب معامل جامعية';
      case bulkResearch:
        return 'يقبل كميات بحثية';
      default:
        return id;
    }
  }

  String labelEn() {
    switch (id) {
      case verified:
        return 'Managed Verified';
      case officialImporter:
        return 'Official importer';
      case uniLabFit:
        return 'University-lab fit';
      case bulkResearch:
        return 'Bulk research orders';
      default:
        return id;
    }
  }

  String label() => appTr(labelAr(), labelEn());

  static const verified = 'verified';
  static const officialImporter = 'official_importer';
  static const uniLabFit = 'uni_lab_fit';
  static const bulkResearch = 'bulk_research';

  static const all = <StoreBadge>[
    StoreBadge(
      id: verified,
      icon: Icons.verified_outlined,
      color: Color(0xFF0F766E),
    ),
    StoreBadge(
      id: officialImporter,
      icon: Icons.local_shipping_outlined,
      color: Color(0xFF334155),
    ),
    StoreBadge(
      id: uniLabFit,
      icon: Icons.school_outlined,
      color: Color(0xFF475569),
    ),
    StoreBadge(
      id: bulkResearch,
      icon: Icons.inventory_2_outlined,
      color: Color(0xFFC2410C),
    ),
  ];

  static StoreBadge? byId(String id) {
    for (final b in all) {
      if (b.id == id) return b;
    }
    return null;
  }

  static List<StoreBadge> resolve(
    List<String> ids, {
    bool isVerifiedSeller = false,
  }) {
    final out = <StoreBadge>[];
    final seen = <String>{};
    if (isVerifiedSeller) {
      final v = byId(verified);
      if (v != null) {
        out.add(v);
        seen.add(verified);
      }
    }
    for (final id in ids) {
      if (seen.contains(id)) continue;
      final b = byId(id);
      if (b == null) continue;
      out.add(b);
      seen.add(id);
    }
    return out;
  }
}
