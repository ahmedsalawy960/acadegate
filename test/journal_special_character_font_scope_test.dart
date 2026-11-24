import 'package:archive/archive.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/journal_guidelines_heuristic.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';

void main() {
  final fixture = jsonDecode(
    File(
      'test/fixtures/special_character_font_excerpt.json',
    ).readAsStringSync(),
  );
  final excerpt = fixture['text'] as String;
  for (final flat in [false, true]) {
    test('actual F1000 symbol instructions do not set body font, flat=$flat', () {
      final text =
          'Manuscript must be double-spaced.\n${flat ? excerpt.replaceAll(RegExp(r'\s+'), ' ') : excerpt}';
      final e = JournalGuidelinesHeuristic.extract(
        text,
        requireDistinctive: false,
      )!;
      expect(e['fontFamily'], isNull);
      expect(e['bodyFontSizePt'], isNull);
      expect(e['lineSpacing'], 2.0);
      final fallback = JournalFormatRules.forStudentStyle(
        PublishCitationStyle.apa,
      ).copyWith(fontFamily: 'Arial');
      final rules = JournalFormatRules.fromExtracted(
        journalName: 'QA',
        sourceUrl: fixture['source_url'],
        fallback: fallback,
        extracted: e,
      );
      expect(rules.fontFamily, 'Arial');
    });
  }
  for (final instruction in [
    'For European accents, Greek, Hebrew, or Cyrillic letters, or phonetic symbols: choose Times New Roman font from the dropdown menu in the Insert Symbol window.',
    'For transliterated Arabic: you may choose either Times New Roman or Arial.',
    '## Special characters\n### Inserting accents\nFont: Times New Roman, 10 pt.',
    'To insert diacritics, choose Arial font at 9 pt.',
  ]) {
    test('local character instruction stays local: $instruction', () {
      final e = JournalGuidelinesHeuristic.extract(
        'Double-spaced manuscript.\n$instruction',
        requireDistinctive: false,
      )!;
      expect(e['fontFamily'], isNull);
      expect(e['bodyFontSizePt'], isNull);
    });
  }
  test('symbol section ends before explicit body section', () {
    final e = JournalGuidelinesHeuristic.extract(
      '## Special characters\nFont: Times New Roman, 10 pt.\n## Manuscript formatting\nThe manuscript must use Arial font at 11 pt and double spacing.',
      requireDistinctive: false,
    )!;
    expect(e['fontFamily'], 'Arial');
    expect(e['bodyFontSizePt'], 11);
  });
  test('explicit body rule survives preceding real character instructions', () {
    final e = JournalGuidelinesHeuristic.extract(
      '$excerpt\nThe manuscript must use Arial font at 11 pt and double spacing.',
      requireDistinctive: false,
    )!;
    expect(e['fontFamily'], 'Arial');
    expect(e['bodyFontSizePt'], 11);
  });
  test(
    'local symbol font cannot replace chosen fallback in actual DOCX',
    () async {
      final e = JournalGuidelinesHeuristic.extract(
        'Manuscript must be double-spaced.\n$excerpt',
        requireDistinctive: false,
      )!;
      final fallback = JournalFormatRules.forStudentStyle(
        PublishCitationStyle.apa,
      ).copyWith(fontFamily: 'Arial');
      final rules = JournalFormatRules.fromExtracted(
        journalName: 'QA',
        sourceUrl: fixture['source_url'],
        fallback: fallback,
        extracted: e,
      ).withCitationStyle(PublishCitationStyle.apa);
      final bytes = await ManuscriptDocxExportService.instance.buildDocx(
        manuscript: PublishManuscript(
          userId: 'qa',
          title: 'QA symbol font scope',
          body: 'Original scientific text: alpha α, Cyrillic Ж and Arabic ع.',
        ),
        rules: rules,
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      final styles = utf8.decode(
        archive.findFile('word/styles.xml')!.content as List<int>,
      );
      expect(styles, contains('w:ascii="Arial"'));
      expect(styles, isNot(contains('w:ascii="Times New Roman"')));
      if (Platform.environment['QA_CHARACTER_FONT_DOCX'] != null) {
        File(
          Platform.environment['QA_CHARACTER_FONT_DOCX']!,
        ).writeAsBytesSync(bytes);
      }
    },
  );
}
