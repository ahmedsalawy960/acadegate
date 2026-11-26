import 'dart:io';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/journal_template_reader.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';

void main() {
  JournalTemplateRead read(String attrs) {
    final a = Archive()
      ..addFile(
        ArchiveFile(
          'word/document.xml',
          0,
          utf8.encode(
            '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:sectPr><w:cols w:num="1"/><w:pgSz $attrs/></w:sectPr></w:body></w:document>',
          ),
        ),
      );
    return JournalTemplateReader.read(
      bytes: Uint8List.fromList(ZipEncoder().encode(a)),
      filename: 'qa.docx',
      journalName: 'QA',
      fallback: JournalFormatRules.forStudentStyle(
        PublishCitationStyle.apa,
      ).copyWith(paperSize: 'a4'),
    )!;
  }

  for (final attrs in [
    'w:w="12240" w:h="20160"',
    'w:w="12240"',
    'w:w="11906" w:h="20000"',
    'w:w="16838" w:h="11906" w:orient="landscape"',
    'w:w="12240" w:h="15840" w:orient="landscape"',
  ]) {
    test(
      'unsupported or incomplete dimensions are not portrait paper evidence: $attrs',
      () {
        expect(read(attrs).layout['paperSize'], isNull);
      },
    );
  }
  for (final item in {
    'w:w="12240" w:h="15840"': 'letter',
    'w:w="11906" w:h="16838"': 'a4',
    'w:w="11900" w:h="16840" w:orient="portrait"': 'a4',
  }.entries) {
    test('supported full dimensions resolve ${item.value}', () {
      expect(read(item.key).layout['paperSize'], item.value);
    });
  }
  test('Legal width cannot force Letter on actual DOCX export', () async {
    final r = read('w:w="12240" w:h="20160"');
    final bytes = await ManuscriptDocxExportService.instance.buildDocx(
      manuscript: PublishManuscript(
        userId: 'qa',
        title: 'Template paper size scope',
        body: 'Scientific text keeps the selected fallback paper size.',
      ),
      rules: r.rules.withCitationStyle(PublishCitationStyle.apa),
    );
    final xml = utf8.decode(
      ZipDecoder().decodeBytes(bytes).findFile('word/document.xml')!.content
          as List<int>,
    );
    expect(xml, contains('w:w="11906" w:h="16838"'));
    if (Platform.environment['QA_PAPER_DOCX'] != null) {
      File(Platform.environment['QA_PAPER_DOCX']!).writeAsBytesSync(bytes);
    }
  });
}
