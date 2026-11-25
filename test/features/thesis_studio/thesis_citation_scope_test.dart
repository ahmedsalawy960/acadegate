import 'package:acadegate/features/ai_advisor/grounded_work.dart';
import 'package:acadegate/features/research_supply_chain/research_goal.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_citation_report.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_citations.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_kind.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// AI paragraphs number their OWN harvested references, and the abstract
/// numbers its own reference set. Exports and the citation report must
/// resolve `[n]` against that exact list, not the global literature list.
void main() {
  const adams = GroundedWork(
    title: 'Global list first paper',
    doi: '10.1000/scope.adams',
    source: 'OpenAlex',
    year: 2020,
    authors: 'Adams',
  );
  const bakr = GroundedWork(
    title: 'Global list second paper',
    doi: '10.1000/scope.bakr',
    source: 'OpenAlex',
    year: 2021,
    authors: 'Bakr',
  );
  const chen = GroundedWork(
    title: 'Global list third paper',
    doi: '10.1000/scope.chen',
    source: 'OpenAlex',
    year: 2022,
    authors: 'Chen',
  );

  final goal = ResearchGoalParser.parse(
    'Master thesis in analytical chemistry HPLC edible oil refining',
  );
  final plan = ThesisPlan(
    goal: goal,
    kind: ThesisKind.experimental,
    shape: ThesisShape.englishExperimentalMerged,
    arabic: false,
  );

  ThesisDraft draftWith({
    List<GroundedWork> literature = const [adams, bakr, chen],
    List<GroundedWork> abstractReferences = const [],
    String abstractText = '',
    List<ThesisChapter> chapters = const [],
  }) {
    return ThesisDraft(
      goal: goal,
      plan: plan,
      literature: GroundedReferenceBundle(topic: 'oil', works: literature),
      abstractReferences: abstractReferences,
      abstractText: abstractText,
      chapters: chapters,
    );
  }

  ThesisChapter chapterWithParagraph(
    List<GroundedWork> references,
    String body,
  ) {
    final paragraph = ThesisParagraph(
      id: 'intro_p0',
      headingAr: 'السياق',
      headingEn: 'Context',
      body: body,
      references: references,
    );
    return ThesisChapter(
      id: 'intro',
      titleAr: 'مقدمة',
      titleEn: 'Introduction',
      paragraphs: [paragraph],
      body: ThesisChapter.assembleBody([paragraph], false),
    );
  }

  group('citationListFor', () {
    test('paragraph with its own references cites that list', () {
      final draft = draftWith(
        chapters: [chapterWithParagraph(const [chen, adams], 'Body [1].')],
      );
      final list = ThesisStudioCitations.citationListFor(
        draft,
        paragraph: draft.chapters.first.paragraphs.first,
      );
      expect(list.map((w) => w.doi), ['10.1000/scope.chen', '10.1000/scope.adams']);
    });

    test('paragraph without references falls back to the global list', () {
      final draft = draftWith(
        chapters: [chapterWithParagraph(const [], 'Body [1].')],
      );
      final list = ThesisStudioCitations.citationListFor(
        draft,
        paragraph: draft.chapters.first.paragraphs.first,
      );
      expect(list.map((w) => w.doi), [
        '10.1000/scope.adams',
        '10.1000/scope.bakr',
        '10.1000/scope.chen',
      ]);
    });

    test('abstract with its own references cites that list', () {
      final draft = draftWith(abstractReferences: const [bakr]);
      final list = ThesisStudioCitations.citationListFor(
        draft,
        isAbstract: true,
      );
      expect(list.map((w) => w.doi), ['10.1000/scope.bakr']);
    });

    test('abstract without references falls back to the global list', () {
      final draft = draftWith();
      final list = ThesisStudioCitations.citationListFor(
        draft,
        isAbstract: true,
      );
      expect(list.first.doi, '10.1000/scope.adams');
    });
  });

  test('styledProse names the work the paragraph actually cited', () {
    final draft = draftWith(
      chapters: [
        chapterWithParagraph(
          const [chen, adams],
          'Finding one [1] and a second finding [2] in this long sentence.',
        ),
      ],
    );
    final paragraph = draft.chapters.first.paragraphs.first;
    final styled = ThesisStudioCitations.styledProse(
      paragraph.body,
      draft,
      works: ThesisStudioCitations.citationListFor(draft, paragraph: paragraph),
    );
    // [1] is Chen (the paragraph's first source), not Adams (global first).
    expect(styled, contains('Chen'));
    expect(styled, contains('Adams'));
    expect(styled, isNot(contains('Bakr')));
  });

  group('citation report with paragraph-local numbering', () {
    test('markers resolve to the cited work row in the global catalog', () {
      final draft = draftWith(
        chapters: [
          chapterWithParagraph(
            const [chen, adams],
            'A supported claim about the method [1] and another one [2] here.',
          ),
        ],
      );
      final report = ThesisCitationReport.fromDraft(draft);
      // Local [1] = Chen = global 3; local [2] = Adams = global 1.
      expect(report.usedIndexes, containsAll(<int>[1, 3]));
      expect(report.usedIndexes, isNot(contains(2)));
      expect(report.unusedIndexes, [2]);
      expect(report.unknownMarkers, isEmpty);
    });

    test('markers beyond the local list are unknown', () {
      final draft = draftWith(
        chapters: [
          chapterWithParagraph(
            const [chen],
            'A supported claim [1] and an unsupported marker [9] in text here.',
          ),
        ],
      );
      final report = ThesisCitationReport.fromDraft(draft);
      expect(report.usedIndexes, [3]);
      expect(report.unknownMarkers, contains('[9]'));
    });

    test('abstract markers resolve against abstract references', () {
      final draft = draftWith(
        abstractReferences: const [bakr],
        abstractText:
            'This abstract summarises the planned work and cites one study [1] only.',
      );
      final report = ThesisCitationReport.fromDraft(draft);
      expect(report.usedIndexes, [2]);
      expect(report.unusedIndexes, containsAll(<int>[1, 3]));
    });

    test('chapters without paragraphs still cite the global list', () {
      final draft = draftWith(
        chapters: const [
          ThesisChapter(
            id: 'intro',
            titleAr: 'مقدمة',
            titleEn: 'Introduction',
            body: 'A supported claim about the gap in prior work [2] stands.',
          ),
        ],
      );
      final report = ThesisCitationReport.fromDraft(draft);
      expect(report.usedIndexes, [2]);
    });
  });
}
