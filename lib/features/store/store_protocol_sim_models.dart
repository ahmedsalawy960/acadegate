import 'store_catalog_service.dart';

/// مستوى استرشادي لمحاكاة البروتوكول قبل الشراء (ليس ضمان نجاح تجريبي).
enum ProtocolSimLevel { low, medium, high }

enum ProtocolFeasibility { likely, uncertain, unlikely }

class ProtocolSimRisk {
  final String title;
  final String severity;
  final String detail;
  final List<String> relatedProductIds;

  const ProtocolSimRisk({
    required this.title,
    this.severity = 'medium',
    this.detail = '',
    this.relatedProductIds = const [],
  });
}

class ProtocolSimInteraction {
  final List<String> materials;
  final String issue;
  final String mitigation;

  const ProtocolSimInteraction({
    this.materials = const [],
    this.issue = '',
    this.mitigation = '',
  });
}

class ProtocolSimGap {
  final String needed;
  final String reason;
  final String searchQuery;
  final List<StoreCatalogProduct> catalogMatches;

  const ProtocolSimGap({
    required this.needed,
    this.reason = '',
    this.searchQuery = '',
    this.catalogMatches = const [],
  });

  ProtocolSimGap copyWith({List<StoreCatalogProduct>? catalogMatches}) =>
      ProtocolSimGap(
        needed: needed,
        reason: reason,
        searchQuery: searchQuery,
        catalogMatches: catalogMatches ?? this.catalogMatches,
      );
}

class ProtocolSimQtyChange {
  final String productId;
  final String productName;
  final int currentQty;
  final int suggestedQty;
  final String reason;

  const ProtocolSimQtyChange({
    required this.productId,
    required this.productName,
    required this.currentQty,
    required this.suggestedQty,
    this.reason = '',
  });

  bool get isIncrease => suggestedQty > currentQty;
  bool get isDecrease => suggestedQty < currentQty;
}

class ProtocolSimCartNote {
  final String productId;
  final String productName;
  final String note;

  const ProtocolSimCartNote({
    required this.productId,
    required this.productName,
    required this.note,
  });
}

class ProtocolSimResult {
  final String protocolSummary;
  final String overallSummary;
  final ProtocolSimLevel overallLevel;
  final ProtocolFeasibility feasibility;
  final List<ProtocolSimRisk> risks;
  final List<ProtocolSimInteraction> interactions;
  final List<ProtocolSimGap> gaps;
  final List<ProtocolSimQtyChange> quantityChanges;
  final List<ProtocolSimCartNote> cartNotes;
  final bool fromAi;
  final String? modelUsed;
  final String? error;
  final String disclaimer;
  final String sourceLabel;

  const ProtocolSimResult({
    this.protocolSummary = '',
    this.overallSummary = '',
    this.overallLevel = ProtocolSimLevel.medium,
    this.feasibility = ProtocolFeasibility.uncertain,
    this.risks = const [],
    this.interactions = const [],
    this.gaps = const [],
    this.quantityChanges = const [],
    this.cartNotes = const [],
    this.fromAi = false,
    this.modelUsed,
    this.error,
    this.disclaimer = '',
    this.sourceLabel = '',
  });

  bool get hasError => error != null && error!.trim().isNotEmpty;
  bool get hasContent =>
      overallSummary.trim().isNotEmpty ||
      risks.isNotEmpty ||
      interactions.isNotEmpty ||
      gaps.isNotEmpty ||
      quantityChanges.isNotEmpty ||
      cartNotes.isNotEmpty;
}
