import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:acadegate/features/ai_advisor/grounded_reference_service.dart';
import 'package:acadegate/features/ai_advisor/grounded_work.dart';
import 'package:acadegate/features/profile/academic_profile.dart';
import 'package:acadegate/features/research_supply_chain/research_goal.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_ai_service.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_citation_report.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_citations.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_command.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_discipline.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_engine.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_kind.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_latex_export.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_length.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_literature_ai.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_models.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_outline.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_prose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Arabic lab masters uses five-chapter empirical spine', () {
    final goal = ResearchGoalParser.parse(
      'أريد ماجستير في الكيمياء التحليلية لتطوير مصنع زيوت',
    );
    final outline = ThesisStudioEngine.outlineFor(goal);
    expect(outline.map((c) => c.id).toList(), [
      'intro',
      'literature',
      'experimental',
      'results_discussion',
      'conclusion',
    ]);
    expect(outline.first.depth, ThesisChapterDepth.full);
    expect(outline.firstWhere((c) => c.id == 'experimental').depth,
        ThesisChapterDepth.protocol);
    expect(outline.firstWhere((c) => c.id == 'results_discussion').depth,
        ThesisChapterDepth.scaffold);
    for (final chapter in outline) {
      expect(
        chapter.titleAr.contains(goal.field) ||
            chapter.titleEn.toLowerCase().contains(goal.fieldEn.toLowerCase()),
        isTrue,
        reason: chapter.titleAr,
      );
    }
  });

  test('English experimental merged matches IMRaD-with-experimental', () {
    final goal = ResearchGoalParser.parse(
      'Master thesis in analytical chemistry HPLC edible oil refining',
    );
    final guess = ThesisKindDetector.detect(raw: goal.raw);
    expect(guess.kind, ThesisKind.experimental);
    expect(guess.arabic, isFalse);
    expect(guess.shape, ThesisShape.englishExperimentalMerged);
    final outline = ThesisStudioOutline.forPlan(
      ThesisPlan(
        goal: goal,
        kind: guess.kind,
        shape: guess.shape,
        arabic: guess.arabic,
      ),
    );
    expect(outline.map((c) => c.id).toList(), [
      'intro',
      'literature',
      'experimental',
      'results_discussion',
      'conclusion',
    ]);
  });

  test('English experimental split keeps results then discussion', () {
    final goal = ResearchGoalParser.parse(
      'PhD in analytical chemistry of edible oil refining',
    );
    final outline = ThesisStudioOutline.forPlan(
      ThesisPlan(
        goal: goal,
        kind: ThesisKind.experimental,
        shape: ThesisShape.englishExperimentalSplit,
        arabic: false,
      ),
    );
    expect(outline.map((c) => c.id).toList(), [
      'intro',
      'literature',
      'experimental',
      'results',
      'discussion',
      'conclusion',
    ]);
  });

  test('Arabic literary thesis uses thematic chapters not lab results', () {
    final goal = ResearchGoalParser.parse(
      'ماجستير في نقد الرواية العربية المعاصرة',
    );
    final guess = ThesisKindDetector.detect(raw: goal.raw);
    expect(guess.kind, ThesisKind.literary);
    final outline = ThesisStudioEngine.outlineFor(goal);
    expect(outline.map((c) => c.id), isNot(contains('experimental')));
    expect(outline.map((c) => c.id), isNot(contains('results')));
    expect(outline.map((c) => c.id).toList(), containsAll(['intro', 'literature', 'theme_a', 'conclusion']));
  });

  test('literary PhD adds a theory chapter', () {
    final goal = ResearchGoalParser.parse(
      'دكتوراه في شعر المعلقات وتحليل الخطاب',
    );
    final outline = ThesisStudioOutline.forPlan(
      ThesisPlan(
        goal: goal,
        kind: ThesisKind.literary,
        shape: ThesisShape.arabicLiterary,
        arabic: true,
      ),
    );
    expect(outline.first.id, 'intro');
    expect(outline[1].id, 'theory');
    expect(outline.last.id, 'conclusion');
  });

  test('diploma lab outline stays short', () {
    final goal = ResearchGoalParser.parse(
      'دبلوم في الكيمياء التحليلية للزيوت',
    );
    final outline = ThesisStudioEngine.outlineFor(goal);
    expect(outline.map((c) => c.id).toList(), [
      'intro',
      'literature',
      'experimental',
      'conclusion',
    ]);
  });

  test('local draft cites only supplied DOIs', () {
    const allowed = '10.1000/ag.test.oil';
    final goal = ResearchGoalParser.parse(
      'ماجستير في الكيمياء التحليلية لتكرير الزيوت',
    );
    final literature = GroundedReferenceBundle(
      topic: 'analytical chemistry edible oil',
      works: const [
        GroundedWork(
          title: 'HPLC of refined edible oils',
          doi: allowed,
          source: 'OpenAlex',
          year: 2021,
          authors: 'Test Author',
        ),
      ],
    );
    final draft = ThesisStudioAiService.buildLocalDraft(
      goal: goal,
      literature: literature,
    );
    expect(draft.chapters, isNotEmpty);
    expect(draft.kind, ThesisKind.experimental);
    expect(draft.literatureMap, hasLength(1));
    final blob = [
      draft.abstractText,
      ...draft.chapters.map((c) => c.body),
    ].join('\n');
    final dois = GroundedReferenceService.extractDois(blob);
    expect(dois, everyElement(equals(allowed)));
    expect(blob, contains('https://doi.org/$allowed'));
    expect(blob, isNot(contains('10.9999/invented')));
    final apa = ThesisStudioCitations.bibliographyLine(
      literature.works.first,
      index: 1,
      style: PublishCitationStyle.apa,
    );
    expect(apa.toLowerCase(), contains('doi.org/$allowed'));
  });

  test('local draft with no literature invents no DOI', () {
    final goal = ResearchGoalParser.parse(
      'ماجستير في الكيمياء التحليلية لتكرير الزيوت',
    );
    final draft = ThesisStudioAiService.buildLocalDraft(
      goal: goal,
      literature: const GroundedReferenceBundle(topic: 'oil'),
    );
    final blob = [
      draft.abstractText,
      ...draft.chapters.map((c) => c.body),
    ].join('\n');
    expect(GroundedReferenceService.extractDois(blob), isEmpty);
    expect(draft.chapters.any((c) => c.body.contains('DOI')), isTrue);
  });

  test('PhD with merged English shape keeps a single results-and-discussion chapter', () {
    final goal = ResearchGoalParser.parse(
      'PhD thesis in analytical chemistry HPLC edible oil refining',
    );
    final outline = ThesisStudioOutline.forPlan(
      ThesisPlan(
        goal: goal,
        kind: ThesisKind.experimental,
        shape: ThesisShape.englishExperimentalMerged,
        arabic: false,
      ),
    );
    expect(outline.map((c) => c.id).toList(), [
      'intro',
      'literature',
      'experimental',
      'results_discussion',
      'conclusion',
    ]);
    expect(outline.map((c) => c.id), isNot(contains('results')));
    expect(outline.map((c) => c.id), isNot(contains('discussion')));
  });

  test('English experimental titles stay short and do not dump a pasted manuscript', () {
    final goal = ResearchGoal(
      raw: 'n the chemical profiles acquired, such as J Experimental ${'x' * 200}',
      field: '',
      fieldEn: 'n the chemical profiles acquired, such as J Experimental',
    );
    expect(
      ThesisStudioOutline.displayTopic(
        goal.fieldEn,
        fallback: goal.raw,
      ),
      isNot(startsWith('n the')),
    );
    expect(
      ThesisStudioOutline.displayTopic('x' * 500).length,
      lessThan(80),
    );
    final outline = ThesisStudioOutline.forPlan(
      ThesisPlan(
        goal: goal,
        kind: ThesisKind.experimental,
        shape: ThesisShape.englishExperimentalMerged,
        arabic: false,
      ),
    );
    expect(outline.first.titleEn, 'Chapter 1: Introduction');
    expect(outline.first.titleEn.toLowerCase(), isNot(contains('chemical profiles')));
  });

  test('local intro body is distinct from experimental and results', () {
    final goal = ResearchGoalParser.parse(
      'Master thesis in analytical chemistry HPLC edible oil refining',
    );
    final draft = ThesisStudioAiService.buildLocalDraft(
      goal: goal,
      literature: const GroundedReferenceBundle(topic: 'oil'),
      plan: ThesisPlan(
        goal: goal,
        kind: ThesisKind.experimental,
        shape: ThesisShape.englishExperimentalMerged,
        arabic: false,
      ),
    );
    final intro = draft.chapters.firstWhere((c) => c.id == 'intro').body;
    final literature = draft.chapters.firstWhere((c) => c.id == 'literature').body;
    final experimental =
        draft.chapters.firstWhere((c) => c.id == 'experimental').body;
    final results =
        draft.chapters.firstWhere((c) => c.id == 'results_discussion').body;
    expect(intro, isNot(equals(experimental)));
    expect(intro, isNot(equals(literature)));
    expect(intro, isNot(equals(results)));
    expect(intro.toLowerCase(), contains('introduction'));
    expect(experimental.toLowerCase(), contains('materials'));
    expect(results.toLowerCase(), contains('table'));
    expect(results.toLowerCase(), isNot(contains('1.1 context')));
  });

  test('page budget scales sources and literature weight', () {
    expect(ThesisLengthBudget.defaultPages, 40);
    expect(ThesisLengthBudget.sourceLimit(24), greaterThanOrEqualTo(20));
    expect(ThesisLengthBudget.sourceLimit(80), 64);
    expect(ThesisLengthBudget.clampPages(3), 12);
    expect(ThesisLengthBudget.harvestPool(40), greaterThan(ThesisLengthBudget.sourceLimit(40)));
    final goal = ResearchGoalParser.parse(
      'Master thesis in analytical chemistry HPLC edible oil refining',
    );
    final plan = ThesisPlan(
      goal: goal,
      kind: ThesisKind.experimental,
      shape: ThesisShape.englishExperimentalMerged,
      arabic: false,
      targetPages: 22,
    );
    final outline = ThesisStudioOutline.forPlan(plan);
    final words = ThesisLengthBudget.chapterWordTargets(plan, outline);
    expect(words['literature']!, greaterThan(words['results_discussion']!));
    expect(words['intro']!, greaterThanOrEqualTo(400));
  });

  test('citation report flags unknown markers and unused sources', () {
    const allowed = '10.1000/ag.test.oil';
    final goal = ResearchGoalParser.parse(
      'Master thesis in analytical chemistry HPLC edible oil refining',
    );
    final literature = GroundedReferenceBundle(
      topic: 'oil',
      works: const [
        GroundedWork(
          title: 'HPLC of refined edible oils',
          doi: allowed,
          source: 'OpenAlex',
          year: 2021,
          authors: 'Test Author',
        ),
        GroundedWork(
          title: 'Unused paper',
          doi: '10.1000/ag.unused',
          source: 'Semantic Scholar',
          year: 2020,
          authors: 'Other',
        ),
      ],
    );
    var draft = ThesisStudioAiService.buildLocalDraft(
      goal: goal,
      literature: literature,
      plan: ThesisPlan(
        goal: goal,
        kind: ThesisKind.experimental,
        shape: ThesisShape.englishExperimentalMerged,
        arabic: false,
      ),
    );
    draft = draft.copyWith(
      chapters: [
        for (final ch in draft.chapters)
          ch.id == 'intro'
              ? ch.copyWith(
                  body: 'Prior work established the gap [1]. Extra claim [9].',
                )
              : ch.copyWith(body: 'Frame without bibliography markers.'),
      ],
    );
    final report = ThesisCitationReport.fromDraft(draft);
    expect(report.usedIndexes, contains(1));
    expect(report.unusedIndexes, contains(2));
    expect(report.unknownMarkers, contains('[9]'));
  });

  test('LaTeX export maps [n] to cite keys and writes DOI BibTeX', () {
    const allowed = '10.1000/ag.test.oil';
    final goal = ResearchGoalParser.parse(
      'Master thesis in analytical chemistry HPLC edible oil refining',
    );
    var draft = ThesisStudioAiService.buildLocalDraft(
      goal: goal,
      literature: GroundedReferenceBundle(
        topic: 'oil',
        works: const [
          GroundedWork(
            title: 'HPLC of refined edible oils',
            doi: allowed,
            source: 'OpenAlex',
            year: 2021,
            authors: 'Test Author',
          ),
        ],
      ),
      plan: ThesisPlan(
        goal: goal,
        kind: ThesisKind.experimental,
        shape: ThesisShape.englishExperimentalMerged,
        arabic: false,
      ),
    );
    draft = draft.copyWith(
      chapters: [
        for (final ch in draft.chapters)
          ch.id == 'intro' ? ch.copyWith(body: 'See the method in [1].') : ch,
      ],
    );
    final tex = ThesisStudioLatexExport.instance.mainTex(draft);
    final bib = ThesisStudioLatexExport.instance.bibtex(draft);
    expect(ThesisStudioLatexExport.toLatexBody('See [1].'), contains(r'\cite{ref1}'));
    expect(tex, contains(r'\cite{ref1}'));
    expect(bib, contains('@article{ref1'));
    expect(bib, contains(allowed));
    expect(
      ThesisStudioLatexExport.instance.overleafZip(draft).length,
      greaterThan(100),
    );
  });

  test('AI literature plan and keep-list parsers are field-agnostic', () {
    final fallback = LiteratureSearchPlan(
      topic: 'nanomaterials',
      queries: const ['green synthesis of zinc oxide nanomaterials'],
      includeTerms: const ['nanomaterials'],
    );
    final plan = ThesisLiteratureAi.parsePlan(
      '{"topic":"Arabic novel discourse analysis","queries":["contemporary Arabic novel narrative discourse","narratology Arabic fiction"],"include":["discourse","novel"],"exclude":["chemical characteristics"]}',
      fallback: fallback,
    );
    expect(plan.topic.toLowerCase(), contains('novel'));
    expect(plan.queries.join(' ').toLowerCase(), isNot(contains('soybean')));
    expect(plan.includeTerms, contains('discourse'));

    expect(
      ThesisLiteratureAi.parseKeepIndexes(
        '{"keep":[1,3,99,"2"]}',
        maxIndex: 4,
      ),
      [1, 3, 2],
    );
    expect(
      ThesisLiteratureAi.parseKeepIndexes('{"keep":[]}', maxIndex: 5),
      isEmpty,
    );
  });

  test('empty skeleton has paragraph slots and no generated prose', () {
    final goal = ResearchGoalParser.parse(
      'ماجستير في الكيمياء التحليلية لتكرير الزيوت',
    );
    final draft = ThesisStudioAiService.buildSkeletonDraft(
      plan: ThesisPlan(
        goal: goal,
        kind: ThesisKind.experimental,
        shape: ThesisShape.arabicEmpirical,
        arabic: true,
      ),
    );
    expect(draft.hasGeneratedProse, isFalse);
    expect(draft.abstractText, isEmpty);
    expect(draft.literature.works, isEmpty);
    expect(draft.chapters, isNotEmpty);
    final intro = draft.chapters.firstWhere((c) => c.id == 'intro');
    expect(intro.paragraphs, hasLength(5));
    expect(intro.body, isEmpty);
    expect(intro.paragraphs.every((p) => p.isEmpty), isTrue);
    expect(intro.paragraphs.first.headingAr, contains('السياق'));
  });

  test('English draft skeleton title stays English', () {
    final goal = ResearchGoalParser.parse(
      'I want a master’s in analytical chemistry to improve edible-oil refining. I will compare HPLC and GC-MS.',
    );
    final draft = ThesisStudioAiService.buildSkeletonDraft(
      plan: ThesisPlan(
        goal: goal,
        kind: ThesisKind.experimental,
        shape: ThesisShape.englishExperimentalMerged,
        arabic: false,
      ),
    );
    expect(draft.arabic, isFalse);
    expect(draft.proposedTitle, contains("Master's"));
    expect(draft.proposedTitle.toLowerCase(), contains('laboratory'));
    expect(RegExp(r'[\u0600-\u06FF]').hasMatch(draft.proposedTitle), isFalse);
  });

  test('command spec reads page and word length from any field', () {
    final twenty = ThesisCommandSpec.parse(
      'مقدمة لا تقل عن 20 صفحة عن أي موضوع مع استشهادات',
      depth: ThesisChapterDepth.full,
    );
    expect(twenty.requestedPages, 20);
    expect(twenty.targetWords, 20 * ThesisLengthBudget.wordsPerPage);
    expect(twenty.hasExplicitLength, isTrue);

    final words = ThesisCommandSpec.parse(
      'Write at least 4000 words of historiography of the novel',
      depth: ThesisChapterDepth.full,
    );
    expect(words.requestedWords, 4000);
    expect(words.targetWords, 4000);

    final short = ThesisCommandSpec.parse(
      'Explain the research gap only',
      depth: ThesisChapterDepth.full,
    );
    expect(short.hasExplicitLength, isFalse);
    expect(short.targetWords, ThesisLengthBudget.paragraphWords(ThesisChapterDepth.full));

    final forty = ThesisCommandSpec.parse(
      'مقدمة 40 صفحة في أي تخصص',
      depth: ThesisChapterDepth.full,
    );
    expect(forty.requestedPages, 40);
    expect(forty.targetWords, 40 * ThesisLengthBudget.wordsPerPage);
    expect(
      ThesisLengthBudget.commandSourceLimit(twenty.targetWords),
      greaterThanOrEqualTo(40),
    );
  });

  test('APA in-text converts verified [n] to author-year', () {
    final goal = ResearchGoalParser.parse(
      'Master thesis in analytical chemistry HPLC edible oil refining',
    );
    final draft = ThesisStudioAiService.buildLocalDraft(
      goal: goal,
      literature: const GroundedReferenceBundle(
        topic: 'oil',
        works: [
          GroundedWork(
            title: 'HPLC of refined edible oils',
            doi: '10.1000/ag.test.oil',
            source: 'OpenAlex',
            year: 2021,
            authors: 'Smith, J.',
          ),
        ],
      ),
      plan: ThesisPlan(
        goal: goal,
        kind: ThesisKind.experimental,
        shape: ThesisShape.englishExperimentalMerged,
        arabic: false,
        citationStyle: PublishCitationStyle.apa,
      ),
    );
    final apa = ThesisStudioCitations.styledProse('See the method in [1].', draft);
    expect(apa, isNot(contains('[1]')));
    expect(apa, contains('2021'));
    final ieee = ThesisStudioCitations.styledProse(
      'See the method in [1].',
      draft.copyWith(
        plan: draft.plan.copyWith(citationStyle: PublishCitationStyle.ieee),
      ),
    );
    expect(ieee, contains('[1]'));
  });

  test('assembled chapter body uses only filled paragraphs', () {
    const paragraph = ThesisParagraph(
      id: 'intro_p0',
      headingAr: '1.1 السياق',
      headingEn: '1.1 Context',
      body: 'نص الفقرة الأولى [1].',
    );
    expect(
      ThesisChapter.assembleBody(const [
        paragraph,
        ThesisParagraph(
          id: 'intro_p1',
          headingAr: '1.2 مشكلة الدراسة',
          headingEn: '1.2 Research problem',
        ),
      ], true),
      '1.1 السياق\nنص الفقرة الأولى [1].',
    );
  });

  test('appendWorks keeps earlier citation order', () {
    const first = GroundedWork(
      title: 'First',
      doi: '10.1000/a',
      source: 'OpenAlex',
      year: 2020,
    );
    const second = GroundedWork(
      title: 'Second',
      doi: '10.1000/b',
      source: 'OpenAlex',
      year: 2021,
    );
    final merged = ThesisStudioEngine.appendWorks(
      const GroundedReferenceBundle(topic: 't', works: [first]),
      const [first, second],
    );
    expect(merged.works.map((w) => w.doi), ['10.1000/a', '10.1000/b']);
  });

  test('prose sanitizer drops markdown and latex leftovers', () {
    const raw = '''
### Botanical Origins
Historically used (*Brassica napus*) with \$2n = 20\$ AA.
##F leftover
''';
    final cleaned = ThesisStudioProse.sanitize(raw);
    expect(cleaned, contains('Botanical Origins'));
    expect(cleaned, contains('Brassica napus'));
    expect(cleaned, contains('2n = 20'));
    expect(cleaned, isNot(contains('*')));
    expect(cleaned, isNot(contains('###')));
    expect(cleaned, isNot(contains('##')));
    expect(cleaned, isNot(contains(r'$')));
    expect(ThesisStudioProse.isFallbackPartHeading('1.1 Context - part 1'), isTrue);
    expect(ThesisStudioProse.isFallbackPartHeading('Botanical origins'), isFalse);
  });

  test('paragraph command search prefers the named object not a broad field', () {
    final queries = ThesisLiteratureAi.queriesFromCommand(
      'Write 20 pages on botanical origins and domestication of Brassica napus',
    );
    expect(queries.join(' ').toLowerCase(), contains('brassica napus'));
    expect(queries.join(' ').toLowerCase(), isNot(contains('20 pages')));
    final terms = ThesisLiteratureAi.distinctiveTerms(
      ThesisCommandSpec.parse(
        'botanical origins domestication Brassica napus',
        depth: ThesisChapterDepth.full,
      ).topicText,
    );
    expect(terms.join(' '), contains('brassica napus'));
    expect(terms, isNot(contains('seeds')));
  });

  test('APA uses paragraph references when numbering is local', () {
    final goal = ResearchGoalParser.parse(
      'Master thesis in analytical chemistry HPLC edible oil refining',
    );
    final draft = ThesisStudioAiService.buildLocalDraft(
      goal: goal,
      literature: const GroundedReferenceBundle(
        topic: 'oil',
        works: [
          GroundedWork(
            title: 'Unrelated seed review',
            doi: '10.1000/ag.test.seed',
            source: 'OpenAlex',
            year: 2019,
            authors: 'Lee, A.',
          ),
        ],
      ),
      plan: ThesisPlan(
        goal: goal,
        kind: ThesisKind.experimental,
        shape: ThesisShape.englishExperimentalMerged,
        arabic: false,
        citationStyle: PublishCitationStyle.apa,
      ),
    );
    const paragraphWorks = [
      GroundedWork(
        title: 'Brassica napus domestication',
        doi: '10.1000/ag.test.napus',
        source: 'OpenAlex',
        year: 2021,
        authors: 'Smith, J.',
      ),
    ];
    final apa = ThesisStudioCitations.styledProse(
      'See the method in [1].',
      draft,
      works: paragraphWorks,
    );
    expect(apa, contains('2021'));
    expect(apa, isNot(contains('[1]')));
    expect(apa, isNot(contains('2019')));
  });

  test('ThesisDiscipline resolve prefers faculty and department overrides', () {
    final disc = ThesisDiscipline.resolve(
      facultyId: 'Science',
      departmentId: 'analytical_chem',
    );
    expect(disc.isPresent, isTrue);
    expect(disc.facultyId, 'Science');
    expect(disc.departmentId, 'analytical_chem');
    expect(disc.searchTerms, isNotEmpty);
    expect(disc.alienHints, isNotEmpty);
    expect(disc.promptBlock(false).toLowerCase(), contains('science'));

    final fromProfile = ThesisDiscipline.resolve(
      profile: const AcademicProfile(
        fullName: 'A',
        university: 'U',
        degree: 'ماجستير',
        facultyCategory: 'Agriculture',
        specialization: 'تربية نبات',
        researchInterest: 'محاصيل زيتية',
        methodology: 'كمي',
        preferredLanguage: 'العربية',
        city: '',
      ),
    );
    expect(fromProfile.facultyId, 'Agriculture');
    expect(fromProfile.isPresent, isTrue);
  });

  test('command seed never searches with Context heading alone', () {
    final goal = ResearchGoalParser.parse(
      'Master thesis on botanical domestication of Brassica napus oilseed',
    );
    final seed = ThesisStudioEngine.commandSeedForTest(
      command: '',
      heading: '1.1 Context',
      goal: goal,
    );
    expect(seed.toLowerCase(), isNot(contains('context')));
    expect(seed.toLowerCase(), contains('brassica'));
  });

  test('literature review slots follow thesis shape and longer default length', () {
    final goal = ResearchGoalParser.parse(
      'Master thesis in analytical chemistry HPLC edible oil refining',
    );
    final draft = ThesisStudioAiService.buildSkeletonDraft(
      plan: ThesisPlan(
        goal: goal,
        kind: ThesisKind.experimental,
        shape: ThesisShape.englishExperimentalMerged,
        arabic: false,
      ),
    );
    final lit = draft.chapters.firstWhere((c) => c.id == 'literature');
    expect(lit.paragraphs, hasLength(5));
    expect(lit.paragraphs.first.headingEn.toLowerCase(), contains('scope'));
    expect(lit.paragraphs.last.headingEn.toLowerCase(), contains('gap'));
    final spec = ThesisCommandSpec.parse(
      'Write the thematic synthesis',
      depth: ThesisChapterDepth.full,
      chapterId: 'literature',
    );
    expect(spec.targetWords, ThesisLengthBudget.literatureParagraphWords);
    expect(spec.hasExplicitLength, isFalse);
  });
}
