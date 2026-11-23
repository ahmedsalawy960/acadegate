import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Static wiring guards supplement the pure validator tests. They do not
// replace a Flutter integration test against the generated draft/UI.
void main() {
  final service = File(
    'lib/features/thesis_studio/thesis_studio_ai_service.dart',
  ).readAsStringSync();
  final client = File('lib/features/ai_advisor/gemini_advisor_client.dart')
      .readAsStringSync();

  String between(String text, String start, String end) {
    final first = text.indexOf(start);
    expect(first, greaterThanOrEqualTo(0));
    final last = text.indexOf(end, first + start.length);
    expect(last, greaterThan(first));
    return text.substring(first, last);
  }

  test('each abstract request opts out of the shared cloud failure retry', () {
    for (final markers in [
      ['  Future<String> fillAbstract(', '  Future<String> _growChapter('],
      [
        '  Future<ThesisDraft> enrichSkeleton(',
        '  static bool _titleMatchesDraftLanguage(',
      ],
      ['      _frontMatter(', '  String _chapterSystem('],
    ]) {
      final section = between(service, markers[0], markers[1]);
      expect('generateResult('.allMatches(section).length, 1);
      expect('retryCloudFailure: false'.allMatches(section).length, 1);
    }
    expect(client, contains('retryCloudFailure: retryCloudFailure'));
    expect(
      client,
      contains(
        'if (retryCloudFailure && !viaFunction.isSuccess && !retryWouldRepeat)',
      ),
    );
  });

  test('manual abstract generation validates before its only return', () {
    final section = between(
      service,
      '  Future<String> fillAbstract(',
      '  Future<String> _growChapter(',
    );
    expect(
      section,
      contains(
        'return requireGeneratedAbstract(cleaned, failureMessage: failureMessage)',
      ),
    );
    expect(section, isNot(contains('for (')));
    expect(section, isNot(contains('while (')));
    expect(section, contains('on ThesisAbstractGenerationException'));
  });

  test('other abstract slots use the same guard and no raw JSON fallback', () {
    final enrich = between(
      service,
      '  Future<ThesisDraft> enrichSkeleton(',
      '  static bool _titleMatchesDraftLanguage(',
    );
    expect(
      enrich,
      contains('generatedAbstractOrPrevious(abstractText, draft.abstractText)'),
    );
    final front = between(
      service,
      '      _frontMatter(',
      '  String _chapterSystem(',
    );
    expect(front, contains('abstractText: generatedAbstractOrPrevious('));
    expect(front, isNot(contains('abstractText: result.text!')));
  });

  test('failed abstract generation cannot replace or persist the draft', () {
    final engine = File('lib/features/thesis_studio/thesis_studio_engine.dart')
        .readAsStringSync();
    final write = between(
      engine,
      '  Future<ThesisDraft> writeAbstract(',
      '  Future<GroundedReferenceBundle> harvestForCommand(',
    );
    expect(
      write.indexOf('await ThesisStudioAiService.instance.fillAbstract('),
      lessThan(write.indexOf('return current.copyWith(abstractText: text')),
    );
    final screen = File('lib/features/thesis_studio/thesis_studio_screen.dart')
        .readAsStringSync();
    final busy = between(
      screen,
      '  Future<void> _runBusy(',
      '    } catch (e) {',
    );
    expect(
      busy.indexOf('final draft = await job();'),
      lessThan(busy.indexOf('setState(() => _draft = draft)')),
    );
    final errorPath = busy.substring(
      busy.indexOf('on ThesisAbstractGenerationException'),
    );
    expect(errorPath, isNot(contains('_persistDraft')));
    expect(errorPath, isNot(contains('_draft =')));
  });
}
