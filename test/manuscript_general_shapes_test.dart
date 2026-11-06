import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:acadegate/features/acadegate_publish/citation_linker.dart';
import 'package:acadegate/features/acadegate_publish/docx_scientific_extractor.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_structure_advisor.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Shape rules, checked on synthetic papers that share no vocabulary with
/// the soybean fixture: lettered brackets stay, numeric cites collapse,
/// formulas of 1–3 digits subscript, longer digit runs stay baseline.
void main() {
  test('bracket and formula rules follow shape, not a named instrument', () {
    expect(
      CitationLinker.normalizeNumberedCiteDigits(
        'See [Peak Table] and [جدول المقارنة] and [1⁴].',
      ),
      'See [Peak Table] and [جدول المقارنة] and [14].',
    );
    expect(
      DocxScientificExtractor.formatChemicalFormula(
        'H2SO4 and C60 beside catalog AB-X5000',
      ),
      'H₂SO₄ and C₆₀ beside catalog AB-X5000',
    );
    expect(
      ManuscriptStructureAdvisor.isCatalogLine(
        'Benchtop centrifuge ( Eppendorf 5810 R )',
      ),
      isTrue,
    );
    expect(
      ManuscriptStructureAdvisor.isCatalogLine('Sample preparation'),
      isFalse,
    );
    expect(
      ManuscriptStructureAdvisor.isCatalogLine(
        'Oscilloscope, 4 channel, 200 MHz, model DSOX2024A, Keysight bench',
      ),
      isTrue,
    );
  });

  test('a methods paper keeps labels, formulas, merges, and section roles', () async {
    final parsed = await _parse(_methodsPaper);
    final joined = _joined(parsed);

    expect(joined, contains('[LCMS-TQ8050 Ultra]'));
    expect(joined, contains('[Peak Table]'));
    expect(joined, contains('[1,2]'));
    expect(joined, contains('H₂SO₄'));
    expect(joined, contains('AB-X5000'));
    expect(joined, contains('80°C'));
    expect(joined, contains('10 μL'));
    expect(joined, contains('Merged header'));
    expect(joined, contains('1.2 mL/min'));
    expect(_type(parsed, 'Materials and methods'), ManuscriptBlockType.heading);
    expect(_type(parsed, 'Sample preparation'), ManuscriptBlockType.heading);
    expect(_type(parsed, 'Benchtop centrifuge'), ManuscriptBlockType.paragraph);
    expect(_type(parsed, 'Oscilloscope, 4 channel'), ManuscriptBlockType.paragraph);
    expect(
      parsed.bodyBlocks.any(
        (block) => block.colSpans.any((row) => row.contains(2)),
      ),
      isTrue,
    );

    final xml = await _exportXml(parsed);
    expect(xml, contains('[LCMS-TQ8050 Ultra]'));
    expect(xml, contains('[Peak Table]'));
    expect(xml, contains('H₂SO₄'));
    expect(xml, contains('AB-X5000'));
    expect(xml, contains('Merged header'));
    XmlDocument.parse(xml);
  });

  test('an Arabic essay keeps its wording, symbols, and section labels', () async {
    final parsed = await _parse(_arabicEssay);
    final joined = _joined(parsed);
    final refs = parsed.references.map((ref) => ref.rawText).join('\n');
    final everywhere = '$joined\n$refs';

    expect(_type(parsed, 'المقدمة'), ManuscriptBlockType.heading);
    expect(_type(parsed, 'المنهجية'), ManuscriptBlockType.heading);
    expect(joined, contains('[جدول المقارنة]'));
    expect(joined, contains('كما كتبها الباحث'));
    expect(joined, contains('25°'));
    expect(joined, contains('μ'));
    expect(everywhere, contains('مناهج تحليل الخطاب'));

    final exported = await _exportBytes(parsed);
    final archive = ZipDecoder().decodeBytes(exported);
    final document = archive.findFile('word/document.xml')!;
    final xmlBytes = document.readBytes()!;
    expect(document.size, xmlBytes.length);
    expect(document.size, greaterThan(utf8.decode(xmlBytes).length));
    final xml = utf8.decode(xmlBytes);
    expect(xml, contains('[جدول المقارنة]'));
    expect(xml, contains('كما كتبها الباحث'));
    expect(xml, contains('25°'));
    XmlDocument.parse(xml);

    File('${Directory.systemTemp.path}${Platform.pathSeparator}acadegate_shape_arabic.docx')
        .writeAsBytesSync(exported);
  });

  test('a numbered engineering outline keeps captions and inset labels', () async {
    final parsed = await _parse(_engineeringOutline);
    final joined = _joined(parsed);

    expect(_type(parsed, '1. System architecture'), ManuscriptBlockType.heading);
    expect(_type(parsed, '1.1 Sensor interface'), ManuscriptBlockType.heading);
    expect(joined, contains('[Fig. 2 inset]'));
    expect(joined, contains('ΔG = −RT ln K'));
    expect(joined, contains('Figure 2. Sensor path'));
    expect(_type(parsed, 'Figure 2. Sensor path'), isNot(ManuscriptBlockType.heading));

    final xml = await _exportXml(parsed);
    expect(xml, contains('[Fig. 2 inset]'));
    expect(xml, contains('ΔG'));
    expect(xml, contains('Figure 2. Sensor path'));
    XmlDocument.parse(xml);

    File('${Directory.systemTemp.path}${Platform.pathSeparator}acadegate_shape_methods.docx')
        .writeAsBytesSync(await _exportBytes(await _parse(_methodsPaper)));
  });
}

Future<ManuscriptParseResult> _parse(String body) {
  return ManuscriptDocumentParser.parseFile(
    bytes: _docx(body),
    filename: 'shape.docx',
  );
}

String _joined(ManuscriptParseResult parsed) {
  return parsed.bodyBlocks.map((block) {
    final rows = block.rows.map((row) => row.join(' ')).join('\n');
    return '${block.text}\n${block.caption ?? ''}\n$rows';
  }).join('\n');
}

ManuscriptBlockType? _type(ManuscriptParseResult parsed, String snippet) {
  for (final block in parsed.bodyBlocks) {
    if (block.text.contains(snippet)) return block.type;
  }
  return null;
}

Future<List<int>> _exportBytes(ManuscriptParseResult parsed) {
  return ManuscriptDocxExportService.instance.buildDocx(
    manuscript: PublishManuscript(
      userId: 'u',
      title: 'Shape check',
      bodyBlocks: parsed.bodyBlocks,
      references: parsed.references,
    ),
    rules: JournalFormatRules.forStudentStyle(PublishCitationStyle.apa),
  );
}

Future<String> _exportXml(ManuscriptParseResult parsed) async {
  final bytes = await _exportBytes(parsed);
  final archive = ZipDecoder().decodeBytes(bytes);
  return utf8.decode(archive.findFile('word/document.xml')!.readBytes()!);
}

Uint8List _docx(String body) {
  final documentXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math">
  <w:body>
    $body
  </w:body>
</w:document>
''';
  final encoded = utf8.encode(documentXml);
  final archive = Archive()
    ..addFile(ArchiveFile('word/document.xml', encoded.length, encoded));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

const _methodsPaper = '''
<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Materials and methods</w:t></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>Benchtop centrifuge ( Eppendorf 5810 R )</w:t></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>Sample preparation</w:t></w:r></w:p>
<w:p><w:r><w:t>The run used [LCMS-TQ8050 Ultra] and [Peak Table] as recorded in [1, 2]. Added 5 mL of H2SO4 at 80°C using 10 μL. Detector AB-X5000 stayed inline.</w:t></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>Oscilloscope, 4 channel, 200 MHz, model DSOX2024A, Keysight bench</w:t></w:r></w:p>
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

const _arabicEssay = '''
<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>المقدمة</w:t></w:r></w:p>
<w:p><w:r><w:t>يوضح [جدول المقارنة] أن النتيجة بقيت كما كتبها الباحث في الفقرة العربية عند 25° مع الرمز μ.</w:t></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>المنهجية</w:t></w:r></w:p>
<w:p><w:r><w:t>اعتمد التحليل على قراءة النص كما ورد، من غير إعادة صياغة الجمل.</w:t></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>المراجع</w:t></w:r></w:p>
<w:p><w:r><w:t>عبدالله، س. (2021). مناهج تحليل الخطاب. مجلة الدراسات، 4، 10-22.</w:t></w:r></w:p>
''';

const _engineeringOutline = '''
<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>1. System architecture</w:t></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>1.1 Sensor interface</w:t></w:r></w:p>
<w:p><w:r><w:t>See [Fig. 2 inset] for the sensor path. The balance is ΔG = −RT ln K at the stated temperature.</w:t></w:r></w:p>
<w:p><w:r><w:t>Figure 2. Sensor path</w:t></w:r></w:p>
<w:p><w:r><w:t>The caption stays attached to the float and is not promoted to a section.</w:t></w:r></w:p>
''';
