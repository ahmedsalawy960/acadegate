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
/// كل قسم يعرض عدة خيارات مفيدة للطالب عند توفرها.
class ResearchSupplyBundle {
  final String topic;
  final List<MatchResult<AcademicResearchIdea>> ideas;
  final List<MatchResult<AcademicSupervisor>> supervisors;
  final List<MatchResult<AcademicLab>> labs;
  final List<SupplyChainProduct> products;
  final StoreCategory? storeCategory;
  final List<StoreCategory> storeCategories;
  final List<MatchResult<WritingExpert>> writingExperts;
  final int overallScore;
  final List<String> chainSummary;
  final ResearchPathAiInsight? aiInsight;

  const ResearchSupplyBundle({
    required this.topic,
    this.ideas = const [],
    this.supervisors = const [],
    this.labs = const [],
    this.products = const [],
    this.storeCategory,
    this.storeCategories = const [],
    this.writingExperts = const [],
    this.overallScore = 0,
    this.chainSummary = const [],
    this.aiInsight,
  });

  MatchResult<AcademicResearchIdea>? get idea =>
      ideas.isEmpty ? null : ideas.first;

  MatchResult<AcademicSupervisor>? get supervisor =>
      supervisors.isEmpty ? null : supervisors.first;

  MatchResult<AcademicLab>? get lab => labs.isEmpty ? null : labs.first;

  MatchResult<WritingExpert>? get writingExpert =>
      writingExperts.isEmpty ? null : writingExperts.first;

  ResearchSupplyBundle copyWith({
    String? topic,
    List<MatchResult<AcademicResearchIdea>>? ideas,
    List<MatchResult<AcademicSupervisor>>? supervisors,
    List<MatchResult<AcademicLab>>? labs,
    List<SupplyChainProduct>? products,
    StoreCategory? storeCategory,
    List<StoreCategory>? storeCategories,
    List<MatchResult<WritingExpert>>? writingExperts,
    int? overallScore,
    List<String>? chainSummary,
    ResearchPathAiInsight? aiInsight,
  }) {
    return ResearchSupplyBundle(
      topic: topic ?? this.topic,
      ideas: ideas ?? this.ideas,
      supervisors: supervisors ?? this.supervisors,
      labs: labs ?? this.labs,
      products: products ?? this.products,
      storeCategory: storeCategory ?? this.storeCategory,
      storeCategories: storeCategories ?? this.storeCategories,
      writingExperts: writingExperts ?? this.writingExperts,
      overallScore: overallScore ?? this.overallScore,
      chainSummary: chainSummary ?? this.chainSummary,
      aiInsight: aiInsight ?? this.aiInsight,
    );
  }

  bool get hasAnyMatch =>
      ideas.isNotEmpty ||
      supervisors.isNotEmpty ||
      labs.isNotEmpty ||
      products.isNotEmpty ||
      writingExperts.isNotEmpty;

  int get completedSteps {
    var n = 0;
    if (ideas.isNotEmpty) n++;
    if (supervisors.isNotEmpty) n++;
    if (labs.isNotEmpty) n++;
    if (products.isNotEmpty) n++;
    if (writingExperts.isNotEmpty) n++;
    return n;
  }
}
