import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/thesis_studio/thesis_abstract_result.dart';

void main() {
  test('missing/empty/short generation throws instead of becoming content', () {
    for (final value in [null, '', '  ', 'short response']) {
      expect(
        () => requireGeneratedAbstract(value, failureMessage: 'retry'),
        throwsA(
          isA<ThesisAbstractGenerationException>().having(
            (e) => e.message,
            'message',
            'retry',
          ),
        ),
      );
    }
  });
  test('successful text is trimmed but otherwise preserved', () {
    final text = '${List.filled(180, 'ملخص').join(' ')}.';
    expect(
      requireGeneratedAbstract('  $text  ', failureMessage: 'retry'),
      text,
    );
  });
  String prose(int words, {String word = 'research', String ending = '.'}) =>
      '${List.filled(words, word).join(' ')}$ending';

  test(
    'word floor rejects the observed short-success class despite 80 chars',
    () {
      final short = prose(48, word: 'الدراسة');
      expect(short.length, greaterThan(80));
      expect(isUsableGeneratedAbstract(short), isFalse);
      expect(isUsableGeneratedAbstract(prose(139)), isFalse);
      expect(isUsableGeneratedAbstract(prose(140)), isTrue);
      expect(isUsableGeneratedAbstract(prose(180, word: 'الدراسة')), isTrue);
      expect(isUsableGeneratedAbstract(prose(250)), isTrue);
    },
  );

  test('long output without a sentence ending is not completed content', () {
    for (final ending in [
      '',
      ',',
      '،',
      ':',
      ';',
      '؛',
      '-',
      '/',
      '...',
      '…',
      '..."',
      '… [1]',
    ]) {
      expect(
        isUsableGeneratedAbstract(prose(180, ending: ending)),
        isFalse,
        reason: 'ending: $ending',
      );
    }
  });

  test(
    'Arabic and English endings, closing quotes and citations are allowed',
    () {
      for (final ending in [
        '.',
        '!',
        '?',
        '؟',
        '۔',
        '."',
        '.”',
        '.»',
        '.)',
        '. [1]',
        '. [1, 2]',
        '. [1–3]',
      ]) {
        expect(
          isUsableGeneratedAbstract(prose(180, ending: ending)),
          isTrue,
          reason: 'ending: $ending',
        );
      }
    },
  );

  test(
    'whitespace and punctuation padding do not manufacture enough words',
    () {
      expect(
        isUsableGeneratedAbstract(
          '${prose(48)} ${List.filled(150, '-').join(' ')}.',
        ),
        isFalse,
      );
      expect(
        isUsableGeneratedAbstract(prose(180).replaceAll(' ', '\n\t ')),
        isTrue,
      );
    },
  );

  test(
    'all abstract replacement callers can preserve the exact previous value',
    () {
      const previous = 'Existing reviewed abstract, preserved verbatim.  ';
      for (final candidate in [
        null,
        '',
        prose(48),
        prose(180, ending: ''),
        prose(180, ending: '…'),
      ]) {
        expect(generatedAbstractOrPrevious(candidate, previous), previous);
        expect(
          () => requireGeneratedAbstract(
            candidate,
            failureMessage: 'manual retry',
          ),
          throwsA(isA<ThesisAbstractGenerationException>()),
        );
      }
      expect(generatedAbstractOrPrevious(prose(48), ''), '');
      final valid = prose(180);
      expect(generatedAbstractOrPrevious('  $valid  ', previous), valid);
      expect(
        requireGeneratedAbstract(valid, failureMessage: 'manual retry'),
        valid,
      );
    },
  );

  test('only valid DOI syntax produces a doi.org destination', () {
    for (final value in [
      '',
      ' ',
      'not-a-doi',
      'https://evil.example/x',
      '10.123/x',
      '10.1234/',
      '10.1234/a b',
    ]) {
      expect(thesisDoiUri(value), isNull);
    }
    for (final value in [
      '10.1234/abc',
      'https://doi.org/10.1234/abc',
      'https://dx.doi.org/10.1234/abc',
    ]) {
      expect(thesisDoiUri(value).toString(), 'https://doi.org/10.1234/abc');
    }
  });
  test('DOI fragment/query characters are path data, never URL control', () {
    final uri = thesisDoiUri('10.1234/a?b#c')!;
    expect(uri.host, 'doi.org');
    expect(uri.query, '');
    expect(uri.fragment, '');
    expect(Uri.decodeComponent(uri.path), '/10.1234/a?b#c');
  });
}
