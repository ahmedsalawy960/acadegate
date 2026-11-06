import 'package:acadegate/features/acadegate_publish/citation_reading_advisor.dart';
import 'package:acadegate/features/acadegate_publish/citation_style_converter.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:flutter_test/flutter_test.dart';

PublishReference _ref({
  required String id,
  required String author,
  required String year,
  required String raw,
}) {
  return PublishReference(
    id: id,
    type: ReferenceType.journal,
    authors: [author],
    title: 'Work',
    year: year,
    rawText: raw,
  );
}

void main() {
  test('compound and author-year citations are numbered from the first paragraph', () {
    final ieee = CitationStyleConverter.apply(
      manuscript: PublishManuscript(
        userId: 'u',
        title: 'Rapeseed',
        bodyBlocks: const [
          ManuscriptBlock(
            id: 'p1',
            type: ManuscriptBlockType.paragraph,
            text:
                'The amount of oil (Daun et al., 2011). Its appeal [1,2,3,4]. '
                'The method outlined by Raghuram Ulu et al. (2003). '
                'Volatiles are distributed (Olabode and Arueva, 2016). '
                'Fig. [1] stays. ..........(34)',
          ),
        ],
        references: [
          _ref(
            id: 'ulu',
            author: 'Ulu, Raghuram',
            year: '2003',
            raw: 'Ulu, Raghuram (2003). Carbohydrate method.',
          ),
          _ref(
            id: 'olabode',
            author: 'Olabode, A.',
            year: '2016',
            raw: 'Olabode, A., & Arueva, G. (2016). Volatiles.',
          ),
          _ref(
            id: 'daun',
            author: 'Daun, J. K.',
            year: '2011',
            raw: 'Daun, J. K. (2011). Canola.',
          ),
        ],
        citationStyle: PublishCitationStyle.apa,
      ),
      style: PublishCitationStyle.ieee,
    );
    final body = ieee.bodyBlocks.first.text;
    expect(body, contains('oil [1]'));
    expect(body, contains('by [2]'));
    expect(body, contains('distributed [3]'));
    expect(body, isNot(contains('Daun et al')));
    expect(body, isNot(contains('Raghuram Ulu')));
    expect(body, isNot(contains('Olabode and Arueva')));
    expect(body, contains('Fig. [1]'));
    expect(body, contains('..........(34)'));
    expect(ieee.references.map((r) => r.id).take(3).toList(), [
      'daun',
      'ulu',
      'olabode',
    ]);
  });

  test('a gemini phrase is numbered when the local spelling does not match', () {
    const manuscript = PublishManuscript(
      userId: 'u',
      title: 'Volatiles',
      bodyBlocks: [
        ManuscriptBlock(
          id: 'p1',
          type: ManuscriptBlockType.paragraph,
          text: 'Seeds are distributed (Olabode and Arueva, 2016).',
        ),
        ManuscriptBlock(
          id: 'eq',
          type: ManuscriptBlockType.paragraph,
          text: '..........(12)',
        ),
      ],
      references: [
        PublishReference(
          id: 'arueya',
          type: ReferenceType.journal,
          authors: ['Arueya, G. L.'],
          title: 'Fruit volatiles',
          year: '2016',
          rawText: 'Arueya, G. L. (2016). Fruit volatiles.',
        ),
      ],
    );
    final marked = CitationReadingAdvisor.applyReadings(
      manuscript: manuscript,
      readings: const [
        CitationReading(
          blockIndex: 0,
          phrase: '(Olabode and Arueva, 2016)',
          referenceId: 'arueya',
        ),
        CitationReading(
          blockIndex: 1,
          phrase: '..........(12)',
          referenceId: 'arueya',
        ),
        CitationReading(
          blockIndex: 0,
          phrase: '(Nobody, 1999)',
          referenceId: 'missing',
        ),
      ],
    );
    expect(marked.marked, 1);
    expect(marked.manuscript.bodyBlocks.first.text, contains('{{cite:arueya}}'));
    expect(marked.manuscript.bodyBlocks[1].text, '..........(12)');

    final ieee = CitationStyleConverter.apply(
      manuscript: marked.manuscript,
      style: PublishCitationStyle.ieee,
    );
    expect(ieee.bodyBlocks.first.text, contains('[1]'));
    expect(ieee.bodyBlocks.first.text, isNot(contains('Arueva')));
    expect(ieee.bodyBlocks[1].text, '..........(12)');
    expect(ieee.references.first.id, 'arueya');
  });

  test('a cut-off citation reading still keeps the finished citations', () {
    final readings = CitationReadingAdvisor.parseReadings(
      '{"cites":[{"p":3,"phrase":"(Daun et al., 2011)","id":"daun"},'
      '{"p":8,"phrase":"Raghuram Ulu et al. (2003)","id":"ulu"}',
    );
    expect(readings.length, 2);
    expect(readings.first.phrase, '(Daun et al., 2011)');
    expect(readings[1].referenceId, 'ulu');
  });
}
