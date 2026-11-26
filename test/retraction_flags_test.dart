import 'package:acadegate/features/acadegate_publish/academic_reference_lookup_service.dart';
import 'package:acadegate/features/academic_integrity/citation_health.dart';
import 'package:acadegate/features/academic_integrity/consensus_client.dart';
import 'package:acadegate/features/ai_advisor/assistant/assistant_tools.dart';
import 'package:acadegate/features/ai_advisor/grounded_reference_service.dart';
import 'package:acadegate/features/ai_advisor/grounded_work.dart';
import 'package:acadegate/features/research_supply_chain/research_goal.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_citation_report.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_kind.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_models.dart';
import 'package:flutter_test/flutter_test.dart';

GroundedWork _work({
  String title = 'Biochar improves wheat yield',
  String doi = '10.1000/xyz111',
  bool isRetracted = false,
}) {
  return GroundedWork(
    title: title,
    doi: doi,
    year: 2021,
    authors: 'A. Ali',
    source: 'Test',
    isRetracted: isRetracted,
  );
}

ThesisDraft _draftWith(List<GroundedWork> works) {
  const goal = ResearchGoal(raw: 'test goal', field: 'agronomy');
  return ThesisDraft(
    goal: goal,
    plan: const ThesisPlan(
      goal: goal,
      kind: ThesisKind.experimental,
      shape: ThesisShape.englishExperimentalMerged,
      arabic: false,
    ),
    literature: GroundedReferenceBundle(topic: 'biochar', works: works),
  );
}

void main() {
  group('GroundedWork retraction flag', () {
    test('mergeWorks keeps the flag when either record is retracted', () {
      final clean = _work();
      final flagged = _work(isRetracted: true);
      expect(
        GroundedReferenceService.mergeWorks(clean, flagged).isRetracted,
        isTrue,
      );
      expect(
        GroundedReferenceService.mergeWorks(flagged, clean).isRetracted,
        isTrue,
      );
      expect(
        GroundedReferenceService.mergeWorks(clean, _work()).isRetracted,
        isFalse,
      );
    });

    test('defaults to not retracted', () {
      expect(_work().isRetracted, isFalse);
    });
  });

  group('search_scientific_literature tool', () {
    test('flags retracted results and adds a warning note', () async {
      final box = AssistantToolbox(
        literatureSearch: (query, {limit}) async => GroundedReferenceBundle(
          topic: 'biochar',
          works: [_work(), _work(title: 'Retracted study', doi: '10.1000/xyz222', isRetracted: true)],
        ),
      );
      final out = await box
          .execute('search_scientific_literature', {'query': 'biochar yield'});
      final results = out['results'] as List;
      expect(results, hasLength(2));
      final first = results.first as Map<String, dynamic>;
      final second = results[1] as Map<String, dynamic>;
      expect(first.containsKey('retracted'), isFalse);
      expect(second['retracted'], isTrue);
      expect(out['note']?.toString() ?? '', contains('retracted'));
    });

    test('clean results carry no retraction note', () async {
      final box = AssistantToolbox(
        literatureSearch: (query, {limit}) async =>
            GroundedReferenceBundle(topic: 'biochar', works: [_work()]),
      );
      final out = await box
          .execute('search_scientific_literature', {'query': 'biochar yield'});
      final results = out['results'] as List;
      final row = results.first as Map<String, dynamic>;
      expect(row.containsKey('retracted'), isFalse);
      expect(out.containsKey('note'), isFalse);
    });
  });

  group('check_research_evidence tool', () {
    ConsensusPaper paper() => ConsensusPaper(
          title: 'Biochar and yield',
          doi: '10.1000/xyz999',
          year: 2022,
          authors: 'A. Ali',
          journal: 'Soil Research',
          abstractText: 'A field study on biochar.',
          takeaway: 'Biochar improves crop yield in sandy soils.',
          url: 'https://example.org/p1',
        );

    test('flags a retracted evidence paper via the registry health check', () async {
      const health = CitationHealth(notices: [
        CitationNotice(kind: CitationNoticeKind.retraction, source: 'Crossref'),
      ]);
      final box = AssistantToolbox(
        consensusSearch: (query, {limit}) async => [paper()],
        healthForDoi: (doi) async => health,
      );
      final out = await box.execute(
          'check_research_evidence', {'query': 'does biochar improve yield'});
      final results = out['results'] as List;
      final row = results.first as Map<String, dynamic>;
      expect(row['retracted'], isTrue);
      expect(out['note']?.toString() ?? '', contains('retracted'));
    });

    test('clean registry health leaves the result unflagged', () async {
      final box = AssistantToolbox(
        consensusSearch: (query, {limit}) async => [paper()],
        healthForDoi: (doi) async => CitationHealth.empty,
      );
      final out = await box.execute(
          'check_research_evidence', {'query': 'does biochar improve yield'});
      final results = out['results'] as List;
      final row = results.first as Map<String, dynamic>;
      expect(row.containsKey('retracted'), isFalse);
      expect(out.containsKey('note'), isFalse);
    });

    test('papers without DOI skip the health check entirely', () async {
      var calls = 0;
      final box = AssistantToolbox(
        consensusSearch: (query, {limit}) async => [
          ConsensusPaper(
            title: 'No DOI paper',
            doi: '',
            year: 2020,
            authors: 'B. Baker',
            journal: 'Field Crops',
            abstractText: 'No identifier.',
            takeaway: 'Some statement.',
            url: 'https://example.org/p2',
          ),
        ],
        healthForDoi: (doi) async {
          calls++;
          return CitationHealth.empty;
        },
      );
      await box.execute(
          'check_research_evidence', {'query': 'does biochar improve yield'});
      expect(calls, 0);
    });
  });

  group('verifyPastedBibliography', () {
    test('marks retracted verified DOIs with a brand-neutral warning', () async {
      final report = await GroundedReferenceService.instance
          .verifyPastedBibliography(
        'Ali, A. (2021). Biochar improves wheat yield. https://doi.org/10.1000/xyz111',
        statusLookup: (doi) async =>
            DoiCheckResult(_work(isRetracted: true), answered: true),
      );
      final warned =
          report.contains('Retracted') || report.contains('مسحوبة');
      expect(warned, isTrue, reason: report);
      expect(report.contains('OpenAlex'), isFalse, reason: report);
      expect(report.contains('Crossref'), isFalse, reason: report);
    });

    test('clean verified DOIs get no retraction warning', () async {
      final report = await GroundedReferenceService.instance
          .verifyPastedBibliography(
        'Ali, A. (2021). Biochar improves wheat yield. https://doi.org/10.1000/xyz111',
        statusLookup: (doi) async => DoiCheckResult(_work(), answered: true),
      );
      final warned =
          report.contains('Retracted') || report.contains('مسحوبة');
      expect(warned, isFalse, reason: report);
    });
  });

  group('Publishing portal hits', () {
    test('AcademicWorkHit carries the retraction flag', () {
      const hit = AcademicWorkHit(
        title: 'Retracted paper',
        source: 'OpenAlex',
        isRetracted: true,
      );
      expect(hit.isRetracted, isTrue);
      const clean = AcademicWorkHit(title: 'Clean paper', source: 'Crossref');
      expect(clean.isRetracted, isFalse);
    });
  });

  group('Thesis citation report', () {
    test('lists retracted catalog works and warns in the text report', () {
      final draft = _draftWith([
        _work(),
        _work(title: 'Retracted study', doi: '10.1000/xyz222', isRetracted: true),
      ]);
      final report = ThesisCitationReport.fromDraft(draft);
      expect(report.retractedIndexes, [2]);
      final textEn = report.asText(arabic: false);
      expect(textEn, contains('Retracted references: [2]'));
      final textAr = report.asText(arabic: true);
      expect(textAr, contains('مسحوبة'));
    });

    test('clean drafts report no retracted references', () {
      final report = ThesisCitationReport.fromDraft(_draftWith([_work()]));
      expect(report.retractedIndexes, isEmpty);
      expect(report.asText(arabic: false), isNot(contains('Retracted')));
    });
  });
}
