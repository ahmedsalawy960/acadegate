import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/journal_template_reader.dart';

void main() {
  const page = '<w:pgSz w:w="11906" w:h="16838"/>';
  const margins =
      '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>';
  const instruction =
      '<w:p><w:r><w:t>The manuscript should be double-spaced.</w:t></w:r></w:p>';
  JournalTemplateRead read(List<String> sections) {
    final a = Archive()
      ..addFile(
        ArchiveFile(
          'word/document.xml',
          0,
          utf8.encode(
            '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>$instruction${sections.map((s) => '<w:p><w:pPr><w:sectPr>$s</w:sectPr></w:pPr></w:p>').join()}</w:body></w:document>',
          ),
        ),
      );
    return JournalTemplateReader.read(
      bytes: Uint8List.fromList(ZipEncoder().encode(a)),
      filename: 'qa.docx',
      journalName: 'QA',
    )!;
  }

  test('last section cannot dictate conflicting whole-paper columns', () {
    expect(
      read(['<w:cols w:num="1"/>', '<w:cols w:num="2"/>']).layout['columns'],
      isNull,
    );
  });
  test('all matching explicit sections retain their shared rules', () {
    final r = read([
      '$page$margins<w:cols w:num="2"/>',
      '$page$margins<w:cols w:num="2"/>',
    ]);
    expect(r.layout['columns'], 2);
    expect(r.layout['paperSize'], 'a4');
    expect(r.layout['marginCm'], closeTo(1440 / 567, 0.001));
  });
  test(
    'missing evidence in earlier section cannot be filled by last section',
    () {
      final r = read(['', '$page$margins<w:cols w:num="1"/>']);
      expect(r.layout['paperSize'], isNull);
      expect(r.layout['marginCm'], isNull);
      expect(r.layout['columns'], isNull);
    },
  );
  test('conflicting sections hold only conflicting fields', () {
    final r = read([
      '$page$margins<w:cols w:num="1"/>',
      '<w:pgSz w:w="12240" w:h="15840"/>$margins<w:cols w:num="1"/>',
    ]);
    expect(r.layout['paperSize'], isNull);
    expect(r.layout['columns'], 1);
    expect(r.layout['marginCm'], isNotNull);
  });
  for (final cols in [
    '<w:cols w:num="3"/>',
    '<w:cols w:num="2" w:equalWidth="0"/>',
    '<w:cols w:num="2"><w:col w:w="2000"/><w:col w:w="5000"/></w:cols>',
  ]) {
    test('unsupported columns not coerced: $cols', () {
      expect(read([cols]).layout['columns'], isNull);
    });
  }
  test('tracked old section properties do not override current layout',(){
    final r=read(['<w:cols w:num="1"/><w:sectPrChange><w:sectPr><w:cols w:num="2"/></w:sectPr></w:sectPrChange>']);
    expect(r.layout['columns'],1);
  });

}
