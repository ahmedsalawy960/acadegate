import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';

const frac =
    '<m:oMath><m:f><m:num><m:r><m:t>x</m:t></m:r></m:num><m:den><m:r><m:t>y</m:t></m:r></m:den></m:f></m:oMath>';
const cell =
    '<w:p><w:r><w:t>Rate </w:t></w:r>$frac<w:r><w:t> units</w:t></w:r></w:p><w:p><m:oMathPara>$frac</m:oMathPara></w:p>';
Uint8List source(String tables) {
  final a = Archive();
  final s =
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"><w:body><w:p><w:r><w:t>Native table math preservation study</w:t></w:r></w:p><w:p><w:r><w:t>Introduction</w:t></w:r></w:p><w:p><w:r><w:t>This manuscript contains native equations inside editable table cells.</w:t></w:r></w:p>$tables<w:sectPr/></w:body></w:document>';
  final b = utf8.encode(s);
  a.addFile(ArchiveFile('word/document.xml', b.length, b));
  return Uint8List.fromList(ZipEncoder().encode(a));
}

String table(String body) =>
    '<w:tbl><w:tblGrid><w:gridCol w:w="5000"/><w:gridCol w:w="2000"/></w:tblGrid>$body</w:tbl>';
String row(String math, {String props = ''}) =>
    '<w:tr><w:tc>$props$math</w:tc><w:tc><w:p><w:r><w:t>Marker</w:t></w:r></w:p></w:tc></w:tr>';
Future<List<ManuscriptBlock>> parse(Uint8List bytes) async {
  final p = await ManuscriptDocumentParser.parseFile(
    bytes: bytes,
    filename: 'fixture.docx',
    allowCloud: false,
  );
  final m = await ManuscriptDocumentParser.applyParseResult(
    manuscript: const PublishManuscript(
      userId: 'test',
      title: 'Native table math preservation study',
    ),
    parsed: p,
    replaceBody: true,
    replaceReferences: true,
  );
  return m.bodyBlocks.map((b) => ManuscriptBlock.fromMap(b.toMap())).toList();
}

Future<XmlDocument> export(
  List<ManuscriptBlock> blocks,
  PublishCitationStyle style,
) async {
  final b = await ManuscriptDocxExportService.instance.buildDocx(
    manuscript: PublishManuscript(
      userId: 'test',
      title: 'Native table math preservation study',
      bodyBlocks: blocks,
      citationStyle: style,
    ),
    rules: JournalFormatRules.forStudentStyle(style),
  );
  final a = ZipDecoder().decodeBytes(b);
  for (final f in a.files.where(
    (f) => f.name.endsWith('.xml') || f.name.endsWith('.rels'),
  )) {
    XmlDocument.parse(utf8.decode(f.content as List<int>));
  }
  return XmlDocument.parse(
    utf8.decode(a.findFile('word/document.xml')!.content as List<int>),
  );
}

int mathCount(XmlDocument x) => x.descendants
    .whereType<XmlElement>()
    .where((e) => e.localName == 'oMath')
    .length;
void main() {
  test(
    'mixed text, fractions and multiple paragraphs survive map roundtrip and both exports',
    () async {
      final blocks = await parse(source(table(row(cell))));
      final t = blocks.firstWhere((b) => b.type == ManuscriptBlockType.table);
      expect(t.rowCellMath.first.first, contains('snapshot'));
      for (final style in [
        PublishCitationStyle.apa,
        PublishCitationStyle.ieee,
      ]) {
        final x = await export(blocks, style);
        expect(mathCount(x), 2);
        final tc = x.descendants.whereType<XmlElement>().firstWhere(
          (e) => e.localName == 'tc',
        );
        expect(tc.innerText, contains('Rate xy units'));
        expect(
          tc.descendants
              .whereType<XmlElement>()
              .where((e) => e.localName == 'f')
              .length,
          2,
        );
        expect(
          tc.descendants
              .whereType<XmlElement>()
              .where((e) => e.localName == 'spacing')
              .every((e) => e.getAttribute('w:lineRule') == 'atLeast'),
          isTrue,
        );
      }
    },
  );
  test(
    'editing cell text prevents stale native content from being exported',
    () async {
      var blocks = await parse(source(table(row(cell))));
      blocks = blocks
          .map(
            (b) => b.type != ManuscriptBlockType.table
                ? b
                : b.copyWith(
                    rows: [
                      ['Edited result', 'Marker'],
                    ],
                  ),
          )
          .toList();
      final x = await export(blocks, PublishCitationStyle.apa);
      expect(mathCount(x), 0);
      expect(x.rootElement.innerText, contains('Edited result'));
    },
  );
  test('legacy grid without native fragments exports plain text', () async {
    final x = await export([
      const ManuscriptBlock(
        id: 't',
        type: ManuscriptBlockType.table,
        rows: [
          ['Rate x/y', 'Marker'],
        ],
      ),
    ], PublishCitationStyle.apa);
    expect(mathCount(x), 0);
    expect(x.rootElement.innerText, contains('Rate x/y'));
  });
  test(
    'column spans and vertical continuation do not duplicate equations',
    () async {
      final merged =
          '<w:tr><w:tc><w:tcPr><w:gridSpan w:val="2"/><w:vMerge w:val="restart"/></w:tcPr>$cell</w:tc></w:tr><w:tr><w:tc><w:tcPr><w:gridSpan w:val="2"/><w:vMerge/></w:tcPr><w:p/></w:tc></w:tr>';
      final b = await parse(source(table(merged)));
      final x = await export(b, PublishCitationStyle.ieee);
      expect(mathCount(x), 2);
      expect(
        x.descendants
            .whereType<XmlElement>()
            .where((e) => e.localName == 'gridSpan')
            .length,
        2,
      );
    },
  );
  test(
    'nested table math is retained once in flattened editable cell',
    () async {
      final b = await parse(source(table(row(table(row(cell))))));
      final x = await export(b, PublishCitationStyle.apa);
      expect(mathCount(x), 2);
    },
  );
  test(
    'hyperlink text remains visible without relationships or field instructions',
    () async {
      final part =
          '<w:p><w:hyperlink><w:r><w:t>Before </w:t></w:r></w:hyperlink>$frac<w:r><w:instrText>DO NOT RETAIN</w:instrText></w:r><w:fldSimple w:instr="DATE"><w:r><w:t> After</w:t></w:r></w:fldSimple></w:p>';
      final b = await parse(source(table(row(part))));
      final x = await export(b, PublishCitationStyle.apa);
      expect(mathCount(x), 1);
      expect(x.rootElement.innerText, contains('Before xy After'));
      expect(x.toXmlString(), isNot(contains('DO NOT RETAIN')));
      expect(x.toXmlString(), isNot(contains('fldSimple')));
    },
  );
  test('ancestor namespace bindings inside native math remain valid', () async {
    final native = cell.replaceFirst(
      '<m:r>',
      '<m:r><w:rPr><w14:ligatures w14:val="none"/></w:rPr>',
    );
    final raw = source(table(row(native)));
    final a = ZipDecoder().decodeBytes(raw);
    final xml = utf8
        .decode(a.findFile('word/document.xml')!.content as List<int>)
        .replaceFirst(
          '<w:document ',
          '<w:document xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" ',
        );
    final b = utf8.encode(xml);
    a.addFile(ArchiveFile('word/document.xml', b.length, b));
    final blocks = await parse(Uint8List.fromList(ZipEncoder().encode(a)));
    final out = await export(blocks, PublishCitationStyle.apa);
    expect(mathCount(out), 2);
    expect(
      out.descendants
          .whereType<XmlElement>()
          .firstWhere((e) => e.localName == 'ligatures')
          .namespaceUri,
      'http://schemas.microsoft.com/office/word/2010/wordml',
    );
  });
  test('two separate math tables preserve both grids', () async {
    final b = await parse(
      source(
        '${table(row(cell))}<w:p><w:r><w:t>Independent explanatory paragraph between two equation tables.</w:t></w:r></w:p>${table(row(cell))}',
      ),
    );
    expect(mathCount(await export(b, PublishCitationStyle.apa)), 4);
  });

  test('malformed saved cell fragment falls back to visible text', () async {
    final b = const ManuscriptBlock(
      id: 't',
      type: ManuscriptBlockType.table,
      rows: [
        ['Current visible text'],
      ],
      rowCellMath: [
        ['<cell><broken>'],
      ],
    );
    final x = await export([b], PublishCitationStyle.apa);
    expect(mathCount(x), 0);
    expect(x.rootElement.innerText, contains('Current visible text'));
  });
  test('adjacent continued tables keep all retained native cells', () async {
    final second = cell.replaceAll('Rate ', 'Second rate ');
    final b = await parse(source(table(row(cell)) + table(row(second))));
    expect(mathCount(await export(b, PublishCitationStyle.apa)), 4);
  });

  test(
    'alternate math prefix does not lose inherited bindings',
    () async {
      final raw = source(table(row(cell)));
      final a = ZipDecoder().decodeBytes(raw);
      final xml = utf8
          .decode(a.findFile('word/document.xml')!.content as List<int>)
          .replaceAll('xmlns:m=', 'xmlns:math=')
          .replaceAll('m:', 'math:');
      final b = utf8.encode(xml);
      a.addFile(ArchiveFile('word/document.xml', b.length, b));
      final blocks = await parse(Uint8List.fromList(ZipEncoder().encode(a)));
      final out = await export(blocks, PublishCitationStyle.apa);
      expect(mathCount(out), 2);
    },
  );
}
