import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/journal_template_reader.dart';

void main() {
  const ns = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  Uint8List zip(Map<String, String> files) {
    final a = Archive();
    files.forEach((k, v) => a.addFile(ArchiveFile(k, 0, utf8.encode(v))));
    return Uint8List.fromList(ZipEncoder().encode(a));
  }

  String doc(String body) =>
      '<w:document xmlns:w="$ns"><w:body>$body</w:body></w:document>';
  JournalTemplateRead? read(Uint8List b, {String name = 'qa.docx'}) =>
      JournalTemplateReader.read(bytes: b, filename: name, journalName: 'QA');
  for (final item in <String, Map<String, String>>{
    'unrelated ZIP': {'other.xml': '<root/>'},
    'styles without Word body': {
      'word/styles.xml':
          '<w:styles xmlns:w="$ns"><w:rPr><w:rFonts w:ascii="Arial"/></w:rPr></w:styles>',
    },
    'malformed document': {'word/document.xml': '<w:document'},
    'empty Word body': {'word/document.xml': doc('')},
    'placeholder text only': {
      'word/document.xml': doc(
        '<w:p><w:r><w:t>Enter your manuscript title here</w:t></w:r></w:p>',
      ),
    },
    'wrong root': {
      'word/document.xml': '<w:other xmlns:w="$ns"><w:body/></w:other>',
    },
    'wrong namespace': {
      'word/document.xml':
          '<w:document xmlns:w="urn:not-word"><w:body><w:sectPr><w:cols w:num="2"/></w:sectPr></w:body></w:document>',
    },
    'missing body': {'word/document.xml': '<w:document xmlns:w="$ns"/>'},
  }.entries) {
    test('rejects ${item.key} without claiming extracted rules', () {
      expect(read(zip(item.value)), isNull);
    });
  }
  test('binary legacy Word header renamed DOCX is rejected', () {
    expect(
      read(
        Uint8List.fromList([
          0xd0,
          0xcf,
          0x11,
          0xe0,
          0xa1,
          0xb1,
          0x1a,
          0xe1,
          ...List.filled(512, 0),
        ]),
      ),
      isNull,
    );
  });
  test('legacy extension rejected even if bytes are valid DOCX', () {
    expect(
      read(
        zip({
          'word/document.xml': doc('<w:sectPr><w:cols w:num="2"/></w:sectPr>'),
        }),
        name: 'qa.doc',
      ),
      isNull,
    );
  });
  test('valid layout-only DOCX is still useful evidence', () {
    final r = read(
      zip({
        'word/document.xml': doc('<w:sectPr><w:cols w:num="2"/></w:sectPr>'),
      }),
    );
    expect(r, isNotNull);
    expect(r!.layout['columns'], 2);
    expect(r.rules.extractedFromGuide, true);
    expect(r.rules.citationStyleResolved, false);
  });
  test('valid instructions without styles are still useful evidence', () {
    final r = read(
      zip({
        'word/document.xml': doc(
          '<w:p><w:r><w:t>The manuscript must use Arial font at 11 pt and double spacing.</w:t></w:r></w:p>',
        ),
      }),
    );
    expect(r, isNotNull);
    expect(r!.rules.fontFamily, 'Arial');
    expect(r.rules.lineSpacing, 2);
  });
  test(
    'failed read returns before changing existing UI rules or calling enrichment',
    () {
      final s = File(
        'lib/features/acadegate_publish/journal_format_apply_screen.dart',
      ).readAsStringSync();
      final a = s.indexOf('if (local == null)');
      final b = s.indexOf('_guideTextCtrl.text = local.text;', a);
      expect(a, greaterThan(0));
      expect(b, greaterThan(a));
      expect(s.substring(a, b), contains('return;'));
      expect(s.substring(a, b), isNot(contains('_rules =')));
      expect(s.substring(a, b), contains('Your current rules were kept.'));
    },
  );
}
