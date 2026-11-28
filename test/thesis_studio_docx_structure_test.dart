import 'package:acadegate/features/ai_advisor/grounded_work.dart';
import 'package:acadegate/features/research_supply_chain/research_goal.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_docx_export.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_kind.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_models.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

ThesisDraft _draft({required bool arabic, required List<ThesisChapter> chapters}) {
  final goal = ResearchGoal(raw: 'Improving dye removal', field: 'chemistry');
  return ThesisDraft(
    goal: goal,
    plan: ThesisPlan(
      goal: goal,
      kind: ThesisKind.experimental,
      shape: ThesisShape.englishExperimentalMerged,
      arabic: arabic,
    ),
    literature: const GroundedReferenceBundle(topic: ''),
    proposedTitle: 'Dye removal study',
    abstractText: 'Short abstract.',
    chapters: chapters,
  );
}

String _part(List<int> bytes, String name) {
  final f = ZipDecoder().decodeBytes(bytes).findFile(name)!;
  return String.fromCharCodes(f.content as List<int>);
}

void main() {
  test('chapter titles are renumbered by position in one style', () {
    String n(String t, int i, {bool ar = false}) =>
        ThesisStudioDocxExport.numberedChapterTitle(t, i, arabic: ar);
    expect(n('Chapter 3: Methods', 2), 'Chapter 2: Methods');
    expect(n('Methods', 3), 'Chapter 3: Methods');
    expect(n('Chapter Two - Methods', 2), 'Chapter 2: Methods');
    expect(n('الفصل الثالث: المنهجية', 2, ar: true), 'الفصل الثاني: المنهجية');
    expect(n('المنهجية', 1, ar: true), 'الفصل الأول: المنهجية');
    // A title that merely starts with the word is kept whole.
    expect(n('Chapter structure in theses', 1), 'Chapter 1: Chapter structure in theses');
  });

  test('docx uses real Word heading styles and sequential chapters', () {
    final draft = _draft(arabic: false, chapters: const [
      ThesisChapter(
        id: 'intro',
        titleAr: 'الفصل الأول: مقدمة',
        titleEn: 'Introduction',
        body: '',
        paragraphs: [
          ThesisParagraph(
            id: 'p1',
            headingAr: 'خلفية',
            headingEn: 'Background',
            body: 'Body text one.',
          ),
        ],
      ),
      ThesisChapter(
        id: 'methods',
        titleAr: 'الفصل الخامس: المنهجية',
        titleEn: 'Chapter 5: Methods',
        body: 'Methods body.',
      ),
    ]);
    final bytes = ThesisStudioDocxExport.instance.build(draft);
    final doc = _part(bytes, 'word/document.xml');
    final styles = _part(bytes, 'word/styles.xml');
    expect(doc, contains('w:val="Title"'));
    expect(doc, contains('w:val="Heading1"'));
    expect(doc, contains('w:val="Heading2"'));
    expect(doc, contains('Chapter 1: Introduction'));
    expect(doc, contains('Chapter 2: Methods'));
    expect(doc, isNot(contains('Chapter 5')));
    for (final id in ['Title', 'Heading1', 'Heading2']) {
      expect(styles, contains('w:styleId="$id"'));
    }
  });
}
