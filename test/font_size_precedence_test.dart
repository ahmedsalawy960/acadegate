import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/journal_guidelines_heuristic.dart';
import 'package:acadegate/features/acadegate_publish/journal_template_reader.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';

JournalFormatRules rules(
  Map<String, dynamic> fields, {
  JournalFormatRules? fallback,
}) => JournalFormatRules.fromExtracted(
  journalName: 'Independent journal',
  sourceUrl: 'https://example.invalid/guide',
  extracted: {'found': true, 'citationStyle': 'apa', ...fields},
  fallback: fallback,
);
Uint8List template(String text) {
  final a = Archive();
  void add(String n, String t) =>
      a.addFile(ArchiveFile(n, utf8.encode(t).length, utf8.encode(t)));
  add(
    'word/document.xml',
    '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>${XmlText(text).toXmlString()}</w:t></w:r></w:p></w:body></w:document>',
  );
  add(
    'word/styles.xml',
    '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:docDefaults><w:rPrDefault><w:rPr><w:sz w:val="20"/></w:rPr></w:rPrDefault></w:docDefaults></w:styles>',
  );
  return Uint8List.fromList(ZipEncoder().encode(a));
}

Future<XmlDocument> doc(
  JournalFormatRules r, {
  String author = 'Alice Baker ¹*, Brian Cole ² and Dana West ¹',
}) async {
  final m = PublishManuscript(
    userId: 'qa',
    title: 'Independent formatting study',
    bodyBlocks: [
      ManuscriptBlock(id: 'a', type: ManuscriptBlockType.heading, text: author),
      const ManuscriptBlock(
        id: 'h',
        type: ManuscriptBlockType.heading,
        text: 'INTRODUCTION',
      ),
      const ManuscriptBlock(
        id: 'p',
        type: ManuscriptBlockType.paragraph,
        text: 'Body observations remain unchanged.',
      ),
    ],
    references: const [
      PublishReference(
        id: 'r',
        type: ReferenceType.journal,
        authors: ['Baker, A.'],
        title: 'Independent source',
        year: '2021',
        rawText: 'Baker, A. (2021). Independent source. Science, 2, 3-4.',
      ),
    ],
  );
  final b = await ManuscriptDocxExportService.instance.buildDocx(
    manuscript: m,
    rules: r,
  );
  final dir = Platform.environment['QA_FONT_DIR'];
  if (dir != null) {
    await Directory(dir).create(recursive: true);
    await File(
      '$dir/${r.titleFontHalfPoints}-${r.headingFontHalfPoints}-${r.bodyFontHalfPoints}.docx',
    ).writeAsBytes(b);
  }
  return XmlDocument.parse(
    utf8.decode(
      ZipDecoder().decodeBytes(b).findFile('word/document.xml')!.content
          as List<int>,
    ),
  );
}

XmlElement paragraph(XmlDocument x, String text) => x
    .findAllElements('w:p')
    .firstWhere(
      (p) => p
          .findAllElements('w:t')
          .map((t) => t.innerText)
          .join()
          .contains(text),
    );
void sizes(XmlDocument x, String text, int half) {
  expect(
    paragraph(
      x,
      text,
    ).findAllElements('w:sz').map((e) => e.getAttribute('w:val')).toSet(),
    {half.toString()},
  );
}

void main() {
  test('missing sizes are independent14 12 11 defaults', () async {
    final r = rules({});
    expect(r.titleFontHalfPoints, 28);
    expect(r.headingFontHalfPoints, 24);
    expect(r.bodyFontHalfPoints, 22);
    final x = await doc(r);
    sizes(x, 'Independent formatting study', 28);
    sizes(x, 'INTRODUCTION', 24);
    sizes(x, 'Body observations', 22);
    sizes(x, 'Independent source', 20);
  });
  for (final n in [9, 10, 12, 13]) {
    test('body only$n does not invent title or heading sizes', () {
      final r = rules({'bodyFontSizePt': n});
      expect(r.bodyFontHalfPoints, n * 2);
      expect(r.titleFontHalfPoints, 28);
      expect(r.headingFontHalfPoints, 24);
    });
  }
  test('explicit individual sizes win in actual Word output', () async {
    final x = await doc(
      rules({
        'titleFontSizePt': 18,
        'headingFontSizePt': 15,
        'bodyFontSizePt': 12,
        'referenceFontSizePt': 9,
      }),
    );
    sizes(x, 'Independent formatting study', 36);
    sizes(x, 'INTRODUCTION', 30);
    sizes(x, 'Body observations', 24);
    sizes(x, 'Independent source', 18);
  });
  test('estimated publisher fallback does not overrule defaults', () {
    final r = rules(
      {},
      fallback: const JournalFormatRules(
        journalName: 'Estimate',
        citationStyle: PublishCitationStyle.apa,
        bodyFontHalfPoints: 30,
        titleFontHalfPoints: 40,
        headingFontHalfPoints: 34,
      ),
    );
    expect(r.bodyFontHalfPoints, 22);
    expect(r.titleFontHalfPoints, 28);
    expect(r.headingFontHalfPoints, 24);
  });
  test('prior extracted guide fills missing sizes, current values win', () {
    final prior = rules({
      'bodyFontSizePt': 13,
      'titleFontSizePt': 17,
      'headingFontSizePt': 15,
    });
    final r = rules({'titleFontSizePt': 18}, fallback: prior);
    expect(r.bodyFontHalfPoints, 26);
    expect(r.titleFontHalfPoints, 36);
    expect(r.headingFontHalfPoints, 30);
  });
  test('explicit guide wording wins over template style', () {
    final r = JournalTemplateReader.read(
      bytes: template(
        'Use APA references. The body text must use 12 pt Times New Roman. Title must use 16 pt. Headings must use 13 pt.',
      ),
      filename: 'guide.docx',
      journalName: 'Independent journal',
    )!.rules;
    expect(r.bodyFontHalfPoints, 24);
    expect(r.titleFontHalfPoints, 32);
    expect(r.headingFontHalfPoints, 26);
  });
  test('template-only extracted body size beats defaults', () {
    final r = JournalTemplateReader.read(
      bytes: template('Use APA references in this scientific manuscript.'),
      filename: 'guide.docx',
      journalName: 'Independent journal',
    )!.rules;
    expect(r.bodyFontHalfPoints, 20);
    expect(r.titleFontHalfPoints, 28);
    expect(r.headingFontHalfPoints, 24);
  });
  test('explicit source font sizes survive richer extraction disagreement', () {
    final h = JournalGuidelinesHeuristic.extract(
      'Use APA references. The body text must use 12 pt Times New Roman. Title must use 16 pt. Headings must use 13 pt.',
    )!;
    final r = rules(
      JournalGuidelinesHeuristic.merge(h, {
        'found': true,
        'bodyFontSizePt': 10,
        'titleFontSizePt': 20,
        'headingFontSizePt': 18,
      }),
    );
    expect(r.bodyFontHalfPoints, 24);
    expect(r.titleFontHalfPoints, 32);
    expect(r.headingFontHalfPoints, 26);
  });
  for (final text in [
    'Headings must use 13 pt font. Use APA references.',
    'References must use 9 pt font. Use APA citations.',
    'The title must use 18 pt font. Use APA references.',
  ]) {
    test('role-specific font never sets body $text', () {
      final h = JournalGuidelinesHeuristic.extract(text)!;
      expect(h['bodyFontSizePt'], isNull);
      expect(rules(h).bodyFontHalfPoints, 22);
    });
  }
  for (final name in [
    'Independent Journal',
    'IEEE Letters',
    'Bulletin of the Chemical Society of Ethiopia',
    'Elsevier Research',
    'Springer Science',
  ]) {
    test('publisher estimate is not a sourced size $name', () {
      final r = JournalFormatRulesService.instance.resolve(journalName: name);
      expect(r.bodyFontHalfPoints, 22);
      expect(r.titleFontHalfPoints, 28);
      expect(r.headingFontHalfPoints, 24);
    });
  }
  test('heading/reference wording cannot bleed sizes across sentences', () {
    final h = JournalGuidelinesHeuristic.extract(
      'Use APA references. Headings must be bold. Body text must use 11 pt font. References follow APA style.',
    )!;
    expect(h['headingFontSizePt'], isNull);
    expect(h['referenceFontSizePt'], isNull);
  });
  test('explicit override of extracted rules still wins after copy', () async {
    final r =
        rules({
          'titleFontSizePt': 18,
          'headingFontSizePt': 15,
          'bodyFontSizePt': 12,
        }).copyWith(
          titleFontHalfPoints: 40,
          headingFontHalfPoints: 32,
          bodyFontHalfPoints: 26,
          referenceFontHalfPoints: 24,
        );
    final x = await doc(r);
    sizes(x, 'Independent formatting study', 40);
    sizes(x, 'INTRODUCTION', 32);
    sizes(x, 'Body observations', 26);
    sizes(x, 'Independent source', 24);
  });
  test('author heading never consumes a section number', () async {
    final x = await doc(rules({}).copyWith(headingNumbered: true));
    expect(
      paragraph(
        x,
        'INTRODUCTION',
      ).findAllElements('w:t').map((e) => e.innerText).join(),
      startsWith('1'),
    );
  });
  for (final author in [
    'Alice Baker ¹*, Brian Cole ² and Dana West ¹',
    'Chemistry Department, Independent University, Cairo, Egypt',
    'Corresponding author: writer@example.invalid',
  ]) {
    test(
      'author/affiliation mistakenly tagged heading is normal centered body $author',
      () async {
        final x = await doc(rules({}), author: author);
        final p = paragraph(x, author);
        sizes(x, author, 22);
        expect(p.findAllElements('w:b'), isEmpty);
        expect(
          p.findAllElements('w:jc').single.getAttribute('w:val'),
          'center',
        );
      },
    );
  }
}
