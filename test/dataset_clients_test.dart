import 'dart:convert';

import 'package:acadegate/features/academic_integrity/citation_http.dart';
import 'package:acadegate/features/academic_integrity/datacite_client.dart';
import 'package:acadegate/features/academic_integrity/zenodo_client.dart';
import 'package:acadegate/features/ai_advisor/grounded_reference_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

http.Response _ok(Object body) => http.Response(jsonEncode(body), 200);

Map<String, dynamic> _dataciteItem({
  String doi = '10.5281/zenodo.24530466',
  String title = 'Irrigation under climate change',
  int? year = 2026,
  dynamic creators = const [
    {'name': 'Hotamboyeva Zarnigor'},
    {'name': 'Yormatova Aziza'},
  ],
  String? publisher = 'Zenodo',
  String? abstractText = 'Spatially explicit irrigation outputs.',
  String? url = 'https://zenodo.org/doi/10.5281/zenodo.24530466',
  int? citationCount = 3,
}) {
  return {
    'id': doi,
    'attributes': {
      'doi': doi,
      'titles': [
        {'title': title},
      ],
      'creators': creators,
      'publisher': publisher,
      'publicationYear': year,
      'descriptions': abstractText == null
          ? const []
          : [
              {'descriptionType': 'Abstract', 'description': abstractText},
            ],
      'url': url,
      'citationCount': citationCount,
    },
  };
}

Map<String, dynamic> _zenodoItem({
  String doi = '10.5281/zenodo.19813576',
  String title = 'Data for: sustainable irrigation limits',
  String publicationDate = '2026-04-27',
  dynamic creators = const [
    {'name': 'Anonymous'},
  ],
  String description = '<p>The dataset supporting the paper.</p>',
  String selfHtml = 'https://zenodo.org/records/19813576',
  String accessRight = 'open',
}) {
  return {
    'doi': doi,
    'metadata': {
      'title': title,
      'publication_date': publicationDate,
      'description': description,
      'creators': creators,
      'access_right': accessRight,
    },
    'links': {'self_html': selfHtml},
  };
}

void main() {
  setUp(() {
    CitationHttp.debugGet = null;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    CitationHttp.debugGet = null;
  });

  group('DataCiteClient.searchDatasets', () {
    test('parses attributes: title, doi, year, creators, abstract, count',
        () async {
      CitationHttp.debugGet = (uri, {headers}) async => _ok({
            'data': [_dataciteItem()],
          });
      final out = await DataCiteClient.instance.searchDatasets('irrigation');
      expect(out, hasLength(1));
      final ds = out.single;
      expect(ds.title, 'Irrigation under climate change');
      expect(ds.doi, '10.5281/zenodo.24530466');
      expect(ds.year, 2026);
      expect(ds.authors, 'Hotamboyeva Zarnigor; Yormatova Aziza');
      expect(ds.publisher, 'Zenodo');
      expect(ds.abstractText, contains('Spatially explicit'));
      expect(ds.citationCount, 3);
    });

    test('sends dataset filter and clamps size', () async {
      Uri? seen;
      CitationHttp.debugGet = (uri, {headers}) async {
        seen = uri;
        return _ok({'data': const []});
      };
      await DataCiteClient.instance.searchDatasets('irrigation', limit: 500);
      expect(seen!.host, 'api.datacite.org');
      expect(seen!.queryParameters['resource-type-id'], 'dataset');
      expect(seen!.queryParameters['page[size]'], '25');
      expect(seen!.queryParameters['query'], 'irrigation');
    });

    test('tolerates missing optional fields and untitled items', () async {
      CitationHttp.debugGet = (uri, {headers}) async => _ok({
            'data': [
              _dataciteItem(
                year: null,
                creators: const [],
                publisher: null,
                abstractText: null,
                url: null,
                citationCount: null,
              ),
              _dataciteItem(title: ''),
            ],
          });
      final out = await DataCiteClient.instance.searchDatasets('irrigation');
      expect(out, hasLength(1));
      expect(out.single.year, isNull);
      expect(out.single.authors, isNull);
      expect(out.single.publisher, isNull);
      expect(out.single.abstractText, isEmpty);
      expect(out.single.citationCount, isNull);
    });

    test('non-200 and malformed bodies yield empty lists', () async {
      CitationHttp.debugGet =
          (uri, {headers}) async => http.Response('busy', 429);
      expect(await DataCiteClient.instance.searchDatasets('x y z'), isEmpty);
      CitationHttp.debugGet =
          (uri, {headers}) async => http.Response('<html>', 200);
      expect(await DataCiteClient.instance.searchDatasets('x y z'), isEmpty);
    });
  });

  group('ZenodoClient.searchDatasets', () {
    test('parses hits: title, doi, year, creators, HTML-stripped abstract',
        () async {
      CitationHttp.debugGet = (uri, {headers}) async => _ok({
            'hits': {
              'hits': [_zenodoItem()],
            },
          });
      final out = await ZenodoClient.instance.searchDatasets('irrigation');
      expect(out, hasLength(1));
      final ds = out.single;
      expect(ds.title, 'Data for: sustainable irrigation limits');
      expect(ds.doi, '10.5281/zenodo.19813576');
      expect(ds.year, 2026);
      expect(ds.authors, 'Anonymous');
      expect(ds.abstractText, 'The dataset supporting the paper.');
      expect(ds.url, 'https://zenodo.org/records/19813576');
      expect(ds.accessRight, 'open');
    });

    test('sends type=dataset and bestmatch sort', () async {
      Uri? seen;
      CitationHttp.debugGet = (uri, {headers}) async {
        seen = uri;
        return _ok({
          'hits': {'hits': const []},
        });
      };
      await ZenodoClient.instance.searchDatasets('irrigation');
      expect(seen!.host, 'zenodo.org');
      expect(seen!.queryParameters['type'], 'dataset');
      expect(seen!.queryParameters['sort'], 'bestmatch');
    });

    test('missing hits node and non-200 yield empty lists', () async {
      CitationHttp.debugGet = (uri, {headers}) async => _ok({'nope': true});
      expect(await ZenodoClient.instance.searchDatasets('x y z'), isEmpty);
      CitationHttp.debugGet =
          (uri, {headers}) async => http.Response('no', 500);
      expect(await ZenodoClient.instance.searchDatasets('x y z'), isEmpty);
    });
  });

  group('dataset sources in searchTopic', () {
    test('datasets from both sources merge into the bundle, DOI-deduped',
        () async {
      const sharedDoi = '10.5281/zenodo.24530466';
      CitationHttp.debugGet = (uri, {headers}) async {
        if (uri.host == 'api.datacite.org') {
          return _ok({
            'data': [_dataciteItem()],
          });
        }
        if (uri.host == 'zenodo.org') {
          return _ok({
            'hits': {
              'hits': [_zenodoItem(doi: sharedDoi)],
            },
          });
        }
        return http.Response('unavailable', 500);
      };
      final bundle = await GroundedReferenceService.instance
          .searchTopic('irrigation', limit: 10);
      final matches = bundle.works
          .where((w) => w.doi.toLowerCase() == sharedDoi)
          .toList();
      expect(matches, hasLength(1));
      expect(matches.single.citationCount, 3);
    });
  });
}
