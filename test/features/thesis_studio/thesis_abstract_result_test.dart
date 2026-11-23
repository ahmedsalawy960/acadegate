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
    final text = List.filled(30, 'ملخص').join(' ');
    expect(
      requireGeneratedAbstract('  $text  ', failureMessage: 'retry'),
      text,
    );
  });
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
