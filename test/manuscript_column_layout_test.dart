import 'dart:convert';

import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const manuscript = PublishManuscript(
    userId: 'u',
    title: 'Adsorption study',
    abstractText:
        'Short abstract about adsorption isotherms for this paper.',
    bodyBlocks: [
      ManuscriptBlock(
        id: 'h1',
        type: ManuscriptBlockType.heading,
        text: 'Introduction',
      ),
      ManuscriptBlock(
        id: 'p1',
        type: ManuscriptBlockType.paragraph,
        text:
            'Body text that must flow in two columns after the abstract.',
      ),
      ManuscriptBlock(
        id: 't1',
        type: ManuscriptBlockType.table,
        rows: [
          ['Metal ions', 'qmax', 'Kl', 'R2'],
          ['Pb(II)', '11.57', '0.032889', '0.998'],
        ],
      ),
      ManuscriptBlock(
        id: 'p2',
        type: ManuscriptBlockType.paragraph,
        text: 'Discussion continues in two columns after the wide table.',
      ),
    ],
  );

  Future<String> documentXml(JournalFormatRules rules) async {
    final bytes = await ManuscriptDocxExportService.instance.buildDocx(
      manuscript: manuscript,
      rules: rules,
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final document = archive.findFile('word/document.xml');
    expect(document, isNotNull);
    return utf8.decode(document!.readBytes()!);
  }

  test('two-column journal keeps body text in columns and the table full width',
      () async {
    final xml = await documentXml(
      JournalFormatRules.forStudentStyle(PublishCitationStyle.apa)
          .copyWith(columnCount: 2),
    );

    final columnCounts = RegExp(r'<w:cols w:num="(\d+)"')
        .allMatches(xml)
        .map((match) => int.parse(match.group(1)!))
        .toList();
    expect(columnCounts, [1, 2, 1, 2]);

    final bodyAt = xml.indexOf('Body text that must flow');
    final tableAt = xml.indexOf('0.032889');
    final afterAt = xml.indexOf('Discussion continues');
    expect(bodyAt, greaterThan(0));
    expect(tableAt, greaterThan(bodyAt));
    expect(afterAt, greaterThan(tableAt));

    final tableXml = xml.substring(tableAt - 800, tableAt + 200);
    expect(tableXml, contains('<w:noWrap/>'));
    expect(xml, contains('<w:tblW w:w="'));
    expect(xml, contains('w:type="dxa"'));
    expect(xml, isNot(contains('w:type="pct"')));
  });

  test('single-column journal does not insert a two-column section', () async {
    final xml = await documentXml(
      JournalFormatRules.forStudentStyle(PublishCitationStyle.apa),
    );
    final columnCounts = RegExp(r'<w:cols w:num="(\d+)"')
        .allMatches(xml)
        .map((match) => int.parse(match.group(1)!))
        .toList();
    expect(columnCounts, [1]);
    expect(xml, contains('0.032889'));
    expect(xml, contains('Metal ions'));
  });
}
