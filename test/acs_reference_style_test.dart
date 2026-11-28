import 'package:acadegate/features/acadegate_publish/citation_formatter.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _ref = PublishReference(
  id: 'a',
  type: ReferenceType.journal,
  authors: ['Smith, John A.', 'Jones, C. D.'],
  title: 'Article Title',
  container: 'J. Test Chem.',
  year: '2024',
  volume: '15',
  pages: '120-128',
  doi: '10.1000/xyz123',
);

BibliographyEntry _acs(PublishReference r, {int i = 1}) =>
    CitationFormatter.buildBibliographyEntry(
      reference: r,
      style: PublishCitationStyle.acs,
      index: i,
    );

void main() {
  test('ACS journal article has the documented shape', () {
    expect(_acs(_ref).plain,
        '(1) Smith, J. A.; Jones, C. D. Article Title. J. Test Chem. 2024, 15, 120-128. https://doi.org/10.1000/xyz123');
  });

  test('ACS year is bold, volume and journal italic', () {
    final spans = _acs(_ref).spans;
    expect(spans.where((s) => s.bold).map((s) => s.text), ['2024']);
    expect(spans.where((s) => s.italic).map((s) => s.text),
        containsAll(['J. Test Chem.', '15']));
  });

  test('ACS list prefix is (n) and survives the number policy with styling', () {
    final e = CitationFormatter.applyListNumberPolicy(_acs(_ref, i: 3),
        style: PublishCitationStyle.acs, index: 3);
    expect(e.plain, startsWith('(3) Smith'));
    expect(e.spans.any((s) => s.bold), isTrue);
  });

  test('ACS never invents a journal abbreviation or a DOI', () {
    const r = PublishReference(
      id: 'b',
      type: ReferenceType.journal,
      authors: ['Doe, A.'],
      title: 'No doi paper',
      container: 'Journal of Very Long Names',
      year: '2020',
    );
    final p = _acs(r).plain;
    expect(p, contains('Journal of Very Long Names'));
    expect(p, isNot(contains('doi.org')));
  });

  test('ACS line is not read as APA when parsed', () {
    final r = CitationFormatter.parseBibliographicLine(
        'Smith, J. A.; Jones, C. D. Article Title. J. Test Chem. 2024, 15, 120-128.');
    expect(r, isNotNull);
    expect(r!.authors.length, 2);
    expect(r.title, 'Article Title');
    expect(r.container, 'J. Test Chem');
    expect(r.year, '2024');
    expect(r.volume, '15');
    expect(r.pages, '120-128');
  });

  test('ACS parse splits title and journal for abbreviated and single-name journals', () {
    final a = CitationFormatter.parseBibliographicLine(
        'Smith, J. A.; Jones, C. D. Article Title. Acc. Chem. Res. 2019, 52 (3), 700-710.');
    expect(a!.title, 'Article Title');
    expect(a.container, startsWith('Acc. Chem. Res'));
    expect(a.issue, '3');
    final b = CitationFormatter.parseBibliographicLine(
        'Lee, K.; Park, S. Another Title Here. ACS Nano 2021, 15, 12345.');
    expect(b!.title, 'Another Title Here');
    expect(b.container, 'ACS Nano');
  });

  test('ACS round trip prints one period after an abbreviated journal', () {
    final r = CitationFormatter.parseBibliographicLine(
        'Smith, J. A.; Jones, C. D. Article Title. Acc. Chem. Res. 2019, 52 (3), 700-710.')!;
    final out = _acs(r).plain;
    expect(out, contains('Acc. Chem. Res. 2019'));
    expect(out, isNot(contains('..')));
  });
}
