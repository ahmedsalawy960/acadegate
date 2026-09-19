import 'package:acadegate/features/supervisor_metrics/supervisor_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concept scores become percents like analytical chemistry 94%', () {
    final topics = SupervisorIdentity.topicsFromAuthor({
      'x_concepts': [
        {'display_name': 'Analytical chemistry', 'score': 0.94, 'level': 2},
        {'display_name': 'Nanomaterials', 'score': 0.87, 'level': 2},
        {'display_name': 'Adsorption', 'score': 81, 'level': 2},
        {'display_name': 'Chemistry', 'score': 0.9, 'level': 0},
        {'display_name': 'Weak', 'score': 0.1, 'level': 2},
      ],
    });

    expect(topics.map((t) => t.label).toList(), [
      'Analytical chemistry 94%',
      'Nanomaterials 87%',
      'Adsorption 81%',
    ]);
  });

  test('topics use share relative to the strongest axis', () {
    final topics = SupervisorIdentity.topicsFromAuthor({
      'topics': [
        {'display_name': 'Analytical chemistry', 'count': 40},
        {'display_name': 'Nanomaterials', 'count': 35},
        {'display_name': 'GC/MS', 'count': 27},
      ],
    });

    expect(topics.first.label, 'Analytical chemistry 100%');
    expect(topics[1].label, 'Nanomaterials 88%');
    expect(topics[2].label, 'GC/MS 68%');
  });

  test('collaborators skip the supervisor and keep joint work counts', () {
    final people = SupervisorIdentity.collaboratorsFromWorks(
      selfOpenAlexId: 'https://openalex.org/A1',
      works: [
        {
          'authorships': [
            {
              'author': {
                'id': 'https://openalex.org/A1',
                'display_name': 'Self',
              },
            },
            {
              'author': {
                'id': 'https://openalex.org/A2',
                'display_name': 'Co Author',
              },
              'institutions': [
                {'display_name': 'Cairo University'},
              ],
            },
          ],
        },
        {
          'authorships': [
            {
              'author': {
                'id': 'https://openalex.org/A2',
                'display_name': 'Co Author',
              },
            },
          ],
        },
      ],
    );

    expect(people, hasLength(1));
    expect(people.first.name, 'Co Author');
    expect(people.first.institution, 'Cairo University');
    expect(people.first.jointWorks, 2);
  });

  test('works prefer an OA PDF, then DOI, and skip untitled rows', () {
    final works = SupervisorIdentity.worksFromOpenAlex([
      {'title': ''},
      {
        'display_name': 'Adsorption of dyes',
        'publication_year': 2024,
        'cited_by_count': 5,
        'doi': '10.1000/xyz',
        'primary_location': {
          'landing_page_url': 'https://journal.example/paper',
          'source': {'display_name': 'Talanta'},
        },
        'best_oa_location': {
          'pdf_url': 'https://files.example/paper.pdf',
        },
      },
      {
        'title': 'GC/MS method',
        'doi': 'https://doi.org/10.1000/abc',
      },
    ]);

    expect(works, hasLength(2));
    expect(works.first.title, 'Adsorption of dyes');
    expect(works.first.venue, 'Talanta');
    expect(works.first.hasPdf, isTrue);
    expect(works.first.openUrl, 'https://files.example/paper.pdf');
    expect(works.last.openUrl, 'https://doi.org/10.1000/abc');
    expect(works.last.hasPdf, isFalse);
  });
}
