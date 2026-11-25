import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
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
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" xmlns:ext="urn:independent:math-extension"><w:body><w:p>${run('Independent measurements of scientific properties')}</w:p><w:p>${run('INTRODUCTION')}</w:p>$content<w:p>${run('Surrounding observations remain unchanged.')}</w:p></w:body></w:document>';
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
  for (final style in [PublishCitationStyle.apa, PublishCitationStyle.ieee]) {
    for (final mixed in [false, true]) {
      test('inherited extension bindings survive mixed=$mixed $style', () async {
        final nativeMath =
            '<m:oMath><m:r><w:rPr><w14:ligatures w14:val="none"/>'
            '<ext:setting ext:val="retained"/></w:rPr><m:t>x</m:t></m:r></m:oMath>';
        final content = mixed
            ? '<w:p>${run('Value = ')}$nativeMath${run(' (3)')}</w:p>'
            : '<w:p><m:oMathPara>$nativeMath</m:oMathPara></w:p>';
        final xml = await exported(content, style);
        final extension = xml.descendants.whereType<XmlElement>().firstWhere(
          (e) => e.localName == 'ligatures',
        );
        expect(
          extension.namespaceUri,
          'http://schemas.microsoft.com/office/word/2010/wordml',
        );
        expect(
          extension.attributes.first.namespaceUri,
          'http://schemas.microsoft.com/office/word/2010/wordml',
        );
        final custom = xml.descendants.whereType<XmlElement>().firstWhere(
          (e) => e.localName == 'setting',
        );
        expect(custom.namespaceUri, 'urn:independent:math-extension');
        expect(
          custom.attributes.first.namespaceUri,
          'urn:independent:math-extension',
        );
        expect(
          xml.descendants
              .whereType<XmlElement>()
              .where((e) => e.localName == 'oMath')
              .length,
          1,
        );
        if (mixed) {
          expect(xml.toXmlString(), contains('Value = '));
          expect(xml.toXmlString(), contains(' (3)'));
        }
      });
    }
  }
}
