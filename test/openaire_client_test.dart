import 'dart:convert';

import 'package:acadegate/features/academic_integrity/citation_http.dart';
import 'package:acadegate/features/academic_integrity/openaire_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

Map<String, dynamic> _record({
  dynamic title = const {r'$': 'Soybean yield under drip irrigation'},
  dynamic pid = const [
    {r'@classid': 'pmid', r'$': 19287680},
    {r'@classid': 'doi', r'$': '10.2134/agronj1994.00021962008600050009x'},
  ],
  dynamic dateofacceptance = const {r'$': '2011-07-14'},
  dynamic creator = const [
    {r'@rank': '1', r'$': 'D B, Weaver'},
    {r'@rank': '2', r'$': 'R, Rodriguez-Kabana'},
  ],
  dynamic journal = const {r'$': 'Journal of Nematology'},
  dynamic description = const {r'$': 'Yield differed among cultivars.'},
  dynamic bestaccessright = const {r'@classid': 'OPEN'},
  dynamic measure = const [
    {r'@id': 'influence', r'@score': '2.63E-9'},
    {r'@id': 'citationCount', r'@score': '14'},
  ],
  dynamic children = const {
    'instance': {
      'webresource': {
        'url': {r'$': 'https://example.org/record1'},
      },
    },
  },
}) {
  return {
    'metadata': {
      'oaf:entity': {
        'oaf:result': {
          'title': title,
          'pid': pid,
          'dateofacceptance': dateofacceptance,
          'creator': creator,
          'journal': journal,
          'description': description,
          'bestaccessright': bestaccessright,
          'measure': measure,
          'children': children,
        },
      },
    },
  };
}

http.Response _ok(Object body) =>
    http.Response(jsonEncode(body), 200);

void main() {
  setUp(() {
    CitationHttp.debugGet = null;
  });

  tearDown(() {
    CitationHttp.debugGet = null;
  });

  group('OpenAireClient.search', () {
    test('parses a list of records with doi, year, authors, metrics', () async {
      CitationHttp.debugGet = (uri, {headers}) async => _ok({
            'response': {
              'header': {
                'total': {r'$': 2},
              },
              'results': {
                'result': [_record(), _record()],
              },
            },
          });
      final works = await OpenAireClient.instance.search('soybean yield');
      expect(works, hasLength(2));
      final w = works.first;
      expect(w.title, 'Soybean yield under drip irrigation');
      expect(w.doi, '10.2134/agronj1994.00021962008600050009x');
      expect(w.year, 2011);
      expect(w.authors, 'D B, Weaver; R, Rodriguez-Kabana');
      expect(w.journal, 'Journal of Nematology');
      expect(w.abstractText, contains('Yield differed'));
      expect(w.url, 'https://example.org/record1');
      expect(w.isOpenAccess, isTrue);
      expect(w.citationCount, 14);
    });

    test('handles a single result returned as a bare object', () async {
      CitationHttp.debugGet = (uri, {headers}) async => _ok({
            'response': {
              'results': {
                'result': _record(),
              },
            },
          });
      final works = await OpenAireClient.instance.search('soybean');
      expect(works, hasLength(1));
      expect(works.single.doi, isNotNull);
    });

    test('handles pid as a single doi object', () async {
      CitationHttp.debugGet = (uri, {headers}) async => _ok({
            'response': {
              'results': {
                'result': _record(
                  pid: {r'@classid': 'doi', r'$': '10.1000/single.doi'},
                ),
              },
            },
          });
      final works = await OpenAireClient.instance.search('soybean');
      expect(works.single.doi, '10.1000/single.doi');
    });

    test('tolerates missing optional fields', () async {
      CitationHttp.debugGet = (uri, {headers}) async => _ok({
            'response': {
              'results': {
                'result': _record(
                  pid: null,
                  dateofacceptance: null,
                  creator: null,
                  journal: null,
                  description: null,
                  bestaccessright: null,
                  measure: null,
                  children: null,
                ),
              },
            },
          });
      final w = (await OpenAireClient.instance.search('soybean')).single;
      expect(w.doi, isNull);
      expect(w.year, isNull);
      expect(w.authors, isNull);
      expect(w.journal, isNull);
      expect(w.abstractText, isEmpty);
      expect(w.url, isNull);
      expect(w.isOpenAccess, isFalse);
      expect(w.citationCount, isNull);
    });

    test('empty results node yields an empty list', () async {
      CitationHttp.debugGet = (uri, {headers}) async => _ok({
            'response': {'results': null},
          });
      expect(await OpenAireClient.instance.search('zzz nothing'), isEmpty);
    });

    test('non-200 yields an empty list', () async {
      CitationHttp.debugGet =
          (uri, {headers}) async => http.Response('busy', 429);
      expect(await OpenAireClient.instance.search('soybean'), isEmpty);
    });

    test('blank and tiny queries are not sent', () async {
      var calls = 0;
      CitationHttp.debugGet = (uri, {headers}) async {
        calls++;
        return _ok({'response': {'results': null}});
      };
      expect(await OpenAireClient.instance.search('  '), isEmpty);
      expect(await OpenAireClient.instance.search('ab'), isEmpty);
      expect(calls, 0);
    });

    test('fromYear maps to fromDateAccepted and limit clamps size', () async {
      Uri? seen;
      CitationHttp.debugGet = (uri, {headers}) async {
        seen = uri;
        return _ok({'response': {'results': null}});
      };
      await OpenAireClient.instance
          .search('irrigation', limit: 500, fromYear: 2020);
      expect(seen, isNotNull);
      expect(seen!.queryParameters['fromDateAccepted'], '2020-01-01');
      expect(seen!.queryParameters['size'], '50');
      expect(seen!.queryParameters['format'], 'json');
      expect(seen!.queryParameters['keywords'], 'irrigation');
    });

    test('records without a title are dropped', () async {
      CitationHttp.debugGet = (uri, {headers}) async => _ok({
            'response': {
              'results': {
                'result': [
                  _record(title: null),
                  _record(),
                ],
              },
            },
          });
      final works = await OpenAireClient.instance.search('soybean');
      expect(works, hasLength(1));
    });
  });
}
