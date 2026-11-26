import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/citation_formatter.dart';
import 'package:acadegate/features/acadegate_publish/citation_style_converter.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';

Uint8List docx(List<String> paragraphs) {
  final body = paragraphs
      .map(
        (p) => '<w:p><w:r><w:t>${p.replaceAll('&', '&amp;')}</w:t></w:r></w:p>',
      )
      .join();
  final xml =
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>$body</w:body></w:document>';
  final a = Archive()
    ..addFile(
      ArchiveFile(
        'word/document.xml',
        utf8.encode(xml).length,
        utf8.encode(xml),
      ),
    );
  return Uint8List.fromList(ZipEncoder().encode(a));
}

void main() {
  test(
    'first genuine reference heading wins over table labels and supplement',
    () {
      const text =
          'A study\nIntroduction\nReference\nDataset size\nResults\nThe treatment changed the outcome.\nReferences\n[1]M. Author, "A sufficiently long scientific title", Journal, 2020.\n[2]B. Writer, "Another sufficiently long paper title", Journal, 2021.\nSupplementary Information\nReferences\n[1]Z. Other, "A different supplementary work", Journal, 2018.';
      final r = ManuscriptDocumentParser.parseReferencesFromText(text);
      expect(r.length, 2);
      expect(r.first.rawText, contains('M. Author'));
      expect(r.last.rawText, isNot(contains('Z. Other')));
    },
  );
  test('organization and title mentions are not extra works', () {
    const text =
        'Introduction\nEvidence (Foundation, 2017; IDF, 2017; WHO, 2010; Malawi, 2010; Washington, 1989).\nReferences\nInternational Diabetes Foundation. (2017). IDF DIABETES ATLAS. Brussels.\nMinistry of Health, & WHO. (2010). Malawi National STEPS Survey for Chronic Diseases.\nNational research council. (1989). Recommended Dietary Allowances. Washington DC. https://doi.org/10.17226/1349';
    final r = ManuscriptDocumentParser.parseReferencesFromText(text);
    expect(r.length, 3);
    expect(r[0].rawText, contains('IDF DIABETES ATLAS'));
    expect(r[1].rawText, contains('Malawi National'));
    expect(r[2].rawText, contains('Washington DC'));
  });
  test('compact year-end metadata keeps surname, title, venue and pages', () {
    final r = CitationFormatter.parseBibliographicLine(
      'Payne S, van Eijndhoven JHM. Cerebral hemodynamics: concepts of clinical importance. Arq Neuropsiquiatr 70: 357–365, 2012. doi: 10.1590/test.',
    )!;
    expect(r.authors, ['Payne S', 'van Eijndhoven JHM']);
    expect(r.title, 'Cerebral hemodynamics: concepts of clinical importance');
    expect(r.container, 'Arq Neuropsiquiatr');
    expect(r.pages, '357–365');
    expect(r.year, '2012');
  });
  test(
    'old block maps default to normal citations and scope survives round trip',
    () {
      final old = ManuscriptBlock.fromMap({
        'id': 'a',
        'type': 'paragraph',
        'text': 'Body [1]',
      });
      expect(old.preserveCitationText, false);
      final scoped = old.copyWith(preserveCitationText: true);
      expect(
        ManuscriptBlock.fromMap(
          scoped.toMap(),
        ).copyWith(text: 'changed').preserveCitationText,
        true,
      );
    },
  );
  test(
    'supplement list stays separate through import and both actual exports',
    () async {
      final bytes = docx([
        'A sufficiently long title',
        'Introduction',
        'Ordinary body evidence [1] remains connected to the main list.',
        'References',
        '1. Main A. The principal work used in this manuscript. Science 10: 20–30, 2020.',
        '2. Second B. Another principal work used in the study. Science 12: 40–50, 2021.',
        'Table 1',
        'Main study measurements follow here.',
        'Supplementary Information',
        'Independent supplementary methods and evidence follow here.',
        'References',
        '1. Extra C. An independent supplementary source. Science 8: 10–15, 2015.',
        '2. Other D. Another supplementary source. Science 9: 16–19, 2016.',
        'Supplementary Table 1',
        'Supplementary measurements follow here.',
      ]);
      final p = await ManuscriptDocumentParser.parseFile(
        bytes: bytes,
        filename: 'scope.docx',
      );
      expect(p.references.length, 2);
      expect(p.references.first.rawText, contains('Main A'));
      expect(
        p.bodyBlocks
            .where((b) => b.preserveCitationText && b.text.contains('Extra C'))
            .length,
        1,
      );
      expect(
        p.bodyBlocks
            .where((b) => b.text.contains('Supplementary measurements'))
            .single
            .preserveCitationText,
        false,
      );
      for (final style in [
        PublishCitationStyle.apa,
        PublishCitationStyle.ieee,
      ]) {
        final m = PublishManuscript(
          userId: 'test',
          title: 'Test title',
          references: p.references,
          bodyBlocks: p.bodyBlocks
              .map((b) => ManuscriptBlock.fromMap(b.toMap()))
              .toList(),
        );
        final converted = CitationStyleConverter.apply(
          manuscript: m,
          style: style,
        );
        expect(
          converted.bodyBlocks
              .where((b) => b.text.contains('Extra C'))
              .single
              .text,
          startsWith('1. Extra C.'),
        );
        final out = await ManuscriptDocxExportService.instance.buildDocx(
          manuscript: m,
          rules: JournalFormatRules.forStudentStyle(style),
        );
        final a = ZipDecoder().decodeBytes(out);
        final xml = utf8.decode(
          a.findFile('word/document.xml')!.content as List<int>,
        );
        expect(xml, contains('Extra C'));
        expect(xml, contains('independent supplementary source'));
        expect(xml, contains('Supplementary measurements'));
      }
    },
  );
}
