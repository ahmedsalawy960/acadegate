import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/locale/app_translate.dart';
import '../academic/academic_content_service.dart';
import '../academic/academic_models.dart';
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
      degree: profile?.degree ?? appTr('ماجستير', 'Master\'s'),
      specialization: topic,
      researchInterest: topic,
      methodology: profile?.methodology ?? appTr('كمي', 'Quantitative'),
      preferredLanguage:
          profile?.preferredLanguage ?? appTr('العربية', 'Arabic'),
      city: profile?.city ?? '',
      skills: profile?.skills ?? const [],
    );
  }

  StoreCategory? _storeCategoryById(String id) {
    for (final category in storeCategories) {
      if (category.id == id) return category;
    }
    return null;
  }

  StoreCategory? _inferStoreCategory(List<String> keywords) {
    const rules = <String, String>{
      'كيم': 'chemicals',
      'chem': 'chemicals',
      'كاشف': 'chemicals',
      'بيول': 'biology',
      'حيو': 'biology',
      'dna': 'biology',
      'طبي': 'medical',
      'med': 'medical',
      'صيدل': 'medical',
      'أسنان': 'medical',
      'هند': 'engineering',
      'eng': 'engineering',
      'إلكتر': 'engineering',
      'فيزي': 'physics_materials',
      'مواد': 'physics_materials',
      'جيول': 'physics_materials',
      'زراع': 'agriculture',
      'بيطر': 'agriculture',
      'agri': 'agriculture',
      'حاسب': 'computing',
      'برمج': 'computing',
      'بيانات': 'computing',
      'مستهلك': 'consumables',
      'جهاز': 'instruments',
      'قياس': 'instruments',
      'سلام': 'safety',
      'ميدان': 'field',
      'مسح': 'field',
      'كتاب': 'books',
      'مرجع': 'books',
      'تربي': 'humanities',
      'آداب': 'humanities',
      'اجتماع': 'humanities',
    };

    final haystack = keywords.join(' ').toLowerCase();
    for (final entry in rules.entries) {
      if (haystack.contains(entry.key)) {
        return _storeCategoryById(entry.value);
      }
    }
    return _storeCategoryById('general');
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
    return const [];
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
          reasons.add(appTr('يتوافق مع «$kw»', 'Matches "$kw"'));
        }
      }

      final category = data['category']?.toString() ?? '';
      if (preferredCategory != null && category == preferredCategory) {
        score += 15;
        reasons.add(appTr('من القسم المناسب لبحثك', 'From the right section for your research'));
      }

      return SupplyChainProduct(
        id: data['id']?.toString(),
        name: data['name']?.toString() ?? appTr('منتج', 'Product'),
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

      if (_isPhdDegree(profile.degree) && expert.category.contains('رسائل')) {
        score += 20;
        reasons.add(appTr('مناسب لمرحلة الدكتوراه', 'Suitable for PhD stage'));
      } else if (_isMastersDegree(profile.degree) &&
          (expert.category.contains('رسائل') ||
              expert.category.contains('إحصاء'))) {
        score += 18;
        reasons.add(appTr('يدعم رسائل الماجستير', 'Supports master\'s theses'));
      }

      if (preferredCategory != null &&
          expert.category.contains(preferredCategory)) {
        score += 15;
        reasons.add(appTr('خدمة كتابة مناسبة لنوع بحثك', 'Writing service suited to your research type'));
      }

      if (_isQuantitativeMethodology(profile.methodology) &&
          expert.category.contains('إحصاء')) {
        score += 12;
        reasons.add(appTr('تحليل كمي متاح', 'Quantitative analysis available'));
      }

      final result = MatchResult(
        item: expert,
        score: score.clamp(0, 100),
        reasons: reasons.isEmpty
            ? [appTr('كاتب أكاديمي مقترح', 'Suggested academic writer')]
            : reasons,
      );

      if (best == null || result.score > best.score) best = result;
    }

    return best;
  }

  String? _inferWritingCategory(AcademicProfile profile) {
    final text = profile.keywords.join(' ');
    if (text.contains('إحص') ||
        text.contains('spss') ||
        _isQuantitativeMethodology(profile.methodology)) {
      return 'إحصاء';
    }
    if (text.contains('أدب') || text.contains('literature')) {
      return 'مراجعة';
    }
    if (_isPhdDegree(profile.degree) || _isMastersDegree(profile.degree)) {
      return 'رسائل';
    }
    return 'أوراق';
  }

  bool _isPhdDegree(String degree) {
    final d = degree.toLowerCase();
    return d.contains('دكتوراه') || d.contains('phd') || d.contains('doctorate');
  }

  bool _isMastersDegree(String degree) {
    final d = degree.toLowerCase();
    return d.contains('ماجستير') || d.contains('master');
  }

  bool _isQuantitativeMethodology(String methodology) {
    final m = methodology.toLowerCase();
    return m.contains('كمي') || m.contains('quant');
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
      lines.add(appTr(
        '💡 فكرة: ${idea.item.title} (${idea.score}%)',
        '💡 Idea: ${idea.item.title} (${idea.score}%)',
      ));
    }
    if (supervisor != null) {
      lines.add(appTr(
        '👤 مشرف: ${supervisor.item.name} (${supervisor.score}%)',
        '👤 Supervisor: ${supervisor.item.name} (${supervisor.score}%)',
      ));
    }
    if (lab != null) {
      lines.add(appTr(
        '🔬 مختبر: ${lab.item.name} (${lab.score}%)',
        '🔬 Lab: ${lab.item.name} (${lab.score}%)',
      ));
    }
    if (storeCategory != null) {
      lines.add(appTr(
        '🛒 قسم متجر: ${storeCategory.title}',
        '🛒 Store section: ${storeCategory.title}',
      ));
    }
    if (products.isNotEmpty) {
      lines.add(appTr(
        '📦 ${products.length} منتج/ات مقترحة',
        '📦 ${products.length} suggested product(s)',
      ));
    }
    if (expert != null) {
      lines.add(appTr(
        '✍️ كاتب: ${expert.item.name} (${expert.score}%)',
        '✍️ Writer: ${expert.item.name} (${expert.score}%)',
      ));
    }
    return lines;
  }
}
