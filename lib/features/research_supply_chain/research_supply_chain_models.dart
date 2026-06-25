import '../academic/academic_models.dart';
import '../academic_writing/writing_models.dart';
import '../matchmaking/smart_matchmaking_engine.dart';
import '../store/store_categories.dart';

/// نتيجة تحليل Gemini (أو التحليل الأساسي) لحزمة البحث.
class ResearchPathAiInsight {
  final String analysis;
  final String researchPlan;
  final String? nextStep;
  final bool fromGemini;
  final String? modelUsed;
  final String? error;

  const ResearchPathAiInsight({
    required this.analysis,
    required this.researchPlan,
    this.nextStep,
    this.fromGemini = false,
    this.modelUsed,
    this.error,
  });
}

/// منتج مقترح من المتجر ضمن مسار البحث الذكي.
class SupplyChainProduct {
  final String? id;
  final String name;
  final num price;
  final String category;
  final String? imageUrl;
  final String? createdBy;
  final int score;
  final List<String> reasons;

  const SupplyChainProduct({
    this.id,
    required this.name,
    required this.price,
    required this.category,
    this.imageUrl,
    this.createdBy,
    this.score = 0,
    this.reasons = const [],
  });
}

/// حزمة بحثية متكاملة — فكرة + مشرف + مختبر + متجر + كتابة.
class ResearchSupplyBundle {
  final String topic;
  final MatchResult<AcademicResearchIdea>? idea;
  final MatchResult<AcademicSupervisor>? supervisor;
  final MatchResult<AcademicLab>? lab;
  final List<SupplyChainProduct> products;
  final StoreCategory? storeCategory;
  final MatchResult<WritingExpert>? writingExpert;
  final int overallScore;
  final List<String> chainSummary;
  final ResearchPathAiInsight? aiInsight;

  const ResearchSupplyBundle({
    required this.topic,
    this.idea,
    this.supervisor,
    this.lab,
    this.products = const [],
    this.storeCategory,
    this.writingExpert,
    this.overallScore = 0,
    this.chainSummary = const [],
    this.aiInsight,
  });

  ResearchSupplyBundle copyWith({
    String? topic,
    MatchResult<AcademicResearchIdea>? idea,
    MatchResult<AcademicSupervisor>? supervisor,
    MatchResult<AcademicLab>? lab,
    List<SupplyChainProduct>? products,
    StoreCategory? storeCategory,
    MatchResult<WritingExpert>? writingExpert,
    int? overallScore,
    List<String>? chainSummary,
    ResearchPathAiInsight? aiInsight,
  }) {
    return ResearchSupplyBundle(
      topic: topic ?? this.topic,
      idea: idea ?? this.idea,
      supervisor: supervisor ?? this.supervisor,
      lab: lab ?? this.lab,
      products: products ?? this.products,
      storeCategory: storeCategory ?? this.storeCategory,
      writingExpert: writingExpert ?? this.writingExpert,
      overallScore: overallScore ?? this.overallScore,
      chainSummary: chainSummary ?? this.chainSummary,
      aiInsight: aiInsight ?? this.aiInsight,
    );
  }

  bool get hasAnyMatch =>
      idea != null ||
      supervisor != null ||
      lab != null ||
      products.isNotEmpty ||
      writingExpert != null;

  int get completedSteps {
    var n = 0;
    if (idea != null) n++;
    if (supervisor != null) n++;
    if (lab != null) n++;
    if (products.isNotEmpty) n++;
    if (writingExpert != null) n++;
    return n;
  }
}
