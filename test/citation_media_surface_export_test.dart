import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';

void main() {
  const ref = PublishReference(
    id: 'source',
    type: ReferenceType.journal,
    authors: ['Baker, A.'],
    title: 'Independent source',
    year: '2020',
  );
  for (final style in [PublishCitationStyle.apa, PublishCitationStyle.ieee]) {
    test(
      'citations resolve in captions, cells and missing-image captions: ${style.name}',
      () async {
        final m = PublishManuscript(
          userId: 'test',
          title: 'Surface control',
          references: const [ref],
          bodyBlocks: const [
            ManuscriptBlock(
              id: 'p',
              type: ManuscriptBlockType.paragraph,
              text: 'Body {{cite:source}}.',
            ),
            ManuscriptBlock(
              id: 't',
              type: ManuscriptBlockType.table,
              rows: [
                ['Heading', 'Value'],
                ['Cell {{cite:source}}', '{{ total_commits }}'],
              ],
              caption: 'Table1. Independent finding {{cite:source}}.',
            ),
            ManuscriptBlock(
              id: 'i',
              type: ManuscriptBlockType.image,
              caption: 'Figure1. Independent finding {{cite:source}}.',
            ),
          ],
        );
        final bytes = await ManuscriptDocxExportService.instance.buildDocx(
          manuscript: m,
          rules: JournalFormatRules.forStudentStyle(style),
        );
        final a = ZipDecoder().decodeBytes(bytes);
        final x = XmlDocument.parse(
          utf8.decode(a.findFile('word/document.xml')!.content as List<int>),
        );
        final text = x.findAllElements('w:t').map((e) => e.innerText).join(' ').replaceAll(RegExp(r'\s+'), ' ');
        expect(text, isNot(contains('{{cite:source}}')));
        expect(text, contains('{{ total_commits }}'));
        for (final lead in [
          'Body',
          'Cell',
          'Table1. Independent finding',
          'Figure1. Independent finding',
        ]) {
          expect(
            text,
            contains(
              '$lead ${style == PublishCitationStyle.apa ? '(Baker, 2020)' : '[1]'}',
            ),
          );
        }
      },
    );
  }
  test(
    'unknown citation identity and ordinary brace expressions are not silently deleted',
    () async {
      const m = PublishManuscript(
        userId: 'test',
        title: 'Literal preservation',
        bodyBlocks: [
          ManuscriptBlock(
            id: 't',
            type: ManuscriptBlockType.table,
            rows: [
              ['{{ total_commits }}', '{{cite:unknown}}'],
            ],
          ),
        ],
      );
      final bytes = await ManuscriptDocxExportService.instance.buildDocx(
        manuscript: m,
        rules: JournalFormatRules.forStudentStyle(PublishCitationStyle.apa),
      );
      final a = ZipDecoder().decodeBytes(bytes);
      final x = utf8.decode(
        a.findFile('word/document.xml')!.content as List<int>,
      );
      expect(x, contains('{{ total_commits }}'));
      expect(x, contains('{{cite:unknown}}'));
    },
  );
}
