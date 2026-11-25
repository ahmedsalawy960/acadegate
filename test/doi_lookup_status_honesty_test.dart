import 'package:acadegate/features/academic_integrity/citation_http.dart';
import 'package:acadegate/features/academic_integrity/crossref_client.dart';
import 'package:acadegate/features/academic_integrity/openalex_works_client.dart';
import 'package:acadegate/features/academic_integrity/semantic_scholar_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  void stubStatus(int status, [String body = '{}']) {
    CitationHttp.debugGet =
        (uri, {headers}) async => http.Response(body, status);
  }

  tearDown(() {
    CitationHttp.debugGet = null;
  });

  group('DOI lookup status honesty', () {
    test('404 means not found, never an error', () async {
      stubStatus(404);
      expect(await OpenAlexWorksClient.instance.lookupDoi('10.1000/x'), isNull);
      expect(await SemanticScholarClient.instance.lookupDoi('10.1000/x'), isNull);
      expect(await CrossrefClient.instance.lookupDoi('10.1000/x'), isNull);
    });

    test('429 rate limit throws so the check is reported as unanswered', () async {
      stubStatus(429);
      expect(
        () => OpenAlexWorksClient.instance.lookupDoi('10.1000/x'),
        throwsA(predicate((e) => '$e'.contains('429'))),
      );
      expect(
        () => SemanticScholarClient.instance.lookupDoi('10.1000/x'),
        throwsA(predicate((e) => '$e'.contains('429'))),
      );
    });

    test('server errors throw on all three indexes', () async {
      stubStatus(500);
      for (final lookup in [
        OpenAlexWorksClient.instance.lookupDoi,
        SemanticScholarClient.instance.lookupDoi,
        CrossrefClient.instance.lookupDoi,
      ]) {
        expect(() => lookup('10.1000/x'), throwsA(anything));
      }
    });

    test('a valid 200 body still parses', () async {
      stubStatus(200, '{"title": "A paper", "publication_year": 2023, '
          '"doi": "https://doi.org/10.1000/x", "authorships": []}');
      final work = await OpenAlexWorksClient.instance.lookupDoi('10.1000/x');
      expect(work, isNotNull);
      expect(work!.title, 'A paper');
    });
  });
}
