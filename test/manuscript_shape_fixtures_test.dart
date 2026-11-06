import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:acadegate/features/acadegate_publish/citation_style_shapes.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tiny Word files for one content type each. Nothing in them is taken from
/// a particular manuscript.
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory('test/fixtures/shapes')..createSync(recursive: true);
  });

  test('outline numbers and heading styles are headings', () async {
    expect(
      CitationStyleShapes.looksLikeSectionHeading('1.1 Sensor interface'),
      isTrue,
    );
    expect(
      CitationStyleShapes.looksLikeSectionHeading('2. Experimental'),
      isTrue,
    );
    final parsed = await _parse(_headings, 'shape_headings.docx', dir);
    expect(_type(parsed, 'Materials and methods'), ManuscriptBlockType.heading);
    expect(_type(parsed, '1.1 Sensor interface'), ManuscriptBlockType.heading);
    expect(_type(parsed, 'المقدمة'), ManuscriptBlockType.heading);
    expect(_type(parsed, 'Bench centrifuge'), ManuscriptBlockType.paragraph);
  });

  test('a merged table keeps both cells', () async {
    final parsed = await _parse(_table, 'shape_table.docx', dir);
    final tables = parsed.bodyBlocks.where(
      (block) => block.type == ManuscriptBlockType.table,
    );
    expect(tables, isNotEmpty);
    final text = tables.map((block) => block.rows.map((row) => row.join(' ')).join('\n')).join('\n');
    expect(text, contains('Merged header'));
    expect(text, contains('1.2 mL/min'));
    expect(
      tables.first.colSpans.any((row) => row.contains(2)),
      isTrue,
    );
  });

  test('an embedded picture becomes an image block', () async {
    final parsed = await _parse(_image, 'shape_image.docx', dir, embedImage: true);
    expect(
      parsed.bodyBlocks.any((block) => block.type == ManuscriptBlockType.image),
      isTrue,
    );
    expect(_joined(parsed), contains('Figure 1. Calibration curve'));
  });

  test('an OMML subscript stays an equation', () async {
    final parsed = await _parse(_equation, 'shape_equation.docx', dir);
    final equation = parsed.bodyBlocks.where(
      (block) => block.type == ManuscriptBlockType.equation,
    );
    expect(equation, isNotEmpty);
    expect(equation.first.text, contains('Cₑ'));
  });

  test('Arabic prose and scientific symbols stay in the paragraph', () async {
    final parsed = await _parse(_arabicSymbols, 'shape_arabic_symbols.docx', dir);
    final text = _joined(parsed);
    expect(text, contains('كما كتبها الباحث'));
    expect(text, contains('[جدول المقارنة]'));
    expect(text, contains('25°'));
    expect(text, contains('μL'));
    expect(text, contains('H₂SO₄'));
    expect(text, contains('AB-X5000'));
  });
}

Future<ManuscriptParseResult> _parse(
  String body,
  String name,
  Directory dir, {
  bool embedImage = false,
}) {
  final bytes = _docx(body, embedImage: embedImage);
  File('${dir.path}/$name').writeAsBytesSync(bytes);
  return ManuscriptDocumentParser.parseFile(bytes: bytes, filename: name);
}

String _joined(ManuscriptParseResult parsed) => parsed.bodyBlocks
    .map((block) => '${block.text}\n${block.caption ?? ''}')
    .join('\n');

ManuscriptBlockType? _type(ManuscriptParseResult parsed, String snippet) {
  for (final block in parsed.bodyBlocks) {
    if (block.text.contains(snippet)) return block.type;
  }
  return null;
}

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

const _rels = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId8" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/>
</Relationships>
''';

const _image = '''
<w:p><w:r><w:t>Figure 1. Calibration curve</w:t></w:r></w:p>
<w:p>
  <w:r>
    <w:drawing>
      <wp:inline>
        <a:graphic>
          <a:graphicData>
            <pic:pic>
              <pic:blipFill>
                <a:blip r:embed="rId8"/>
              </pic:blipFill>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>
''';

const _table = '''
<w:tbl>
  <w:tr>
    <w:tc><w:tcPr><w:gridSpan w:val="2"/></w:tcPr><w:p><w:r><w:t>Merged header</w:t></w:r></w:p></w:tc>
  </w:tr>
  <w:tr>
    <w:tc><w:p><w:r><w:t>Condition</w:t></w:r></w:p></w:tc>
    <w:tc><w:p><w:r><w:t>1.2 mL/min</w:t></w:r></w:p></w:tc>
  </w:tr>
</w:tbl>
''';

const _equation = '''
<w:p><w:r><w:t>The equilibrium concentration is defined by the following expression for the sample.</w:t></w:r></w:p>
<w:p>
  <m:oMath>
    <m:sSub>
      <m:e><m:r><m:t>C</m:t></m:r></m:e>
      <m:sub><m:r><m:t>e</m:t></m:r></m:sub>
    </m:sSub>
  </m:oMath>
</w:p>
''';

const _headings = '''
<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Materials and methods</w:t></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>1.1 Sensor interface</w:t></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>المقدمة</w:t></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>Bench centrifuge ( LabCo 4000 )</w:t></w:r></w:p>
<w:p><w:r><w:t>The following sentence stays in the body of the methods section.</w:t></w:r></w:p>
''';

const _arabicSymbols = '''
<w:p><w:r><w:t>يوضح [جدول المقارنة] أن النتيجة بقيت كما كتبها الباحث عند 25° باستخدام 5 μL من H2SO4 على الجهاز AB-X5000.</w:t></w:r></w:p>
''';

Uint8List _docx(String body, {bool embedImage = false}) {
  final documentXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
  xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"
  xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math">
  <w:body>
    $body
  </w:body>
</w:document>
''';
  final encoded = utf8.encode(documentXml);
  final archive = Archive()
    ..addFile(ArchiveFile('word/document.xml', encoded.length, encoded));
  if (embedImage) {
    archive
      ..addFile(ArchiveFile('word/media/image1.png', _png.length, _png))
      ..addFile(ArchiveFile('word/_rels/document.xml.rels', utf8.encode(_rels).length, utf8.encode(_rels)));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
