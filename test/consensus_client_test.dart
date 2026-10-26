import 'package:acadegate/features/academic_integrity/consensus_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('consensus payload keeps doi abstract and takeaway', () {
    final papers = ConsensusClient.papersFromBody('''
{
  "papers": [
    {
      "title": "Creatine and working memory",
      "doi": "10.1000/example",
      "year": 2021,
      "authors": "Ada Lovelace, Alan Turing",
      "journal": "Journal of Example Studies",
      "abstract": "A randomized trial of creatine.",
      "takeaway": "Working memory improved.",
      "url": "https://consensus.app/papers/example"
    },
    { "title": "" }
  ]
}
''');

    expect(papers, hasLength(1));
    expect(papers.single.doi, '10.1000/example');
    expect(papers.single.year, 2021);
    expect(papers.single.authors, contains('Ada Lovelace'));
    expect(
      papers.single.groundedAbstract,
      contains('A randomized trial of creatine.'),
    );
    expect(papers.single.groundedAbstract, contains('Working memory improved.'));
  });
}
