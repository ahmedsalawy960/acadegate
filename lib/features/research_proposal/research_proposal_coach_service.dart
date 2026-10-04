import 'dart:convert';

import '../academic/faculty_departments.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import '../ai_advisor/grounded_reference_service.dart';
import '../ai_advisor/grounded_work.dart';
import '../research_supply_chain/research_goal.dart';
import '../topic_bank/topic_english_search.dart';
import '../topic_bank/topic_similarity.dart';
import 'research_proposal_models.dart';
import 'research_proposal_storage.dart';
import 'research_proposal_templates.dart';
import 'research_proposal_workshop.dart';

class ProposalCoachFinding {
  final String severity; // high | medium | low | ok
  final String titleAr;
  final String titleEn;
  final String detailAr;
  final String detailEn;
  final String? sectionKey;

  const ProposalCoachFinding({
    required this.severity,
    required this.titleAr,
    required this.titleEn,
    required this.detailAr,
    required this.detailEn,
    this.sectionKey,
  });
}

class ProposalCoachResult {
  final int readinessScore;
  final List<ProposalCoachFinding> findings;
  final Map<String, String> suggestedSections;
  final List<GroundedWork> priorWorks;
  final String englishSearchTopic;
  final List<String> searchQueriesUsed;
  final bool usedAi;
  final String summaryAr;
  final String summaryEn;

  const ProposalCoachResult({
    required this.readinessScore,
    required this.findings,
    required this.suggestedSections,
    required this.priorWorks,
    this.englishSearchTopic = '',
    this.searchQueriesUsed = const [],
    this.usedAi = false,
    this.summaryAr = '',
    this.summaryEn = '',
  });
}

/// تشخيص عميق + جلب دراسات بجودة اعتماد النقطة (استعلام إنجليزي + core tokens).
class ResearchProposalCoachService {
  ResearchProposalCoachService._();
  static final ResearchProposalCoachService instance =
      ResearchProposalCoachService._();

  Future<ProposalCoachResult> diagnoseAndAssist(ProposalDraft draft) async {
    final seedTitle = draft.titleAr.trim().isNotEmpty
        ? draft.titleAr.trim()
        : _firstLine(draft.section(ProposalSectionKeys.problem));
    final seedDetails = [
      draft.section(ProposalSectionKeys.problem),
      draft.section(ProposalSectionKeys.questions),
      draft.section(ProposalSectionKeys.objectives),
      draft.section(ProposalSectionKeys.methodology),
    ].where((e) => e.trim().isNotEmpty).join('\n');

    // 1) Deep local diagnosis (always) — not length-only.
    final findings = _deepLocalDiagnose(draft);

    // 2) English bibliographic plan (AI preferred) + expanded variants.
    final enPlan = await TopicEnglishSearch.instance.build(
      title: seedTitle.isNotEmpty ? seedTitle : 'Egypt research',
      details: seedDetails,
      category: draft.facultyId,
    );
    final queries = _expandQueries(enPlan, draft.facultyId);

    // 3) Parallel: AI coach + literature harvest.
    var usedAi = enPlan.usedAi;
    var summaryAr = '';
    var summaryEn = '';

    final aiFuture = GeminiAdvisorClient.isAvailable && seedTitle.length >= 6
        ? _aiCoach(draft, enTopic: enPlan.englishTopic, queries: queries)
        : Future<
            (
              Map<String, String>,
              List<ProposalCoachFinding>,
              String,
              String,
            )?>.value(null);

    final litFuture = _harvestLiterature(
      draft: draft,
      enPlan: enPlan,
      queries: queries,
      seedTitle: seedTitle,
      seedDetails: seedDetails,
    );

    final ai = await aiFuture;
    final works = await litFuture;

    // Smart topic-specific drafts first (never bracket placeholders).
    var suggested = _smartSuggestions(
      draft: draft,
      title: seedTitle,
      details: seedDetails,
      englishTopic: enPlan.englishTopic,
    );

    if (ai != null) {
      usedAi = true;
      for (final e in ai.$1.entries) {
        if (_isWeakTemplate(e.value)) continue;
        suggested[e.key] = e.value.trim();
      }
      for (final f in ai.$2) {
        if (f.titleAr.isEmpty && f.titleEn.isEmpty) continue;
        findings.add(f);
      }
      if (ai.$3.trim().isNotEmpty) summaryAr = ai.$3.trim();
      if (ai.$4.trim().isNotEmpty) summaryEn = ai.$4.trim();
    }

    // If AI was available but sections stayed weak, retry a focused rewrite.
    if (GeminiAdvisorClient.isAvailable &&
        seedTitle.length >= 6 &&
        _needsStrongerSections(suggested)) {
      try {
        final retry = await _aiSectionsOnly(
          draft,
          enTopic: enPlan.englishTopic,
          worksHint: works.take(4).map((w) => w.title).toList(),
        );
        if (retry != null) {
          usedAi = true;
          for (final e in retry.entries) {
            if (_isWeakTemplate(e.value)) continue;
            suggested[e.key] = e.value.trim();
          }
        }
      } catch (_) {}
    }

    // Strip any remaining weak templates rather than showing them.
    suggested.removeWhere((_, v) => _isWeakTemplate(v));
    if (suggested.isEmpty) {
      suggested = _smartSuggestions(
        draft: draft,
        title: seedTitle,
        details: seedDetails,
        englishTopic: enPlan.englishTopic,
      );
    }

    if (works.isEmpty) {
      findings.add(const ProposalCoachFinding(
        severity: 'high',
        titleAr: 'لم تُجلب دراسات كافية',
        titleEn: 'Too few prior studies fetched',
        detailAr:
            'جرّب توسيع المشكلة بجملة إنجليزية للمفاهيم الأساسية، أو سجّل الدخول لترجمة أدق ثم أعد التشخيص.',
        detailEn:
            'Add English key concepts in the problem, or sign in for better translation, then re-run.',
        sectionKey: ProposalSectionKeys.priorStudies,
      ));
    } else {
      findings.add(ProposalCoachFinding(
        severity: 'ok',
        titleAr: 'دراسات سابقة: ${works.length} عملاً مفهرساً',
        titleEn: 'Prior studies: ${works.length} indexed works',
        detailAr:
            'رُتّبت حسب الصلة. أدرجها نقدياً (اتفاق/اختلاف/فجوة) — الاستعلام: ${enPlan.englishTopic}',
        detailEn:
            'Ranked by relevance. Insert critically (agree/differ/gap) — query: ${enPlan.englishTopic}',
        sectionKey: ProposalSectionKeys.priorStudies,
      ));
    }

    if (summaryAr.isEmpty) {
      final highs = findings.where((f) => f.severity == 'high').length;
      summaryAr = highs == 0
          ? 'التشخيص جاهز. راجع الاقتراحات والدراسات ثم حسّن الجاهزية قبل القسم.'
          : 'وُجدت $highs ملاحظات عالية الأهمية — عالجها قبل العرض على القسم.';
      summaryEn = highs == 0
          ? 'Diagnosis ready. Review suggestions and studies, then improve readiness.'
          : '$highs high-priority notes found — fix them before the department.';
    }

    final score = _readinessScore(findings, works.length, suggested.length);

    // Dedupe findings by titleAr
    final seen = <String>{};
    final uniqueFindings = <ProposalCoachFinding>[];
    for (final f in findings) {
      final key = f.titleAr.trim().isEmpty ? f.titleEn : f.titleAr;
      if (!seen.add(key.toLowerCase())) continue;
      uniqueFindings.add(f);
    }
    uniqueFindings.sort((a, b) {
      int rank(String s) => s == 'high'
          ? 0
          : s == 'medium'
              ? 1
              : s == 'low'
                  ? 2
                  : 3;
      return rank(a.severity).compareTo(rank(b.severity));
    });

    return ProposalCoachResult(
      readinessScore: score,
      findings: uniqueFindings,
      suggestedSections: suggested,
      priorWorks: works,
      englishSearchTopic: enPlan.englishTopic,
      searchQueriesUsed: queries,
      usedAi: usedAi,
      summaryAr: summaryAr,
      summaryEn: summaryEn,
    );
  }

  ProposalDraft applySuggestions(
    ProposalDraft draft,
    ProposalCoachResult result, {
    bool overwriteFilled = false,
    bool insertPriorStudies = true,
  }) {
    for (final e in result.suggestedSections.entries) {
      final current = draft.section(e.key);
      if (overwriteFilled || current.length < 24) {
        draft.setSection(e.key, e.value.trim());
      }
    }
    if (insertPriorStudies && result.priorWorks.isNotEmpty) {
      final existing = draft.section(ProposalSectionKeys.priorStudies);
      final block = _criticalPriorBlock(
        result.priorWorks,
        topic: result.englishSearchTopic,
      );
      if (existing.length < 40) {
        draft.setSection(ProposalSectionKeys.priorStudies, block);
      } else if (!existing.contains(result.priorWorks.first.title)) {
        draft.setSection(
          ProposalSectionKeys.priorStudies,
          '$existing\n\n$block',
        );
      }
    }
    return draft;
  }

  /// يملأ قسماً واحداً في المسودة (AI إن وُجد، وإلا صياغة ذكية من الموضوع).
  Future<String> generateSectionText({
    required ProposalDraft draft,
    required String sectionKey,
  }) async {
    final title = draft.titleAr.trim().isNotEmpty
        ? draft.titleAr.trim()
        : _firstLine(draft.section(ProposalSectionKeys.problem));
    final details = [
      draft.section(ProposalSectionKeys.problem),
      draft.section(ProposalSectionKeys.questions),
      draft.section(ProposalSectionKeys.objectives),
    ].where((e) => e.trim().isNotEmpty).join('\n');

    if (title.trim().length < 4 && details.trim().length < 12) {
      return '';
    }

    if (GeminiAdvisorClient.isAvailable && title.length >= 4) {
      try {
        final ai = await _aiOneSection(
          draft: draft,
          sectionKey: sectionKey,
          title: title.isNotEmpty ? title : details,
          details: details,
        );
        if (ai != null && ai.trim().length >= 8 && !_isWeakTemplate(ai)) {
          return ai.trim();
        }
      } catch (_) {}
    }

    // Always have a concrete local fallback for every template section key.
    final local = sectionTextForKey(
      draft: draft,
      sectionKey: sectionKey,
      title: title.isNotEmpty ? title : details,
      details: details,
      englishTopic: '',
    );
    return local.trim();
  }

  /// يملأ كل أقسام القالب الفارغة (أو يستبدلها) ويحفظها في المسودة.
  Future<int> fillDraftSections({
    required ProposalDraft draft,
    bool overwriteFilled = false,
    List<String>? onlyKeys,
  }) async {
    final keys = onlyKeys ?? draft.activeSections;
    var filled = 0;

    final title = draft.titleAr.trim().isNotEmpty
        ? draft.titleAr.trim()
        : _firstLine(draft.section(ProposalSectionKeys.problem));
    final details = draft.section(ProposalSectionKeys.problem);
    if (title.trim().length < 4 && details.trim().length < 12) {
      return 0;
    }

    final smart = _smartSuggestions(
      draft: draft,
      title: title.isNotEmpty ? title : details,
      details: details,
      englishTopic: '',
      allKeys: true,
    );

    for (final key in keys) {
      final current = draft.section(key);
      if (!overwriteFilled && current.trim().length >= 24) continue;
      final local = smart[key]?.trim() ??
          sectionTextForKey(
            draft: draft,
            sectionKey: key,
            title: title,
            details: details,
            englishTopic: '',
          );
      if (local.isNotEmpty) {
        draft.setSection(key, local);
        filled++;
      }
    }

    if (GeminiAdvisorClient.isAvailable && title.length >= 4) {
      try {
        final aiMap = await _aiSectionsOnly(
          draft,
          enTopic: title,
          worksHint: const [],
        );
        if (aiMap != null) {
          for (final key in keys) {
            final current = draft.section(key);
            if (!overwriteFilled &&
                current.trim().length >= 40 &&
                !_isWeakTemplate(current)) {
              continue;
            }
            final v = aiMap[key]?.trim() ?? '';
            if (v.length >= 8 && !_isWeakTemplate(v)) {
              draft.setSection(key, v);
              filled++;
            }
          }
        }
      } catch (_) {}
    }

    // Guarantee every still-empty required key gets a local draft.
    for (final key in keys) {
      if (draft.section(key).trim().length >= 12) continue;
      if (!overwriteFilled && draft.section(key).trim().isNotEmpty) continue;
      final local = sectionTextForKey(
        draft: draft,
        sectionKey: key,
        title: title,
        details: details,
        englishTopic: '',
      );
      if (local.isNotEmpty) {
        draft.setSection(key, local);
        filled++;
      }
    }

    await ResearchProposalStorage.instance.save(draft);
    return filled;
  }

  Future<String?> _aiOneSection({
    required ProposalDraft draft,
    required String sectionKey,
    required String title,
    required String details,
  }) async {
    final labelAr = ProposalSectionKeys.labelAr(sectionKey);
    final hint = ProposalSectionKeys.hintAr(sectionKey);
    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: '''
Write ONE finished Egyptian academic thesis-proposal section in Arabic (or English if sectionKey is titleEn).
Return JSON only: {"text":"..."}
FORBIDDEN: square brackets [], ellipsis placeholders, "اكتب هنا".
Use concrete population/variables/method inferred from the topic.
No fake citations or DOIs.
''',
      userMessage: '''
Faculty: ${draft.facultyId}
Degree: ${draft.degreeLevel}
Section key: $sectionKey
Section label: $labelAr
Hint: $hint
Title: $title
Problem / context:
${details.length > 1200 ? details.substring(0, 1200) : details}
Other draft snippets:
questions: ${draft.section(ProposalSectionKeys.questions)}
objectives: ${draft.section(ProposalSectionKeys.objectives)}
methodology: ${draft.section(ProposalSectionKeys.methodology)}
''',
      maxOutputTokens: 1200,
      preferPro: true,
    );
    if (!result.isSuccess || result.text == null) return null;
    final text = result.text!.trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final map =
            jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
        final t = map['text']?.toString().trim() ?? '';
        if (t.isNotEmpty) return t;
      } catch (_) {}
    }
    // Plain text fallback
    if (text.length >= 20 && !text.startsWith('{')) return text;
    return null;
  }

  Future<List<GroundedWork>> _harvestLiterature({
    required ProposalDraft draft,
    required TopicEnglishSearchPlan enPlan,
    required List<String> queries,
    required String seedTitle,
    required String seedDetails,
  }) async {
    final scoreAgainst = enPlan.englishTopic.isNotEmpty
        ? enPlan.englishTopic
        : seedTitle;
    final tokenSource = '$scoreAgainst\n$seedDetails\n${queries.join(' ')}';
    final core = TopicSimilarity.tokens(scoreAgainst).take(10).toList();
    final strong = TopicSimilarity.tokens(tokenSource).take(16).toList();
    final discipline = _disciplineTokens(draft.facultyId);

    final byKey = <String, GroundedWork>{};

    void absorb(Iterable<GroundedWork> works) {
      for (final w in works) {
        byKey.putIfAbsent(w.mergeKey, () => w);
      }
    }

    // Pass A — strict relevance (like topic adoption).
    try {
      final a = await GroundedReferenceService.instance.searchScientific(
        queries: queries,
        limit: 16,
        preferEnglish: true,
        minYear: 2012,
        includeTheses: true,
        requireDoi: false,
        minScore: 2,
        commandText: '$scoreAgainst\n$seedDetails'.trim(),
        corePhrases: core,
        strongTokens: [...strong, ...discipline],
        disciplineTokens: discipline,
      );
      absorb(a.works);
    } catch (_) {}

    // Pass B — broader if thin.
    if (byKey.length < 6) {
      try {
        final b = await GroundedReferenceService.instance.searchScientific(
          queries: queries.take(4).toList(),
          limit: 18,
          preferEnglish: true,
          minYear: 2005,
          includeTheses: true,
          requireDoi: false,
          minScore: 1,
          commandText: scoreAgainst,
          corePhrases: core.take(6),
          strongTokens: strong.take(10),
        );
        absorb(b.works);
      } catch (_) {}
    }

    // Pass C — searchTopic fallback (includes Scholar path).
    if (byKey.length < 5) {
      try {
        final c = await GroundedReferenceService.instance.searchTopic(
          scoreAgainst,
          limit: 14,
          byRelevance: true,
        );
        absorb(c.works);
      } catch (_) {}
      if (queries.length > 1) {
        try {
          final d = await GroundedReferenceService.instance.searchTopic(
            queries[1],
            limit: 10,
            byRelevance: true,
          );
          absorb(d.works);
        } catch (_) {}
      }
    }

    // Soft re-rank locally by token overlap with English topic.
    final ranked = byKey.values.toList()
      ..sort((a, b) {
        final sa = TopicSimilarity.score(scoreAgainst, a.title);
        final sb = TopicSimilarity.score(scoreAgainst, b.title);
        final ya = a.year ?? 0;
        final yb = b.year ?? 0;
        if ((sb - sa).abs() > 0.02) return sb.compareTo(sa);
        return yb.compareTo(ya);
      });

    return ranked.take(14).toList();
  }

  List<String> _expandQueries(TopicEnglishSearchPlan plan, String facultyId) {
    final topic = plan.englishTopic.trim();
    final faculty = _facultyShort(facultyId);
    final base = <String>[
      ...plan.queries,
      if (topic.isNotEmpty) topic,
      if (topic.isNotEmpty) '$topic Egypt',
      if (topic.isNotEmpty) '$topic literature review',
      if (topic.isNotEmpty) '$topic thesis OR dissertation',
      if (topic.isNotEmpty && faculty.isNotEmpty) '$topic $faculty',
      if (topic.isNotEmpty) '$topic empirical study',
      ..._facultyQueryBoosts(facultyId, topic),
    ];
    final seen = <String>{};
    final out = <String>[];
    for (final q in base) {
      final t = q.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (t.length < 5) continue;
      if (ResearchGoalParser.containsArabic(t)) continue;
      if (seen.add(t.toLowerCase())) out.add(t);
    }
    return out.take(6).toList();
  }

  List<String> _facultyQueryBoosts(String facultyId, String topic) {
    if (topic.isEmpty) return const [];
    switch (facultyId) {
      case 'Education':
        return [
          '$topic education students teachers',
          '$topic curriculum OR pedagogy Egypt',
        ];
      case 'Law':
        return [
          '$topic law legislation OR jurisprudence',
          '$topic comparative law OR court',
        ];
      case 'Arts':
        return [
          '$topic literary OR linguistics OR discourse',
          '$topic humanities research',
        ];
      case 'Business':
        return [
          '$topic management OR accounting OR finance',
          '$topic firm OR organization Egypt',
        ];
      case 'MassCommunication':
        return [
          '$topic media OR journalism OR content analysis',
        ];
      case 'Tourism':
        return [
          '$topic tourism OR hospitality Egypt',
        ];
      default:
        return const [];
    }
  }

  List<String> _disciplineTokens(String facultyId) {
    switch (facultyId) {
      case 'Education':
        return const [
          'education',
          'teacher',
          'student',
          'school',
          'curriculum',
          'pedagogy',
          'learning',
        ];
      case 'Law':
        return const [
          'law',
          'legal',
          'statute',
          'court',
          'legislation',
          'jurisprudence',
        ];
      case 'Arts':
        return const [
          'literature',
          'linguistics',
          'discourse',
          'narrative',
          'translation',
        ];
      case 'Business':
        return const [
          'management',
          'accounting',
          'finance',
          'marketing',
          'organization',
        ];
      case 'MassCommunication':
        return const ['media', 'journalism', 'audience', 'communication'];
      case 'Tourism':
        return const ['tourism', 'hospitality', 'hotel', 'destination'];
      default:
        return const [];
    }
  }

  String _facultyShort(String facultyId) {
    final en = FacultyDepartments.facultyTitleEn(facultyId)
        .replaceFirst(RegExp(r'^Faculty of\s+', caseSensitive: false), '')
        .trim();
    if (en.isNotEmpty && en != facultyId) return en;
    return facultyId.replaceAll(RegExp(r'(?<=[a-z])(?=[A-Z])'), ' ');
  }

  List<ProposalCoachFinding> _deepLocalDiagnose(ProposalDraft draft) {
    final findings = <ProposalCoachFinding>[];
    final title = draft.titleAr.trim();
    final problem = draft.section(ProposalSectionKeys.problem);
    final questions = draft.section(ProposalSectionKeys.questions);
    final objectives = draft.section(ProposalSectionKeys.objectives);
    final limits = draft.section(ProposalSectionKeys.limits);
    final prior = draft.section(ProposalSectionKeys.priorStudies);
    final method = draft.section(ProposalSectionKeys.methodology);
    final instruments = draft.section(ProposalSectionKeys.instruments);
    final analysis = draft.section(ProposalSectionKeys.analysis);
    final validity = draft.section(ProposalSectionKeys.validity);

    // Title quality
    if (title.isEmpty) {
      findings.add(const ProposalCoachFinding(
        severity: 'high',
        titleAr: 'لا يوجد عنوان',
        titleEn: 'No title',
        detailAr: 'ابدأ بعنوان يحدد الظاهرة + الميدان + السياق إن أمكن.',
        detailEn: 'Start with a title naming phenomenon + field + context.',
        sectionKey: ProposalSectionKeys.titleAr,
      ));
    } else {
      if (title.length < 18) {
        findings.add(const ProposalCoachFinding(
          severity: 'high',
          titleAr: 'العنوان قصير جداً',
          titleEn: 'Title too short',
          detailAr: 'العنوان المقبول عادةً يحدد المتغير/الظاهرة والميدان بوضوح.',
          detailEn: 'A workable title usually names the variable/phenomenon and field.',
          sectionKey: ProposalSectionKeys.titleAr,
        ));
      }
      if (RegExp(r'^(دراسة|بحث|أثر|دور)\b').hasMatch(title) &&
          title.split(RegExp(r'\s+')).length < 8) {
        findings.add(const ProposalCoachFinding(
          severity: 'medium',
          titleAr: 'صيغة عنوان عامة شائعة الرفض',
          titleEn: 'Generic title pattern often rejected',
          detailAr:
              'تجنّب الاكتفاء بـ«دراسة/أثر/دور…» بلا تحديد مجتمع أو متغير أو سياق مصري.',
          detailEn:
              'Avoid bare “study/effect/role…” without sample, variable, or Egyptian context.',
          sectionKey: ProposalSectionKeys.titleAr,
        ));
      }
      if (!RegExp(r'[\u0600-\u06FF]').hasMatch(title) &&
          draft.section(ProposalSectionKeys.titleEn).isEmpty) {
        // ok english-only
      } else if (draft.section(ProposalSectionKeys.titleEn).trim().length < 8) {
        findings.add(const ProposalCoachFinding(
          severity: 'medium',
          titleAr: 'العنوان الإنجليزي ناقص (مطلوب غالباً في عين شمس)',
          titleEn: 'English title missing (often required at ASU)',
          detailAr: 'كثير من كليات عين شمس تطلب خطة عربي+إنجليزي موقّعة.',
          detailEn: 'Many ASU faculties require signed Arabic + English plans.',
          sectionKey: ProposalSectionKeys.titleEn,
        ));
      }
    }

    // Problem
    if (problem.trim().length < 40) {
      findings.add(const ProposalCoachFinding(
        severity: 'high',
        titleAr: 'المشكلة غير كافية للتشخيص القوي',
        titleEn: 'Problem too thin for strong diagnosis',
        detailAr:
            'اكتب فقرة توضّح: الواقع الحالي → القصور/الفجوة → الحاجة للبحث. جملة واحدة لا تكفي.',
        detailEn:
            'Write a paragraph: current situation → gap → need for the study. One sentence is not enough.',
        sectionKey: ProposalSectionKeys.problem,
      ));
    } else {
      final hasGap = RegExp(
        r'فجوة|قصور|ندرة|رغم|غير أن|لا تزال|gap|lack|however|despite',
        caseSensitive: false,
      ).hasMatch(problem);
      if (!hasGap) {
        findings.add(const ProposalCoachFinding(
          severity: 'high',
          titleAr: 'المشكلة بلا فجوة صريحة',
          titleEn: 'Problem lacks an explicit gap',
          detailAr:
              'أضف جملة فجوة: ماذا ينقص الأدبيات/الممارسة المصرية؟ لماذا الآن؟',
          detailEn:
              'Add a gap sentence: what is missing in Egyptian literature/practice? Why now?',
          sectionKey: ProposalSectionKeys.problem,
        ));
      }
      if (!RegExp(r'\?|؟|ما |كيف |إلى أي|whether|how |what ', caseSensitive: false)
          .hasMatch(problem) &&
          questions.length < 20) {
        findings.add(const ProposalCoachFinding(
          severity: 'medium',
          titleAr: 'لا يظهر سؤال محوري من المشكلة',
          titleEn: 'No core question emerges from the problem',
          detailAr: 'حوّل المشكلة إلى سؤال بحثي واحد جامع ثم فرّعه.',
          detailEn: 'Turn the problem into one core research question, then sub-questions.',
          sectionKey: ProposalSectionKeys.questions,
        ));
      }
    }

    // Questions / objectives alignment
    if (questions.trim().length < 20) {
      findings.add(const ProposalCoachFinding(
        severity: 'high',
        titleAr: 'أسئلة البحث غائبة',
        titleEn: 'Research questions missing',
        detailAr: 'سؤال رئيس + ٢–٤ فرعية قابلة للإجابة بالمنهج المختار.',
        detailEn: 'One main question + 2–4 answerable sub-questions.',
        sectionKey: ProposalSectionKeys.questions,
      ));
    } else {
      final qCount = RegExp(r'[؟?]').allMatches(questions).length +
          RegExp(r'(^|\n)\s*\d+[\).\-]').allMatches(questions).length;
      if (qCount < 2) {
        findings.add(const ProposalCoachFinding(
          severity: 'medium',
          titleAr: 'يُفضَّل تفريع الأسئلة',
          titleEn: 'Prefer splitting into sub-questions',
          detailAr: 'سؤال واحد عام يصعب ربطه بأداة وتحليل لاحقاً.',
          detailEn: 'One broad question is hard to link to instrument and analysis later.',
          sectionKey: ProposalSectionKeys.questions,
        ));
      }
    }

    if (objectives.trim().length < 20) {
      findings.add(const ProposalCoachFinding(
        severity: 'high',
        titleAr: 'الأهداف غائبة',
        titleEn: 'Objectives missing',
        detailAr: 'صغ أهدافاً بأفعال قابلة للقياس متسقة مع الأسئلة.',
        detailEn: 'Write measurable-verb objectives aligned with questions.',
        sectionKey: ProposalSectionKeys.objectives,
      ));
    } else if (questions.length >= 20 &&
        TopicSimilarity.score(objectives, questions) < 0.18) {
      findings.add(const ProposalCoachFinding(
        severity: 'high',
        titleAr: 'ضعف اتساق الأهداف ↔ الأسئلة',
        titleEn: 'Weak objectives ↔ questions fit',
        detailAr:
            'كل هدف يجب أن يقابل سؤالاً. أعد صياغة الأهداف بنفس مفاهيم الأسئلة.',
        detailEn:
            'Each objective should map to a question. Reuse the same core concepts.',
        sectionKey: ProposalSectionKeys.objectives,
      ));
    }

    // Limits
    if (limits.trim().length < 25) {
      findings.add(const ProposalCoachFinding(
        severity: 'medium',
        titleAr: 'الحدود غير مكتوبة',
        titleEn: 'Limits not written',
        detailAr: 'موضوعي / مكاني / زماني + ما لن تدّعيه الدراسة.',
        detailEn: 'Subject / place / time + what you will not claim.',
        sectionKey: ProposalSectionKeys.limits,
      ));
    }

    // Prior studies critical voice
    if (prior.trim().length < 50) {
      findings.add(const ProposalCoachFinding(
        severity: 'high',
        titleAr: 'الدراسات السابقة ناقصة',
        titleEn: 'Prior studies section thin',
        detailAr:
            'سنحاول جلب أعمال مفهرسة؛ عند الإدراج: قارن المنهج/العينة/النتائج وحدد الفجوة.',
        detailEn:
            'We will fetch indexed works; when inserting: compare method/sample/findings and state the gap.',
        sectionKey: ProposalSectionKeys.priorStudies,
      ));
    } else {
      final criticalHits = RegExp(
        r'فجوة|قصور|اختلاف|اتفاق|مقارنة|بينما|غير أن|موقع الدراسة|gap|unlike|however|limitation|differ|compare',
        caseSensitive: false,
      ).allMatches(prior).length;
      if (criticalHits < 2) {
        findings.add(const ProposalCoachFinding(
          severity: 'high',
          titleAr: 'الدراسات تبدو سردية لا نقدية',
          titleEn: 'Prior studies look narrative, not critical',
          detailAr:
              'أضف على الأقل: اتفاق الدراسات · اختلافها · قصورها · فجوة دراستك.',
          detailEn:
              'Add at least: agreement · differences · limitations · your gap.',
          sectionKey: ProposalSectionKeys.priorStudies,
        ));
      }
    }

    // Method–instrument–analysis triad
    if (method.trim().length < 25) {
      findings.add(const ProposalCoachFinding(
        severity: 'high',
        titleAr: 'المنهج غير مذكور',
        titleEn: 'Method not stated',
        detailAr: 'سمِّ المنهج (كمّي/نوعي/مختلط/وثائقي/مقارن…) وعلّل مناسبته للأسئلة.',
        detailEn: 'Name the method and justify why it answers your questions.',
        sectionKey: ProposalSectionKeys.methodology,
      ));
    } else if (!_mentionsMethodFamily(method)) {
      findings.add(const ProposalCoachFinding(
        severity: 'medium',
        titleAr: 'المنهج غير مسمّى بوضوح',
        titleEn: 'Method family not clearly named',
        detailAr: 'اذكر صراحة: وصفي، تجريبي، نوعي، مختلط، وثائقي، مقارن…',
        detailEn: 'Name explicitly: descriptive, experimental, qualitative, mixed, doctrinal…',
        sectionKey: ProposalSectionKeys.methodology,
      ));
    }

    if (draft.facultyId != 'Law') {
      if (instruments.trim().length < 15 && method.length >= 25) {
        findings.add(const ProposalCoachFinding(
          severity: 'high',
          titleAr: 'الأداة غير مربوطة بالأسئلة',
          titleEn: 'Instrument not linked to questions',
          detailAr: 'جدول مقترح: سؤال → بُعد/مؤشر → بند استبانة أو سؤال مقابلة.',
          detailEn: 'Suggested matrix: question → dimension → survey item or interview prompt.',
          sectionKey: ProposalSectionKeys.instruments,
        ));
      } else if (instruments.length >= 15 &&
          questions.length >= 20 &&
          TopicSimilarity.score(instruments, questions) < 0.12) {
        findings.add(const ProposalCoachFinding(
          severity: 'high',
          titleAr: 'ضعف ربط الأداة بالأسئلة',
          titleEn: 'Weak instrument–questions link',
          detailAr: 'اذكر أي جزء من الأداة يخدم أي سؤال.',
          detailEn: 'State which instrument part serves which question.',
          sectionKey: ProposalSectionKeys.instruments,
        ));
      }

      if (analysis.trim().length < 15 && method.length >= 25) {
        findings.add(const ProposalCoachFinding(
          severity: 'medium',
          titleAr: 'أساليب التحليل غير موضحة',
          titleEn: 'Analysis methods unclear',
          detailAr: 'اربط كل سؤال بأسلوب تحليل (إحصاء / ترميز موضوعي / …).',
          detailEn: 'Map each question to an analysis approach (stats / thematic coding / …).',
          sectionKey: ProposalSectionKeys.analysis,
        ));
      }

      if ((draft.facultyId == 'Education' || draft.facultyId == 'Business') &&
          instruments.length >= 15 &&
          validity.length < 12) {
        findings.add(const ProposalCoachFinding(
          severity: 'medium',
          titleAr: 'الصدق/الثبات غير مذكور',
          titleEn: 'Validity/reliability missing',
          detailAr: 'اذكر محكّمين، ثبات ألفا، تجريب أولّي، أو تثليث.',
          detailEn: 'Mention expert review, alpha, pilot, or triangulation.',
          sectionKey: ProposalSectionKeys.validity,
        ));
      }
    } else if (method.length >= 20 &&
        !RegExp(r'تشريع|حكم|فقه|مقارن|قضاء|statute|case|doctrin',
                caseSensitive: false)
            .hasMatch(method)) {
      findings.add(const ProposalCoachFinding(
        severity: 'medium',
        titleAr: 'منهج الحقوق ينقصه أدوات الأسانيد',
        titleEn: 'Law method lacks authorities tools',
        detailAr: 'وضّح: تشريع / أحكام / فقه / مقارنة — وكيف تُبنى سلسلة الاستدلال.',
        detailEn: 'Clarify statutes / cases / doctrine / comparison and the argument chain.',
        sectionKey: ProposalSectionKeys.methodology,
      ));
    }

    // Consistency engine extras
    final local = ProposalConsistencyEngine.instance.evaluate(draft);
    for (final i in local.issues) {
      findings.add(ProposalCoachFinding(
        severity: i.severity,
        titleAr: i.titleAr,
        titleEn: i.titleEn,
        detailAr: i.detailAr,
        detailEn: i.detailEn,
        sectionKey: _guessSection(i.id),
      ));
    }

    return findings;
  }

  Future<(Map<String, String>, List<ProposalCoachFinding>, String, String)?>
      _aiCoach(
    ProposalDraft draft, {
    required String enTopic,
    required List<String> queries,
  }) async {
    final tpl = proposalTemplateById(draft.templateId);
    final title = draft.titleAr;
    final problem = draft.section(ProposalSectionKeys.problem);
    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: '''
You are a strict Egyptian postgraduate proposal examiner (Education/Law/Arts/Commerce).
Return JSON only:
{
  "summaryAr":"2-3 Arabic sentences: overall verdict for the department seminar",
  "summaryEn":"2-3 English sentences",
  "findings":[
    {"severity":"high|medium|low","titleAr":"...","titleEn":"...","detailAr":"actionable fix","detailEn":"...","sectionKey":"titleAr|problem|questions|objectives|limits|priorStudies|methodology|instruments|analysis|validity"}
  ],
  "sections":{
    "titleAr":"improved Arabic title",
    "titleEn":"improved English title",
    "problem":"improved problem paragraph with explicit gap",
    "questions":"main + sub questions",
    "objectives":"aligned measurable objectives",
    "limits":"subject/place/time + non-claims",
    "priorStudies":"CRITICAL outline only (themes/agree/differ/gap) — NO fake citations",
    "methodology":"named method + rationale",
    "instruments":"instrument mapped to questions",
    "analysis":"analysis mapped to questions",
    "validity":"validity/reliability plan if field study"
  }
}
Hard rules:
- Give 5-8 SPECIFIC findings tied to THIS topic (not generic "write more").
- sections must be COMPLETE usable Egyptian academic Arabic — NO square brackets [], NO ellipsis placeholders (…), NO "اكتب هنا".
- Infer concrete population, place, variables, instrument dimensions FROM the topic (e.g. LLM + educational UI → university students / LMS users / instructional designers).
- NEVER invent author names, years, journals, or DOIs.
- priorStudies = critical skeleton of themes only, plus how to use real fetched papers.
- Align questions ↔ objectives ↔ method ↔ instrument ↔ analysis with the SAME concrete nouns.
- titleEn must be a proper English scholarly title when the topic is technical (keep LLM/UI terms in English if needed).
''',
      userMessage: '''
Faculty: ${draft.facultyId} (${tpl?.titleAr ?? ''})
Degree: ${draft.degreeLevel}
English search topic already planned: $enTopic
Queries: ${queries.join(' | ')}

Title AR: $title
Title EN: ${draft.section(ProposalSectionKeys.titleEn)}
Problem:
$problem
Questions:
${draft.section(ProposalSectionKeys.questions)}
Objectives:
${draft.section(ProposalSectionKeys.objectives)}
Limits:
${draft.section(ProposalSectionKeys.limits)}
Prior:
${draft.section(ProposalSectionKeys.priorStudies)}
Method:
${draft.section(ProposalSectionKeys.methodology)}
Instruments:
${draft.section(ProposalSectionKeys.instruments)}
Analysis:
${draft.section(ProposalSectionKeys.analysis)}
''',
      maxOutputTokens: 3500,
      preferPro: true,
    );
    if (!result.isSuccess || result.text == null) return null;
    final text = result.text!.trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final map =
          jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      final sections = <String, String>{};
      final sec = map['sections'];
      if (sec is Map) {
        sec.forEach((k, v) {
          final t = '$v'.trim();
          if (t.length >= 12) sections['$k'] = t;
        });
      }
      final findings = <ProposalCoachFinding>[];
      final rawF = map['findings'];
      if (rawF is List) {
        for (final item in rawF) {
          if (item is! Map) continue;
          final titleAr = item['titleAr']?.toString().trim() ?? '';
          final titleEn = item['titleEn']?.toString().trim() ?? '';
          if (titleAr.isEmpty && titleEn.isEmpty) continue;
          findings.add(ProposalCoachFinding(
            severity: item['severity']?.toString() ?? 'medium',
            titleAr: titleAr,
            titleEn: titleEn,
            detailAr: item['detailAr']?.toString() ?? '',
            detailEn: item['detailEn']?.toString() ?? '',
            sectionKey: item['sectionKey']?.toString(),
          ));
        }
      }
      return (
        sections,
        findings,
        map['summaryAr']?.toString() ?? '',
        map['summaryEn']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>?> _aiSectionsOnly(
    ProposalDraft draft, {
    required String enTopic,
    List<String> worksHint = const [],
  }) async {
    final title = draft.titleAr.trim();
    final problem = draft.section(ProposalSectionKeys.problem);
    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: '''
Rewrite Egyptian thesis-proposal SECTIONS as finished Arabic academic text.
Return JSON only: {"sections":{"titleAr":"","titleEn":"","problem":"","questions":"","objectives":"","limits":"","methodology":"","instruments":"","analysis":"","validity":"","priorStudies":""}}
FORBIDDEN: square brackets [], ellipsis …, "اكتب", "حدد", "مثال فارغ".
REQUIRED: concrete population, Egyptian university context, named method, named instrument with dimensions mapped to each question.
Keep technical English terms (LLM, UI, personalization) when scientifically standard.
No fake citations.
''',
      userMessage: '''
Faculty: ${draft.facultyId}
English topic: $enTopic
Title: $title
Problem: $problem
Fetched paper titles (themes only, do not invent citations):
${worksHint.isEmpty ? '(none yet)' : worksHint.map((e) => '- $e').join('\n')}
''',
      maxOutputTokens: 2800,
      preferPro: true,
    );
    if (!result.isSuccess || result.text == null) return null;
    final text = result.text!.trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final map =
          jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      final sec = map['sections'];
      if (sec is! Map) return null;
      final out = <String, String>{};
      sec.forEach((k, v) {
        final t = '$v'.trim();
        if (t.length >= 20 && !_isWeakTemplate(t)) out['$k'] = t;
      });
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  bool _needsStrongerSections(Map<String, String> sections) {
    const keys = [
      ProposalSectionKeys.questions,
      ProposalSectionKeys.objectives,
      ProposalSectionKeys.methodology,
      ProposalSectionKeys.instruments,
      ProposalSectionKeys.limits,
    ];
    var weak = 0;
    for (final k in keys) {
      final v = sections[k] ?? '';
      if (v.isEmpty || _isWeakTemplate(v) || v.length < 40) weak++;
    }
    return weak >= 2;
  }

  static bool _isWeakTemplate(String text) {
    final t = text.trim();
    if (t.isEmpty) return true;
    if (t.contains('[') && t.contains(']')) return true;
    if (RegExp(
      r'أبعاد\s*:\s*(\.\.\.|…)|بنود\s*:\s*(\.\.\.|…)|\[استبانة|مجتمع الدراسة\]|المؤسسة/المحافظة|اكتب هنا|حدد هنا',
    ).hasMatch(t)) {
      return true;
    }
    if (RegExp(r'لـ\s*$').hasMatch(t) || t.endsWith('لـ...')) return true;
    // mostly placeholder dots
    final dots = RegExp(r'(\.\.\.|…)').allMatches(t).length;
    if (dots >= 3 && t.length < 280) return true;
    return false;
  }

  /// Public local draft for any template section key (AI-independent).
  String sectionTextForKey({
    required ProposalDraft draft,
    required String sectionKey,
    required String title,
    required String details,
    required String englishTopic,
  }) {
    final ctx = _inferContext(
      title: title,
      details: details,
      englishTopic: englishTopic,
      facultyId: draft.facultyId,
    );
    return _sectionBody(ctx: ctx, key: sectionKey, facultyId: draft.facultyId);
  }

  /// Concrete drafts from the topic — no bracket placeholders.
  /// When [allKeys] is true, every known section key is filled (for fill-all /
  /// per-paragraph generate). Otherwise only empty/weak slots are suggested.
  Map<String, String> _smartSuggestions({
    required ProposalDraft draft,
    required String title,
    required String details,
    required String englishTopic,
    bool allKeys = false,
  }) {
    final ctx = _inferContext(
      title: title,
      details: details,
      englishTopic: englishTopic,
      facultyId: draft.facultyId,
    );
    final out = <String, String>{};

    const keys = [
      ProposalSectionKeys.titleAr,
      ProposalSectionKeys.titleEn,
      ProposalSectionKeys.introduction,
      ProposalSectionKeys.motives,
      ProposalSectionKeys.problem,
      ProposalSectionKeys.questions,
      ProposalSectionKeys.hypotheses,
      ProposalSectionKeys.objectives,
      ProposalSectionKeys.significance,
      ProposalSectionKeys.limits,
      ProposalSectionKeys.terms,
      ProposalSectionKeys.framework,
      ProposalSectionKeys.priorStudies,
      ProposalSectionKeys.methodology,
      ProposalSectionKeys.population,
      ProposalSectionKeys.instruments,
      ProposalSectionKeys.validity,
      ProposalSectionKeys.analysis,
      ProposalSectionKeys.chapterPlan,
      ProposalSectionKeys.expectedResults,
      ProposalSectionKeys.ethics,
      ProposalSectionKeys.references,
      ProposalSectionKeys.timeline,
    ];

    for (final key in keys) {
      final current = draft.section(key).trim();
      if (!allKeys) {
        final minLen = switch (key) {
          ProposalSectionKeys.titleAr => 18,
          ProposalSectionKeys.titleEn => 8,
          ProposalSectionKeys.problem => 60,
          ProposalSectionKeys.questions ||
          ProposalSectionKeys.objectives ||
          ProposalSectionKeys.limits =>
            40,
          ProposalSectionKeys.priorStudies => 50,
          ProposalSectionKeys.methodology => 40,
          ProposalSectionKeys.instruments => 30,
          ProposalSectionKeys.analysis => 25,
          ProposalSectionKeys.validity => 20,
          _ => 24,
        };
        if (current.length >= minLen && !_isWeakTemplate(current)) continue;
      }
      final body =
          _sectionBody(ctx: ctx, key: key, facultyId: draft.facultyId);
      if (body.isNotEmpty) out[key] = body;
    }
    return out;
  }

  String _sectionBody({
    required _ProposalTopicContext ctx,
    required String key,
    required String facultyId,
  }) {
    final focus = ctx.focus;
    final isLaw = facultyId == 'Law';
    final isArts = facultyId == 'Arts' || facultyId == 'AlAlsun';

    switch (key) {
      case ProposalSectionKeys.titleAr:
        return focus.length >= 12 ? focus : 'دراسة في $focus';
      case ProposalSectionKeys.titleEn:
        return ctx.titleEn.isNotEmpty ? ctx.titleEn : focus;
      case ProposalSectionKeys.introduction:
        return 'يشهد المجال المرتبط بـ«$focus» تحوّلات متسارعة في السياق المصري، '
            'مع تنامي الاعتماد على ${ctx.techPhrase} وما يرتبط بها من ممارسات تطبيقية. '
            'وتأتي هذه الدراسة استجابةً للحاجة إلى فهم أدق لـ${ctx.outcomePhrase} '
            'لدى ${ctx.population}، وربط ذلك بأسئلة بحثية قابلة للقياس. '
            'ويُمهّد هذا المدخل لصياغة المشكلة والأهداف والمنهج في الأقسام التالية.';
      case ProposalSectionKeys.motives:
        return 'تنبع دوافع اختيار الموضوع من:\n'
            '1) أهمية عملية لـ${ctx.outcomePhrase} في المؤسسات المصرية ذات الصلة.\n'
            '2) فجوة بحثية ظاهرة في الدراسات المحلية حول ${ctx.techPhrase}.\n'
            '3) قابلية الموضوع للبحث الميداني/التحليلي ضمن إطار زمني مناسب لدرجة التسجيل.\n'
            '4) اتساقه مع تخصص الباحث وإمكانية توظيف النتائج توصياتٍ قابلة للتطبيق.';
      case ProposalSectionKeys.problem:
        return 'مع توسّع الممارسات المرتبطة بـ${ctx.techPhrase} في السياق المصري، '
            'برز الاهتمام بتحسين ${ctx.outcomePhrase}. '
            'غير أن الواقع الحالي ما زال يعتمد غالباً على ممارسات عامة أو غير مقنّنة بما يكفي. '
            'وتشير الفجوة البحثية إلى ندرة الدراسات التطبيقية المحلية التي تقيس أبعاد دور ${ctx.techPhrase} '
            'في ${ctx.outcomePhrase} لدى ${ctx.population}. '
            'ومن هنا تتحدد مشكلة الدراسة في الحاجة إلى استجلاء هذا الدور وربطه بأسئلة قابلة للقياس.';
      case ProposalSectionKeys.questions:
        return 'السؤال الرئيس: ما دور ${ctx.techPhrase} في تحسين ${ctx.outcomePhrase} '
            'لدى ${ctx.population} في ${ctx.place}؟\n'
            '1) ما مستوى إدراك ${ctx.population} لأبعاد دور ${ctx.techPhrase} في ${ctx.outcomePhrase}؟\n'
            '2) هل توجد فروق دالة في هذا الإدراك وفق ${ctx.variables.join(' و')}؟\n'
            '3) ما العلاقة بين أبعاد استخدام ${ctx.techPhrase} ومؤشرات ${ctx.outcomeShort}؟\n'
            '4) ما المقترحات العملية لتعزيز توظيف ${ctx.techPhrase} في ${ctx.outcomePhrase}؟';
      case ProposalSectionKeys.hypotheses:
        if (isArts || isLaw) {
          return 'نظراً لطبيعة الدراسة ${isLaw ? 'القانونية التحليلية' : 'الإنسانية/الأدبية'}، '
              'قد تُكتفى بأسئلة بحثية دون فرضيات إحصائية صارمة. '
              'وإن لزم الأمر تُصاغ فرضيات توجهية مثل: '
              'يساهم التحليل المنظّم لـ${ctx.techPhrase} في تفسير أوضح لـ${ctx.outcomeShort}.';
        }
        return 'الفرضية الرئيسة: توجد علاقة دالة إحصائياً بين أبعاد استخدام ${ctx.techPhrase} '
            'ومؤشرات ${ctx.outcomeShort} لدى ${ctx.population}.\n'
            'ف1: يختلف مستوى إدراك أبعاد الدور باختلاف ${ctx.variables.first}.\n'
            'ف2: توجد فروق دالة وفق ${ctx.variables.length > 1 ? ctx.variables[1] : ctx.variables.first}.\n'
            'ف3: يمكن التنبؤ بمؤشرات ${ctx.outcomeShort} من أبعاد استخدام ${ctx.techPhrase}.';
      case ProposalSectionKeys.objectives:
        return 'تهدف الدراسة إلى:\n'
            '1) قياس/تحليل أبعاد دور ${ctx.techPhrase} في ${ctx.outcomePhrase} لدى ${ctx.population}.\n'
            '2) الكشف عن الفروق/الاختلافات وفق ${ctx.variables.join(' و')}.\n'
            '3) تحليل العلاقة بين استخدام ${ctx.techPhrase} ومؤشرات ${ctx.outcomeShort}.\n'
            '4) تقديم توصيات إجرائية قابلة للتطبيق في السياق المصري.';
      case ProposalSectionKeys.significance:
        return 'الأهمية النظرية: إثراء الأدبيات العربية حول ${ctx.techPhrase} وربطها بـ${ctx.outcomeShort} '
            'من منظور تطبيقي مصري.\n'
            'الأهمية التطبيقية: تزويد ${ctx.population.isNotEmpty ? 'صانعي القرار والممارسين' : 'الجهات المعنية'} '
            'بتوصيات مبنية على بيانات حول تحسين ${ctx.outcomePhrase}.\n'
            'الأهمية المنهجية: تقديم إطار أسئلة/أبعاد يمكن البناء عليه في دراسات لاحقة.';
      case ProposalSectionKeys.limits:
        return 'الحد الموضوعي: دور ${ctx.techPhrase} في ${ctx.outcomePhrase} دون التوسع إلى موضوعات فرعية بعيدة.\n'
            'الحد المكاني: ${ctx.place}.\n'
            'الحد الزماني: ${ctx.time}.\n'
            'الحد البشري: ${ctx.population}.\n'
            'لن تدّعي الدراسة تعميماً مطلقاً خارج مجتمع العينة أو تصميماً سببياً خارج حدود منهجها.';
      case ProposalSectionKeys.terms:
        return 'يُعرَّف إجرائياً:\n'
            '• ${ctx.techPhrase}: المفهوم المحوري المستقل كما يُقاس عبر أبعاد الأداة/التحليل في هذه الدراسة.\n'
            '• ${ctx.outcomeShort}: المتغير/المؤشر التابع المستهدف بالقياس أو التحليل.\n'
            '• ${ctx.population}: مجتمع الدراسة الذي تُطبَّق عليه الأداة أو يُحلَّل نصّه/وثائقه.\n'
            '• ${ctx.methodName}: الإطار المنهجي المعتمد للإجابة عن أسئلة الدراسة.';
      case ProposalSectionKeys.framework:
        return 'يُبنى الإطار النظري حول محاور مترابطة بموضوع «$focus»:\n'
            '1) مفاهيم ${ctx.techPhrase} ونماذجها النظرية ذات الصلة.\n'
            '2) أبعاد ${ctx.outcomeShort} ومؤشراتها في الأدبيات.\n'
            '3) نظريات/نماذج وسيطة تفسّر العلاقة أو تفسّر الظاهرة في السياق التربوي/الإنساني.\n'
            '4) استخلاص إطار مفاهيمي يوجّه صياغة الأسئلة والأداة دون الاكتفاء بسرد نظري منفصل.';
      case ProposalSectionKeys.priorStudies:
        return 'تُنظَّم الأدبيات حول ثلاثة محاور نقدية مرتبطة بـ«$focus»:\n'
            '1) محور ${ctx.techPhrase}: ماذا أنجزت الدراسات؟ وما حدود قابلية التعميم؟\n'
            '2) محور ${ctx.outcomeShort}: كيف قاست الدراسات المؤشرات؟ وما المقاييس المتكررة؟\n'
            '3) محور السياق المصري/العربي: أين ندرة التطبيقات الميدانية المحلية؟\n'
            'ثم تُستخلص الفجوة: الحاجة لدراسة تقيس/تحلل الأبعاد لدى ${ctx.population} '
            'وتربطها بـ${ctx.variables.join(' و')}.\n'
            'موقع الدراسة الحالية: تسد هذه الفجوة تطبيقياً دون الاكتفاء بسرد الدراسات.';
      case ProposalSectionKeys.methodology:
        if (isLaw) {
          return 'يُعتمد المنهج الوصفي التحليلي عبر تحليل الأسانيد التشريعية والقضائية والفقهية '
              'المتصلة بـ«$focus»، مع بناء سلسلة استدلال تربط المسألة القانونية بالأسانيد واجبة التطبيق.';
        }
        return 'يُعتمد ${ctx.methodName} لملاءمته لطبيعة أسئلة الدراسة حول دور ${ctx.techPhrase} '
            'في ${ctx.outcomePhrase}. ويتمثل مجتمع الدراسة في ${ctx.population} بـ${ctx.place}، '
            'وتُختار عينة ${ctx.sampleHint}. وتُجمع البيانات عبر ${ctx.instrumentName}، '
            'ثم تُحلَّل ${ctx.analysisHint} بما يجيب عن كل سؤال بحثي.';
      case ProposalSectionKeys.population:
        if (isLaw) {
          return 'مجتمع الدراسة: النصوص التشريعية والأحكام والاجتهادات ذات الصلة بـ«$focus». '
              'العينة: عمدية للنصوص والأحكام الأكثر اتصالاً بالمسألة القانونية محل البحث.';
        }
        return 'مجتمع الدراسة: ${ctx.population}.\n'
            'الإطار المكاني: ${ctx.place}.\n'
            'العينة: ${ctx.sampleHint}.\n'
            'يُحدَّد حجم العينة بما يسمح بالتحليل المطلوب ويجيب عن أسئلة الفروق والعلاقات.';
      case ProposalSectionKeys.instruments:
        if (isLaw) {
          return 'الأداة الرئيسة: ${ctx.instrumentName} لرصد الأسانيد وتصنيفها وفق سلسلة الاستدلال. '
              'تشمل حقولاً للمصدر، وجه الدلالة، والقوة النسبية، والتعارض المحتمل مع أسانيد أخرى.';
        }
        if (isArts) {
          return 'الأدوات المقترحة وفق طبيعة الأسئلة: بطاقة تحليل مضمون/خطاب للنصوص ذات الصلة بـ«$focus»، '
              'و${ctx.instrumentName} إن لزم قياس إدراكات ${ctx.population}. '
              'يُربط كل بند/فئة تحليل بسؤال بحثي محدد.';
        }
        final b = StringBuffer();
        b.writeln(
          'الأداة الرئيسة: ${ctx.instrumentName} موجّهة إلى ${ctx.population}، '
          'وتغطي الأبعاد التالية المرتبطة مباشرة بأسئلة الدراسة:',
        );
        for (var i = 0; i < ctx.dimensions.length; i++) {
          final d = ctx.dimensions[i];
          b.writeln(
            '${i + 1}) البعد «${d.name}» (يجيب عن السؤال ${d.questionNo}): '
            'بنود حول ${d.items}.',
          );
        }
        b.writeln(
          'يُبنى المقياس على سلم ليكرت خماسي، مع التحقق من الصدق الظاهري بمحكّمين متخصصين '
          'وحساب ثبات ألفا كرونباخ بعد تطبيق استطلاعي.',
        );
        return b.toString().trim();
      case ProposalSectionKeys.validity:
        if (isLaw) {
          return 'يُراجع اتساق سلسلة الاستدلال مع الأسانيد المعتمدة، وتُختبر كفاية التغطية التشريعية/القضائية، '
              'مع تجنب الانتقاء الانحيازي للنصوص. كما تُوثَّق مصادر الاستشهاد بدقة.';
        }
        return 'الصدق: صدق ظاهري عبر عرض الأداة على محكّمين في ${ctx.reviewerField}. '
            'الثبات: معامل ألفا كرونباخ لكل بعد وللأداة ككل بعد تطبيق استطلاعي على عينة صغيرة من مجتمع الدراسة. '
            'كما يُراجع اتساق البنود مع تعريفات الأبعاد إجرائياً قبل التطبيق النهائي.';
      case ProposalSectionKeys.analysis:
        if (isLaw) {
          return 'تُحلَّل المواد ${ctx.analysisHint}: تصنيف الأسانيد، وزن الدلالة، بيان التعارض إن وُجد، '
              'ثم بناء نتيجة قانونية متسقة مع أسئلة الدراسة.';
        }
        if (isArts) {
          return 'يُعتمد تحليل نوعي منظم (ترميز → محاور → ثيمات) للنصوص/البيانات المرتبطة بـ«$focus»، '
              'مع ربط كل ثيمة بسؤال بحثي. وإن وُجدت بيانات كمية مساندة تُعالج ${ctx.analysisHint}.';
        }
        return 'بعد الترميز وإدخال البيانات يُستخدم ${ctx.analysisHint}: '
            'إحصاءات وصفية للأبعاد، واختبارات فروق وفق ${ctx.variables.join(' و')}، '
            'ومعاملات ارتباط/انحدار لفحص العلاقة بين استخدام ${ctx.techPhrase} ومؤشرات ${ctx.outcomeShort}، '
            'بما يطابق أسئلة الدراسة واحداً بواحد.';
      case ProposalSectionKeys.chapterPlan:
        if (isLaw) {
          return 'الفصل الأول: الإطار العام (المشكلة، الأسئلة، الأهمية، المنهج).\n'
              'الفصل الثاني: الإطار النظري والمفاهيم القانونية ذات الصلة.\n'
              'الفصل الثالث: التحليل التطبيقي للأسانيد والأحكام.\n'
              'الفصل الرابع: النتائج والتوصيات والمقترحات التشريعية إن لزم.';
        }
        return 'الفصل الأول: الإطار العام للدراسة (مقدمة، مشكلة، أسئلة، أهداف، حدود، مصطلحات).\n'
            'الفصل الثاني: الإطار النظري والدراسات السابقة نقدياً.\n'
            'الفصل الثالث: إجراءات الدراسة (منهج، مجتمع، عينة، أداة، صدق/ثبات).\n'
            'الفصل الرابع: نتائج التحليل ومناقشتها.\n'
            'الفصل الخامس: الخلاصة والتوصيات والمقترحات.';
      case ProposalSectionKeys.expectedResults:
        return 'يُتوقَّع أن تُظهر الدراسة:\n'
            '1) وصفاً كمياً/نوعياً لأبعاد دور ${ctx.techPhrase} لدى ${ctx.population}.\n'
            '2) بياناً بالفروق ذات الدلالة وفق ${ctx.variables.join(' و')} إن وُجدت.\n'
            '3) توضيحاً لقوة العلاقة مع ${ctx.outcomeShort}.\n'
            '4) توصيات عملية لتحسين ${ctx.outcomePhrase} في السياق المصري.';
      case ProposalSectionKeys.ethics:
        return 'تُراعى موافقة المشاركين المستنيرة (إن وُجد جمع بيانات بشرية)، وسرية البيانات، '
            'وعدم الإضرار، والاستخدام الأكاديمي فقط. '
            'كما يُتجنَّب الانتحال ويُوثَّق الاقتباس وفق أسلوب الاستشهاد المعتمد في الكلية. '
            'ولا تُنشر بيانات تعريفية دون موافقة.';
      case ProposalSectionKeys.references:
        return 'يُبنى ثبت أولي من:\n'
            '• مراجع عربية حديثة في ${ctx.outcomeShort} و${ctx.techPhrase}.\n'
            '• دراسات إنجليزية مفهرسة (Scopus/Google Scholar) حول الموضوع.\n'
            '• وثائق/تقارير مؤسسية مصرية ذات صلة إن وُجدت.\n'
            'يُستكمل الثبت بعد جلب الدراسات من مساعد الخطة وفرزها نقدياً.';
      case ProposalSectionKeys.timeline:
        return 'الشهر 1–2: صياغة المشكلة والأسئلة ومراجعة الأدبيات.\n'
            'الشهر 3: بناء الأداة وتحكيمها والتطبيق الاستطلاعي.\n'
            'الشهر 4: جمع البيانات الميدانية/التحليلية.\n'
            'الشهر 5: التحليل الإحصائي/النوعي ومناقشة النتائج.\n'
            'الشهر 6: الكتابة النهائية والمراجعة قبل العرض على القسم.';
      default:
        return 'مسودة أولية لقسم «${ProposalSectionKeys.labelAr(key)}» مرتبطة بموضوع «$focus»: '
            'يُربط المحتوى مباشرة بـ${ctx.techPhrase} و${ctx.outcomePhrase} لدى ${ctx.population}، '
            'ويُراجع لاحقاً بلغة القسم المعتمدة.';
    }
  }

  _ProposalTopicContext _inferContext({
    required String title,
    required String details,
    required String englishTopic,
    required String facultyId,
  }) {
    final hay = '$title\n$details\n$englishTopic'.toLowerCase();
    final focus = _cleanFocus(title.isNotEmpty ? title : details);

    final isLlm = RegExp(
      r'llm|llms|large language|نموذج(?:ات)? لغوي|نماذج لغوية|chatgpt|generative',
      caseSensitive: false,
    ).hasMatch(hay);
    final isUi = RegExp(
      r'ui|interface|واجهة|واجهات|user experience|ux|تخصيص|personaliz|adaptive',
      caseSensitive: false,
    ).hasMatch(hay);
    final isEdu = facultyId == 'Education' ||
        RegExp(r'educat|تعلم|تعليمليم|ترب|طالب|معلم|university|جامع')
            .hasMatch(hay);

    String techPhrase;
    String outcomePhrase;
    String outcomeShort;
    String titleEn;
    if (isLlm && isUi) {
      techPhrase = 'النماذج اللغوية الكبيرة (LLMs)';
      outcomePhrase = 'التخصيص التلقائي لواجهات المستخدم التعليمية';
      outcomeShort = 'جودة التخصيص وفاعلية الواجهة التعليمية';
      titleEn = englishTopic.isNotEmpty
          ? englishTopic
          : 'Role of Large Language Models (LLMs) in Improving Automated Personalization of Educational User Interfaces in Egyptian Universities';
    } else if (isLlm) {
      techPhrase = 'النماذج اللغوية الكبيرة (LLMs)';
      outcomePhrase = isEdu ? 'تحسين نواتج/ممارسات التعلم الرقمي' : 'تحسين الأداء التطبيقي المستهدف';
      outcomeShort = isEdu ? 'نواتج التعلم الرقمي' : 'الأداء التطبيقي';
      titleEn = englishTopic.isNotEmpty
          ? englishTopic
          : 'Large Language Models (LLMs) applications in Egyptian higher education';
    } else if (isUi) {
      techPhrase = 'تقنيات تخصيص واجهات المستخدم';
      outcomePhrase = 'تحسين تجربة الواجهة التعليمية';
      outcomeShort = 'تجربة الواجهة التعليمية';
      titleEn = englishTopic.isNotEmpty
          ? englishTopic
          : 'Educational user-interface personalization in Egyptian universities';
    } else {
      techPhrase = focus;
      outcomePhrase = 'معالجة المشكلة البحثية المحددة';
      outcomeShort = 'المؤشرات المستهدفة';
      titleEn = englishTopic.isNotEmpty ? englishTopic : focus;
    }

    String population;
    if (RegExp(r'معلم|teachers').hasMatch(hay)) {
      population = 'معلمي المراحل المستهدفة';
    } else if (RegExp(r'مصمم|designer').hasMatch(hay)) {
      population = 'مصممي المقررات والواجهات التعليمية';
    } else if (isEdu || isLlm || isUi) {
      population = 'طلاب الجامعات المصرية مستخدمي أنظمة التعلم الإلكتروني';
    } else if (facultyId == 'Law') {
      population = 'النصوص التشريعية والأحكام ذات الصلة';
    } else {
      population = 'أفراد مجتمع الدراسة المستهدف في المؤسسات المصرية ذات الصلة';
    }

    final variables = <String>[];
    if (isEdu || isLlm || isUi) {
      variables.addAll(const ['التخصص الدراسي', 'المستوى الأكاديمي', 'مستوى الخبرة التقنية']);
    } else if (facultyId == 'Business') {
      variables.addAll(const ['سنوات الخبرة', 'المسمى الوظيفي', 'حجم المؤسسة']);
    } else {
      variables.addAll(const ['النوع', 'الخبرة', 'السياق المؤسسي']);
    }

    final dimensions = <_InstrumentDim>[
      _InstrumentDim(
        name: isLlm ? 'الوعي بإمكانات LLMs' : 'الوعي بالمتغير المستقل',
        questionNo: '1',
        items: isLlm
            ? 'المعرفة بالقدرات وحدود النماذج، وأنماط الاستخدام التعليمي'
            : 'المعرفة بالمفهوم ومجالات تطبيقه',
      ),
      _InstrumentDim(
        name: isUi ? 'جودة التخصيص التلقائي للواجهة' : 'أبعاد التطبيق',
        questionNo: '1',
        items: isUi
            ? 'ملاءمة المحتوى، تكيف المسارات، وضوح التفاعل، تقليل الحمل المعرفي'
            : 'مستوى التطبيق، انتظامه، ومجالاته',
      ),
      _InstrumentDim(
        name: 'الفروق الفردية والسياقية',
        questionNo: '2',
        items: 'بنود مقارنة وفق ${variables.take(2).join(' و')}',
      ),
      _InstrumentDim(
        name: isUi ? 'مؤشرات فاعلية الواجهة التعليمية' : 'المؤشرات التابعة',
        questionNo: '3',
        items: isEdu
            ? 'الرضا، سهولة الاستخدام، الاندماج، الفائدة التعليمية المدركة'
            : 'الرضا، الكفاءة، تحقيق الهدف',
      ),
      _InstrumentDim(
        name: 'المعوقات والمقترحات',
        questionNo: '4',
        items: 'تحديات تقنية/تربوية/أخلاقية، ومتطلبات التبني المؤسسي',
      ),
    ];

    return _ProposalTopicContext(
      focus: focus,
      titleEn: titleEn,
      techPhrase: techPhrase,
      outcomePhrase: outcomePhrase,
      outcomeShort: outcomeShort,
      population: population,
      place: 'عينة من الجامعات الحكومية/الخاصة في جمهورية مصر العربية',
      time: 'العام الجامعي الجاري أثناء جمع البيانات',
      variables: variables,
      methodName: facultyId == 'Law'
          ? 'المنهج الوصفي التحليلي'
          : 'المنهج الوصفي التحليلي (أسلوب المسح)',
      sampleHint: facultyId == 'Law'
          ? 'عمدية للنصوص والأحكام'
          : 'عشوائية أو طبقية بحسب الكليات المتاحة وبما يسمح بالتحليل الإحصائي',
      instrumentName: facultyId == 'Law'
          ? 'بطاقة تحليل أسانيد'
          : (isLlm || isUi
              ? 'استبانة مقننة لإدراك الاستخدام والفاعلية'
              : 'استبانة مقننة'),
      analysisHint: facultyId == 'Law'
          ? 'تحليلياً وفق سلسلة الاستدلال القانوني'
          : 'إحصائياً عبر برنامج SPSS',
      reviewerField: isEdu || isLlm || isUi
          ? 'تكنولوجيا التعليم وتفاعل الإنسان مع الحاسوب'
          : 'التخصص الدقيق لموضوع الدراسة',
      dimensions: dimensions,
    );
  }

  static String _cleanFocus(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    s = s.replaceAll(RegExp(r'[…\.]+$'), '');
    s = s.replaceAll(RegExp(r'لـ\s*$'), '');
    if (s.length > 110) {
      final cut = s.substring(0, 110);
      final sp = cut.lastIndexOf(' ');
      s = sp > 40 ? cut.substring(0, sp) : cut;
    }
    return s.trim();
  }

  String _criticalPriorBlock(List<GroundedWork> works, {String topic = ''}) {
    final b = StringBuffer();
    b.writeln(
      'دراسات مفهرسة لموضوع'
      '${topic.isEmpty ? '' : ' «$topic»'}'
      ' — للإدراج النقدي (اتفاق / اختلاف / فجوة):',
    );
    for (var i = 0; i < works.take(8).length; i++) {
      final w = works[i];
      b.writeln('${i + 1}) ${w.apaLine}');
      if (w.primaryUrl.isNotEmpty) b.writeln('   رابط: ${w.primaryUrl}');
      final abs = w.abstractText.trim();
      if (abs.length > 40) {
        final cut = abs.length > 220 ? '${abs.substring(0, 220)}…' : abs;
        b.writeln('   ملخص موجز: $cut');
      }
      b.writeln(
        '   نقد مطلوب: ماذا غطّت؟ بأي منهج/عينة؟ ما القصور؟ كيف تختلف دراستك؟',
      );
    }
    b.writeln(
      'خلاصة الفجوة بعد المراجعة: تُكتب بعد قراءة الأعمال أعلاه.\n'
      'موقع الدراسة الحالية: يُصاغ بمقارنة المنهج والعينة والسياق المصري.',
    );
    return b.toString().trim();
  }

  int _readinessScore(
    List<ProposalCoachFinding> findings,
    int worksCount,
    int suggestionsCount,
  ) {
    var score = 100;
    for (final f in findings) {
      if (f.severity == 'ok') continue;
      score -= f.severity == 'high'
          ? 12
          : f.severity == 'medium'
              ? 7
              : 3;
    }
    if (worksCount >= 6) {
      score += 8;
    } else if (worksCount >= 3) {
      score += 4;
    } else if (worksCount == 0) {
      score -= 10;
    }
    if (suggestionsCount >= 3) score += 3;
    return score.clamp(0, 100);
  }

  static bool _mentionsMethodFamily(String method) {
    return RegExp(
      r'وصفي|تجريبي|نوعي|كمّي|كمي|مختلط|وثائقي|مقارن|تحليلي|استقرائي|استنباطي|qualitative|quantitative|mixed|doctrinal|survey|experimental',
      caseSensitive: false,
    ).hasMatch(method);
  }

  static String _firstLine(String text) {
    final t = text.trim();
    if (t.isEmpty) return '';
    final line = t.split(RegExp(r'[\n\r]+')).first.trim();
    return line.length > 120 ? line.substring(0, 120) : line;
  }

  static String? _guessSection(String issueId) {
    if (issueId.contains('title')) return ProposalSectionKeys.titleAr;
    if (issueId.contains('problem')) return ProposalSectionKeys.problem;
    if (issueId.contains('question') || issueId.contains('obj')) {
      return ProposalSectionKeys.questions;
    }
    if (issueId.contains('limit')) return ProposalSectionKeys.limits;
    if (issueId.contains('prior')) return ProposalSectionKeys.priorStudies;
    if (issueId.contains('method')) return ProposalSectionKeys.methodology;
    if (issueId.contains('instrument') || issueId.contains('inst')) {
      return ProposalSectionKeys.instruments;
    }
    if (issueId.contains('analysis') || issueId.contains('validity')) {
      return ProposalSectionKeys.analysis;
    }
    return null;
  }
}

class _InstrumentDim {
  final String name;
  final String questionNo;
  final String items;
  const _InstrumentDim({
    required this.name,
    required this.questionNo,
    required this.items,
  });
}

class _ProposalTopicContext {
  final String focus;
  final String titleEn;
  final String techPhrase;
  final String outcomePhrase;
  final String outcomeShort;
  final String population;
  final String place;
  final String time;
  final List<String> variables;
  final String methodName;
  final String sampleHint;
  final String instrumentName;
  final String analysisHint;
  final String reviewerField;
  final List<_InstrumentDim> dimensions;

  const _ProposalTopicContext({
    required this.focus,
    required this.titleEn,
    required this.techPhrase,
    required this.outcomePhrase,
    required this.outcomeShort,
    required this.population,
    required this.place,
    required this.time,
    required this.variables,
    required this.methodName,
    required this.sampleHint,
    required this.instrumentName,
    required this.analysisHint,
    required this.reviewerField,
    required this.dimensions,
  });
}
