import '../../core/locale/app_translate.dart';
import '../acadegate_publish/publish_models.dart';
import '../ai_advisor/grounded_reference_service.dart';
import '../ai_advisor/grounded_work.dart';
import '../ai_advisor/literature_relevance.dart';
import '../profile/academic_profile.dart';
import '../research_supply_chain/research_goal.dart';
import '../research_supply_chain/research_path_ai_service.dart';
import 'thesis_studio_ai_service.dart';
import 'thesis_studio_command.dart';
import 'thesis_studio_discipline.dart';
import 'thesis_studio_kind.dart';
import 'thesis_studio_length.dart';
import 'thesis_studio_literature_ai.dart';
import 'thesis_studio_literature_map.dart';
import 'thesis_studio_models.dart';
import 'thesis_studio_outline.dart';
import 'thesis_studio_prior_studies.dart';

class ThesisStudioEngine {
  ThesisStudioEngine._();

  static final ThesisStudioEngine instance = ThesisStudioEngine._();

  static List<ThesisChapterTemplate> outlineFor(ResearchGoal goal) =>
      ThesisStudioOutline.forGoal(goal);

  static List<ThesisChapterTemplate> outlineForPlan(ThesisPlan plan) =>
      ThesisStudioOutline.forPlan(plan);

  Future<ThesisDraft> buildSkeleton({
    required String rawGoal,
    ResearchDegreeTrack? trackOverride,
    ThesisKind? kindOverride,
    ThesisShape? shapeOverride,
    bool? arabicDraft,
    PublishCitationStyle citationStyle = PublishCitationStyle.apa,
    int targetPages = 40,
    AcademicProfile? profile,
    String? facultyId,
    String? departmentId,
    ThesisProgress? onProgress,
  }) async {
    onProgress?.call(_progressCollecting);
    final plan = await _resolvePlan(
      rawGoal: rawGoal,
      trackOverride: trackOverride,
      kindOverride: kindOverride,
      shapeOverride: shapeOverride,
      arabicDraft: arabicDraft,
      citationStyle: citationStyle,
      targetPages: targetPages,
      profile: profile,
      facultyId: facultyId,
      departmentId: departmentId,
    );
    onProgress?.call(_progressOutline);
    var draft = ThesisStudioAiService.buildSkeletonDraft(plan: plan);
    onProgress?.call(_progressUnderstand);
    draft = await ThesisStudioAiService.instance.enrichSkeleton(
      draft: draft,
      profile: profile,
    );
    return draft;
  }

  Future<ThesisDraft> buildDraft({
    required String rawGoal,
    ResearchDegreeTrack? trackOverride,
    ThesisKind? kindOverride,
    ThesisShape? shapeOverride,
    bool? arabicDraft,
    PublishCitationStyle citationStyle = PublishCitationStyle.apa,
    int targetPages = 40,
    AcademicProfile? profile,
    String? facultyId,
    String? departmentId,
    ThesisProgress? onProgress,
  }) async {
    onProgress?.call(_progressCollecting);
    final plan = await _resolvePlan(
      rawGoal: rawGoal,
      trackOverride: trackOverride,
      kindOverride: kindOverride,
      shapeOverride: shapeOverride,
      arabicDraft: arabicDraft,
      citationStyle: citationStyle,
      targetPages: targetPages,
      profile: profile,
      facultyId: facultyId,
      departmentId: departmentId,
    );
    final goal = plan.goal;

    onProgress?.call(_progressLiterature);
    final keepLimit = ThesisLengthBudget.sourceLimit(plan.targetPages);
    final pool = ThesisLengthBudget.harvestPool(plan.targetPages);
    final preferEnglish = !plan.arabic;
    final searchPlan = await ThesisLiteratureAi.instance.planSearch(
      rawGoal: goal.raw,
      goal: goal,
      arabicDraft: plan.arabic,
      discipline: plan.discipline,
    );
    var literature = await GroundedReferenceService.instance.searchScientific(
      queries: searchPlan.queries.isNotEmpty
          ? searchPlan.queries
          : ResearchGoalParser.scientificSearchQueries(
              goal,
              includeNativeField: plan.arabic,
            ),
      limit: pool,
      preferEnglish: preferEnglish,
      minYear: 0,
      includeTheses: true,
      corePhrases: [
        ...ResearchGoalParser.corePhrases(goal),
        ...searchPlan.includeTerms,
      ].where((t) => !preferEnglish || !RegExp(r'[\u0600-\u06FF]').hasMatch(t)).toList(),
      strongTokens: [
        ...ResearchGoalParser.strongMatchTokens(goal),
        ...searchPlan.includeTerms,
      ],
      disciplineTokens: plan.discipline.searchTerms,
      alienTokens: plan.discipline.alienHints,
      requireCoreHit: false,
      requireTitleCoreHit: false,
      commandText: goal.raw,
      minScore: preferEnglish ? 3 : 2,
    );
    onProgress?.call(_progressGate);
    final mapPreLimit = (keepLimit * 2).clamp(24, 48);
    final mapPre = LiteratureRelevance.rank(
      works: literature.works,
      corePhrases: searchPlan.includeTerms.isNotEmpty
          ? searchPlan.includeTerms
          : ResearchGoalParser.corePhrases(goal),
      strongTokens: ResearchGoalParser.strongMatchTokens(goal),
      preferEnglish: preferEnglish,
      minYear: 0,
      limit: mapPreLimit,
      minScore: 2,
      requireCoreHit: false,
      requireTitleCoreHit: false,
      commandText: goal.raw,
      disciplineTokens: plan.discipline.searchTerms,
      alienTokens: plan.discipline.alienHints,
    );
    final mapGatePool =
        mapPre.isNotEmpty ? mapPre : literature.works.take(mapPreLimit).toList();
    var gated = await ThesisLiteratureAi.instance.gate(
      plan: searchPlan,
      works: mapGatePool,
      maxKeep: keepLimit.clamp(12, 40),
    );
    if (gated.isEmpty) {
      gated = LiteratureRelevance.rank(
        works: literature.works,
        corePhrases: searchPlan.includeTerms.isNotEmpty
            ? searchPlan.includeTerms
            : ResearchGoalParser.corePhrases(goal),
        strongTokens: ResearchGoalParser.strongMatchTokens(goal),
        preferEnglish: preferEnglish,
        minYear: 0,
        limit: keepLimit,
        minScore: 2,
        requireCoreHit: false,
        requireTitleCoreHit: false,
        commandText: goal.raw,
        disciplineTokens: plan.discipline.searchTerms,
        alienTokens: plan.discipline.alienHints,
      );
      if (gated.isEmpty && literature.works.isNotEmpty) {
        gated = literature.works.take(keepLimit).toList();
      }
    }
    literature = GroundedReferenceBundle(
      topic: searchPlan.topic.isNotEmpty ? searchPlan.topic : literature.topic,
      works: gated,
    );

    onProgress?.call(_progressOutline);
    final templates = ThesisStudioOutline.forPlan(plan);
    return ThesisStudioAiService.instance.compose(
      plan: plan,
      literature: literature,
      templates: templates,
      profile: profile,
      onProgress: onProgress,
    );
  }

  Future<ThesisChapter> regenerateChapter({
    required ThesisDraft draft,
    required String chapterId,
    AcademicProfile? profile,
  }) {
    final chapter = draft.chapters.firstWhere((c) => c.id == chapterId);
    final template = ThesisChapterTemplate(
      id: chapter.id,
      titleAr: chapter.titleAr,
      titleEn: chapter.titleEn,
      purposeAr: chapter.purposeAr,
      purposeEn: chapter.purposeEn,
      depth: chapter.depth,
    );
    return ThesisStudioAiService.instance.fillChapter(
      plan: draft.plan,
      literature: draft.literature,
      template: template,
      priorChapters: draft.chapters.where((c) => c.id != chapterId).toList(),
      profile: profile,
      targetWords: ThesisLengthBudget.chapterWordTargets(
        draft.plan,
        ThesisStudioOutline.forPlan(draft.plan),
      )[chapterId],
    );
  }

  Future<ThesisDraft> harvestParagraph({
    required ThesisDraft draft,
    required String chapterId,
    required String paragraphId,
    required String command,
    ThesisProgress? onProgress,
    int? targetWords,
  }) async {
    final chapter = draft.chapters.firstWhere((c) => c.id == chapterId);
    final paragraph = chapter.paragraphs.firstWhere((p) => p.id == paragraphId);
    final seed = _commandSeed(
      command: command,
      heading: paragraph.heading(draft.arabic),
      goal: draft.goal,
    );
    final spec = ThesisCommandSpec.parse(
      seed,
      depth: chapter.depth,
      chapterId: chapter.id,
    );
    onProgress?.call(_progressLiterature);
    final found = await harvestForCommand(
      draft: draft,
      command: seed,
      onProgress: onProgress,
      targetWords: targetWords ?? spec.targetWords,
    );
    final updated = paragraph.copyWith(
      references: found.works,
      lastCommand: command.trim().isEmpty ? seed : command.trim(),
    );
    return _withLiterature(
      draft.replacingChapter(
        chapter.replacingParagraph(updated, arabic: draft.arabic),
      ),
      found,
    );
  }

  Future<ThesisDraft> writeParagraph({
    required ThesisDraft draft,
    required String chapterId,
    required String paragraphId,
    required String command,
    AcademicProfile? profile,
    ThesisProgress? onProgress,
    void Function(ThesisDraft partial)? onPartial,
  }) async {
    var current = draft;
    var chapter = current.chapters.firstWhere((c) => c.id == chapterId);
    var paragraph = chapter.paragraphs.firstWhere((p) => p.id == paragraphId);
    final seed = _commandSeed(
      command: command,
      heading: paragraph.heading(current.arabic),
      goal: current.goal,
    );
    final spec = ThesisCommandSpec.parse(
      seed,
      depth: chapter.depth,
      chapterId: chapter.id,
    );
    if (paragraph.references.isEmpty) {
      current = await harvestParagraph(
        draft: current,
        chapterId: chapterId,
        paragraphId: paragraphId,
        command: seed,
        onProgress: onProgress,
        targetWords: spec.targetWords,
      );
      chapter = current.chapters.firstWhere((c) => c.id == chapterId);
      paragraph = chapter.paragraphs.firstWhere((p) => p.id == paragraphId);
      onPartial?.call(current);
    }
    onProgress?.call(
      current.arabic
          ? 'جارٍ كتابة «${paragraph.heading(true)}» (هدف ≈ ${spec.estimatedPages} صفحة)...'
          : 'Writing «${paragraph.heading(false)}» (target ≈ ${spec.estimatedPages} pages)...',
    );
    final template = ThesisChapterTemplate(
      id: chapter.id,
      titleAr: chapter.titleAr,
      titleEn: chapter.titleEn,
      purposeAr: chapter.purposeAr,
      purposeEn: chapter.purposeEn,
      depth: chapter.depth,
    );
    final filled = await ThesisStudioAiService.instance.fillParagraph(
      plan: current.plan,
      literature: _citingBundle(current, paragraph, seed),
      template: template,
      paragraph: paragraph,
      command: seed,
      siblingParagraphs: chapter.paragraphs,
      profile: profile,
      onProgress: onProgress,
      spec: spec,
      onBodyUpdate: (body) {
        final live = paragraph.copyWith(
          body: body,
          fromGemini: true,
          lastCommand: seed,
        );
        current = current
            .replacingChapter(
              chapter.replacingParagraph(live, arabic: current.arabic),
            )
            .copyWith(fromGemini: true);
        chapter = current.chapters.firstWhere((c) => c.id == chapterId);
        paragraph = chapter.paragraphs.firstWhere((p) => p.id == paragraphId);
        onPartial?.call(current);
      },
    );
    return current
        .replacingChapter(
          chapter.replacingParagraph(filled, arabic: current.arabic),
        )
        .copyWith(fromGemini: current.fromGemini || filled.fromGemini);
  }

  /// Paste DOIs → resolve + merge into literature without wiping written prose.
  Future<ThesisDraft> importPriorStudyDois({
    required ThesisDraft draft,
    required String pasted,
    ThesisProgress? onProgress,
  }) async {
    onProgress?.call(
      draft.arabic
          ? 'جارٍ استيراد المراجع وجلب الملخصات من الفهارس...'
          : 'Importing references and fetching abstracts...',
    );
    final works = await GroundedReferenceService.instance.resolveBibliography(
      pasted,
      limit: 80,
    );
    if (works.isEmpty) {
      throw StateError(
        draft.arabic
            ? 'لم يُعثر على DOI صالح في النص. الصق روابط doi.org أو أرقام DOI.'
            : 'No valid DOI found. Paste doi.org links or DOI strings.',
      );
    }
    final withAbs =
        works.where((w) => w.abstractText.trim().length >= 80).length;
    final merged = appendWorks(
      draft.literature,
      works,
      topic: draft.literature.topic.isNotEmpty
          ? draft.literature.topic
          : 'prior-studies-import',
    );
    return draft.copyWith(
      literature: merged,
      literatureMap: ThesisLiteratureMapper.fromBundle(merged),
      note: draft.arabic
          ? 'أُضيف ${works.length} مرجعاً ($withAbs بـ Abstract). اضغط «تلخيص Abstracts» لشكل الدراسات السابقة.'
          : 'Added ${works.length} works ($withAbs with Abstract). Tap “Summarise abstracts” for prior-studies form.',
    );
  }

  /// Pull intro (+ literature) confirmed refs, fetch Abstracts, write one
  /// thesis-style paragraph per study: Author et al. (Year). findings…
  Future<ThesisDraft> writePriorStudiesChapter({
    required ThesisDraft draft,
    List<GroundedWork>? worksOverride,
    bool overwriteExisting = true,
    ThesisProgress? onProgress,
  }) async {
    final chapterIndex = draft.chapters.indexWhere((c) => c.id == 'literature');
    if (chapterIndex < 0) {
      throw StateError(
        draft.arabic
            ? 'لا يوجد فصل أدبيات في المسودة.'
            : 'No literature chapter in this draft.',
      );
    }
    final chapter = draft.chapters[chapterIndex];
    final pooled = _collectPriorStudyWorks(draft, worksOverride);
    if (pooled.isEmpty) {
      throw StateError(
        draft.arabic
            ? 'لا مراجع مؤكدة من فصل المقدمة أو الأدبيات بعد. اجلب مراجع المقدمة أولاً، أو الصق DOI.'
            : 'No confirmed references from the introduction or literature yet. Harvest introduction sources first, or paste DOIs.',
      );
    }
    onProgress?.call(
      draft.arabic
          ? 'جلب نصوص Abstract من الفهارس لـ ${pooled.length} مرجعاً (مقدمة + أدبيات)...'
          : 'Fetching Abstract texts for ${pooled.length} works (intro + literature)...',
    );
    final enriched = await GroundedReferenceService.instance.enrichAbstracts(
      pooled.take(80).toList(),
      onProgress: onProgress,
      arabic: draft.arabic,
      forceRefreshShort: true,
    );
    final withAbs =
        enriched.where((w) => w.abstractText.trim().length >= 80).length;
    if (withAbs == 0) {
      throw StateError(
        draft.arabic
            ? 'تعذّر جلب أي Abstract مفتوح لهذه المراجع من الفهارس.'
            : 'Could not fetch any open Abstract for these works.',
      );
    }
    enriched.sort((a, b) {
      final aa = a.abstractText.trim().length;
      final bb = b.abstractText.trim().length;
      return bb.compareTo(aa);
    });

    final existingByDoi = <String, ThesisParagraph>{};
    if (!overwriteExisting) {
      for (final p in chapter.paragraphs) {
        if (!p.id.startsWith('lit_study_')) continue;
        if (p.body.trim().length < 80) continue;
        for (final w in p.references) {
          final key = w.doi.trim().toLowerCase();
          if (key.isNotEmpty) existingByDoi[key] = p;
        }
      }
    }

    final summaries = <({GroundedWork work, String paragraph})>[];
    for (var i = 0; i < enriched.length; i++) {
      final work = enriched[i];
      final key = work.doi.trim().toLowerCase();
      final kept = existingByDoi[key];
      if (kept != null &&
          kept.body.trim().length >= 80 &&
          work.abstractText.trim().length >= 80) {
        summaries.add((work: work, paragraph: kept.body.trim()));
        continue;
      }
      onProgress?.call(
        draft.arabic
            ? 'كتابة فقرة الدراسة ${i + 1}/${enriched.length} من Abstract...'
            : 'Writing study paragraph ${i + 1}/${enriched.length} from Abstract...',
      );
      final text = await ThesisPriorStudiesWriter.instance.summarizeStudy(
        work: work,
        goal: draft.goal,
        arabic: draft.arabic,
        studyIndex: i,
      );
      summaries.add((work: work, paragraph: text));
    }

    final paragraphs = <ThesisParagraph>[
      for (var i = 0; i < summaries.length; i++)
        ThesisParagraph(
          id: 'lit_study_${i + 1}',
          headingAr: _priorHeading(summaries[i].work, arabic: true),
          headingEn: _priorHeading(summaries[i].work, arabic: false),
          body: summaries[i].paragraph,
          references: [summaries[i].work],
          fromGemini: true,
          lastCommand: '',
        ),
    ];
    final updated = chapter.copyWith(
      paragraphs: paragraphs,
      body: ThesisChapter.assembleBody(paragraphs, draft.arabic),
      fromGemini: true,
    );
    final merged = appendWorks(draft.literature, enriched);
    final pages = ThesisLengthBudget.estimatedPagesOf(updated.body);
    return draft.replacingChapter(updated).copyWith(
          literature: merged,
          literatureMap: ThesisLiteratureMapper.fromBundle(merged),
          fromGemini: true,
          note: draft.arabic
              ? 'كُتب فصل الدراسات السابقة: ${paragraphs.length} دراسة من Abstract ($withAbs بملخص) · ≈ $pages صفحة.'
              : 'Prior-studies chapter written: ${paragraphs.length} studies from Abstracts ($withAbs with text) · ≈ $pages pp.',
        );
  }

  /// Sources for prior studies: introduction harvest first, then literature pool.
  static List<GroundedWork> _collectPriorStudyWorks(
    ThesisDraft draft,
    List<GroundedWork>? worksOverride,
  ) {
    final pooled = <String, GroundedWork>{};

    void add(GroundedWork w) {
      final key = w.mergeKey;
      if (key.isEmpty || key == 't:|0') return;
      final prev = pooled[key];
      if (prev == null) {
        pooled[key] = w;
        return;
      }
      pooled[key] = GroundedWork(
        title: prev.title.trim().length >= w.title.trim().length
            ? prev.title
            : w.title,
        doi: prev.hasDoi ? prev.doi : w.doi,
        year: prev.year ?? w.year,
        authors: prev.authors.trim().isNotEmpty ? prev.authors : w.authors,
        source: prev.abstractText.trim().length >= w.abstractText.trim().length
            ? prev.source
            : w.source,
        journal: (prev.journal ?? '').trim().isNotEmpty
            ? prev.journal
            : w.journal,
        abstractText:
            prev.abstractText.trim().length >= w.abstractText.trim().length
                ? prev.abstractText
                : w.abstractText,
        externalUrl: prev.externalUrl.trim().isNotEmpty
            ? prev.externalUrl
            : w.externalUrl,
      );
    }

    for (final chapter in draft.chapters) {
      if (chapter.id != 'intro') continue;
      for (final paragraph in chapter.paragraphs) {
        for (final work in paragraph.references) {
          add(work);
        }
      }
    }
    for (final work in worksOverride ?? const <GroundedWork>[]) {
      add(work);
    }
    for (final work in draft.literature.works) {
      add(work);
    }
    for (final work in draft.abstractReferences) {
      add(work);
    }
    for (final chapter in draft.chapters) {
      if (chapter.id != 'literature') continue;
      for (final paragraph in chapter.paragraphs) {
        for (final work in paragraph.references) {
          add(work);
        }
      }
    }
    return pooled.values.toList();
  }

  /// Refresh one study card from its Abstract only (never the whole chapter).
  Future<ThesisDraft> writePriorStudyParagraph({
    required ThesisDraft draft,
    required String chapterId,
    required String paragraphId,
    ThesisProgress? onProgress,
  }) async {
    if (chapterId != 'literature') {
      throw StateError(
        draft.arabic
            ? 'تلخيص الملخصات مخصص لفصل الأدبيات.'
            : 'Abstract summarising is for the literature chapter only.',
      );
    }
    // Legacy combined card — rebuild chapter once.
    if (paragraphId == 'lit_abstracts_all') {
      return writePriorStudiesChapter(draft: draft, onProgress: onProgress);
    }

    final chapter = draft.chapters.firstWhere((c) => c.id == chapterId);
    final paragraph = chapter.paragraphs.firstWhere((p) => p.id == paragraphId);
    if (paragraph.references.isEmpty) {
      throw StateError(
        draft.arabic
            ? 'لا مرجع مؤكد لهذه البطاقة.'
            : 'No confirmed reference on this card.',
      );
    }
    onProgress?.call(
      draft.arabic
          ? 'جلب Abstract لهذه الدراسة فقط ثم التلخيص الذكي...'
          : 'Fetching Abstract for this study only, then smart summary...',
    );
    final enriched = await GroundedReferenceService.instance.enrichAbstracts(
      [paragraph.references.first],
      arabic: draft.arabic,
      forceRefreshShort: true,
    );
    final work = enriched.first;
    if (work.abstractText.trim().length < 40) {
      throw StateError(
        draft.arabic
            ? 'تعذّر جلب Abstract مفتوح لهذا المرجع من الفهارس.'
            : 'Could not fetch an open Abstract for this reference.',
      );
    }
    final indexMatch = RegExp(r'lit_study_(\d+)').firstMatch(paragraphId);
    final studyIndex =
        ((int.tryParse(indexMatch?.group(1) ?? '1') ?? 1) - 1).clamp(0, 999);
    final body = await ThesisPriorStudiesWriter.instance.summarizeStudy(
      work: work,
      goal: draft.goal,
      arabic: draft.arabic,
      studyIndex: studyIndex,
    );
    final updated = paragraph.copyWith(
      headingAr: _priorHeading(work, arabic: true),
      headingEn: _priorHeading(work, arabic: false),
      body: body,
      references: [work],
      fromGemini: true,
      lastCommand: '',
    );
    final merged = appendWorks(draft.literature, [work]);
    return draft
        .replacingChapter(
          chapter.replacingParagraph(updated, arabic: draft.arabic),
        )
        .copyWith(
          literature: merged,
          literatureMap: ThesisLiteratureMapper.fromBundle(merged),
          fromGemini: true,
          note: draft.arabic
              ? 'لُخّص Abstract لدراسة واحدة فقط: ${_priorHeading(work, arabic: true)}.'
              : 'Summarised Abstract for one study only: ${_priorHeading(work, arabic: false)}.',
        );
  }

  static String _priorHeading(GroundedWork work, {required bool arabic}) {
    final who = ThesisPriorStudiesWriter.shortAuthors(work.authors, arabic);
    final year = work.year?.toString() ?? (arabic ? 'د.ت.' : 'n.d.');
    return '$who ($year)';
  }

  Future<ThesisDraft> harvestAbstract({
    required ThesisDraft draft,
    required String command,
    ThesisProgress? onProgress,
  }) async {
    final seed = _commandSeed(
      command: command,
      heading: draft.arabic ? 'الملخص' : 'Abstract',
      goal: draft.goal,
    );
    onProgress?.call(_progressLiterature);
    final found = await harvestForCommand(
      draft: draft,
      command: seed,
      onProgress: onProgress,
    );
    return _withLiterature(
      draft.copyWith(
        abstractReferences: found.works,
      ),
      found,
    );
  }

  Future<ThesisDraft> writeAbstract({
    required ThesisDraft draft,
    required String command,
    AcademicProfile? profile,
    ThesisProgress? onProgress,
  }) async {
    var current = draft;
    final seed = _commandSeed(
      command: command,
      heading: draft.arabic ? 'الملخص' : 'Abstract',
      goal: draft.goal,
    );
    if (current.abstractReferences.isEmpty && current.literature.works.isEmpty) {
      current = await harvestAbstract(
        draft: current,
        command: seed,
        onProgress: onProgress,
      );
    }
    onProgress?.call(
      current.arabic ? 'جارٍ كتابة الملخص فقط...' : 'Writing the abstract only...',
    );
    final text = await ThesisStudioAiService.instance.fillAbstract(
      plan: current.plan,
      literature: current.abstractReferences.isNotEmpty
          ? GroundedReferenceBundle(
              topic: seed,
              works: current.abstractReferences,
            )
          : current.literature,
      command: seed,
      profile: profile,
    );
    return current.copyWith(abstractText: text, fromGemini: current.fromGemini);
  }

  Future<GroundedReferenceBundle> harvestForCommand({
    required ThesisDraft draft,
    required String command,
    ThesisProgress? onProgress,
    int? targetWords,
  }) async {
    final words = targetWords ??
        ThesisCommandSpec.parse(
          command,
          depth: ThesisChapterDepth.full,
        ).targetWords;
    final keepLimit = ThesisLengthBudget.commandSourceLimit(words);
    final pool = ThesisLengthBudget.commandHarvestPool(words);
    final preferEnglish = !draft.arabic;
    final searchPlan = await ThesisLiteratureAi.instance.planSearch(
      rawGoal: command,
      goal: draft.goal,
      arabicDraft: draft.arabic,
      discipline: draft.plan.discipline,
    );
    final topicText = ThesisCommandSpec.parse(
      command,
      depth: ThesisChapterDepth.full,
    ).topicText;
    final goalText = ResearchGoalParser.contextForAi(draft.goal.raw);
    final scopeText = '$goalText $topicText';
    final commandPhrases = ThesisLiteratureAi.distinctiveTerms(topicText);
    final goalPhrases = ThesisLiteratureAi.distinctiveTerms(goalText);
    final topicLower = topicText.toLowerCase();
    final corePhrases = <String>{
      ...commandPhrases,
      ...goalPhrases,
      for (final term in searchPlan.includeTerms)
        if (term.trim().length >= 4 &&
            (scopeText.toLowerCase().contains(term.trim().toLowerCase()) ||
                commandPhrases.any(
                  (c) =>
                      c.contains(term.toLowerCase()) ||
                      term.toLowerCase().contains(c),
                ) ||
                goalPhrases.any(
                  (c) =>
                      c.contains(term.toLowerCase()) ||
                      term.toLowerCase().contains(c),
                )))
          term.trim().toLowerCase(),
    }.where((t) => !LiteratureRelevance.weakAlone.contains(t)).toList();
    final strongTokens = <String>{
      ..._commandTokens(command),
      ...commandPhrases,
      ...goalPhrases,
      for (final term in searchPlan.includeTerms)
        if (scopeText.toLowerCase().contains(term.trim().toLowerCase()))
          term.trim(),
    }.where((t) => !LiteratureRelevance.weakAlone.contains(t.toLowerCase())).toList();
    final aliens = draft.plan.discipline.alienHints;
    // Prefer Latin cores for English drafts so Arabic goal words do not
    // zero out every English OpenAlex title via requireTitleCoreHit.
    final latinCores = [
      for (final t in corePhrases)
        if (!RegExp(r'[\u0600-\u06FF]').hasMatch(t)) t,
    ];
    final searchCores =
        preferEnglish && latinCores.isNotEmpty ? latinCores : corePhrases;
    final hasLatinCore = searchCores.any((t) => RegExp(r'[A-Za-z]{4,}').hasMatch(t));
    var literature = await GroundedReferenceService.instance.searchScientific(
      queries: _commandQueries(command, searchPlan, draft),
      limit: pool,
      preferEnglish: preferEnglish,
      minYear: 0,
      includeTheses: true,
      corePhrases: searchCores,
      strongTokens: strongTokens,
      disciplineTokens: draft.plan.discipline.searchTerms,
      alienTokens: aliens,
      requireCoreHit: false,
      requireTitleCoreHit: false,
      commandText: scopeText,
      minScore: preferEnglish ? 3 : 2,
    );
    onProgress?.call(_progressGate);
    // Cap AI gate batches so long paragraph harvests leave quota for write/grow.
    final preRankLimit = (keepLimit * 2).clamp(24, 48);
    final preRanked = LiteratureRelevance.rank(
      works: literature.works,
      corePhrases: searchCores.isNotEmpty ? searchCores : goalPhrases,
      strongTokens: strongTokens,
      preferEnglish: preferEnglish,
      minYear: 0,
      limit: preRankLimit,
      minScore: 2,
      requireCoreHit: false,
      requireTitleCoreHit: false,
      commandText: scopeText,
      disciplineTokens: draft.plan.discipline.searchTerms,
      alienTokens: aliens,
    );
    final gatePool = preRanked.isNotEmpty
        ? preRanked
        : literature.works.take(preRankLimit).toList();
    final gateKeep = keepLimit.clamp(12, 40);
    var gated = await ThesisLiteratureAi.instance.gate(
      plan: searchPlan,
      works: gatePool,
      maxKeep: gateKeep,
    );
    if (gated.isEmpty) {
      gated = LiteratureRelevance.rank(
        works: literature.works,
        corePhrases: searchCores.isNotEmpty ? searchCores : goalPhrases,
        strongTokens: strongTokens,
        preferEnglish: preferEnglish,
        minYear: 0,
        limit: keepLimit,
        minScore: 2,
        requireCoreHit: false,
        requireTitleCoreHit: false,
        commandText: scopeText,
        disciplineTokens: draft.plan.discipline.searchTerms,
        alienTokens: aliens,
      );
    } else if (gated.length < keepLimit) {
      final have = {for (final w in gated) w.mergeKey};
      final filler = LiteratureRelevance.rank(
        works: literature.works
            .where((w) => !have.contains(w.mergeKey))
            .toList(),
        corePhrases: searchCores.isNotEmpty ? searchCores : goalPhrases,
        strongTokens: strongTokens,
        preferEnglish: preferEnglish,
        minYear: 0,
        limit: keepLimit - gated.length,
        minScore: 3,
        requireCoreHit: hasLatinCore,
        requireTitleCoreHit: false,
        commandText: scopeText,
        disciplineTokens: draft.plan.discipline.searchTerms,
        alienTokens: aliens,
      );
      gated = [...gated, ...filler];
    }
    // Soft polish only — never wipe a non-empty gated set.
    if (gated.isNotEmpty) {
      final polished = LiteratureRelevance.rank(
        works: gated,
        corePhrases: searchCores.isNotEmpty ? searchCores : goalPhrases,
        strongTokens: strongTokens,
        preferEnglish: preferEnglish,
        minYear: 0,
        limit: keepLimit,
        minScore: 1,
        requireCoreHit: false,
        requireTitleCoreHit: false,
        commandText: scopeText,
        disciplineTokens: draft.plan.discipline.searchTerms,
        alienTokens: aliens,
      );
      if (polished.isNotEmpty) gated = polished;
    }
    if (gated.isEmpty && literature.works.isNotEmpty) {
      gated = literature.works.take(keepLimit).toList();
    }
    return GroundedReferenceBundle(
      topic: searchPlan.topic.isNotEmpty ? searchPlan.topic : command,
      works: gated,
    );
  }

  ThesisDraft _withLiterature(
    ThesisDraft draft,
    GroundedReferenceBundle found,
  ) {
    final goalText = ResearchGoalParser.contextForAi(draft.goal.raw);
    final cores = ThesisLiteratureAi.distinctiveTerms(goalText);
    final aliens = <String>{
      ...draft.plan.discipline.alienHints,
      ...LiteratureRelevance.opportunisticJunk,
    };
    // Rebuild the map from paragraph/abstract refs + this harvest, then
    // drop anything that does not hit the thesis goal in the title.
    final pooled = <GroundedWork>[
      ...found.works,
      for (final chapter in draft.chapters)
        for (final paragraph in chapter.paragraphs) ...paragraph.references,
      ...draft.abstractReferences,
    ];
    final byKey = <String, GroundedWork>{};
    for (final work in pooled) {
      final key = work.mergeKey;
      if (key.isEmpty || key == 't:|0') continue;
      if (LiteratureRelevance.isOpportunisticJunkWork(work, goalText)) continue;
      byKey.putIfAbsent(key, () => work);
    }
    final kept = cores.isEmpty
        ? byKey.values.toList()
        : LiteratureRelevance.rank(
            works: byKey.values.toList(),
            corePhrases: cores,
            strongTokens: cores,
            preferEnglish: !draft.arabic,
            limit: byKey.length.clamp(1, 220),
            minScore: 2,
            requireCoreHit: false,
            requireTitleCoreHit: false,
            commandText: goalText,
            disciplineTokens: draft.plan.discipline.searchTerms,
            alienTokens: aliens,
          );
    final keptOrAll =
        kept.isNotEmpty ? kept : byKey.values.take(220).toList();
    // Always keep the just-harvested works that already passed the gate.
    final finalByKey = <String, GroundedWork>{
      for (final w in keptOrAll) w.mergeKey: w,
      for (final w in found.works)
        if (!LiteratureRelevance.isOpportunisticJunkWork(w, goalText))
          w.mergeKey: w,
    };
    final cleaned = GroundedReferenceBundle(
      topic: found.topic.isNotEmpty ? found.topic : draft.literature.topic,
      works: finalByKey.values.toList(),
    );
    return draft.copyWith(
      literature: cleaned,
      literatureMap: ThesisLiteratureMapper.fromBundle(cleaned),
    );
  }

  static GroundedReferenceBundle appendWorks(
    GroundedReferenceBundle current,
    List<GroundedWork> extra, {
    String? topic,
  }) {
    final byKey = <String, GroundedWork>{};
    for (final work in [...current.works, ...extra]) {
      final key = work.mergeKey;
      if (key.isEmpty || key == 't:|0') continue;
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = work;
        continue;
      }
      byKey[key] = GroundedWork(
        title: existing.title.trim().length >= work.title.trim().length
            ? existing.title
            : work.title,
        doi: existing.hasDoi ? existing.doi : work.doi,
        year: existing.year ?? work.year,
        authors: existing.authors.trim().isNotEmpty
            ? existing.authors
            : work.authors,
        source: existing.abstractText.trim().isNotEmpty
            ? existing.source
            : work.source,
        journal: (existing.journal ?? '').trim().isNotEmpty
            ? existing.journal
            : work.journal,
        abstractText: existing.abstractText.trim().isNotEmpty
            ? existing.abstractText
            : work.abstractText,
        externalUrl: existing.externalUrl.trim().isNotEmpty
            ? existing.externalUrl
            : work.externalUrl,
      );
    }
    return GroundedReferenceBundle(
      topic: (topic != null && topic.trim().isNotEmpty)
          ? topic
          : current.topic,
      works: byKey.values.toList(),
    );
  }

  Future<ThesisPlan> _resolvePlan({
    required String rawGoal,
    ResearchDegreeTrack? trackOverride,
    ThesisKind? kindOverride,
    ThesisShape? shapeOverride,
    bool? arabicDraft,
    required PublishCitationStyle citationStyle,
    required int targetPages,
    AcademicProfile? profile,
    String? facultyId,
    String? departmentId,
  }) async {
    var goal = ResearchGoalParser.parse(
      rawGoal,
      profileDegree: profile?.degree,
    );
    if (trackOverride != null &&
        trackOverride != ResearchDegreeTrack.unspecified) {
      goal = goal.copyWith(
        track: trackOverride,
        years: trackOverride == ResearchDegreeTrack.phd
            ? 3
            : trackOverride == ResearchDegreeTrack.diploma
                ? 1
                : 2,
      );
    }
    goal = await ResearchPathAiService.instance.briefGoal(
      goal,
      arabicDraft: arabicDraft,
    );
    final guess = ThesisKindDetector.detect(
      raw: rawGoal,
      profile: profile,
      kindOverride: kindOverride,
      shapeOverride: shapeOverride,
      arabicOverride: arabicDraft,
    );
    return ThesisPlan(
      goal: goal,
      kind: guess.kind,
      shape: guess.shape,
      arabic: guess.arabic,
      citationStyle: citationStyle,
      targetPages: ThesisLengthBudget.clampPages(targetPages),
      discipline: ThesisDiscipline.resolve(
        facultyId: facultyId,
        departmentId: departmentId,
        profile: profile,
      ),
    );
  }

  /// Test/debug seam for [_commandSeed].
  static String commandSeedForTest({
    required String command,
    required String heading,
    required ResearchGoal goal,
  }) =>
      _commandSeed(command: command, heading: heading, goal: goal);

  static String _commandSeed({
    required String command,
    required String heading,
    required ResearchGoal goal,
  }) {
    // Heading is UI chrome only — never search with "1.1 Context" / "السياق".
    final typed = command.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (typed.length >= 4) {
      return typed.length > 2500 ? typed.substring(0, 2500) : typed;
    }
    final clip = ResearchGoalParser.contextForAi(goal.raw, maxChars: 800);
    if (clip.trim().length >= 8) return clip.trim();
    final field = goal.fieldEn.trim().isNotEmpty ? goal.fieldEn : goal.field;
    return field.trim().isNotEmpty ? field.trim() : goal.raw.trim();
  }

  static GroundedReferenceBundle _citingBundle(
    ThesisDraft draft,
    ThesisParagraph paragraph,
    String seed,
  ) {
    if (paragraph.references.isNotEmpty) {
      return GroundedReferenceBundle(
        topic: seed,
        works: paragraph.references,
      );
    }
    return draft.literature;
  }

  static List<String> _commandQueries(
    String command,
    LiteratureSearchPlan searchPlan,
    ThesisDraft draft,
  ) {
    final queries = <String>[];
    queries.addAll(ThesisLiteratureAi.queriesFromCommand(command));
    for (final q in searchPlan.queries) {
      if (q.trim().length >= 4) queries.add(q.trim());
    }
    final suffix = draft.plan.discipline.querySuffix;
    if (suffix.isNotEmpty) {
      queries.addAll([
        for (final q in [...queries])
          if (!q.toLowerCase().contains(suffix.toLowerCase())) '$q $suffix',
      ]);
    }
    if (queries.isEmpty) {
      queries.addAll(
        ResearchGoalParser.scientificSearchQueries(
          draft.goal,
          includeNativeField: draft.arabic,
        ),
      );
    }
    final unique = <String>{};
    return [
      for (final q in queries)
        if (unique.add(q.toLowerCase())) q,
    ].take(6).toList();
  }

  static List<String> _commandTokens(String command) {
    return ThesisLiteratureAi.distinctiveTerms(
      ThesisCommandSpec.parse(
        command,
        depth: ThesisChapterDepth.full,
      ).topicText,
    );
  }

  static List<GroundedWork> _mergeWorks(
    List<GroundedWork> primary,
    List<GroundedWork> extra,
    int limit,
  ) {
    final byKey = <String, GroundedWork>{};
    for (final w in [...primary, ...extra]) {
      byKey.putIfAbsent(w.mergeKey, () => w);
    }
    final list = byKey.values.toList()
      ..sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
    return list.take(limit).toList();
  }

  static String get _progressCollecting =>
      appTr('جارٍ فهم هدف الرسالة ونوعها...', 'Understanding the thesis goal and type...');
  static String get _progressLiterature =>
      appTr(
        'جارٍ البحث في الفهارس الحرة (+ Google Scholar إن فُعّل SerpAPI)...',
        'Searching free indexes (+ Google Scholar when SerpAPI is enabled)...',
      );
  static String get _progressGate =>
      appTr(
        'جارٍ تصفية المرشحين حسب كليتك وقسمك فقط...',
        'Keeping only papers from your faculty and department...',
      );
  static String get _progressOutline =>
      appTr('جارٍ بناء هيكل الفصول حسب التخصص...', 'Building the disciplinary outline...');
  static String get _progressUnderstand =>
      appTr(
        'Gemini 2.5 Pro يقرأ هدفك كاملاً ويضع العنوان بلغة المسودة...',
        'Gemini 2.5 Pro is reading your full goal and writing the title in the draft language...',
      );
}
