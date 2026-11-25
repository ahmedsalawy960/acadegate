import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';

Uint8List source(int images) {
  String p(String t) => '<w:p><w:r><w:t>$t</w:t></w:r></w:p>';
  String row(List<String> cells) =>
      '<w:tr>${cells.map((t) => '<w:tc>${p(t)}</w:tc>').join()}</w:tr>';
  final xml =
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>${p('A general drawing inventory control')}${p('Introduction')}${p('The measured outcomes and every table cell must remain available.')}<w:tbl>${row(['Identifier', 'Structure', 'Drawing'])}${row(['Sample alpha', '', ''])}${row(['Sample beta', '', ''])}</w:tbl>${p('The final observation remains after the table.')}</w:body></w:document>';
  final a = Archive()
    ..addFile(
      ArchiveFile(
        'word/document.xml',
        utf8.encode(xml).length,
        utf8.encode(xml),
      ),
    );
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/lU8AAAAASUVORK5CYII=',
  );
  for (var i = 0; i < images; i++) {
    a.addFile(ArchiveFile('word/media/image$i.png', png.length, png));
  }
  return Uint8List.fromList(ZipEncoder().encode(a));
}

void main() {
  for (final n in [0, 1, 2]) {
    test(
      'drawing pool with$n unused image does not erase structured tables',
      () async {
        final p = await ManuscriptDocumentParser.parseFile(
          bytes: source(n),
          filename: 'input.docx',
        );
        final t = p.bodyBlocks
            .where((b) => b.type == ManuscriptBlockType.table)
            .single;
        expect(t.rows.expand((r) => r).join(' '), contains('Sample alpha'));
        expect(t.rows.expand((r) => r).join(' '), contains('Sample beta'));
        expect(
          p.bodyBlocks.map((b) => b.text).join(' '),
          contains('final observation'),
        );
        final filled = t.rowCellImages
            .expand((r) => r)
            .where((s) => s.isNotEmpty)
            .length;
        expect(
          filled,
          n,
        ); // Each available pool entry can fill one slot.
        final m = PublishManuscript(
          userId: 'test',
          title: 'Control',
          bodyBlocks: p.bodyBlocks,
        );
        final bytes = await ManuscriptDocxExportService.instance.buildDocx(
          manuscript: m,
          rules: JournalFormatRules.forStudentStyle(PublishCitationStyle.apa),
        );
        final a = ZipDecoder().decodeBytes(bytes);
        final x = XmlDocument.parse(
          utf8.decode(a.findFile('word/document.xml')!.content as List<int>),
        );
        expect(x.findAllElements('w:tbl').length, 1);
        expect(
          x.findAllElements('w:t').map((e) => e.innerText).join(' '),
          contains('Sample beta'),
        );
      },
    );
  }
}
