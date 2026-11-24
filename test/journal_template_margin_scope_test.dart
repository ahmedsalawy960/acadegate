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
            '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:sectPr><w:cols w:num="1"/><w:pgMar $attrs/></w:sectPr></w:body></w:document>',
          ),
        ),
      );
    return JournalTemplateReader.read(
      bytes: Uint8List.fromList(ZipEncoder().encode(a)),
      filename: 'qa.docx',
      journalName: 'QA',
      fallback: JournalFormatRules.forStudentStyle(
        PublishCitationStyle.apa,
      ).copyWith(marginTwips: 1440),
    )!;
  }

  for (final attrs in [
    'w:top="720"',
    'w:top="720" w:right="1440" w:bottom="720" w:left="1440"',
    'w:top="400" w:right="400" w:bottom="400" w:left="400"',
    'w:top="3000" w:right="3000" w:bottom="3000" w:left="3000"',
    'w:top="720" w:right="720" w:bottom="720" w:left="720" w:gutter="100"',
  ]) {
    test(
      'unrepresentable margins do not become a fabricated uniform rule: $attrs',
      () {
        final r = read(attrs);
        expect(r.layout['marginCm'], isNull);
        expect(r.rules.marginTwips, 1440);
      },
    );
  }
  test('explicit supported equal margins retain measured size', () {
    final r = read('w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"');
    expect(r.layout['marginCm'], 2);
    expect(r.rules.marginTwips, 1134);
  });
  test(
    'actual DOCX keeps fallback margins when template is asymmetric',
    () async {
      final r = read('w:top="720" w:right="1440" w:bottom="720" w:left="1440"');
      final bytes = await ManuscriptDocxExportService.instance.buildDocx(
        manuscript: PublishManuscript(
          userId: 'qa',
          title: 'Template margin scope',
          body:
              'Scientific text retains the fallback margins, not an invented uniform top margin.',
        ),
        rules: r.rules.withCitationStyle(PublishCitationStyle.apa),
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      final xml = utf8.decode(
        archive.findFile('word/document.xml')!.content as List<int>,
      );
      for (final side in ['top', 'right', 'bottom', 'left']) {
        expect(xml, contains('w:$side="1440"'));
      }
      if (Platform.environment['QA_MARGIN_DOCX'] != null) {
        File(Platform.environment['QA_MARGIN_DOCX']!).writeAsBytesSync(bytes);
      }
    },
  );
}
