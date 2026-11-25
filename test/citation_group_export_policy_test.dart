import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:xml/xml.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/citation_style_converter.dart';
import 'package:acadegate/features/acadegate_publish/in_text_citation_converter.dart';
import 'package:acadegate/features/acadegate_publish/citation_reading_advisor.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';

const refs = [
  PublishReference(
    id: 'a',
    type: ReferenceType.journal,
    authors: ['Baker, A.', 'Young, B.'],
    title: 'Sensor measurements',
    year: '2020',
    rawText:
        'Baker, A., Young, B. (2020). Sensor measurements. Science, 4, 1-9.',
  ),
  PublishReference(
    id: 'b',
    type: ReferenceType.journal,
    authors: ['Cole, C.', 'Stone, D.'],
    title: 'Optical signals',
    year: '2021',
    rawText: 'Cole, C., Stone, D. (2021). Optical signals. Optics, 5, 10-18.',
  ),
  PublishReference(
    id: 'c',
    type: ReferenceType.journal,
    authors: ['De León, E.'],
    title: 'Independent method',
    year: '2022',
    rawText: 'De León, E. (2022). Independent method. Methods, 3, 19-25.',
  ),
];
PublishManuscript manuscript(String text) => PublishManuscript(
  userId: 'qa',
  title: 'Independent control',
  bodyBlocks: [
    ManuscriptBlock(id: 'p', type: ManuscriptBlockType.paragraph, text: text),
  ],
  references: refs,
);
void main() {
  for (final group in [
    '(Baker and Young, 2020; Cole and Stone, 2021)',
    '(Baker, A., Young, B., 2020, Cole, C., Stone, D., 2021)',
    '(Baker and Young 2020 and Cole and Stone 2021)',
  ]) {
    test('complete group survives conversion and export: $group', () async {
      final m = manuscript('Evidence $group supports the measurements.');
      final result = CitationStyleConverter.apply(
        manuscript: m,
        style: PublishCitationStyle.ieee,
      );
      expect(
        result.bodyBlocks.single.text,
        'Evidence [1,2] supports the measurements.',
      );
      expect(result.references.take(2).map((r) => r.id), ['a', 'b']);
      final bytes = await ManuscriptDocxExportService.instance.buildDocx(
        manuscript: m,
        rules: JournalFormatRules.forStudentStyle(PublishCitationStyle.ieee),
      );
      final xml = utf8.decode(
        ZipDecoder().decodeBytes(bytes).findFile('word/document.xml')!.content
            as List<int>,
      );
      for (final token in [
        '[1,2]',
        'Baker',
        'Young',
        'Cole',
        'Stone',
        'supports the measurements',
      ]) {
        expect(xml, contains(token));
      }
    });
  }
  for (final group in [
    '(Baker and Young 2020; Unknown 2021)',
    '(Unknown 2020, Cole and Stone 2021)',
    '(Baker and Young 2020 and Unknown 2021)',
  ]) {
    test(
      'partly unresolved group is atomic in both conversion paths: $group',
      () {
        final text = 'Evidence $group remains. Later (De León, 2022).';
        final out = CitationStyleConverter.apply(
          manuscript: manuscript(text),
          style: PublishCitationStyle.ieee,
        );
        expect(out.bodyBlocks.single.text, contains(group));
        expect(out.bodyBlocks.single.text, contains('Later [1]'));
        expect(
          InTextCitationConverter.applyNumberedCitations(
            text: text,
            references: refs,
            targetStyle: PublishCitationStyle.ieee,
          ),
          contains(group),
        );
      },
    );
  }
  for (final bad in [
    (phrase: 'aker and Young, 2020', id: 'a'),
    (phrase: '(Baker and Young, 2020)', id: 'b'),
    (phrase: '(Unknown, 2020)', id: 'a'),
    (phrase: '(Baker and Young, 2021)', id: 'a'),
    (phrase: '(Baker and Young, 2020; Cole and Stone, 2021)', id: 'a'),
  ]) {
    test(
      'model cannot replace fragment, wrong identity or multiple works: $bad',
      () {
        final text =
            'Evidence (Baker and Young, 2020; Cole and Stone, 2021). Unknown (Unknown, 2020). Wrong (Baker and Young, 2021).';
        final out = CitationReadingAdvisor.applyReadings(
          manuscript: manuscript(text),
          readings: [
            CitationReading(
              blockIndex: 0,
              phrase: bad.phrase,
              referenceId: bad.id,
            ),
          ],
        );
        expect(out.marked, 0);
        expect(out.manuscript.bodyBlocks.single.text, text);
      },
    );
  }
  test('valid model link with exact identity still works', () {
    final out = CitationReadingAdvisor.applyReadings(
      manuscript: manuscript('Evidence (Baker and Young, 2020).'),
      readings: const [
        CitationReading(
          blockIndex: 0,
          phrase: '(Baker and Young, 2020)',
          referenceId: 'a',
        ),
      ],
    );
    expect(out.marked, 1);
    expect(out.manuscript.bodyBlocks.single.text, 'Evidence {{cite:a}}.');
  });
  test('same surname/year ambiguity is not silently assigned', () {
    final m = manuscript('Evidence (Baker, 2020).').copyWith(
      references: [
        ...refs,
        const PublishReference(
          id: 'd',
          type: ReferenceType.journal,
          authors: ['Baker, Z.'],
          title: 'Different work',
          year: '2020',
        ),
      ],
    );
    expect(
      CitationStyleConverter.apply(
        manuscript: m,
        style: PublishCitationStyle.ieee,
      ).bodyBlocks.single.text,
      'Evidence (Baker, 2020).',
    );
  });
  for (final group in [
    '(Baker and Young, 2020; Cole and Stone, 2021)',
    '(Baker and Young, 2020, Cole and Stone, 2021)',
    '(Baker and Young, 2020 and Cole and Stone, 2021)',
  ]) {
    for (final style in [
      PublishCitationStyle.ieee,
      PublishCitationStyle.vancouver,
      PublishCitationStyle.apa,
    ]) {
      test(
        'independent Word fixture group=$group style=${style.name}',
        () async {
          final parsed = await ManuscriptDocumentParser.parseFile(
            bytes: wordSource(group),
            filename: 'group-variant.docx',
          );
          expect(parsed.references.length, 2);
          final m = PublishManuscript(
            userId: 'qa',
            title: 'Independent citation study',
            bodyBlocks: parsed.bodyBlocks,
            references: parsed.references,
          );
          final rules = JournalFormatRules.forStudentStyle(style).copyWith(
            referenceListPlainNumber: style == PublishCitationStyle.vancouver,
          );
          final bytes = await ManuscriptDocxExportService.instance.buildDocx(
            manuscript: m,
            rules: rules,
          );
          final doc = XmlDocument.parse(
            utf8.decode(
              ZipDecoder()
                      .decodeBytes(bytes)
                      .findFile('word/document.xml')!
                      .content
                  as List<int>,
            ),
          );
          final paragraphs = doc
              .findAllElements('w:p')
              .map(
                (p) => p.findAllElements('w:t').map((t) => t.innerText).join(),
              )
              .toList();
          final header = paragraphs.indexWhere(
            (p) => p.toLowerCase() == 'references',
          );
          final body = paragraphs.take(header).join(' ');
          expect(body, contains('Surrounding scientific prose'));
          expect(body, contains('Equation (7)'));
          if (style != PublishCitationStyle.apa) {
            expect(body, contains('[1,2]'));
            expect(body, contains('Later [1]'));
          } else {
            expect(body, contains('Baker'));
            expect(body, contains('Cole'));
          }
          final bibliography = paragraphs
              .skip(header + 1)
              .where((p) => p.isNotEmpty)
              .toList();
          expect(bibliography.length, 2);
          expect(bibliography[0], contains('Baker'));
          expect(bibliography[0], contains('Young'));
          expect(bibliography[1], contains('Cole'));
          expect(bibliography[1], contains('Stone'));
          expect(doc.findAllElements('w:tbl').length, 1);
          expect(doc.findAllElements('m:oMath').length, 1);
          expect(
            doc.findAllElements('m:t').map((e) => e.innerText).join(),
            'q = m × c',
          );
          final dir = Platform.environment['QA_GROUP_DIR'];
          if (dir != null) {
            File(
              '$dir/${style.name}-${group.contains(';')
                  ? 'semicolon'
                  : group.contains('2020 and')
                  ? 'and'
                  : 'comma'}.docx',
            ).writeAsBytesSync(bytes);
          }
        },
      );
    }
  }
  test('non-citation year prose inside parentheses stays intact', () {
    const text = 'Evidence (Baker measured samples in 2020) remains prose.';
    expect(
      CitationStyleConverter.apply(
        manuscript: manuscript(text),
        style: PublishCitationStyle.ieee,
      ).bodyBlocks.single.text,
      text,
    );
  });
  test('even a valid author suffix cannot erase the earlier author', () {
    final text = 'Evidence (Baker and Young, 2020).';
    final out = CitationReadingAdvisor.applyReadings(
      manuscript: manuscript(text),
      readings: const [
        CitationReading(blockIndex: 0, phrase: 'Young, 2020', referenceId: 'a'),
      ],
    );
    expect(out.marked, 0);
    expect(out.manuscript.bodyBlocks.single.text, text);
  });
  test('shared surname is resolved by coauthor rather than file order', () {
    final rows = [
      ...refs,
      const PublishReference(
        id: 'd',
        type: ReferenceType.journal,
        authors: ['Baker, Z.', 'West, Q.'],
        title: 'Different work',
        year: '2020',
      ),
    ];
    final m = manuscript(
      'Evidence (Baker and West, 2020).',
    ).copyWith(references: rows);
    final out = CitationStyleConverter.apply(
      manuscript: m,
      style: PublishCitationStyle.ieee,
    );
    expect(out.bodyBlocks.single.text, 'Evidence [1].');
    expect(out.references.first.id, 'd');
  });
  test('hyphenated and accented authors retain every group member', () {
    const rows = [
      PublishReference(
        id: 'h',
        type: ReferenceType.journal,
        authors: ['Smith-Jones, A.'],
        title: 'Hyphen work',
        year: '2018',
      ),
      PublishReference(
        id: 'l',
        type: ReferenceType.journal,
        authors: ['León, B.'],
        title: 'Accent work',
        year: '2019',
      ),
    ];
    final out = CitationStyleConverter.apply(
      manuscript: manuscript(
        'Evidence (Smith-Jones, 2018; León, 2019).',
      ).copyWith(references: rows),
      style: PublishCitationStyle.ieee,
    );
    expect(out.bodyBlocks.single.text, 'Evidence [1,2].');
    expect(out.references.map((r) => r.id), ['h', 'l']);
  });
  test('explicit year suffix disambiguates otherwise equal names', () {
    const rows = [
      PublishReference(
        id: 'x',
        type: ReferenceType.journal,
        authors: ['Baker, A.'],
        title: 'First work',
        year: '2020a',
      ),
      PublishReference(
        id: 'y',
        type: ReferenceType.journal,
        authors: ['Baker, A.'],
        title: 'Second work',
        year: '2020b',
      ),
    ];
    final out = CitationStyleConverter.apply(
      manuscript: manuscript(
        'Evidence (Baker, 2020b).',
      ).copyWith(references: rows),
      style: PublishCitationStyle.ieee,
    );
    expect(out.bodyBlocks.single.text, 'Evidence [1].');
    expect(out.references.first.id, 'y');
  });
  test('explicit numbered ambiguity remains bound to its printed item', () {
    final rows = [
      ...refs,
      const PublishReference(
        id: 'd',
        type: ReferenceType.journal,
        authors: ['Baker, Z.'],
        title: 'Different work',
        year: '2020',
      ),
    ];
    final out = CitationStyleConverter.apply(
      manuscript: manuscript('Evidence [4].').copyWith(references: rows),
      style: PublishCitationStyle.ieee,
    );
    expect(out.bodyBlocks.single.text, 'Evidence [1].');
    expect(out.references.first.id, 'd');
  });
  test('named coauthor mismatch is not a partial identity match', () {
    final text = 'Evidence (Baker and Wrong, 2020).';
    expect(
      CitationStyleConverter.apply(
        manuscript: manuscript(text),
        style: PublishCitationStyle.ieee,
      ).bodyBlocks.single.text,
      text,
    );
  });
  test('model cannot replace only the final narrative coauthor', () {
    final text = 'Baker and Young (2020) measured signals.';
    final out = CitationReadingAdvisor.applyReadings(
      manuscript: manuscript(text),
      readings: const [
        CitationReading(
          blockIndex: 0,
          phrase: 'Young (2020)',
          referenceId: 'a',
        ),
      ],
    );
    expect(out.marked, 0);
    expect(out.manuscript.bodyBlocks.single.text, text);
  });
  for (final group in [
    '(Baker and Wrong, 2020; Cole and Stone, 2021)',
    '(Baker and Young, 2020 and Unknown, 2021)',
  ]) {
    test('Word import retains an unresolved whole group: $group', () async {
      final parsed = await ManuscriptDocumentParser.parseFile(
        bytes: wordSource(group),
        filename: 'unresolved.docx',
      );
      final m = PublishManuscript(
        userId: 'qa',
        title: 'Unresolved control',
        bodyBlocks: parsed.bodyBlocks,
        references: parsed.references,
      );
      final out = CitationStyleConverter.apply(
        manuscript: m,
        style: PublishCitationStyle.ieee,
      );
      expect(out.bodyBlocks.map((b) => b.text).join(' '), contains(group));
    });
  }
  test('words and years not author cites survive', () {
    const text =
        'Measured 2020 samples in Table 1. Equation (7) and x = 2 remain.';
    expect(
      CitationStyleConverter.apply(
        manuscript: manuscript(text),
        style: PublishCitationStyle.ieee,
      ).bodyBlocks.single.text,
      text,
    );
  });
}

Uint8List wordSource(String group) {
  final content =
      '<w:p><w:r><w:t>INTRODUCTION</w:t></w:r></w:p>'
      '<w:p><w:r><w:t>Surrounding scientific prose $group. Later (Baker and Young, 2020).</w:t></w:r></w:p>'
      '<w:p><m:oMath><m:r><m:t>q = m × c</m:t></m:r></m:oMath></w:p>'
      '<w:p><w:r><w:t>Equation (7)</w:t></w:r></w:p>'
      '<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Control sample</w:t></w:r></w:p></w:tc></w:tr></w:tbl>'
      '<w:p><w:r><w:t>REFERENCES</w:t></w:r></w:p>'
      '<w:p><w:r><w:t>${refs[0].rawText}</w:t></w:r></w:p>'
      '<w:p><w:r><w:t>${refs[1].rawText}</w:t></w:r></w:p>';
  final xml =
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"><w:body>$content</w:body></w:document>';
  final bytes = utf8.encode(xml);
  final zip = Archive()
    ..addFile(ArchiveFile('word/document.xml', bytes.length, bytes));
  return Uint8List.fromList(ZipEncoder().encode(zip));
}
