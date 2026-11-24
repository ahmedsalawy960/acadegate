import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/journal_guidelines_heuristic.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';

void main() {
  for (final item in jsonDecode(File('test/fixtures/citation_style_policy_excerpts.json').readAsStringSync()) as List) {
    test('real policy excerpt stays unresolved: ${item['id']}', () {
      for (final text in [item['text'] as String, (item['text'] as String).replaceAll(RegExp(r'\s+'), ' ')]) {
        final e = JournalGuidelinesHeuristic.extract(text, requireDistinctive: false)!;
        expect(e['citationStyleUnresolved'], true);
        expect(JournalFormatRules.fromExtracted(journalName:item['id'], sourceUrl:item['url'], extracted:e).citationStyleResolved, false);
      }
    });
  }

  for (final source in [
    'Reference example: Smith, A. (2021). APA style in science. ACS Omega.',
    'Journal titles should be abbreviated according to Chemical Abstracts. Use superscript numbers.',
    'References may be in any style. We suggest APA style as the closest match.',
    'This journal uses APA reference style; as the journal offers Free Format submission, this is for information only.',
    'Double-spaced manuscript.\n## Revised manuscripts\nReferences should use Harvard referencing style.',
    '## Revised manuscripts\n### References\nReferences must use APA style.',
    'APA reference style is not required.',
    'APA reference style is optional; use APA style if you wish.',
    'Reference example: APA style.',
    'The manuscript is double-spaced. Use either Harvard referencing style or Vancouver style.',
  ]) {
    test('conditional/sample style stays unresolved: $source', () {
      final e = JournalGuidelinesHeuristic.extract(
        'Double-spaced manuscript.\n$source',
        requireDistinctive: false,
      )!;
      final r = JournalFormatRules.fromExtracted(
        journalName: 'QA',
        sourceUrl: 'qa',
        extracted: e,
      );
      expect(e['citationStyle'], isNull);
      expect(r.citationStyleResolved, false);
      final merged = JournalGuidelinesHeuristic.merge(e, {
        'found': true,
        'citationStyle': 'apa',
        'citationStyleUnresolved': false,
        'keyRequirements': ['APA citation style'],
      });
      expect(merged['citationStyle'], isNull);
      expect(merged['citationStyleUnresolved'], true);
      expect(merged['keyRequirements'], isNot(contains('APA citation style')));
    });
  }
  for (final style in [
    'APA',
    'IEEE',
    'ACS',
    'Harvard',
    'Vancouver',
    'Chicago',
  ]) {
    test('explicit journal style $style stays resolved', () {
      final e = JournalGuidelinesHeuristic.extract(
        'Manuscripts must be double-spaced. References must follow $style style.',
        requireDistinctive: false,
      )!;
      expect(e['citationStyle'], style.toLowerCase());
      expect(
        JournalFormatRules.fromExtracted(
          journalName: 'QA',
          sourceUrl: 'qa',
          extracted: e,
        ).citationStyleResolved,
        true,
      );
    });
  }
  test('explicit IEEE plus numeric evidence is one style', () {
    final e = JournalGuidelinesHeuristic.extract(
      'References must follow IEEE style and citations must be numbered in square brackets.',
      requireDistinctive: false,
    )!;
    expect(e['citationStyle'], 'ieee');
  });
  test('stage heading does not leak into next same-level section', () {
    final e = JournalGuidelinesHeuristic.extract('## Revised manuscripts\nReferences must use Harvard style.\n## Initial submission\nReferences must use APA style.', requireDistinctive: false)!;
    expect(e['citationStyle'], 'apa');
    expect(e['citationStyleUnresolved'], isNot(true));
  });

}
