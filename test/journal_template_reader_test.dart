import 'dart:convert';
import 'dart:typed_data';

import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/journal_template_reader.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads font and double spacing from an uploaded Word template', () {
    final archive = Archive()
      ..addFile(ArchiveFile(
        'word/document.xml',
        0,
        utf8.encode(
          '<?xml version="1.0"?>'
          '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
          '<w:body><w:p><w:r><w:t>Instructions for authors. References should appear as '
          '1. Matheis, K.; Granvogl, M. Quantitation of 3-MCPD. '
          'J. Agric. Food Chem. 2017, 65, 1234-1240. Use numbered citations [1].'
          '</w:t></w:r></w:p>'
          '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
          '<w:pgMar w:top="1440"/><w:cols w:num="1"/></w:sectPr>'
          '</w:body></w:document>',
        ),
      ))
      ..addFile(ArchiveFile(
        'word/styles.xml',
        0,
        utf8.encode(
          '<?xml version="1.0"?>'
          '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
          '<w:docDefaults><w:rPrDefault><w:rPr>'
          '<w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/>'
          '<w:sz w:val="24"/>'
          '</w:rPr></w:rPrDefault></w:docDefaults>'
          '<w:style><w:pPr><w:spacing w:line="480" w:lineRule="auto"/></w:pPr></w:style>'
          '</w:styles>',
        ),
      ));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    final read = JournalTemplateReader.read(
      bytes: bytes,
      filename: 'journal_template.docx',
      journalName: 'Test Journal',
      fallback: JournalFormatRulesService.instance.resolve(
        journalName: 'Test Journal',
      ),
    );
    expect(read, isNotNull);
    expect(read!.layout['fontFamily'], 'Times New Roman');
    expect(read.layout['lineSpacing'], 2.0);
    expect(read.layout['bodyFontSizePt'], 12);
    expect(read.text, contains('Instructions for authors'));
    expect(read.rules.fontFamily, 'Times New Roman');
    expect(read.rules.lineSpacing, 2.0);
    expect(read.rules.extractedFromGuide, isTrue);
    expect(read.rules.sourceUrl, 'template:journal_template.docx');
  });
}
