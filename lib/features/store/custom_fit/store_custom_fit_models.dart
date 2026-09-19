import '../store_catalog_service.dart';

/// متطلبات مستخرجة من الرسم/المواصفات (محلياً أو عبر Gemini).
class CustomFitRequirements {
  final String summaryAr;
  final String summaryEn;
  final String equipmentOrContext;
  final List<String> criticalSpecs;
  final List<String> materialsHints;
  final List<String> keywords;
  final String riskNotes;

  const CustomFitRequirements({
    this.summaryAr = '',
    this.summaryEn = '',
    this.equipmentOrContext = '',
    this.criticalSpecs = const [],
    this.materialsHints = const [],
    this.keywords = const [],
    this.riskNotes = '',
  });

  factory CustomFitRequirements.fromMap(Map<String, dynamic> m) {
    List<String> list(dynamic v) {
      if (v is! List) return const [];
      return v
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return CustomFitRequirements(
      summaryAr: m['summaryAr']?.toString() ?? m['summary']?.toString() ?? '',
      summaryEn: m['summaryEn']?.toString() ?? '',
      equipmentOrContext: m['equipmentOrContext']?.toString() ?? '',
      criticalSpecs: list(m['criticalSpecs']),
      materialsHints: list(m['materialsHints']),
      keywords: list(m['keywords']),
      riskNotes: m['riskNotes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'summaryAr': summaryAr,
        'summaryEn': summaryEn,
        'equipmentOrContext': equipmentOrContext,
        'criticalSpecs': criticalSpecs,
        'materialsHints': materialsHints,
        'keywords': keywords,
        'riskNotes': riskNotes,
      };
}

class CustomFitMatchItem {
  final String productId;
  final String productName;
  final int matchPercent;
  final String whyAr;
  final String whyEn;
  final String gapAr;
  final String gapEn;
  final StoreCatalogProduct? product;

  const CustomFitMatchItem({
    required this.productId,
    required this.productName,
    required this.matchPercent,
    this.whyAr = '',
    this.whyEn = '',
    this.gapAr = '',
    this.gapEn = '',
    this.product,
  });

  CustomFitMatchItem copyWith({StoreCatalogProduct? product}) {
    return CustomFitMatchItem(
      productId: productId,
      productName: productName,
      matchPercent: matchPercent,
      whyAr: whyAr,
      whyEn: whyEn,
      gapAr: gapAr,
      gapEn: gapEn,
      product: product ?? this.product,
    );
  }
}

/// موجز تصنيع رقمي للمورد (CNC / طباعة ثلاثية / تعديل قطعة).
class CustomFitFabricationBrief {
  final String processHint;
  final String materialHint;
  final String tolerances;
  final String dimensionsSummary;
  final String modificationNotes;
  final String supplierAskAr;
  final String supplierAskEn;
  final List<String> checklist;

  const CustomFitFabricationBrief({
    this.processHint = '',
    this.materialHint = '',
    this.tolerances = '',
    this.dimensionsSummary = '',
    this.modificationNotes = '',
    this.supplierAskAr = '',
    this.supplierAskEn = '',
    this.checklist = const [],
  });

  factory CustomFitFabricationBrief.fromMap(Map<String, dynamic> m) {
    final checklist = (m['checklist'] is List)
        ? (m['checklist'] as List)
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];
    return CustomFitFabricationBrief(
      processHint: m['processHint']?.toString() ?? '',
      materialHint: m['materialHint']?.toString() ?? '',
      tolerances: m['tolerances']?.toString() ?? '',
      dimensionsSummary: m['dimensionsSummary']?.toString() ?? '',
      modificationNotes: m['modificationNotes']?.toString() ?? '',
      supplierAskAr:
          m['supplierAskAr']?.toString() ?? m['supplierAsk']?.toString() ?? '',
      supplierAskEn: m['supplierAskEn']?.toString() ?? '',
      checklist: checklist,
    );
  }

  Map<String, dynamic> toMap() => {
        'processHint': processHint,
        'materialHint': materialHint,
        'tolerances': tolerances,
        'dimensionsSummary': dimensionsSummary,
        'modificationNotes': modificationNotes,
        'supplierAskAr': supplierAskAr,
        'supplierAskEn': supplierAskEn,
        'checklist': checklist,
      };

  bool get isEmpty =>
      processHint.isEmpty &&
      materialHint.isEmpty &&
      supplierAskAr.isEmpty &&
      supplierAskEn.isEmpty &&
      dimensionsSummary.isEmpty;
}

class CustomFitAnalysisResult {
  final CustomFitRequirements requirements;
  final List<CustomFitMatchItem> matches;
  final CustomFitFabricationBrief fabrication;
  final bool needsCustomFabrication;
  final String confidenceNoteAr;
  final String confidenceNoteEn;
  final bool fromAi;
  final String? modelUsed;
  final String? error;

  const CustomFitAnalysisResult({
    required this.requirements,
    this.matches = const [],
    this.fabrication = const CustomFitFabricationBrief(),
    this.needsCustomFabrication = false,
    this.confidenceNoteAr = '',
    this.confidenceNoteEn = '',
    this.fromAi = false,
    this.modelUsed,
    this.error,
  });

  bool get hasError => error != null && error!.trim().isNotEmpty;
}
