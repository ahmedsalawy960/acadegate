import 'dart:convert';
import 'dart:io';

import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  test('DOCX stores UTF-8 byte sizes so Arabic and scientific symbols stay intact', () async {
    const marker = 'نهاية-التحقق';
    const body = 'درجة الحرارة 25° والحجم 5 μL في العينة العربية. $marker';
    final bytes = await ManuscriptDocxExportService.instance.buildDocx(
      manuscript: const PublishManuscript(
        userId: 'u',
        title: 'عنوان البحث °C',
        bodyBlocks: [
          ManuscriptBlock(
            id: 'p1',
            type: ManuscriptBlockType.paragraph,
            text: body,
          ),
        ],
      ),
      rules: JournalFormatRules.forStudentStyle(PublishCitationStyle.apa),
    );

    final archive = ZipDecoder().decodeBytes(bytes);
    final document = archive.findFile('word/document.xml');
    expect(document, isNotNull);
    final xmlBytes = document!.readBytes();
    expect(xmlBytes, isNotNull);
    expect(document.size, xmlBytes!.length);
    expect(document.size, greaterThan(utf8.decode(xmlBytes).length));

    final xml = utf8.decode(xmlBytes);
    final parsed = XmlDocument.parse(xml);
    expect(parsed.rootElement.name.local, 'document');
    expect(xml, contains('درجة الحرارة'));
    expect(xml, contains('25°'));
    expect(xml, contains('μL'));
    expect(xml, contains(marker));

    for (final entry in archive.files) {
      if (!entry.name.endsWith('.xml') && !entry.name.endsWith('.rels')) {
        continue;
      }
      final content = entry.readBytes();
      expect(content, isNotNull, reason: entry.name);
      expect(entry.size, content!.length, reason: entry.name);
      expect(
        () => utf8.decode(content),
        returnsNormally,
        reason: entry.name,
      );
    }
  });

  test('soybean manuscript keeps equipment, keywords, GC-MS, and discussion text', () async {
    final file = File('اختبار/soybean 2.docx');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'Place the original at اختبار/soybean 2.docx',
    );
    final parsed = await ManuscriptDocumentParser.parseFile(
      bytes: file.readAsBytesSync(),
      filename: 'soybean 2.docx',
    );
    final joined = parsed.bodyBlocks.map((block) {
      final rows = block.rows.map((row) => row.join(' ')).join('\n');
      return '${block.text}\n${block.caption ?? ''}\n$rows';
    }).join('\n');

    expect(joined, contains('Ultrasonic bath'));
    expect(joined, contains('MS Table'));
    expect(joined, contains('GCMS-QP2010'));
    expect(joined.toLowerCase(), contains('carbohydrate'));
    expect(joined, contains('QP-2010'));
    expect(joined.toLowerCase(), contains('discussion'));
    expect(parsed.references.length, greaterThan(20));

    final exported = await ManuscriptDocxExportService.instance.buildDocx(
      manuscript: PublishManuscript(
        userId: 'u',
        title: 'Soybean',
        bodyBlocks: parsed.bodyBlocks,
        references: parsed.references,
      ),
      rules: JournalFormatRules.forStudentStyle(PublishCitationStyle.apa),
    );
    final archive = ZipDecoder().decodeBytes(exported);
    final xml = utf8.decode(archive.findFile('word/document.xml')!.readBytes()!);
    XmlDocument.parse(xml);
    expect(xml, contains('Ultrasonic bath'));
    expect(xml, contains('MS Table'));
    expect(xml, contains('GCMS-QP2010'));
    expect(xml.toLowerCase(), contains('carbohydrate'));
    expect(xml, contains('QP-2010'));
  });
}
