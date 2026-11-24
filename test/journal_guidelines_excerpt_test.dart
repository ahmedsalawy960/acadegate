import 'package:acadegate/features/acadegate_publish/journal_guidelines_heuristic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('short pasted multiline guide uses the normalized excerpt length', () {
    const guide =
        'Author Guidelines\n\nUse double spacing.\n\nUse 12 point Times New Roman.\n\nAbstract maximum 200 words.';
    final rules = JournalGuidelinesHeuristic.extract(
      guide,
      requireDistinctive: false,
    );
    expect(rules, isNotNull);
    expect(rules!['excerpt'], guide.replaceAll(RegExp(r'\s+'), ' ').trim());
    expect(rules['lineSpacing'], 2.0);
    expect(rules['abstractMaxWords'], 200);
  });
  test('large whitespace-only padding does not overrun a short normalized guide', () {
    final guide =
        'Author Guidelines${List.filled(250, ' \n\t').join()}Use double spacing.';
    final rules = JournalGuidelinesHeuristic.extract(guide);
    expect(rules, isNotNull);
    expect(rules!['excerpt'], 'Author Guidelines Use double spacing.');
  });
  test('long normalized guide is capped at 350 characters without altering rules', () {
    final guide =
        'Author Guidelines. Use double spacing. ${List.filled(100, 'guidance').join(' ')}';
    final rules = JournalGuidelinesHeuristic.extract(guide);
    expect((rules!['excerpt'] as String).length, 350);
    expect(rules['lineSpacing'], 2.0);
  });
  test('unsupported text remains unsupported; empty inputs stay null', () {
    for (final guide in [
      '',
      ' ',
      'too short',
      'ordinary text without formatting guidance',
    ]) {
      expect(JournalGuidelinesHeuristic.extract(guide), isNull);
    }
  });
}
