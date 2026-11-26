import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:acadegate/features/acadegate_publish/bibliography_cite_aligner.dart';

void main() {
  test('parenthesized numbers are printed identities, not years', () {
    expect(PublishReference.numberFromImportedLine('(17) Alpha A. Study'), 17);
    expect(PublishReference.numberFromImportedLine('(2017) Alpha A. Study'), isNull);
    expect(PublishReference.numberFromImportedLine('An ordinary (17) mention'), isNull);
  });
  for (final style in [PublishCitationStyle.apa, PublishCitationStyle.ieee]) {
    test('coherent printed bibliography keeps short web works $style', () async {
      final rows = [
        '(1) Organization. A report on crop treatment. Analytical Brief 2022.',
        '(2) Delta, A.; East, B. Independent agricultural measurements. Journal 2021, 4, 12-18.',
        '(3) Local supplier catalogue.',
        '(4) Another supplier. Product list.',
        '(5) Zeta, C. An independent final scientific study. Journal 2020, 2, 10-20.',
      ];
      final text = 'Independent scientific study\nIntroduction\nOrdinary evidence [1, 3, 5].\nReferences\n${rows.join('\n')}';
      final parsed = ManuscriptDocumentParser.parsePlainTextForTest(text);
      expect(parsed.references.map((r) => r.importedNumber), [1, 2, 3, 4, 5]);
      expect(parsed.references.map((r) => r.rawText), rows);
      final refs = parsed.references.map((r) => PublishReference.fromMap(r.toMap())).toList();
      final output = await ManuscriptDocxExportService.instance.buildDocx(
        manuscript: PublishManuscript(userId: 'qa', title: 'Independent study',
          references: refs, bodyBlocks: parsed.bodyBlocks, citationStyle: style),
        rules: JournalFormatRules.forStudentStyle(style),
      );
      final xml = utf8.decode(ZipDecoder().decodeBytes(output)
          .findFile('word/document.xml')!.content as List<int>);
      expect(xml, isNot(contains('[1] (1)')));
      expect(xml, isNot(contains('[3] (3)')));
      expect(xml, contains('supplier'));
      expect(xml, contains('catalogue'));
      expect(refs.last.importedNumber, 5);
    });
  }
  test('typographic digit variants do not create a second work', () {
    final refs = BibliographyCiteAligner.complete(
      bodyText: 'The standard is useful [1].',
      bibliographyText: '[1] X₃C Consortium and Technical Review Group. (2017). Independent validation vocabulary. Standards Recommendation.',
      parsed: [PublishReference(id: 'one', type: ReferenceType.journal,
        importedNumber: 1, title: 'Independent validation vocabulary',
        rawText: '[1] X3C Consortium and Technical Review Group. (2017). Independent validation vocabulary. Standards Recommendation.'),
        PublishReference(id: 'variant', type: ReferenceType.journal, importedNumber: 1,
          title: 'Independent validation vocabulary',
          rawText: '[1] X₃C Consortium and Technical Review Group. (2017). Independent validation vocabulary. Standards Recommendation.')],
    );
    expect(refs.length, 1);
  });
  test('different numbered works by the same organization remain distinct', () {
    final refs = ManuscriptDocumentParser.parseReferencesFromText(
      'Introduction\nIndependent evidence [1,2,3].\nReferences\n'
      '[1] X3C. (2017). First independent vocabulary. Standards Recommendation.\n'
      '[2] X3C. (2017). Second independent vocabulary. Standards Recommendation.\n'
      '[3] Delta, A. (2020). Third independent work. Journal.');
    expect(refs.length, 3);
    expect(refs.map((r) => r.importedNumber), [1, 2, 3]);
  });
}
