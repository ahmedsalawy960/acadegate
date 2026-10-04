import '../academic/academic_content_service.dart';
import '../academic/academic_models.dart';
import '../ai_advisor/grounded_reference_service.dart';
import '../humanities/humanities_gap_ideas_seed.dart';
import '../research_marketplace/seed/egypt_research_ideas_seed.dart';
import 'topic_english_search.dart';
import 'topic_similarity.dart';

class TopicSimilarHit {
  final String title;
  final String source;
  final double score;
  final String? ideaId;
  final String? url;

  const TopicSimilarHit({
    required this.title,
    required this.source,
    required this.score,
    this.ideaId,
    this.url,
  });
}

class TopicDuplicationReport {
  final String queryTitle;
  final List<TopicSimilarHit> marketplaceHits;
  final List<TopicSimilarHit> literatureHits;
  final List<TopicExternalSearchLink> externalChecks;

  const TopicDuplicationReport({
    required this.queryTitle,
    this.marketplaceHits = const [],
    this.literatureHits = const [],
    this.externalChecks = const [],
  });

  double get maxMarketplaceScore => marketplaceHits.isEmpty
      ? 0
      : marketplaceHits.map((e) => e.score).reduce((a, b) => a > b ? a : b);

  double get maxLiteratureScore => literatureHits.isEmpty
      ? 0
      : literatureHits.map((e) => e.score).reduce((a, b) => a > b ? a : b);

  /// تقدير إجمالي حذر — ليس حكماً نهائياً.
  String overallRiskAr() {
    final m = maxMarketplaceScore;
    final lit = maxLiteratureScore;
    final top = m > lit ? m : lit;
    if (top >= 0.78) {
      return 'تحذير: عناوين قريبة جداً — راجع الفجوة وصغ زاوية أدق قبل الاعتماد.';
    }
    if (top >= 0.55) {
      return 'احتمال تكرار متوسط — ميّز مجتمع الدراسة أو المتغير أو الإطار النظري.';
    }
    if (top >= 0.35) {
      return 'تشابه محدود — يمكنك المتابعة مع توثيق الفجوة.';
    }
    return 'لم يظهر تشابه قوي في المصادر المتاحة داخل التطبيق (فحص تقريبي فقط).';
  }

  String overallRiskEn() {
    final m = maxMarketplaceScore;
    final lit = maxLiteratureScore;
    final top = m > lit ? m : lit;
    if (top >= 0.78) {
      return 'Warning: very close titles — refine the gap/angle before adopting.';
    }
    if (top >= 0.55) {
      return 'Medium duplication risk — differentiate sample, variable, or theory.';
    }
    if (top >= 0.35) {
      return 'Limited similarity — proceed while documenting the gap.';
    }
    return 'No strong in-app similarity found (approximate check only).';
  }
}

class TopicExternalSearchLink {
  final String labelAr;
  final String labelEn;
  final String url;

  const TopicExternalSearchLink({
    required this.labelAr,
    required this.labelEn,
    required this.url,
  });
}

class TopicDuplicationService {
  TopicDuplicationService._();
  static final TopicDuplicationService instance = TopicDuplicationService._();

  Future<TopicDuplicationReport> check({
    required String title,
    String details = '',
    AcademicResearchIdea? excludeIdea,
    TopicEnglishSearchPlan? englishSearch,
  }) async {
    final q = title.trim();
    if (q.length < 4) {
      return TopicDuplicationReport(queryTitle: q);
    }

    final enPlan = englishSearch ??
        await TopicEnglishSearch.instance.build(
          title: title,
          details: details,
          category: excludeIdea?.category ?? '',
          tags: excludeIdea?.tags ?? const [],
        );
    final litQuery = enPlan.englishTopic.isNotEmpty ? enPlan.englishTopic : q;

    final candidates = <_Cand>[];
    void addCand(String t, String source, {String? id}) {
      final tt = t.trim();
      if (tt.length < 4) return;
      if (excludeIdea != null &&
          (id == excludeIdea.id ||
              TopicSimilarity.normalize(tt) ==
                  TopicSimilarity.normalize(excludeIdea.title))) {
        return;
      }
      candidates.add(_Cand(tt, source, id));
    }

    for (final seed in egyptResearchIdeasSeed) {
      addCand(seed.title, 'حزمة مصر');
    }
    for (final seed in humanitiesGapIdeasSeed) {
      addCand(seed.title, 'فجوات إنسانيات');
    }

    try {
      final live = await AcademicContentService.instance
          .researchIdeasStream()
          .first
          .timeout(const Duration(seconds: 8), onTimeout: () => const []);
      for (final idea in live) {
        addCand(idea.title, 'سوق الأفكار', id: idea.id);
      }
    } catch (_) {}

    final marketplaceHits = <TopicSimilarHit>[];
    for (final c in candidates) {
      final s = TopicSimilarity.score(q, c.title);
      if (s < 0.35) continue;
      marketplaceHits.add(
        TopicSimilarHit(
          title: c.title,
          source: c.source,
          score: s,
          ideaId: c.id,
        ),
      );
    }
    marketplaceHits.sort((a, b) => b.score.compareTo(a.score));

    final literatureHits = <TopicSimilarHit>[];
    try {
      final bundle = await GroundedReferenceService.instance.searchScientific(
        queries: enPlan.queries.isNotEmpty ? enPlan.queries : [q],
        limit: 12,
        preferEnglish: true,
        minYear: 0,
        includeTheses: true,
        requireDoi: false,
        minScore: 2,
        commandText: '$litQuery ${details.trim()}'.trim(),
        corePhrases: TopicSimilarity.tokens(litQuery).take(8),
      );
      for (final w in bundle.works) {
        final s = TopicSimilarity.score(litQuery, w.title);
        final displayScore = s < 0.25 ? 0.25 : s;
        literatureHits.add(
          TopicSimilarHit(
            title: w.title,
            source: w.source,
            score: displayScore,
            url: w.primaryUrl.isEmpty ? null : w.primaryUrl,
          ),
        );
      }
      literatureHits.sort((a, b) => b.score.compareTo(a.score));
    } catch (_) {
      try {
        final bundle = await GroundedReferenceService.instance.searchTopic(
          litQuery,
          limit: 10,
          byRelevance: true,
        );
        for (final w in bundle.works) {
          final s = TopicSimilarity.score(litQuery, w.title);
          final displayScore = s < 0.25 ? 0.25 : s;
          literatureHits.add(
            TopicSimilarHit(
              title: w.title,
              source: w.source,
              score: displayScore,
              url: w.primaryUrl.isEmpty ? null : w.primaryUrl,
            ),
          );
        }
        literatureHits.sort((a, b) => b.score.compareTo(a.score));
      } catch (_) {}
    }

    final scholarQ = Uri.encodeComponent(litQuery);
    final arabicQ = Uri.encodeComponent(q);
    final external = <TopicExternalSearchLink>[
      TopicExternalSearchLink(
        labelAr: 'Google Scholar (إنجليزي)',
        labelEn: 'Google Scholar (English)',
        url: 'https://scholar.google.com/scholar?q=$scholarQ',
      ),
      TopicExternalSearchLink(
        labelAr: 'Google Scholar (العنوان الأصلي)',
        labelEn: 'Google Scholar (original title)',
        url: 'https://scholar.google.com/scholar?q=$arabicQ',
      ),
      TopicExternalSearchLink(
        labelAr: 'دار المنظومة (بحث يدوي)',
        labelEn: 'Mandumah (manual search)',
        url: 'https://search.mandumah.com/Search/Results?lookfor=$arabicQ',
      ),
      TopicExternalSearchLink(
        labelAr: 'بنك المعرفة المصري EKB',
        labelEn: 'Egyptian Knowledge Bank',
        url: 'https://www.ekb.eg/',
      ),
      TopicExternalSearchLink(
        labelAr: 'بحث جامعات مصر (Google)',
        labelEn: 'Egypt universities (Google)',
        url:
            'https://www.google.com/search?q=${Uri.encodeComponent('$q رسالة ماجستير OR دكتوراه site:.edu.eg')}',
      ),
    ];

    return TopicDuplicationReport(
      queryTitle: q,
      marketplaceHits: marketplaceHits.take(8).toList(),
      literatureHits: literatureHits.take(8).toList(),
      externalChecks: external,
    );
  }
}

class _Cand {
  final String title;
  final String source;
  final String? id;
  _Cand(this.title, this.source, this.id);
}
