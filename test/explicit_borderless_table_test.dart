import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';

String borders(String v) =>
    '<w:tblBorders>${['top', 'left', 'bottom', 'right', 'insideH', 'insideV'].map((n) => '<w:$n w:val="$v"/>').join()}</w:tblBorders>';
Future<ManuscriptBlock> parsed(String b, {String cell = ''}) async {
  final s =
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Independent study of scientific measurements</w:t></w:r></w:p><w:p><w:r><w:t>Introduction</w:t></w:r></w:p><w:tbl><w:tblPr>$b</w:tblPr><w:tr><w:tc>$cell<w:p><w:r><w:t>Independent measured values remain editable</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>';
  final bytes = utf8.encode(s);
  final a = Archive()
    ..addFile(ArchiveFile('word/document.xml', bytes.length, bytes));
  final p = await ManuscriptDocumentParser.parseFile(
    bytes: Uint8List.fromList(ZipEncoder().encode(a)),
    filename: 'table.docx',
    allowCloud: false,
  );
  return ManuscriptBlock.fromMap(
    p.bodyBlocks.firstWhere((b) => b.type == ManuscriptBlockType.table).toMap(),
  );
}

void main() {
  test(
    'only explicit six-edge no-border tables are retained borderless',
    () async {
      expect((await parsed(borders('none'))).borderless, isTrue);
      expect((await parsed(borders('nil'))).borderless, isTrue);
      expect((await parsed('')).borderless, isFalse);
      expect((await parsed(borders('single'))).borderless, isFalse);
      expect(
        (await parsed(
          '<w:tblBorders><w:top w:val="none"/></w:tblBorders>',
        )).borderless,
        isFalse,
      );
    },
  );
  test('visible cell border prevents no-border inference', () async {
    expect(
      (await parsed(
        borders('none'),
        cell:
            '<w:tcPr><w:tcBorders><w:bottom w:val="single"/></w:tcBorders></w:tcPr>',
      )).borderless,
      isFalse,
    );
  });
  test(
    'explicit no-border table survives export without invented rules',
    () async {
      final b = await parsed(borders('none'));
      for (final style in [
        PublishCitationStyle.apa,
        PublishCitationStyle.ieee,
      ]) {
        final out = await ManuscriptDocxExportService.instance.buildDocx(
          manuscript: PublishManuscript(
            userId: 'test',
            title: 'Independent measurements',
            bodyBlocks: [b],
          ),
          rules: JournalFormatRules.forStudentStyle(style),
        );
        final x = XmlDocument.parse(
          utf8.decode(
            ZipDecoder().decodeBytes(out).findFile('word/document.xml')!.content
                as List<int>,
          ),
        );
        final edges = x.descendants
            .whereType<XmlElement>()
            .firstWhere((e) => e.localName == 'tblBorders')
            .children
            .whereType<XmlElement>();
        expect(edges.length, 6);
        expect(edges.every((e) => e.getAttribute('w:val') == 'nil'), isTrue);
      }
    },
  );
}
