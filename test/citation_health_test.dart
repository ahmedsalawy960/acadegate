import 'package:acadegate/features/academic_integrity/bibliography_harvest.dart';
import 'package:acadegate/features/academic_integrity/citation_health.dart';
import 'package:acadegate/features/academic_integrity/citation_health_service.dart';
import 'package:acadegate/features/academic_integrity/citation_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifies Crossref update types without inventing a DOI', () {
    expect(CitationHealthClassifier.classify('retraction'),
        CitationNoticeKind.retraction);
    expect(CitationHealthClassifier.classify('expression_of_concern'),
        CitationNoticeKind.expressionOfConcern);
    expect(CitationHealthClassifier.classify('erratum'),
        CitationNoticeKind.erratum);
    expect(CitationHealthClassifier.classify('correction'),
        CitationNoticeKind.correction);
    expect(CitationHealthClassifier.classify('new_edition'),
        CitationNoticeKind.other);
  });

  test('OpenAlex is_retracted becomes a retraction notice', () {
    final health = CitationHealthClassifier.fromOpenAlexRetracted(true);
    expect(health.isRetracted, isTrue);
    expect(health.notices.single.source, 'OpenAlex');
    expect(health.notices.single.noticeDoi, isNull);
  });

  test('retracted verified reference zeros the integrity score', () {
    const retracted = CitationHealth(
      notices: [
        CitationNotice(
          kind: CitationNoticeKind.retraction,
          source: 'Crossref',
          noticeDoi: '10.1000/notice-1',
        ),
      ],
    );
    final report = CitationCheckReport(
      items: [
        CitationCheckItem(
          citation: const ParsedCitation(
            index: 1,
            rawText: 'Smith 2018. Fake study. doi:10.1000/retracted',
            doi: '10.1000/retracted',
            titleGuess: 'Fake study',
            searchQuery: 'Fake study',
          ),
          match: const CitationMatch(
            status: CitationValidationStatus.verified,
            source: CitationDataSource.crossref,
            matchedTitle: 'Fake study',
            doi: '10.1000/retracted',
            health: retracted,
          ),
        ),
      ],
      verifiedCount: 1,
      partialCount: 0,
      notFoundCount: 0,
      invalidCount: 0,
      errorCount: 0,
    );
    expect(report.integrityScore, 0);
    expect(report.retractedCount, 1);

    final alerts = CitationHealthService.instance.alerts(report);
    expect(alerts, hasLength(1));
    expect(alerts.first.kind, 'error');
    expect(alerts.first.question, contains('Fake study'));
    expect(alerts.first.question.toLowerCase(), isNot(contains('10.9999')));
  });

  test('harvests bibliography after References heading and keeps DOIs as written', () {
    const text = '''
Methods
We used batch adsorption.

References
[1] Daun, J. K. Canola. 2011. doi:10.1000/canola
[2] Carrer, C. Oilseeds. 2018. https://doi.org/10.1000/oil
''';
    final harvested = BibliographyHarvest.fromThesisText(text);
    expect(harvested, contains('10.1000/canola'));
    expect(harvested, contains('10.1000/oil'));
    expect(harvested.toLowerCase(), isNot(contains('methods')));
  });

  test('snapshot headline flags retractions from registry notices only', () {
    const health = CitationHealth(
      notices: [
        CitationNotice(
          kind: CitationNoticeKind.retraction,
          source: 'OpenAlex',
        ),
      ],
    );
    final report = CitationCheckReport(
      items: [
        CitationCheckItem(
          citation: const ParsedCitation(
            index: 1,
            rawText: 'Retracted paper title 2019 doi:10.1000/r',
            doi: '10.1000/r',
            titleGuess: 'Retracted paper title',
            searchQuery: 'Retracted paper title',
          ),
          match: const CitationMatch(
            status: CitationValidationStatus.verified,
            source: CitationDataSource.openAlex,
            matchedTitle: 'Retracted paper title',
            doi: '10.1000/r',
            health: health,
          ),
        ),
      ],
      verifiedCount: 1,
      partialCount: 0,
      notFoundCount: 0,
      invalidCount: 0,
      errorCount: 0,
    );
    final snap = CitationHealthService.instance.snapshot(report);
    expect(snap.hasSerious, isTrue);
    expect(snap.retracted, 1);
    expect(snap.seriousTitles, contains('Retracted paper title'));
  });
}
