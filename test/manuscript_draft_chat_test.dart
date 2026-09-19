import 'package:acadegate/features/acadegate_publish/manuscript_draft_chat_service.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_draft_index.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:flutter_test/flutter_test.dart';

PublishManuscript _paper({
  String abstractText = '',
  List<ManuscriptBlock> blocks = const [],
}) {
  return PublishManuscript(
    userId: 'u1',
    title: 'Adsorption of heavy metals on biochar',
    abstractText: abstractText,
    bodyBlocks: blocks,
  );
}

ManuscriptBlock _h(String id, String text) => ManuscriptBlock(
      id: id,
      type: ManuscriptBlockType.heading,
      text: text,
    );

ManuscriptBlock _p(String id, String text) => ManuscriptBlock(
      id: id,
      type: ManuscriptBlockType.paragraph,
      text: text,
    );

ManuscriptBlock _table({
  required String id,
  required String caption,
  required List<List<String>> rows,
}) {
  return ManuscriptBlock(
    id: id,
    type: ManuscriptBlockType.table,
    caption: caption,
    rows: rows,
  );
}

void main() {
  test('indexes Table 3 from Arabic جدول ٣ caption', () {
    final m = _paper(
      blocks: [
        _h('h1', 'Results'),
        _p('p1', 'Yield increased after treatment.'),
        _table(
          id: 't1',
          caption: 'Table 1. Controls.',
          rows: [
            ['A', 'B'],
            ['1', '2'],
          ],
        ),
        _table(
          id: 't3',
          caption: 'جدول ٣. خصائص العينة',
          rows: [
            ['pH', 'yield'],
            ['7.2', '85%'],
          ],
        ),
      ],
    );
    final index = ManuscriptDraftIndex.fromManuscript(m);
    expect(index.tables.length, 2);
    expect(index.tableByNumber(3)?.caption, contains('خصائص'));
    expect(index.tableByNumber(1)?.caption, contains('Controls'));
    expect(index.resultsSection, isNotNull);
  });

  test('Table 3 lookup quotes location and does not invent a missing table', () async {
    final m = _paper(
      blocks: [
        _h('h1', 'Results'),
        _table(
          id: 't1',
          caption: 'Table 1. Blank.',
          rows: [
            ['x'],
            ['1'],
          ],
        ),
        _table(
          id: 't3',
          caption: 'Table 3. Physicochemical properties of the adsorbent.',
          rows: [
            ['Ash', 'pH'],
            ['12.4', '8.1'],
          ],
        ),
      ],
    );

    final found = await ManuscriptDraftChatService.instance.ask(
      manuscript: m,
      question: 'Where is Table 3?',
      allowCloud: false,
    );
    expect(found.text.toLowerCase(), contains('table 3'));
    expect(found.text.toLowerCase(), contains('physicochemical'));
    expect(found.hits, isNotEmpty);
    expect(found.hits.first.number, 3);
    expect(found.text.toLowerCase(), isNot(contains('smith')));

    final missing = await ManuscriptDraftChatService.instance.ask(
      manuscript: m,
      question: 'أين جدول 9؟',
      allowCloud: false,
    );
    expect(missing.text, contains('9'));
    expect(
      missing.text.contains('غير موجود') ||
          missing.text.toLowerCase().contains('not labeled'),
      isTrue,
    );
    expect(
      missing.text.contains('Table 1') || missing.text.contains('جدول 1'),
      isTrue,
    );
    expect(
      missing.text.contains('Table 3') || missing.text.contains('جدول 3'),
      isTrue,
    );
  });

  test('abstract vs results reports matching and missing numbers from this file', () async {
    final m = _paper(
      abstractText:
          'The adsorbent removed 85% of Pb(II) at pH 6. Removal was significant (p = 0.03). '
          'Capacity reached 120 mg/g. An unstated 99% dye removal is claimed here only.',
      blocks: [
        _h('r', 'Results'),
        _p(
          'rp',
          'Batch tests showed 85% Pb(II) removal. The difference was significant at p = 0.03. '
              'The Langmuir capacity was 120 mg/g. Table 3 lists ash and pH.',
        ),
        _table(
          id: 't3',
          caption: 'Table 3. Physicochemical properties',
          rows: [
            ['Ash %', 'pH'],
            ['12', '8.1'],
          ],
        ),
      ],
    );

    final reply = await ManuscriptDraftChatService.instance.ask(
      manuscript: m,
      question: 'هل الملخص يطابق النتائج؟',
      allowCloud: false,
    );
    expect(reply.kind, DraftQuestionKind.abstractVsResults);
    expect(reply.text, contains('85%'));
    expect(reply.text, contains('99%'));
    expect(
      reply.text,
      anyOf(contains('لم تظهر'), contains('not found')),
    );
    expect(reply.hits.any((h) => h.number == 3), isTrue);
  });

  test('detects draft questions without stealing generic citation requests', () {
    expect(
      ManuscriptDraftChatService.looksLikeDraftQuestion(
        'هل الملخص يطابق النتائج؟',
      ),
      isTrue,
    );
    expect(
      ManuscriptDraftChatService.looksLikeDraftQuestion('أين جدول 3؟'),
      isTrue,
    );
    expect(
      ManuscriptDraftChatService.looksLikeDraftQuestion(
        'أعطني مراجع عن adsorption of heavy metals',
      ),
      isFalse,
    );
  });

  test('numeric claims match 85.0% to 85% in the results', () {
    final claims = ManuscriptDraftChatService.extractNumericClaims(
      'Removal was 85.0% and p = 0.03 with 120 mg/g.',
    );
    expect(claims.any((c) => c.contains('85')), isTrue);
    expect(
      ManuscriptDraftChatService.claimAppearsIn('85.0%', 'the yield was 85% today'),
      isTrue,
    );
    expect(
      ManuscriptDraftChatService.claimAppearsIn('99%', 'the yield was 85% today'),
      isFalse,
    );
  });
}
