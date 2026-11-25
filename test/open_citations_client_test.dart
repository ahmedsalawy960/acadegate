import 'dart:convert';

import 'package:acadegate/features/academic_integrity/citation_http.dart';
import 'package:acadegate/features/academic_integrity/open_citations_client.dart';
import 'package:acadegate/features/ai_advisor/grounded_reference_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

http.Response _ok(Object body) => http.Response(jsonEncode(body), 200);

void main() {
  setUp(() {
    CitationHttp.debugGet = null;
  });

  tearDown(() {
    CitationHttp.debugGet = null;
  });

  group('OpenCitationsClient.citationCount', () {
    test('parses the string count COCI returns', () async {
      CitationHttp.debugGet = (uri, {headers}) async => _ok([
            {'count': '1806'},
          ]);
      expect(
        await OpenCitationsClient.instance.citationCount('10.1038/nature12373'),
        1806,
      );
    });

    test('accepts an integer count', () async {
      CitationHttp.debugGet = (uri, {headers}) async => _ok([
            {'count': 7},
          ]);
      expect(
        await OpenCitationsClient.instance.citationCount('10.1000/xyz123'),
        7,
      );
    });

    test('strips a doi.org prefix and encodes the slash in the path', () async {
      Uri? seen;
      CitationHttp.debugGet = (uri, {headers}) async {
        seen = uri;
        return _ok([
          {'count': '3'},
        ]);
      };
      await OpenCitationsClient.instance
          .citationCount('https://doi.org/10.1038/nature12373');
      expect(seen, isNotNull);
      expect(seen!.host, 'opencitations.net');
      expect(seen!.path, contains('10.1038%2Fnature12373'));
    });

    test('unindexed DOI (empty array) yields null', () async {
      CitationHttp.debugGet = (uri, {headers}) async => _ok(const []);
      expect(
        await OpenCitationsClient.instance.citationCount('10.1000/nope'),
        isNull,
      );
    });

    test('non-200 yields null', () async {
      CitationHttp.debugGet =
          (uri, {headers}) async => http.Response('missing', 404);
      expect(
        await OpenCitationsClient.instance.citationCount('10.1000/nope'),
        isNull,
      );
    });

    test('malformed body yields null', () async {
      CitationHttp.debugGet =
          (uri, {headers}) async => http.Response('<html>oops', 200);
      expect(
        await OpenCitationsClient.instance.citationCount('10.1000/nope'),
        isNull,
      );
    });

    test('negative count yields null', () async {
      CitationHttp.debugGet = (uri, {headers}) async => _ok([
            {'count': '-4'},
          ]);
      expect(
        await OpenCitationsClient.instance.citationCount('10.1000/nope'),
        isNull,
      );
    });

    test('invalid DOIs are not sent', () async {
      var calls = 0;
      CitationHttp.debugGet = (uri, {headers}) async {
        calls++;
        return _ok(const []);
      };
      expect(await OpenCitationsClient.instance.citationCount(''), isNull);
      expect(await OpenCitationsClient.instance.citationCount('abc'), isNull);
      expect(calls, 0);
    });
  });

  group('GroundedReferenceService citation-count enrichment', () {
    test('fills a missing count from COCI on the final works', () async {
      const doi = '10.2134/agronj1994.00021962008600050009x';
      CitationHttp.debugGet = (uri, {headers}) async {
        if (uri.host == 'api.openaire.eu') {
          return _ok({
            'response': {
              'results': {
                'result': {
                  'metadata': {
                    'oaf:entity': {
                      'oaf:result': {
                        'title': {r'$': 'Soybean yield under drip irrigation'},
                        'pid': {r'@classid': 'doi', r'$': doi},
                        'dateofacceptance': {r'$': '2011-07-14'},
                        'creator': {r'@rank': '1', r'$': 'D B, Weaver'},
                        'journal': {r'$': 'Journal of Nematology'},
                      },
                    },
                  },
                },
              },
            },
          });
        }
        if (uri.host == 'opencitations.net') {
          return _ok([
            {'count': '42'},
          ]);
        }
        return http.Response('unavailable', 500);
      };

      final bundle = await GroundedReferenceService.instance
          .searchTopic('soybean yield', limit: 5);
      expect(bundle.works, isNotEmpty);
      final work =
          bundle.works.firstWhere((w) => w.doi.toLowerCase() == doi);
      expect(work.citationCount, 42);
    });

    test('leaves works alone when COCI has no answer', () async {
      const doi = '10.2134/agronj1994.00021962008600050009x';
      CitationHttp.debugGet = (uri, {headers}) async {
        if (uri.host == 'api.openaire.eu') {
          return _ok({
            'response': {
              'results': {
                'result': {
                  'metadata': {
                    'oaf:entity': {
                      'oaf:result': {
                        'title': {r'$': 'Soybean yield under drip irrigation'},
                        'pid': {r'@classid': 'doi', r'$': doi},
                        'dateofacceptance': {r'$': '2011-07-14'},
                      },
                    },
                  },
                },
              },
            },
          });
        }
        return http.Response('unavailable', 500);
      };

      final bundle = await GroundedReferenceService.instance
          .searchTopic('soybean yield', limit: 5);
      expect(bundle.works, isNotEmpty);
      final work =
          bundle.works.firstWhere((w) => w.doi.toLowerCase() == doi);
      expect(work.citationCount, isNull);
    });
  });
}
