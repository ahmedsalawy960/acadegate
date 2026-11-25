import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Static wiring guard: a full re-run of "Summarise abstracts" wipes manual
// edits to prior-study paragraphs, so the screen must confirm first.
// This does not replace a Flutter widget test of the dialog itself.
void main() {
  final screen = File(
    'lib/features/thesis_studio/thesis_studio_screen.dart',
  ).readAsStringSync();

  String between(String text, String start, String end) {
    final first = text.indexOf(start);
    expect(first, greaterThanOrEqualTo(0));
    final last = text.indexOf(end, first + start.length);
    expect(last, greaterThan(first));
    return text.substring(first, last);
  }

  test('re-summarising all prior studies confirms before wiping edits', () {
    final section = between(
      screen,
      'Future<void> _writePriorStudiesChapter()',
      'Future<void> _writePriorStudyParagraph(',
    );
    expect(section, contains('hasWrittenStudies'));
    expect(section, contains('lit_study_'));
    expect(section, contains('showDialog<bool>'));
    expect(section, contains('إعادة تلخيص كل الدراسات؟'));
    // The confirmation must gate the engine call, not follow it.
    expect(
      section.indexOf('showDialog<bool>'),
      lessThan(
        section.indexOf('ThesisStudioEngine.instance.writePriorStudiesChapter('),
      ),
    );
  });
}
