import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';

String p(String t) => '<w:p><w:r><w:t>$t</w:t></w:r></w:p>';
String cell(String inner) => '<w:tc>$inner</w:tc>';
String grid22(String a) =>
    '<w:tbl><w:tblGrid><w:gridCol w:w="100"/><w:gridCol w:w="100"/></w:tblGrid><w:tr>${cell(p('$a head1'))}${cell(p('$a head2'))}</w:tr><w:tr>${cell(p('$a v1'))}${cell(p('$a v2'))}</w:tr></w:tbl>';

Future<List<ManuscriptBlock>> parse(String body) async {
  final s =
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>${p('Independent study of measured values')}$body</w:body></w:document>';
  final bytes = utf8.encode(s);
  final a = Archive()..addFile(ArchiveFile('word/document.xml', bytes.length, bytes));
  final r = await ManuscriptDocumentParser.parseFile(
      bytes: Uint8List.fromList(ZipEncoder().encode(a)), filename: 't.docx', allowCloud: false);
  return r.bodyBlocks.map((b) => ManuscriptBlock.fromMap(b.toMap())).toList();
}

void main() {
  test('single-cell wrapper around one nested table yields the inner grid', () async {
    final blocks = await parse('<w:tbl><w:tr>${cell(grid22('A'))}</w:tr></w:tbl>');
    final tables = blocks.where((b) => b.type == ManuscriptBlockType.table).toList();
    expect(tables.length, 1);
    expect(tables.first.rows.length, 2);
    expect(tables.first.rows.first.length, 2);
    expect(tables.first.rows.first.join(' '), contains('head1'));
  });
  test('wrapper with real text beside the nested table is not unwrapped', () async {
    final blocks = await parse('<w:tbl><w:tr>${cell('${p('A visible caption sentence about values.')}${grid22('B')}')}</w:tr></w:tbl>');
    final tables = blocks.where((b) => b.type == ManuscriptBlockType.table).toList();
    expect(tables.length, 1);
    expect(tables.first.rows.first.join(' '), contains('A visible caption sentence'));
  });
  test('two captioned same-width tables keep their boundary and captions', () async {
    final blocks = await parse('${p('Table 1. First measured set.')}${grid22('C')}${p('Table 2. Second measured set.')}${grid22('D')}');
    final tables = blocks.where((b) => b.type == ManuscriptBlockType.table).toList();
    expect(tables.length, 2);
    expect(tables.first.caption, contains('First measured set'));
    expect(tables.last.caption, contains('Second measured set'));
    expect(tables.first.rows.length, 2);
    expect(tables.last.rows.length, 2);
  });
  test('uncaptioned continuation fragments of one table still merge', () async {
    final blocks = await parse('${p('Table 1. Split measured set.')}${grid22('E')}${grid22('E')}');
    final tables = blocks.where((b) => b.type == ManuscriptBlockType.table).toList();
    expect(tables.length, 1);
    expect(tables.first.rows.length, 3);
  });
}
