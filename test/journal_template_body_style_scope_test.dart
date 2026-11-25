import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/journal_template_reader.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';

void main() {
  const ns = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  JournalTemplateRead read(String styles) {
    final a = Archive();
    void add(String p, String s) =>
        a.addFile(ArchiveFile(p, 0, utf8.encode(s)));
    add(
      'word/document.xml',
      '<w:document xmlns:w="$ns"><w:body><w:sectPr><w:cols w:num="1"/></w:sectPr></w:body></w:document>',
    );
    add('word/styles.xml', '<w:styles xmlns:w="$ns">$styles</w:styles>');
    return JournalTemplateReader.read(
      bytes: Uint8List.fromList(ZipEncoder().encode(a)),
      filename: 'qa.docx',
      journalName: 'QA',
      fallback: JournalFormatRules.forStudentStyle(
        PublishCitationStyle.apa,
      ).copyWith(fontFamily: 'Arial', lineSpacing: 1.5),
    )!;
  }

  String style(
    String props, {
    String id = 'Normal',
    String type = 'paragraph',
    bool body = true,
  }) =>
      '<w:style w:type="$type" w:styleId="$id"${body ? ' w:default="1"' : ''}>$props</w:style>';
  const font =
      '<w:rPr><w:rFonts w:ascii="Times New Roman"/><w:sz w:val="20"/></w:rPr>';
  String spacing(String attrs) => '<w:pPr><w:spacing $attrs/></w:pPr>';
  for (final type in ['paragraph', 'character']) {
    test('non-body $type style cannot dictate whole-paper defaults', () {
      final r = read(
        style(
          '$font${spacing('w:line="480" w:lineRule="auto"')}',
          id: 'Caption',
          type: type,
          body: false,
        ),
      );
      expect(r.layout['fontFamily'], isNull);
      expect(r.layout['bodyFontSizePt'], isNull);
      expect(r.layout['lineSpacing'], isNull);
      expect(r.rules.fontFamily, 'Arial');
      expect(r.rules.lineSpacing, 1.5);
    });
  }
  test('declared default character style is not body paragraph style', () {
    final r = read(style('$font${spacing('w:line="480"')}', type: 'character'));
    expect(r.layout['fontFamily'], isNull);
    expect(r.layout['lineSpacing'], isNull);
  });
  test('body overrides document defaults regardless of style order', () {
    final r = read(
      '<w:docDefaults><w:rPrDefault>$font</w:rPrDefault><w:pPrDefault>${spacing('w:line="480"')}</w:pPrDefault></w:docDefaults>${style('$font${spacing('w:line="480"')}', id: 'Heading', body: false)}${style('<w:rPr><w:rFonts w:ascii="Arial"/><w:sz w:val="24"/></w:rPr>${spacing('w:line="360"')}')}',
    );
    expect(r.layout['fontFamily'], 'Arial');
    expect(r.layout['bodyFontSizePt'], 12);
    expect(r.layout['lineSpacing'], 1.5);
  });
  test('document paragraph defaults work without body style', () {
    final r = read(
      '<w:docDefaults><w:pPrDefault>${spacing('w:line="360" w:lineRule="auto"')}</w:pPrDefault></w:docDefaults>',
    );
    expect(r.layout['lineSpacing'], 1.5);
  });
  test('default paragraph inherits body properties through basedOn', () {
    final r = read(
      '${style('$font${spacing('w:line="480" w:lineRule="auto"')}', id: 'Base', body: false)}${style('<w:basedOn w:val="Base"/>')}',
    );
    expect(r.layout['fontFamily'], 'Times New Roman');
    expect(r.layout['lineSpacing'], 2);
  });
  for (final rule in ['exact', 'atLeast']) {
    test('$rule spacing is not double line spacing', () {
      final r = read(style(spacing('w:line="480" w:lineRule="$rule"')));
      expect(r.layout['lineSpacing'], isNull);
      expect(r.rules.lineSpacing, 1.5);
    });
  }
  test('omitted lineRule means automatic spacing', () {
    expect(read(style(spacing('w:line="480"'))).layout['lineSpacing'], 2);
  });
  test('inherited exact rule remains exact when child only changes line', () {
    final r = read(
      '${style(spacing('w:line="240" w:lineRule="exact"'), id: 'Base', body: false)}${style('<w:basedOn w:val="Base"/>${spacing('w:line="480"')}')}',
    );
    expect(r.layout['lineSpacing'], isNull);
  });
  test('unsupported triple spacing is not mislabeled double', () {
    expect(read(style(spacing('w:line="720"'))).layout['lineSpacing'], isNull);
  });
  test(
    'actual export preserves fallback instead of unrelated Caption rules',
    () async {
      final r = read(
        style('$font${spacing('w:line="480"')}', id: 'Caption', body: false),
      );
      final bytes = await ManuscriptDocxExportService.instance.buildDocx(
        manuscript: PublishManuscript(
          userId: 'qa',
          title: 'Template body scope',
          body: 'Scientific text remains in the selected body defaults.',
        ),
        rules: r.rules.withCitationStyle(PublishCitationStyle.apa),
      );
      final a = ZipDecoder().decodeBytes(bytes);
      final xml = utf8.decode(
        a.findFile('word/styles.xml')!.content as List<int>,
      );
      expect(xml, contains('w:ascii="Arial"'));
      // 11pt fallback at1.5 spacing is330 twips, not the old12pt360.
      expect(xml, contains('w:line="330"'));
      if (Platform.environment['QA_BODY_STYLE_DOCX'] != null) {
        File(
          Platform.environment['QA_BODY_STYLE_DOCX']!,
        ).writeAsBytesSync(bytes);
      }
    },
  );
  test('cyclic inheritance cannot establish body defaults', () {
    final r = read(
      '${style('<w:basedOn w:val="Base"/>$font')}${style('<w:basedOn w:val="Normal"/>', id: 'Base', body: false)}',
    );
    expect(r.layout['fontFamily'], isNull);
  });
}
