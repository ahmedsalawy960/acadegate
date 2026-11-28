import 'package:acadegate/features/acadegate_publish/citation_formatter.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:flutter_test/flutter_test.dart';

String _chicago(PublishReference r) => CitationFormatter.buildBibliographyEntry(
        reference: r, style: PublishCitationStyle.chicago, index: 1)
    .plain;

PublishReference _first(String line) =>
    ManuscriptDocumentParser.parseReferencesFromText('References\n1. $line\n2. $line').first;

void main() {
  test('compact "Surname AB" authors are not flipped in Chicago', () {
    final r = CitationFormatter.parseBibliographicLine(
        'Werneck GL, Batista MS, Gomes JR (2003) Prognostic factors for death from visceral leishmaniasis in Teresina, Brazil. Infection 31: 174-177.')!;
    final out = _chicago(r);
    expect(out, startsWith('Werneck, G. L.'));
    expect(out, isNot(contains('GL, Werneck')));
  });

  test('"Journal vol: pages" in the container is split so pages print once', () {
    final r = CitationFormatter.parseBibliographicLine(
        'Werneck GL, Batista MS, Gomes JR (2003) Prognostic factors for death from visceral leishmaniasis in Teresina, Brazil. Infection 31: 174-177.')!;
    expect(r.container, 'Infection');
    expect(r.volume, '31');
    expect(r.pages, '174-177');
    final out = _chicago(r);
    expect(RegExp('174-177').allMatches(out).length, 1);
  });

  test('NLM "YYYY Mon;vol(issue):pages" keeps title, journal and authors', () {
    final r = _first(
        'de Cock M, Maas YGH, van de Bor M. Does perinatal exposure to endocrine disruptors induce autism spectrum disorders? Acta Paediatrica. 2012 Aug;101(8):811-8.');
    expect(r.title, startsWith('Does perinatal exposure'));
    expect(r.title, isNot(contains('Aug;')));
    expect(r.container, 'Acta Paediatrica');
    expect(r.volume, '101');
    expect(r.issue, '8');
    expect(r.pages, '811-8');
    expect(r.authors.length, 3);
  });

  test('Chicago does not add a period after a question mark title', () {
    final r = _first(
        'Smith AB, Jones CD. Does perinatal exposure matter in rats? Pediatr Res. 2012 Aug;101(8):811-8.');
    final out = _chicago(r);
    expect(out, contains('rats?"'));
    expect(out, isNot(contains('?."')));
  });
}
