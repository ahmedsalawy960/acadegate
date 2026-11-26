import 'package:acadegate/features/academic_integrity/consensus_client.dart';
import 'package:acadegate/features/ai_advisor/assistant/assistant_tools.dart';
import 'package:flutter_test/flutter_test.dart';

ConsensusPaper _paper({
  String title = 'Biochar and yield',
  String doi = '10.1000/xyz999',
  int? year = 2022,
  String takeaway = 'Biochar improves crop yield in sandy soils.',
  String abstractText = 'A field study on biochar.',
}) {
  return ConsensusPaper(
    title: title,
    doi: doi,
    year: year,
    authors: 'A. Ali',
    journal: 'Soil Research',
    abstractText: abstractText,
    takeaway: takeaway,
    url: 'https://example.org/p1',
  );
}

void main() {
  group('check_research_evidence tool', () {
    test('is declared and has neutral labels', () {
      final names = AssistantToolbox.declarations
          .map((d) => d['name'] as String)
          .toList();
      expect(names, contains('check_research_evidence'));
      final status = AssistantToolbox.statusLabel('check_research_evidence');
      expect(status.contains('Consensus'), isFalse);
      expect(status.isNotEmpty, isTrue);
    });

    test('returns evidence statements and accumulates works', () async {
      final box = AssistantToolbox(
        consensusSearch: (query, {limit}) async => [_paper()],
      );
      final out = await box
          .execute('check_research_evidence', {'query': 'does biochar improve yield'});
      final results = out['results'] as List;
      expect(results, hasLength(1));
      final row = results.first as Map<String, dynamic>;
      expect(row['evidence'], contains('improves crop yield'));
      expect(row['abstract'], contains('field study'));
      expect(row['doi'], '10.1000/xyz999');
      expect(row['citation_apa'], contains('Biochar and yield'));
      // Works accumulate so the final answer DOI check recognizes them.
      expect(box.foundReferences.works, hasLength(1));
      expect(box.foundReferences.works.single.hasDoi, isTrue);
    });

    test('empty index response gives a fallback note, not an error', () async {
      final box = AssistantToolbox(
        consensusSearch: (query, {limit}) async => const <ConsensusPaper>[],
      );
      final out = await box
          .execute('check_research_evidence', {'query': 'obscure question'});
      expect(out['results'], isEmpty);
      expect('${out['note']}', contains('verified literature'));
    });

    test('short query is rejected; a throwing index surfaces {error}', () async {
      final box = AssistantToolbox(
        consensusSearch: (query, {limit}) async => throw StateError('down'),
      );
      final short = await box.execute('check_research_evidence', {'query': 'ab'});
      expect(short['error'], 'query too short');
      final boom = await box.execute(
          'check_research_evidence', {'query': 'a real question'});
      expect('${boom['error']}', contains('down'));
    });
  });
}
