import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/citation_formatter.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';

void main() {
  test('comma year grammar retains Unicode middle authors', () {
    final r = CitationFormatter.parseBibliographicLine(
      'Miller, A., Fränzle, M., Hahn, B., 2018. Independent observations of ocean transport with multiple vessels. Ocean Engineering 160, 168–180. https://doi.org/10.1016/example.2018.123',
    );
    expect(r, isNotNull);
    expect(r!.authors, ['Miller, A.', 'Fränzle, M.', 'Hahn, B.']);
    expect(r.year, '2018');
    expect(
      r.title,
      'Independent observations of ocean transport with multiple vessels',
    );
    expect(r.container, 'Ocean Engineering');
    expect(r.pages, '168–180');
  });
  test('Nature grammar uses publication tail not historical title years', () {
    final r = CitationFormatter.parseBibliographicLine(
      'Brown, A., et al. Impacts of extreme summers in 2003, 2010 and 2018. Philos. Trans. R. Soc. B 375, 20190507 (2020).',
    );
    expect(r, isNotNull);
    expect(r!.year, '2020');
    expect(r.title, 'Impacts of extreme summers in 2003, 2010 and 2018');
    expect(r.authors, ['Brown, A.']);
    expect(r.volume, '375');
    expect(r.pages, '20190507');
  });
  test('multiple surname authors and ampersand retain every person', () {
    final r = CitationFormatter.parseBibliographicLine(
      'Lu, E., Luo, Y., Zhang, R., Wu, Q. & Liu, L. Regional anomalies responsible for the 2009–2010 severe drought. J. Geophys. Res.-Atmos. 116, (2011).',
    );
    expect(r, isNotNull);
    expect(r!.authors.length, 5);
    expect(r.year, '2011');
    expect(r.title, contains('2009–2010'));
  });
  test('APA accented authors do not disappear', () {
    final r = CitationFormatter.parseBibliographicLine(
      'Miller, A., Fränzle, M., & García, B. (2018). Independent title for measured transport. Ocean Studies, 12(3), 11-20.',
    );
    expect(r, isNotNull);
    expect(r!.authors.length, 3);
    expect(r.authors[1], 'Fränzle, M.');
  });
  test('abbreviated author lists remain abbreviated in every export', () {
    const raw =
        'Brown, A., et al. Independent observations of regional ecosystems. Climate Journal 12, eadi6395 (2023).';
    final r = CitationFormatter.parseBibliographicLine(raw)!;
    expect(r.pages, 'eadi6395');
    for (final style in [PublishCitationStyle.apa, PublishCitationStyle.ieee]) {
      final t = CitationFormatter.buildBibliographyEntry(
        reference: r.copyWith(rawText: raw),
        style: style,
        index: 1,
      ).plain;
      expect(t, contains('et al.'));
      expect(t, contains('eadi6395'));
      expect(t, contains('2023'));
    }
  });
  test(
    'complete surnames, title, historical years and locator survive exported APA',
    () {
      const raw =
          'Brown, A., Green, B. & White, C. Changes in 2003, 2010 and 2018 across ecosystems. Climate Studies 375, 20190507 (2020).';
      final r = CitationFormatter.parseBibliographicLine(raw)!;
      final t = CitationFormatter.buildBibliographyEntry(
        reference: r.copyWith(rawText: raw),
        style: PublishCitationStyle.apa,
        index: 1,
      ).plain;
      expect(t, contains('Green'));
      expect(t, contains('White'));
      expect(t, contains('(2020)'));
      expect(t, contains('2003, 2010 and 2018'));
      expect(t, contains('20190507'));
    },
  );
 test('title years without a journal volume are not treated as publication tail',(){
  expect(CitationFormatter.parseBibliographicLine('Brown, A. A historical account of learning in 2003 (2020).'),isNull);
 });
 test('author-year APA retains its own publication year and numeric title',(){
  final r=CitationFormatter.parseBibliographicLine('Brown, A., & Green, B. (2021). Independent observations since 2003 in regional plants. Climate Studies, 12(3), 11-20.');
  expect(r,isNotNull);expect(r!.year,'2021');expect(r.title,'Independent observations since 2003 in regional plants');expect(r.authors.length,2);
 });

 test('partial initials or unconsumed author list never become a title',(){
  for(final raw in ['Kong, Q., Li, X.-F. & Fowler, H. J. Changes in summertime drought. Climate Studies 28, 100242 (2020).','Luyssaert, J. V. Campenhout, P. Bienstman, and V. Thourhout, J. Lightwave Technol. 23, 401 (2005).']) {
   final r=CitationFormatter.parseBibliographicLine(raw);
   if(r!=null){expect(r.title, isNot(startsWith('-F.')));expect(r.title,isNot(startsWith('Bienstman')));}
  }
 });

 test('mixed alphanumeric and supplemental locators are never truncated',(){
  for(final locator in ['e2022AB003421','3376-3393.e17','e135–e136']) {
   final r=CitationFormatter.parseBibliographicLine('Brown, A. Independent research on regional systems. Climate Studies 12, $locator (2023).');
   expect(r,isNotNull);expect(r!.pages,locator);
  }
 });
 test('numeric journal fragments are rejected rather than shifting volume',(){
  expect(CitationFormatter.parseBibliographicLine('Brown,A. A study of processes, Ann. Appl.Study.,15, no. 2, 1506–1535, (2005).'),isNull);
 });
 test('author separator colon is not part of an article title',(){
  final r=CitationFormatter.parseBibliographicLine('Brown, A., Green, B.: Independent research on regional systems. Climate Studies 12, 123–145 (2023).');
  expect(r,isNotNull);expect(r!.title,'Independent research on regional systems');
 });

}
