import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/locale/app_translate.dart';
import '../academic/academic_content_service.dart';
import '../academic/academic_degrees.dart';
import '../academic/academic_models.dart';
import '../academic_writing/writing_models.dart';
import '../ai_advisor/grounded_reference_service.dart';
import '../ai_advisor/grounded_work.dart';
import '../matchmaking/smart_matchmaking_engine.dart';
import '../supervisor_import/multi_source_supervisor_service.dart';
import '../profile/academic_profile.dart';
import '../research_fund/industry_challenge_models.dart';
import '../lab_import/nbsle_university_cities.dart';
import '../store/store_categories.dart';
import 'research_goal.dart';
import 'research_path_ai_service.dart';
import 'research_supply_chain_models.dart';

class ResearchSupplyChainEngine {
  ResearchSupplyChainEngine._();

  static final ResearchSupplyChainEngine instance =
      ResearchSupplyChainEngine._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _ideaLimit = 6;
  static const _supervisorLimit = 8;
  static const _labLocalLimit = 8;
  static const _labOtherLimit = 6;
  static const _productLocalLimit = 10;
  static const _productOtherLimit = 6;
  static const _writerLimit = 4;
  static const _literatureTarget = 15;

  Future<ResearchSupplyBundle> buildBundle({
    required String topic,
    AcademicProfile? profile,
  }) async {
    final trimmed = topic.trim();
    var goal = ResearchGoalParser.parse(
      trimmed,
      profileDegree: profile?.degree,
    );
    goal = await ResearchPathAiService.instance.briefGoal(goal);
    final effectiveProfile = _effectiveProfile(profile, trimmed, goal);
    final keywords = _richKeywords(
      effectiveProfile,
      [
        goal.fieldEn,
        goal.field,
        ...goal.searchQueries,
        ...goal.matchKeywords,
        ...goal.methods,
      ].join(' '),
    );

    final content = await AcademicContentService.instance.fetchAll(
      includeLabs: true,
    );

    // Prefer faculty-scoped labs (larger pool) then merge with cached browse.
    final facultyId = effectiveProfile.resolvedFacultyCategory;
    final researcherCity = effectiveProfile.city.trim();
    final topicQuery = goal.fieldEn.isNotEmpty
        ? goal.fieldEn
        : (goal.field.length >= 3 ? goal.field : trimmed);

    final cityLabsFuture = researcherCity.isEmpty
        ? Future.value(const <AcademicLab>[])
        : AcademicContentService.instance.searchLabs(
            city: researcherCity,
            facultyId: facultyId,
            query: topicQuery,
            limit: 250,
          );
    final nationLabsFuture = AcademicContentService.instance.searchLabs(
      facultyId: facultyId,
      query: topicQuery,
      limit: 250,
    );

    final cityLabs = await cityLabsFuture;
    final nationLabs = await nationLabsFuture;

    final labsById = <String, AcademicLab>{};
    for (final lab in [...cityLabs, ...nationLabs, ...content.labs]) {
      final key = lab.id ?? '${lab.name}|${lab.university}|${lab.city}';
      labsById.putIfAbsent(key, () => lab);
    }
    final labsPool = labsById.values.toList();

    final topicTokens = ResearchGoalParser.relevanceTokens(goal);
    final preferredCategories = _inferStoreCategories(topicTokens);
    final productsFuture = _fetchProducts(
      preferredCategories,
      researcherCity: researcherCity,
    );
    final expertsFuture = _fetchWritingExperts();
    final literatureFuture = _loadLiterature(goal);
    final challengesFuture =
        IndustryChallengeService.instance.getRecentChallenges();

    final products = await productsFuture;
    final experts = await expertsFuture;
    final literature = await literatureFuture;
    final challenges = await challengesFuture;

    final ideaMatches = SmartMatchmakingEngine.matchResearchIdeas(
      effectiveProfile,
      content.ideas,
      limit: _ideaLimit,
      softFallback: false,
      requireTokens: topicTokens,
    );
    List<AcademicSupervisor> liveSupervisors = const [];
    try {
      final hits = await MultiSourceSupervisorService.instance.search(
        topic: goal.fieldEn.isNotEmpty ? goal.fieldEn : goal.field,
        university: effectiveProfile.university,
        limit: 16,
      );
      liveSupervisors = hits.map((h) => h.toAcademicSupervisor()).toList();
    } catch (_) {}
    final catalogKeys = {
      for (final s in content.supervisors)
        if (s.orcid.isNotEmpty)
          'orcid:${s.orcid.toLowerCase()}'
        else
          'name:${s.name.toLowerCase()}',
    };
    final extraSupervisors = liveSupervisors.where((s) {
      final key = s.orcid.isNotEmpty
          ? 'orcid:${s.orcid.toLowerCase()}'
          : 'name:${s.name.toLowerCase()}';
      return !catalogKeys.contains(key);
    });
    final supervisorMatches = SmartMatchmakingEngine.matchSupervisors(
      effectiveProfile,
      [...content.supervisors, ...extraSupervisors],
      limit: _supervisorLimit,
      softFallback: false,
      requireTokens: topicTokens,
      restrictFaculty: false,
    );
    final labMatches = SmartMatchmakingEngine.matchLabs(
      effectiveProfile,
      labsPool,
      limit: _labLocalLimit + _labOtherLimit,
      softFallback: false,
      requireTokens: topicTokens,
      restrictFaculty: false,
      cityFirst: true,
      localLimit: _labLocalLimit,
      otherLimit: _labOtherLimit,
    );

    final productMatches = _matchProducts(
      topicTokens,
      products,
      preferredCategories: preferredCategories,
      researcherCity: researcherCity,
      localLimit: _productLocalLimit,
      otherLimit: _productOtherLimit,
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
      literatureCount: literature.length,
    );
    final fundingFits = _matchFunding(goal, keywords, challenges);

    return ResearchSupplyBundle(
      topic: goal.field.isNotEmpty ? goal.field : trimmed,
      ideas: ideaMatches,
      supervisors: supervisorMatches,
      labs: labMatches,
      products: productMatches,
      storeCategory: primaryStore,
      storeCategories: preferredCategories,
      writingExperts: writingMatches,
      overallScore: overall,
      chainSummary: summary,
      goal: goal,
      degreePlan: DegreePlanEngine.build(goal),
      literature: literature,
      institutionalNotes: DegreePlanEngine.institutionalNotes(goal),
      fundingFits: fundingFits,
    );
  }

  Future<List<GroundedWork>> _loadLiterature(ResearchGoal goal) async {
    final refs = GroundedReferenceService.instance;
    final merged = <String, GroundedWork>{};
    final tokens = ResearchGoalParser.relevanceTokens(goal)
        .where((t) => RegExp(r'^[a-zA-Z0-9\-]{3,}$').hasMatch(t))
        .toList();
    final queries = <String>[
      if (goal.fieldEn.length >= 4) goal.fieldEn,
      ...goal.searchQueries,
      if (goal.methods.isNotEmpty) goal.methods.take(3).join(' '),
    ];
    if (queries.isEmpty && goal.field.length >= 4) {
      queries.add(goal.field);
    }

    Future<void> ingest(String query) async {
      if (query.trim().length < 4) return;
      try {
        final bundle = await refs.searchTopic(
          query,
          limit: 20,
          byRelevance: true,
          mustMatchTokens: tokens,
        );
        for (final work in bundle.works) {
          if (!ResearchGoalParser.titleMatchesTopic(work.title, tokens) &&
              tokens.isNotEmpty) {
            continue;
          }
          merged.putIfAbsent(work.doi.toLowerCase(), () => work);
        }
      } catch (_) {}
    }

    for (final query in queries.take(4)) {
      await ingest(query);
      if (merged.length >= _literatureTarget) break;
    }

    final works = merged.values.toList()
      ..sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
    return works.take(20).toList();
  }

  List<FundingFit> _matchFunding(
    ResearchGoal goal,
    List<String> keywords,
    List<IndustryChallenge> challenges,
  ) {
    final fits = <FundingFit>[];
    final scored = <({IndustryChallenge challenge, int score})>[];
    for (final challenge in challenges) {
      if (!challenge.isOpen) continue;
      final text = [
        challenge.title,
        challenge.problem,
        challenge.acceptanceCriteria,
        challenge.companyName,
      ].join(' ').toLowerCase();
      var score = 0;
      for (final kw in keywords) {
        if (kw.length >= 3 && text.contains(kw)) score += 12;
      }
      if (score > 0) scored.add((challenge: challenge, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    for (final row in scored.take(4)) {
      fits.add(
        FundingFit(
          title: row.challenge.title,
          kind: 'industry_challenge',
          why: appTr(
            'تحدٍ صناعي بعربون — ${row.challenge.companyName}',
            'Industry challenge with escrow — ${row.challenge.companyName}',
          ),
          challengeId: row.challenge.id,
          budget: row.challenge.budgetAmount,
          currency: row.challenge.currency,
        ),
      );
    }
    fits.add(
      FundingFit(
        title: appTr('صندوق تمويل البحث', 'Research fund'),
        kind: 'research_fund',
        why: appTr(
          'إن فُعّل الصندوق يمكن ترشيح فكرة مؤهلة بعد التصويت — بلا اختراع ممول.',
          'If the fund is enabled, an eligible idea can be nominated after votes — no invented funder.',
        ),
      ),
    );
    if (goal.institution != InstitutionTarget.unspecified) {
      fits.add(
        FundingFit(
          title: goal.institutionLabel,
          kind: 'institutional',
          why: appTr(
            'مذكرة الأثر تُبنى من حقلك فقط. لا تُسمَّى جهة خارج المنصة ما لم تظهر هنا.',
            'The impact brief is built from your field only. No external organization is named unless it appears here.',
          ),
        ),
      );
    }
    return fits;
  }

  AcademicProfile _effectiveProfile(
    AcademicProfile? profile,
    String topic,
    ResearchGoal goal,
  ) {
    if (profile != null && profile.isComplete) {
      final field = goal.field.isNotEmpty ? goal.field : topic;
      final mergedInterest = field.isEmpty
          ? profile.researchInterest
          : '$field ${profile.researchInterest}'.trim();
      final mergedSpec = field.isEmpty
          ? profile.specialization
          : '${profile.specialization} $field'.trim();
      return profile.copyWith(
        researchInterest: mergedInterest,
        specialization: mergedSpec,
        degree: goal.track == ResearchDegreeTrack.unspecified
            ? profile.degree
            : goal.profileDegreeValue(),
        skills: {
          ...profile.skills,
          ...goal.matchKeywords,
          ...goal.methods,
          if (goal.fieldEn.isNotEmpty) goal.fieldEn,
        }.toList(),
      );
    }

    return AcademicProfile(
      fullName: profile?.fullName ?? '',
      university: profile?.university ?? '',
      degree: profile?.degree.isNotEmpty == true
          ? profile!.degree
          : goal.profileDegreeValue(),
      facultyCategory: profile?.facultyCategory ?? '',
      specialization: [
        if (goal.fieldEn.isNotEmpty) goal.fieldEn,
        if (goal.field.isNotEmpty) goal.field else topic,
      ].join(' '),
      researchInterest: goal.fieldEn.isNotEmpty
          ? goal.fieldEn
          : (goal.field.isNotEmpty ? goal.field : topic),
      methodology: profile?.methodology ?? appTr('كمي', 'Quantitative'),
      preferredLanguage:
          profile?.preferredLanguage ?? appTr('العربية', 'Arabic'),
      city: profile?.city ?? '',
      skills: {
        ...?profile?.skills,
        ...goal.matchKeywords,
        ...goal.methods,
        if (goal.fieldEn.isNotEmpty) goal.fieldEn,
      }.toList(),
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

  static bool _hayHasKey(String haystack, String key) {
    if (key.isEmpty) return false;
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(key)) {
      return haystack.contains(key);
    }
    if (key.length <= 3) {
      return RegExp(
        '(^|[^a-z0-9])${RegExp.escape(key)}([^a-z0-9]|\$)',
        caseSensitive: false,
      ).hasMatch(haystack);
    }
    return haystack.contains(key);
  }

  /// Public for tests: category ids inferred from the research point only.
  static List<String> inferStoreCategoryIds(Iterable<String> keywords) {
    const rules = <String, String>{
      'كيم': 'chemicals',
      'chem': 'chemicals',
      'analytic': 'chemicals',
      'كاشف': 'chemicals',
      'reagent': 'chemicals',
      'chromat': 'chemicals',
      'titr': 'chemicals',
      'oil': 'chemicals',
      'refin': 'chemicals',
      'adsorp': 'chemicals',
      'بيول': 'biology',
      'حيو': 'biology',
      'dna': 'biology',
      'pcr': 'biology',
      'nano': 'biology',
      'طبي': 'medical',
      'medical': 'medical',
      'صيدل': 'medical',
      'أسنان': 'medical',
      'clinic': 'medical',
      'هند': 'engineering',
      'engineer': 'engineering',
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
      'artificial': 'computing',
      'مستهلك': 'consumables',
      'جهاز': 'instruments',
      'قياس': 'instruments',
      'spectr': 'instruments',
      'hplc': 'instruments',
      'gc-ms': 'instruments',
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
      if (_hayHasKey(haystack, entry.key)) {
        found.add(entry.value);
      }
    }

    if (found.any((id) =>
        id == 'chemicals' ||
        id == 'biology' ||
        id == 'medical' ||
        id == 'physics_materials' ||
        id == 'agriculture')) {
      found.add('consumables');
      found.add('instruments');
      found.add('safety');
    }
    if (found.contains('computing') || found.contains('humanities')) {
      found.add('books');
      found.add('office');
    }
    return found.toList();
  }

  List<StoreCategory> _inferStoreCategories(List<String> keywords) {
    final found = inferStoreCategoryIds(keywords);
    final categories = <StoreCategory>[];
    for (final id in found) {
      final cat = storeCategoryById(id);
      if (cat != null) categories.add(cat);
    }
    return categories;
  }

  Future<List<Map<String, dynamic>>> _fetchProducts(
    List<StoreCategory> preferredCategories, {
    String researcherCity = '',
  }) async {
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
                .limit(50)
                .get(),
          );
        }
      }
      for (final alias in NbsleUniversityCities.cityQueryValues(researcherCity)) {
        queries.add(
          _db.collection('product').where('city', isEqualTo: alias).limit(50).get(),
        );
      }
      if (queries.isEmpty) return const [];

      final snaps = await Future.wait(queries);
      for (final snap in snaps) {
        await ingest(snap);
      }
    } catch (_) {
      return const [];
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
    String researcherCity = '',
    int localLimit = 10,
    int otherLimit = 6,
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
      final city = data['city']?.toString() ?? '';
      final storeName = data['storeName']?.toString() ?? '';
      final topicText = [
        data['name'],
        data['description'],
        data['tags'],
      ].join(' ');
      final hits = SmartMatchmakingEngine.topicHitCount(topicText, keywords);

      var score = 0;
      final reasons = <String>[];
      if (hits > 0) {
        score += (hits * 18).clamp(0, 72);
        final matchedKw = SmartMatchmakingEngine.meaningfulTokens(keywords)
            .where((kw) => topicText.toLowerCase().contains(kw))
            .take(2);
        for (final kw in matchedKw) {
          reasons.add(appTr('يتوافق مع «$kw»', 'Matches "$kw"'));
        }
      }

      if (hits > 0 &&
          (preferredTitles.contains(rawCategory) ||
              preferredTitles.contains(normalized))) {
        score += 16;
        reasons.add(
          appTr(
            'من قسم مناسب لبحثك',
            'From a section suited to your research',
          ),
        );
      }

      final local = NbsleUniversityCities.isSameCity(city, researcherCity);
      if (hits > 0 && local) {
        score += 10;
        reasons.add(appTr('متوفر في مدينتك', 'Available in your city'));
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
        city: city,
        storeName: storeName,
      );
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final matched = scored.where((p) => p.score > 0).toList();
    if (researcherCity.trim().isEmpty) {
      return matched.take(localLimit + otherLimit).toList();
    }
    final local = matched
        .where((p) => NbsleUniversityCities.isSameCity(p.city, researcherCity))
        .take(localLimit);
    final other = matched
        .where((p) => !NbsleUniversityCities.isSameCity(p.city, researcherCity))
        .take(otherLimit);
    return [...local, ...other];
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

  bool _isPhdDegree(String degree) => isDoctoralDegree(degree);

  bool _isMastersDegree(String degree) => isMastersLevelDegree(degree);

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
    int literatureCount = 0,
  }) {
    final lines = <String>[];
    if (ideas.isNotEmpty) {
      lines.add(appTr(
        '💡 ${ideas.length} أفكار بحثية مقترحة (أفضلها: ${ideas.first.item.title})',
        '💡 ${ideas.length} research ideas (top: ${ideas.first.item.title})',
      ));
    } else {
      lines.add(appTr(
        '💡 لا فكرة في الكتالوج تشارك كلمات نقطة بحثك — لن نعرض أفكاراً من كلية أخرى.',
        '💡 No catalog idea shares your topic words — off-faculty ideas are not shown.',
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
    } else {
      lines.add(appTr(
        '🔬 لا مختبر يشارك اسمه أو أجهزته كلمات موضوعك — أفضل قائمة فارغة من توافق 100% بلا صلة.',
        '🔬 No lab name or equipment shares your topic words — an empty list is better than a 100% mismatch.',
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
    } else {
      lines.add(appTr(
        '📦 لا مادة في المتجر يظهر اسمها في نقطة بحثك — لن نملأ القائمة بإلكترونيات عامة.',
        '📦 No store item name appears in your topic — the list is not filled with generic electronics.',
      ));
    }
    if (experts.isNotEmpty) {
      lines.add(appTr(
        '✍️ ${experts.length} خدمات كتابة (أفضلها: ${experts.first.item.name})',
        '✍️ ${experts.length} writing services (top: ${experts.first.item.name})',
      ));
    }
    if (literatureCount > 0) {
      lines.add(appTr(
        '📚 $literatureCount دراسة مؤكدة DOI من OpenAlex/Crossref/Semantic Scholar',
        '📚 $literatureCount DOI-confirmed studies from OpenAlex/Crossref/Semantic Scholar',
      ));
    }
    return lines;
  }
}
