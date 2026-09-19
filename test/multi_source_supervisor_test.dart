import 'package:acadegate/features/supervisor_import/multi_source_supervisor_service.dart';
import 'package:acadegate/features/supervisor_import/official_university_directories.dart';
import 'package:acadegate/features/supervisor_import/orcid_client.dart';
import 'package:acadegate/features/supervisor_import/wikidata_academics_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ORCID expanded search parses name, affiliation, and id', () {
    final rows = OrcidClient.parseExpandedSearch({
      'expanded-result': [
        {
          'orcid-id': '0000-0002-1825-0097',
          'given-names': 'Josiah',
          'family-names': 'Carberry',
          'credit-name': '',
          'institution-name': ['Brown University'],
        },
      ],
    });

    expect(rows, hasLength(1));
    expect(rows.first.orcid, '0000-0002-1825-0097');
    expect(rows.first.name, contains('Carberry'));
    expect(rows.first.institutions, contains('Brown University'));
  });

  test('hits with the same ORCID merge sources instead of duplicating', () {
    final merged = MultiSourceSupervisorService.mergeHits([
      const SupervisorSourceHit(
        name: 'Ahmed Ali',
        institution: 'Fayoum University',
        orcid: '0000-0001-2345-6789',
        sources: ['ORCID'],
      ),
      const SupervisorSourceHit(
        name: 'Ahmed Ali',
        institution: 'Fayoum University',
        orcid: '0000-0001-2345-6789',
        openAlexId: 'A123',
        sources: ['OpenAlex'],
        citedByCount: 40,
      ),
    ]);

    expect(merged, hasLength(1));
    expect(merged.first.sources, containsAll(['ORCID', 'OpenAlex']));
    expect(merged.first.openAlexId, 'A123');
    expect(merged.first.citedByCount, 40);
  });

  test('Fayoum maps to the official university homepage', () {
    final dir = OfficialUniversityDirectories.match('جامعة الفيوم');
    expect(dir, isNotNull);
    expect(dir!.english, 'Fayoum University');
    expect(dir.homepage, contains('fayoum.edu.eg'));
  });

  test('Wikidata SPARQL bindings become named academics only', () {
    final rows = WikidataAcademicsClient.parseSparql({
      'results': {
        'bindings': [
          {
            'personLabel': {'value': 'Example Professor'},
            'employerLabel': {'value': 'Cairo University'},
            'orcid': {'value': '0000-0002-1825-0097'},
            'person': {'value': 'http://www.wikidata.org/entity/Q1'},
          },
          {
            'personLabel': {'value': 'Q'},
            'employerLabel': {'value': 'Cairo University'},
          },
        ],
      },
    });

    expect(rows, hasLength(1));
    expect(rows.first.name, 'Example Professor');
    expect(rows.first.orcid, '0000-0002-1825-0097');
  });
}
