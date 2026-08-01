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

  static const _ideaLimit = 5;
  static const _supervisorLimit = 5;
  static const _labLimit = 5;
  static const _productLimit = 8;
  static const _writerLimit = 4;

  Future<ResearchSupplyBundle> buildBundle({
    required String topic,
    AcademicProfile? profile,
  }) async {
    final trimmed = topic.trim();
    final effectiveProfile = _effectiveProfile(profile, trimmed);
    final keywords = _richKeywords(effectiveProfile, trimmed);

    final content = await AcademicContentService.instance.fetchAll(
      includeLabs: true,
    );

    // Prefer faculty-scoped labs (larger pool) then merge with cached browse.
    final facultyId = effectiveProfile.resolvedFacultyCategory;
    final facultyLabs = facultyId == null || facultyId.isEmpty
        ? const <AcademicLab>[]
        : await AcademicContentService.instance.searchLabs(
            facultyId: facultyId,
            university: effectiveProfile.university.trim().isEmpty
                ? null
                : effectiveProfile.university,
            limit: 100,
          );

    final labsById = <String, AcademicLab>{};
    for (final lab in [...facultyLabs, ...content.labs]) {
      final key = lab.id ?? '${lab.name}|${lab.university}|${lab.city}';
      labsById.putIfAbsent(key, () => lab);
    }
    final labsPool = labsById.values.toList();

    final preferredCategories = _inferStoreCategories(keywords);
    final products = await _fetchProducts(preferredCategories);
    final experts = await _fetchWritingExperts();

    final ideaMatches = SmartMatchmakingEngine.matchResearchIdeas(
      effectiveProfile,
      content.ideas,
      limit: _ideaLimit,
    );
    final supervisorMatches = SmartMatchmakingEngine.matchSupervisors(
      effectiveProfile,
      content.supervisors,
      limit: _supervisorLimit,
    );
    final labMatches = SmartMatchmakingEngine.matchLabs(
      effectiveProfile,
      labsPool,
      limit: _labLimit,
    );

    final productMatches = _matchProducts(
      keywords,
      products,
      preferredCategories: preferredCategories,
      limit: _productLimit,
    );

    final writingMatches = _matchWritingExperts(
      effectiveProfile,
      experts,
      limit: _writerLimit,
    );

    final primaryStore = preferredCategories.isNotEmpty
        ? preferredCategories.first
        : storeCategoryById('general');

    final scores = <int>[
      if (ideaMatches.isNotEmpty) ideaMatches.first.score,
      if (supervisorMatches.isNotEmpty) supervisorMatches.first.score,
      if (labMatches.isNotEmpty) labMatches.first.score,
      if (productMatches.isNotEmpty) productMatches.first.score,
      if (writingMatches.isNotEmpty) writingMatches.first.score,
    ];

    final overall = scores.isEmpty
        ? 0
        : (scores.reduce((a, b) => a + b) / scores.length).round();

    final summary = _buildSummary(
      ideas: ideaMatches,
      supervisors: supervisorMatches,
      labs: labMatches,
      products: productMatches,
      experts: writingMatches,
      storeCategories: preferredCategories,
    );

    return ResearchSupplyBundle(
      topic: trimmed,
      ideas: ideaMatches,
      supervisors: supervisorMatches,
      labs: labMatches,
      products: productMatches,
      storeCategory: primaryStore,
      storeCategories: preferredCategories,
      writingExperts: writingMatches,
      overallScore: overall,
      chainSummary: summary,
    );
  }

  AcademicProfile _effectiveProfile(AcademicProfile? profile, String topic) {
    if (profile != null && profile.isComplete) {
      final mergedInterest = topic.isEmpty
          ? profile.researchInterest
          : '$topic ${profile.researchInterest}'.trim();
      final mergedSpec = topic.isEmpty
          ? profile.specialization
          : '${profile.specialization} $topic'.trim();
      return profile.copyWith(
        researchInterest: mergedInterest,
        specialization: mergedSpec,
      );
    }

    return AcademicProfile(
      fullName: profile?.fullName ?? '',
      university: profile?.university ?? '',
      degree: profile?.degree ?? appTr('ماجستير', 'Master\'s'),
      facultyCategory: profile?.facultyCategory ?? '',
      specialization: topic.isNotEmpty
          ? topic
          : (profile?.specialization ?? ''),
      researchInterest: topic.isNotEmpty
          ? topic
          : (profile?.researchInterest ?? ''),
      methodology: profile?.methodology ?? appTr('كمي', 'Quantitative'),
      preferredLanguage:
          profile?.preferredLanguage ?? appTr('العربية', 'Arabic'),
      city: profile?.city ?? '',
      skills: profile?.skills ?? const [],
    );
  }

  List<String> _richKeywords(AcademicProfile profile, String topic) {
    final tokens = <String>{
      ...profile.keywords,
      ...topic
          .toLowerCase()
          .split(RegExp(r'[\s,،.؛;/\\|+-]+'))
          .map((t) => t.trim())
          .where((t) => t.length >= 3),
    };
    return tokens.toList();
  }

  List<StoreCategory> _inferStoreCategories(List<String> keywords) {
    const rules = <String, String>{
      'كيم': 'chemicals',
      'chem': 'chemicals',
      'كاشف': 'chemicals',
      'reagent': 'chemicals',
      'بيول': 'biology',
      'حيو': 'biology',
      'dna': 'biology',
      'pcr': 'biology',
      'nano': 'biology',
      'طبي': 'medical',
      'med': 'medical',
      'صيدل': 'medical',
      'أسنان': 'medical',
      'clinic': 'medical',
      'هند': 'engineering',
      'eng': 'engineering',
      'إلكتر': 'engineering',
      'circuit': 'engineering',
      'فيزي': 'physics_materials',
      'مواد': 'physics_materials',
      'جيول': 'physics_materials',
      'زراع': 'agriculture',
      'بيطر': 'agriculture',
      'agri': 'agriculture',
      'حاسب': 'computing',
      'برمج': 'computing',
      'بيانات': 'computing',
      'machine': 'computing',
      'ai': 'computing',
      'مستهلك': 'consumables',
      'جهاز': 'instruments',
      'قياس': 'instruments',
      'spectr': 'instruments',
      'سلام': 'safety',
      'ميدان': 'field',
      'مسح': 'field',
      'كتاب': 'books',
      'مرجع': 'books',
      'تربي': 'humanities',
      'آداب': 'humanities',
      'اجتماع': 'humanities',
      'قانون': 'humanities',
    };

    final haystack = keywords.join(' ').toLowerCase();
    final found = <String>{};
    for (final entry in rules.entries) {
      if (haystack.contains(entry.key)) {
        found.add(entry.value);
      }
    }

    // Cross-cutting supplies that help most experimental paths.
    if (found.any((id) =>
        id == 'chemicals' ||
        id == 'biology' ||
        id == 'medical' ||
        id == 'physics_materials' ||
        id == 'agriculture' ||
        id == 'engineering')) {
      found.add('consumables');
      found.add('instruments');
      found.add('safety');
    }
    if (found.contains('computing') || found.contains('humanities')) {
      found.add('books');
      found.add('office');
    }
    if (found.isEmpty) {
      found.addAll(['general', 'books', 'office', 'consumables']);
    }

    final categories = <StoreCategory>[];
    for (final id in found) {
      final cat = storeCategoryById(id);
      if (cat != null) categories.add(cat);
    }
    return categories;
  }

  Future<List<Map<String, dynamic>>> _fetchProducts(
    List<StoreCategory> preferredCategories,
  ) async {
    final byId = <String, Map<String, dynamic>>{};

    Future<void> ingest(QuerySnapshot<Map<String, dynamic>> snap) async {
      for (final doc in snap.docs) {
        final data = {...doc.data(), 'id': doc.id};
        final status = data['approvalStatus']?.toString() ?? 'approved';
        if (status != 'approved') continue;
        byId.putIfAbsent(doc.id, () => data);
      }
    }

    try {
      final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
      for (final category in preferredCategories.take(6)) {
        for (final title in storeCategoryQueryTitles(category)) {
          queries.add(
            _db
                .collection('product')
                .where('category', isEqualTo: title)
                .limit(40)
                .get(),
          );
        }
      }
      // Broad sample so soft matches still work when category tags are messy.
      queries.add(_db.collection('product').limit(120).get());

      final snaps = await Future.wait(queries);
      for (final snap in snaps) {
        await ingest(snap);
      }
    } catch (_) {
      try {
        final snap = await _db.collection('product').limit(120).get();
        await ingest(snap);
      } catch (_) {}
    }

    return byId.values.toList();
  }

  Future<List<WritingExpert>> _fetchWritingExperts() async {
    try {
      final snap = await _db.collection('writing_services').limit(60).get();
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
    required List<StoreCategory> preferredCategories,
    int limit = 8,
  }) {
    if (products.isEmpty) return const [];

    final preferredTitles = <String>{};
    for (final cat in preferredCategories) {
      preferredTitles.addAll(storeCategoryQueryTitles(cat));
      preferredTitles.add(cat.title);
    }

    final scored = products.map((data) {
      final rawCategory = data['category']?.toString() ?? '';
      final normalized =
          storeCategoryByTitle(rawCategory)?.title ?? rawCategory;
      final text = [
        data['name'],
        data['description'],
        rawCategory,
        normalized,
        data['storeName'],
        data['tags'],
      ].join(' ').toLowerCase();

      var score = 0;
      final reasons = <String>[];
      for (final kw in keywords) {
        if (kw.length >= 3 && text.contains(kw)) {
          score += 12;
          reasons.add(appTr('يتوافق مع «$kw»', 'Matches "$kw"'));
        }
      }

      if (preferredTitles.contains(rawCategory) ||
          preferredTitles.contains(normalized)) {
        score += 22;
        reasons.add(
          appTr(
            'من قسم مناسب لبحثك',
            'From a section suited to your research',
          ),
        );
      }

      // Soft boost for always-useful lab supplies.
      if (normalized.contains('مستهلك') ||
          normalized.contains('أجهزة') ||
          normalized.contains('سلامة') ||
          normalized.contains('كتب')) {
        score += 6;
      }

      return SupplyChainProduct(
        id: data['id']?.toString(),
        name: data['name']?.toString() ?? appTr('منتج', 'Product'),
        price: (data['price'] as num?) ?? 0,
        category: normalized.isNotEmpty ? normalized : rawCategory,
        imageUrl: data['imageUrl']?.toString(),
        createdBy: data['createdBy']?.toString(),
        score: score.clamp(0, 100),
        reasons: reasons.toSet().take(2).toList(),
      );
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final matched = scored.where((p) => p.score > 0).take(limit).toList();
    if (matched.isNotEmpty) return matched;

    // Prefer products already in preferred sections over arbitrary catalogue.
    final inPreferred = scored
        .where(
          (p) =>
              preferredTitles.contains(p.category) ||
              preferredCategories.any(
                (c) =>
                    p.category == c.title ||
                    storeCategoryQueryTitles(c).contains(p.category),
              ),
        )
        .take(limit)
        .map(
          (p) => SupplyChainProduct(
            id: p.id,
            name: p.name,
            price: p.price,
            category: p.category,
            imageUrl: p.imageUrl,
            createdBy: p.createdBy,
            score: 24,
            reasons: [
              appTr(
                'من قسم قد يفيد مسار بحثك',
                'From a section that may help your research path',
              ),
            ],
          ),
        )
        .toList();
    if (inPreferred.isNotEmpty) return inPreferred;

    return scored
        .take(limit)
        .map(
          (p) => SupplyChainProduct(
            id: p.id,
            name: p.name,
            price: p.price,
            category: p.category,
            imageUrl: p.imageUrl,
            createdBy: p.createdBy,
            score: 15,
            reasons: [
              appTr(
                'خيار عام من المتجر الأكاديمي',
                'General option from the academic store',
              ),
            ],
          ),
        )
        .toList();
  }

  List<MatchResult<WritingExpert>> _matchWritingExperts(
    AcademicProfile profile,
    List<WritingExpert> experts, {
    int limit = 4,
  }) {
    if (experts.isEmpty) return const [];

    final preferredCategory = _inferWritingCategory(profile);
    final scored = <MatchResult<WritingExpert>>[];

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
        if (kw.length >= 3 && text.contains(kw)) score += 10;
      }

      if (_isPhdDegree(profile.degree) && expert.category.contains('رسائل')) {
        score += 20;
        reasons.add(
          appTr('مناسب لمرحلة الدكتوراه', 'Suitable for PhD stage'),
        );
      } else if (_isMastersDegree(profile.degree) &&
          (expert.category.contains('رسائل') ||
              expert.category.contains('إحصاء'))) {
        score += 18;
        reasons.add(
          appTr('يدعم رسائل الماجستير', 'Supports master\'s theses'),
        );
      }

      if (preferredCategory != null &&
          expert.category.contains(preferredCategory)) {
        score += 15;
        reasons.add(
          appTr(
            'خدمة كتابة مناسبة لنوع بحثك',
            'Writing service suited to your research type',
          ),
        );
      }

      if (_isQuantitativeMethodology(profile.methodology) &&
          expert.category.contains('إحصاء')) {
        score += 12;
        reasons.add(
          appTr('تحليل كمي متاح', 'Quantitative analysis available'),
        );
      }

      scored.add(
        MatchResult(
          item: expert,
          score: score.clamp(0, 100),
          reasons: reasons.isEmpty
              ? [
                  appTr(
                    'كاتب أكاديمي مقترح',
                    'Suggested academic writer',
                  ),
                ]
              : reasons,
        ),
      );
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final matched = scored.where((e) => e.score > 0).take(limit).toList();
    if (matched.isNotEmpty) return matched;
    return scored.take(limit).toList();
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
    List<MatchResult<AcademicResearchIdea>> ideas = const [],
    List<MatchResult<AcademicSupervisor>> supervisors = const [],
    List<MatchResult<AcademicLab>> labs = const [],
    List<SupplyChainProduct> products = const [],
    List<MatchResult<WritingExpert>> experts = const [],
    List<StoreCategory> storeCategories = const [],
  }) {
    final lines = <String>[];
    if (ideas.isNotEmpty) {
      lines.add(appTr(
        '💡 ${ideas.length} أفكار بحثية مقترحة (أفضلها: ${ideas.first.item.title})',
        '💡 ${ideas.length} research ideas (top: ${ideas.first.item.title})',
      ));
    }
    if (supervisors.isNotEmpty) {
      lines.add(appTr(
        '👤 ${supervisors.length} مشرفين (أفضلهم: ${supervisors.first.item.name})',
        '👤 ${supervisors.length} supervisors (top: ${supervisors.first.item.name})',
      ));
    }
    if (labs.isNotEmpty) {
      lines.add(appTr(
        '🔬 ${labs.length} مختبرات (أفضلها: ${labs.first.item.name})',
        '🔬 ${labs.length} labs (top: ${labs.first.item.name})',
      ));
    }
    if (storeCategories.isNotEmpty) {
      lines.add(appTr(
        '🛒 أقسام متجر: ${storeCategories.map((c) => c.title).join('، ')}',
        '🛒 Store sections: ${storeCategories.map((c) => c.title).join(', ')}',
      ));
    }
    if (products.isNotEmpty) {
      lines.add(appTr(
        '📦 ${products.length} منتج/ات مقترحة',
        '📦 ${products.length} suggested product(s)',
      ));
    }
    if (experts.isNotEmpty) {
      lines.add(appTr(
        '✍️ ${experts.length} خدمات كتابة (أفضلها: ${experts.first.item.name})',
        '✍️ ${experts.length} writing services (top: ${experts.first.item.name})',
      ));
    }
    return lines;
  }
}
