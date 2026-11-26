import 'dart:convert';

import 'package:acadegate/features/academic_integrity/citation_http.dart';
import 'package:acadegate/features/academic_integrity/zotero_client.dart';
import 'package:acadegate/features/academic_integrity/zotero_connection_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _item({
  String key = 'ABC123',
  String itemType = 'journalArticle',
  String title = 'Drip irrigation and soybean yield',
  String doi = '10.2134/agronj1994.00021962008600050009x',
  String date = '2011-07-14',
  dynamic creators = const [
    {'creatorType': 'author', 'firstName': 'D B', 'lastName': 'Weaver'},
    {'creatorType': 'author', 'name': 'R Rodriguez-Kabana'},
    {'creatorType': 'editor', 'name': 'Skip Me'},
  ],
  String journal = 'Journal of Nematology',
  String abstractNote = 'Yield differed among cultivars.',
  String url = 'https://example.org/record1',
}) {
  return {
    'key': key,
    'data': {
      'key': key,
      'itemType': itemType,
      'title': title,
      'DOI': doi,
      'date': date,
      'creators': creators,
      'publicationTitle': journal,
      'abstractNote': abstractNote,
      'url': url,
    },
  };
}

http.Response _ok(Object body) => http.Response(jsonEncode(body), 200);

void main() {
  setUp(() {
    CitationHttp.debugGet = null;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    CitationHttp.debugGet = null;
  });

  group('ZoteroClient.searchItems', () {
    test('parses items: authors, year from date, doi, journal', () async {
      CitationHttp.debugGet = (uri, {headers}) async => _ok([_item()]);
      final works = await ZoteroClient.instance.searchItems(
        userId: '123456',
        apiKey: 'key',
        query: 'soybean',
      );
      expect(works, hasLength(1));
      final w = works.single;
      expect(w.title, 'Drip irrigation and soybean yield');
      expect(w.doi, '10.2134/agronj1994.00021962008600050009x');
      expect(w.year, 2011);
      expect(w.authors, 'D B Weaver; R Rodriguez-Kabana');
      expect(w.journal, 'Journal of Nematology');
      expect(w.abstractText, contains('Yield differed'));
      expect(w.url, 'https://example.org/record1');
      expect(w.itemType, 'journalArticle');
    });

    test('sends the API key header and query params', () async {
      Uri? seen;
      Map<String, String>? seenHeaders;
      CitationHttp.debugGet = (uri, {headers}) async {
        seen = uri;
        seenHeaders = headers;
        return _ok(const []);
      };
      await ZoteroClient.instance.searchItems(
        userId: '123456',
        apiKey: 'secretkey',
        query: 'drip irrigation',
        limit: 500,
      );
      expect(seen!.host, 'api.zotero.org');
      expect(seen!.path, '/users/123456/items');
      expect(seen!.queryParameters['q'], 'drip irrigation');
      expect(seen!.queryParameters['qmode'], 'everything');
      expect(seen!.queryParameters['limit'], '50');
      expect(seenHeaders?['Zotero-API-Key'], 'secretkey');
    });

    test('skips attachments, notes, and untitled items', () async {
      CitationHttp.debugGet = (uri, {headers}) async => _ok([
            _item(itemType: 'attachment', key: 'A1'),
            _item(itemType: 'note', key: 'A2'),
            _item(title: '', key: 'A3'),
            _item(key: 'A4'),
          ]);
      final works = await ZoteroClient.instance.searchItems(
        userId: '123456',
        apiKey: 'key',
        query: 'soybean',
      );
      expect(works, hasLength(1));
      expect(works.single.key, 'A4');
    });

    test('extracts the year from free-form dates', () async {
      CitationHttp.debugGet = (uri, {headers}) async => _ok([
            _item(date: 'May 2017', key: 'Y1'),
            _item(date: '2017', key: 'Y2'),
            _item(date: '', key: 'Y3'),
          ]);
      final works = await ZoteroClient.instance.searchItems(
        userId: '123456',
        apiKey: 'key',
        query: 'soybean',
      );
      expect(works[0].year, 2017);
      expect(works[1].year, 2017);
      expect(works[2].year, isNull);
    });

    test('non-200 and malformed bodies yield empty lists', () async {
      CitationHttp.debugGet =
          (uri, {headers}) async => http.Response('forbidden', 403);
      expect(
        await ZoteroClient.instance
            .searchItems(userId: '1', apiKey: 'k', query: 'soybean'),
        isEmpty,
      );
      CitationHttp.debugGet =
          (uri, {headers}) async => http.Response('<html>', 200);
      expect(
        await ZoteroClient.instance
            .searchItems(userId: '1', apiKey: 'k', query: 'soybean'),
        isEmpty,
      );
    });

    test('blank credentials or query are not sent', () async {
      var calls = 0;
      CitationHttp.debugGet = (uri, {headers}) async {
        calls++;
        return _ok(const []);
      };
      expect(
        await ZoteroClient.instance
            .searchItems(userId: '', apiKey: 'k', query: 'soybean'),
        isEmpty,
      );
      expect(
        await ZoteroClient.instance
            .searchItems(userId: '1', apiKey: '', query: 'soybean'),
        isEmpty,
      );
      expect(
        await ZoteroClient.instance
            .searchItems(userId: '1', apiKey: 'k', query: 'ab'),
        isEmpty,
      );
      expect(calls, 0);
    });
  });

  group('ZoteroClient.validate', () {
    test('true on 200, false on 403/404 and blank input', () async {
      CitationHttp.debugGet = (uri, {headers}) async => _ok(const []);
      expect(
        await ZoteroClient.instance.validate(userId: '1', apiKey: 'k'),
        isTrue,
      );
      CitationHttp.debugGet =
          (uri, {headers}) async => http.Response('no', 403);
      expect(
        await ZoteroClient.instance.validate(userId: '1', apiKey: 'k'),
        isFalse,
      );
      expect(
        await ZoteroClient.instance.validate(userId: '', apiKey: 'k'),
        isFalse,
      );
    });
  });

  group('ZoteroConnectionStore', () {
    test('save/read/clear round trip', () async {
      expect(await ZoteroConnectionStore.instance.read(), isNull);
      await ZoteroConnectionStore.instance
          .save(userId: ' 123456 ', apiKey: ' key ');
      final conn = await ZoteroConnectionStore.instance.read();
      expect(conn, isNotNull);
      expect(conn!.userId, '123456');
      expect(conn.apiKey, 'key');
      await ZoteroConnectionStore.instance.clear();
      expect(await ZoteroConnectionStore.instance.read(), isNull);
    });

    test('missing key yields null even with a user ID stored', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('zotero_user_id', '123456');
      expect(await ZoteroConnectionStore.instance.read(), isNull);
    });
  });
}
