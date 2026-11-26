import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:acadegate/features/acadegate_publish/docx_scientific_extractor.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';

const math =
    '<m:oMath><m:f><m:num><m:r><m:t>a</m:t></m:r></m:num><m:den><m:r><m:t>b</m:t></m:r></m:den></m:f></m:oMath>';
String run(String text) =>
    '<w:r><w:t xml:space="preserve">${XmlText(text).toXmlString()}</w:t></w:r>';
Uint8List source(String content) {
  final xml =
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"><w:body><w:p>${run('Independent measurements of scientific properties')}</w:p><w:p>${run('INTRODUCTION')}</w:p>$content<w:p>${run('Surrounding observations remain unchanged.')}</w:p></w:body></w:document>';
  final bytes = utf8.encode(xml);
  return Uint8List.fromList(
    ZipEncoder().encode(
      Archive()..addFile(ArchiveFile('word/document.xml', bytes.length, bytes)),
    ),
  );
}

Future<XmlDocument> exported(String content, PublishCitationStyle style) async {
  final parsed = await ManuscriptDocumentParser.parseFile(
    bytes: source(content),
    filename: 'independent.docx',
  );
  final restored = parsed.bodyBlocks
      .map((b) => ManuscriptBlock.fromMap(b.toMap()))
      .toList();
  final bytes = await ManuscriptDocxExportService.instance.buildDocx(
    manuscript: PublishManuscript(
      userId: 'qa',
      title: 'Independent equation control',
      bodyBlocks: restored,
    ),
    rules: JournalFormatRules.forStudentStyle(style),
  );
  final dir = Platform.environment['QA_EQUATION_DIR'];
  if (dir != null) {
    await Directory(dir).create(recursive: true);
    await File(
      '$dir/${style.name}-${content.hashCode.abs()}.docx',
    ).writeAsBytes(bytes);
  }
  return XmlDocument.parse(
    utf8.decode(
      ZipDecoder().decodeBytes(bytes).findFile('word/document.xml')!.content
          as List<int>,
    ),
  );
}

void main() {
  for (final text in [
    '% Protein = % N × 6.25',
    '% Carbohydrate = 100 - (% protein + % fat + % ash)',
    'Efficiency = 0.00125 .... (8)',
    '% N =',
    'Signal = 1 ······ 2',
    '..........(34)',
    'Yield = 4.2e-5 × 100',
  ]) {
    test('real text is not a placeholder: $text', () {
      expect(DocxScientificExtractor.isEquationPlaceholder(text), false);
    });
    for (final style in [PublishCitationStyle.ieee, PublishCitationStyle.apa]) {
      test('plain formula survives Word round trip $style $text', () async {
        final xml = await exported('<w:p>${run(text)}</w:p>', style);
        expect(
          xml.findAllElements('w:t').map((e) => e.innerText).join(' '),
          contains(text),
        );
      });
    }
  }
  for (final shape in [
    (
      name: 'prefix and label',
      content: '${run('Ratio = ')}$math${run('    (7)')}',
      expected: 'Ratio = ab    (7)',
    ),
    (
      name: 'inline sentence',
      content: '${run('The measured ratio ')}$math${run(' is dimensionless.')}',
      expected: 'The measured ratio ab is dimensionless.',
    ),
    (
      name: 'two math objects',
      content: '${run('R = ')}$math${run(' + ')}$math${run('    (9)')}',
      expected: 'R = ab + ab    (9)',
    ),
    (
      name: 'display container with external label',
      content: '<m:oMathPara>$math</m:oMathPara>${run('    (11)')}',
      expected: 'ab    (11)',
    ),
    (
      name: 'bold equation label',
      content: '$math<w:r><w:rPr><w:b/></w:rPr><w:t>(24)</w:t></w:r>',
      expected: 'ab(24)',
    ),
    (
      name: 'dotted prefix label',
      content: '${run('..........')}$math${run(' (13)')}',
      expected: '..........ab (13)',
    ),
    (
      name: 'line break once',
      content: '${run('Ratio ')}<w:r><w:br/></w:r>$math${run(' (14)')}',
      expected: 'Ratio ab (14)',
    ),
    (
      name: 'bold narrative word stays inert',
      content:
          '<w:r><w:rPr><w:b/></w:rPr><w:t>Measured</w:t></w:r>${run(' ratio ')}$math${run(' remains.')}',
      expected: 'Measured ratio ab remains.',
    ),
    (
      name: 'label and tab',
      content: '$math<w:r><w:tab/></w:r>${run('(12)')}',
      expected: 'ab(12)',
    ),
  ]) {
    for (final style in [
      PublishCitationStyle.ieee,
      PublishCitationStyle.vancouver,
      PublishCitationStyle.apa,
    ]) {
      test(
        'mixed paragraph keeps order and attachment ${shape.name} $style',
        () async {
          final xml = await exported('<w:p>${shape.content}</w:p>', style);
          final ps = xml
              .findAllElements('w:p')
              .where((p) => p.findAllElements('m:oMath').isNotEmpty)
              .toList();
          expect(ps.length, 1);
          final text = ps.single.descendants
              .whereType<XmlElement>()
              .where(
                (e) => e.name.qualified == 'w:t' || e.name.qualified == 'm:t',
              )
              .map((e) => e.innerText)
              .join();
          expect(text, shape.expected);
          expect(text, isNot(contains('<<CITE:')));
          if (shape.name == 'line break once') {
            expect(ps.single.findAllElements('w:br').length, 1);
          }
          if (shape.name == 'label and tab') {
            expect(ps.single.findAllElements('w:tab').length, 1);
          }
          expect(
            ps.single.findAllElements('m:f').length,
            shape.name == 'two math objects' ? 2 : 1,
          );
          expect(
            xml.findAllElements('w:t').map((e) => e.innerText).join(' '),
            contains('Surrounding observations remain unchanged.'),
          );
        },
      );
    }
  }
  for (final blank in ['..........', ' = ____', '······']) {
    test('blank placeholders stay distinct from real equations $blank', () {
      expect(DocxScientificExtractor.isEquationPlaceholder(blank), true);
    });
  }
  test('standalone display remains exactly one native fraction', () async {
    final xml = await exported(
      '<w:p><m:oMathPara>$math</m:oMathPara></w:p>',
      PublishCitationStyle.ieee,
    );
    expect(xml.findAllElements('m:f').length, 1);
  });
}
