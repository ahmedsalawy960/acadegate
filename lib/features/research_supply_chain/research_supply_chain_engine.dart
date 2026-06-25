import 'package:cloud_firestore/cloud_firestore.dart';

import '../academic/academic_content_service.dart';
import '../academic/academic_models.dart';
import '../academic_writing/writing_fallback_data.dart';
import '../academic_writing/writing_models.dart';
import '../matchmaking/smart_matchmaking_engine.dart';
import '../profile/academic_profile.dart';
import '../store/store_categories.dart';
import 'research_supply_chain_models.dart';

class ResearchSupplyChainEngine {
  ResearchSupplyChainEngine._();

  static final ResearchSupplyChainEngine instance =
      ResearchSupplyChainEngine._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<ResearchSupplyBundle> buildBundle({
    required String topic,
    AcademicProfile? profile,
  }) async {
    final trimmed = topic.trim();
    final effectiveProfile = _effectiveProfile(profile, trimmed);

    final content = await AcademicContentService.instance.fetchAll();
    final products = await _fetchProducts();
    final experts = await _fetchWritingExperts();

    final ideaMatches = SmartMatchmakingEngine.matchResearchIdeas(
      effectiveProfile,
      content.ideas,
      limit: 1,
    );
    final supervisorMatches = SmartMatchmakingEngine.matchSupervisors(
      effectiveProfile,
      content.supervisors,
      limit: 1,
    );
    final labMatches = SmartMatchmakingEngine.matchLabs(
      effectiveProfile,
      content.labs,
      limit: 1,
    );

    final storeCategory = _inferStoreCategory(effectiveProfile.keywords);
    final productMatches = _matchProducts(
      effectiveProfile.keywords,
      products,
      preferredCategory: storeCategory?.title,
      limit: 3,
    );

    final writingMatch = _matchWritingExpert(
      effectiveProfile,
      experts,
    );

    final scores = <int>[
      if (ideaMatches.isNotEmpty) ideaMatches.first.score,
      if (supervisorMatches.isNotEmpty) supervisorMatches.first.score,
      if (labMatches.isNotEmpty) labMatches.first.score,
      if (productMatches.isNotEmpty) productMatches.first.score,
      if (writingMatch != null) writingMatch.score,
    ];

    final overall = scores.isEmpty
        ? 0
        : (scores.reduce((a, b) => a + b) / scores.length).round();

    final summary = _buildSummary(
      idea: ideaMatches.isNotEmpty ? ideaMatches.first : null,
      supervisor:
          supervisorMatches.isNotEmpty ? supervisorMatches.first : null,
      lab: labMatches.isNotEmpty ? labMatches.first : null,
      products: productMatches,
      expert: writingMatch,
      storeCategory: storeCategory,
    );

    return ResearchSupplyBundle(
      topic: trimmed,
      idea: ideaMatches.isNotEmpty ? ideaMatches.first : null,
      supervisor:
          supervisorMatches.isNotEmpty ? supervisorMatches.first : null,
      lab: labMatches.isNotEmpty ? labMatches.first : null,
      products: productMatches,
      storeCategory: storeCategory,
      writingExpert: writingMatch,
      overallScore: overall,
      chainSummary: summary,
    );
  }

  AcademicProfile _effectiveProfile(AcademicProfile? profile, String topic) {
    if (profile != null && profile.isComplete) {
      return profile.copyWith(
        researchInterest: topic.isNotEmpty ? topic : profile.researchInterest,
      );
    }

    return AcademicProfile(
      fullName: profile?.fullName ?? '',
      university: profile?.university ?? '',
      degree: profile?.degree ?? 'ماجستير',
      specialization: topic,
      researchInterest: topic,
      methodology: profile?.methodology ?? 'كمي',
      preferredLanguage: profile?.preferredLanguage ?? 'العربية',
      city: profile?.city ?? '',
      skills: profile?.skills ?? const [],
    );
  }

  StoreCategory? _inferStoreCategory(List<String> keywords) {
    const rules = <String, String>{
      'كيم': 'متجر كيميائي',
      'chem': 'متجر كيميائي',
      'تحليل': 'متجر كيميائي',
      'مختبر': 'متجر كيميائي',
      'طبي': 'متجر طبي',
      'med': 'متجر طبي',
      'صح': 'متجر طبي',
      'هند': 'متجر هندسي',
      'eng': 'متجر هندسي',
      'ميكان': 'متجر هندسي',
      'زراع': 'متجر زراعي',
      'agri': 'متجر زراعي',
    };

    final haystack = keywords.join(' ');
    for (final entry in rules.entries) {
      if (haystack.contains(entry.key)) {
        return storeCategoryByTitle(entry.value);
      }
    }
    return storeCategoryByTitle('متجر عام');
  }

  Future<List<Map<String, dynamic>>> _fetchProducts() async {
    try {
      final snap = await _db.collection('product').limit(80).get();
      return snap.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .where(
            (data) =>
                (data['approvalStatus']?.toString() ?? 'approved') ==
                'approved',
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<WritingExpert>> _fetchWritingExperts() async {
    try {
      final snap = await _db.collection('writing_services').limit(40).get();
      final experts = snap.docs
          .map((doc) => WritingExpert.fromMap(doc.data(), id: doc.id))
          .where((e) => e.isPubliclyVisible)
          .toList();
      if (experts.isNotEmpty) return experts;
    } catch (_) {}
    return fallbackWritingExperts;
  }

  List<SupplyChainProduct> _matchProducts(
    List<String> keywords,
    List<Map<String, dynamic>> products, {
    String? preferredCategory,
    int limit = 3,
  }) {
    if (products.isEmpty) return const [];

    final scored = products.map((data) {
      final text = [
        data['name'],
        data['description'],
        data['category'],
        data['storeName'],
      ].join(' ').toLowerCase();

      var score = 0;
      final reasons = <String>[];
      for (final kw in keywords) {
        if (kw.length >= 2 && text.contains(kw)) {
          score += 12;
          reasons.add('يتوافق مع «$kw»');
        }
      }

      final category = data['category']?.toString() ?? '';
      if (preferredCategory != null && category == preferredCategory) {
        score += 15;
        reasons.add('من القسم المناسب لبحثك');
      }

      return SupplyChainProduct(
        id: data['id']?.toString(),
        name: data['name']?.toString() ?? 'منتج',
        price: (data['price'] as num?) ?? 0,
        category: category,
        imageUrl: data['imageUrl']?.toString(),
        createdBy: data['createdBy']?.toString(),
        score: score.clamp(0, 100),
        reasons: reasons.toSet().take(2).toList(),
      );
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final matched = scored.where((p) => p.score > 0).take(limit).toList();
    if (matched.isNotEmpty) return matched;
    return scored.take(limit).toList();
  }

  MatchResult<WritingExpert>? _matchWritingExpert(
    AcademicProfile profile,
    List<WritingExpert> experts,
  ) {
    if (experts.isEmpty) return null;

    final preferredCategory = _inferWritingCategory(profile);

    MatchResult<WritingExpert>? best;
    for (final expert in experts) {
      var score = 0;
      final reasons = <String>[];
      final text = [
        expert.category,
        expert.speciality,
        expert.bio,
        ...expert.tags,
      ].join(' ').toLowerCase();

      for (final kw in profile.keywords) {
        if (kw.length >= 2 && text.contains(kw)) score += 10;
      }

      if (profile.degree.contains('دكتوراه') &&
          expert.category.contains('رسائل')) {
        score += 20;
        reasons.add('مناسب لمرحلة الدكتوراه');
      } else if (profile.degree.contains('ماجستير') &&
          (expert.category.contains('رسائل') ||
              expert.category.contains('إحصاء'))) {
        score += 18;
        reasons.add('يدعم رسائل الماجستير');
      }

      if (preferredCategory != null &&
          expert.category.contains(preferredCategory)) {
        score += 15;
        reasons.add('خدمة كتابة مناسبة لنوع بحثك');
      }

      if (profile.methodology == 'كمي' && expert.category.contains('إحصاء')) {
        score += 12;
        reasons.add('تحليل كمي متاح');
      }

      final result = MatchResult(
        item: expert,
        score: score.clamp(0, 100),
        reasons: reasons.isEmpty ? ['كاتب أكاديمي مقترح'] : reasons,
      );

      if (best == null || result.score > best.score) best = result;
    }

    return best;
  }

  String? _inferWritingCategory(AcademicProfile profile) {
    final text = profile.keywords.join(' ');
    if (text.contains('إحص') || text.contains('spss') || profile.methodology == 'كمي') {
      return 'إحصاء';
    }
    if (text.contains('أدب') || text.contains('literature')) {
      return 'مراجعة';
    }
    if (profile.degree.contains('دكتوراه') || profile.degree.contains('ماجستير')) {
      return 'رسائل';
    }
    return 'أوراق';
  }

  List<String> _buildSummary({
    MatchResult<AcademicResearchIdea>? idea,
    MatchResult<AcademicSupervisor>? supervisor,
    MatchResult<AcademicLab>? lab,
    List<SupplyChainProduct> products = const [],
    MatchResult<WritingExpert>? expert,
    StoreCategory? storeCategory,
  }) {
    final lines = <String>[];
    if (idea != null) {
      lines.add('💡 فكرة: ${idea.item.title} (${idea.score}%)');
    }
    if (supervisor != null) {
      lines.add('👤 مشرف: ${supervisor.item.name} (${supervisor.score}%)');
    }
    if (lab != null) {
      lines.add('🔬 مختبر: ${lab.item.name} (${lab.score}%)');
    }
    if (storeCategory != null) {
      lines.add('🛒 قسم متجر: ${storeCategory.title}');
    }
    if (products.isNotEmpty) {
      lines.add('📦 ${products.length} منتج/ات مقترحة');
    }
    if (expert != null) {
      lines.add('✍️ كاتب: ${expert.item.name} (${expert.score}%)');
    }
    return lines;
  }
}
