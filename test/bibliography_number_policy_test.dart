import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:acadegate/features/acadegate_publish/bibliography_style_advisor.dart';
import 'package:acadegate/features/acadegate_publish/citation_formatter.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';

void main() {
  tearDown(() => BibliographyStyleAdvisor.requestLinesForTesting = null);
  for (final style in PublishCitationStyle.values) {
    for (final plain in [false, true]) {
      for (final sample in [
        '',
        'Baker, A.; Young, B. Sensor study. Science 2020, 4, 1-9.',
        '[9] A. Baker, Sensor study, 2020.',
        '9. Baker A. Sensor study. 2020.',
      ]) {
        test(
          'policy overrides sample: ${style.name} plain=$plain sample=$sample',
          () async {
            BibliographyStyleAdvisor.requestLinesForTesting = (sources) async =>
                [for (final source in sources) '[77] 88. $source'];
            const refs = [
              PublishReference(
                id: 'a',
                type: ReferenceType.journal,
                authors: ['Baker, A.', 'Young, B.'],
                title: 'Sensor study',
                year: '2020',
                rawText:
                    'Baker, A.; Young, B. Sensor study. Science 2020, 4, 1-9.',
              ),
            ];
            final lines = await BibliographyStyleAdvisor.restyle(
              references: refs,
              style: style,
              plainNumbers: plain,
              referenceExample: sample,
            );
            expect(lines, isNotNull);
            final numbered = [
              PublishCitationStyle.ieee,
              PublishCitationStyle.vancouver,
              PublishCitationStyle.acs,
            ].contains(style);
            final prefix = numbered
                ? (plain || style == PublishCitationStyle.acs ? '1. ' : '[1] ')
                : '';
            expect(lines!.single, '$prefix${refs.single.rawText}');
          },
        );
      }
    }
  }

  test('normalization keeps italics and indices beyond one digit', () {
    final result = CitationFormatter.applyListNumberPolicy(
      const BibliographyEntry([
        BibliographySpan('[4'),
        BibliographySpan('2] 7. '),
        BibliographySpan('Journal title', italic: true),
      ]),
      style: PublishCitationStyle.ieee,
      index: 12,
    );
    expect(result.plain, '[12] Journal title');
    expect(result.spans.last.italic, isTrue);
  });
  test('numeric titles and years are not list markers', () {
    for (final text in ['2020. A year in review', '3.14 in optics']) {
      expect(
        CitationFormatter.applyListNumberPolicy(
          BibliographyEntry([BibliographySpan(text)]),
          style: PublishCitationStyle.apa,
          index: 1,
        ).plain,
        text,
      );
    }
  });
  for (final variant in [
    'engineering',
    'chemistry',
    'author-year',
    'bilingual',
  ]) {
    for (final model in ['accepted', 'rejected', 'unavailable']) {
      test('actual Word round trip: $variant / $model', () async {
        final style = variant == 'author-year'
            ? PublishCitationStyle.apa
            : PublishCitationStyle.ieee;
        final plain = variant == 'chemistry';
        final parsed = await ManuscriptDocumentParser.parseFile(
          bytes: source(variant),
          filename: 'independent-$variant.docx',
        );
        expect(parsed.references.length, 2);
        final manuscript = PublishManuscript(
          userId: 'qa',
          title: 'Independent $variant paper',
          bodyBlocks: parsed.bodyBlocks,
          references: parsed.references,
        );
        BibliographyStyleAdvisor.requestLinesForTesting = (sources) async =>
            model == 'unavailable'
            ? null
            : [
                for (final line in sources)
                  model == 'rejected' ? 'Invalid invented source 1999' : line,
              ];
        final rules = JournalFormatRules.forStudentStyle(style).copyWith(
          referenceListPlainNumber: plain,
          referenceExample:
              'Baker, A.; Young, B. Sensor study. Science 2020, 4, 1-9.',
        );
        final bytes = await ManuscriptDocxExportService.instance.buildDocx(
          manuscript: manuscript,
          rules: rules,
        );
        final evidence = Platform.environment['QA_NUMBER_POLICY_DIR'];
        if (evidence != null && model == 'accepted') {
          File('$evidence/$variant.docx').writeAsBytesSync(bytes);
        }
        final zip = ZipDecoder().decodeBytes(bytes);
        final doc = XmlDocument.parse(
          utf8.decode(zip.findFile('word/document.xml')!.content as List<int>),
        );
        final paragraphs = doc
            .findAllElements('w:p')
            .map((p) => p.findAllElements('w:t').map((t) => t.innerText).join())
            .toList();
        final heading = paragraphs.indexWhere(
          (p) => p.toLowerCase() == 'references',
        );
        expect(heading, greaterThanOrEqualTo(0));
        final bibliography = paragraphs
            .sublist(heading + 1)
            .where((p) => p.trim().isNotEmpty)
            .toList();
        expect(bibliography.length, 2);
        for (var i = 0; i < bibliography.length; i++) {
          final marker = RegExp(
            r'^(?:\[\d+\]|\d+\.)\s*',
          ).firstMatch(bibliography[i]);
          if (style == PublishCitationStyle.apa) {
            expect(marker, isNull);
          } else {
            expect(
              marker?.group(0)?.trim(),
              plain ? '${i + 1}.' : '[${i + 1}]',
            );
          }
        }
        final all = paragraphs.join(' ');
        for (final anchor in [
          'Baker',
          'Young',
          'Cole',
          'Stone',
          'Measured signal',
          '2.5',
        ]) {
          expect(all, contains(anchor));
        }
        final bodyText = paragraphs.take(heading).join(' ');
        if (style != PublishCitationStyle.apa) {
          expect(bodyText, contains('[1,2]'));
        } else {
          expect(bodyText, contains('Baker & Young, 2020'));
          expect(bodyText, contains('Cole & Stone, 2021'));
        }
        expect(
          doc.findAllElements('m:t').map((e) => e.innerText).join(),
          contains('z = a + b'),
        );
        if (variant == 'engineering')
          expect(bodyText, contains('Equation (7)'));
        expect(doc.findAllElements('w:tbl').length, 1);
        expect(doc.findAllElements('m:oMath').length, 1);
        if (variant == 'bilingual') expect(all, contains('النص العلمي'));
      });
    }
  }
}

Uint8List source(String variant) {
  final cite = variant == 'engineering'
      ? '[1,2]'
      : variant == 'bilingual'
      ? '(Baker and Young, 2020), (Cole and Stone, 2021)'
      : '(Baker and Young, 2020; Cole and Stone, 2021)';
  final marker1 = variant == 'engineering' ? '[1] ' : '';
  final marker2 = variant == 'engineering' ? '[2] ' : '';
  final body =
      '<w:p><w:r><w:t>INTRODUCTION</w:t></w:r></w:p>'
      '<w:p><w:r><w:t>Measured signal $cite. ${variant == 'bilingual' ? 'النص العلمي' : 'Independent control prose'}.</w:t></w:r></w:p>'
      '<w:p><m:oMath><m:r><m:t>z = a + b</m:t></m:r></m:oMath></w:p>'
      '${variant == 'engineering' ? '<w:p><w:r><w:t>Equation (7)</w:t></w:r></w:p>' : ''}'
      '<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Measured signal</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>2.5</w:t></w:r></w:p></w:tc></w:tr></w:tbl>'
      '<w:p><w:r><w:t>REFERENCES</w:t></w:r></w:p>'
      '<w:p><w:r><w:t>${marker1}Baker, A., Young, B. (2020). Sensor study of measured signals. Science, 4, 1-9.</w:t></w:r></w:p>'
      '<w:p><w:r><w:t>${marker2}Cole, C., Stone, D. (2021). Independent optical measurements. Optics, 5, 10-18.</w:t></w:r></w:p>';
  final xml =
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"><w:body>$body</w:body></w:document>';
  final bytes = utf8.encode(xml);
  final zip = Archive()
    ..addFile(ArchiveFile('word/document.xml', bytes.length, bytes));
  return Uint8List.fromList(ZipEncoder().encode(zip));
}
