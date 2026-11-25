import 'dart:convert';

import 'package:http/http.dart' as http;

import 'citation_http.dart';

/// One item from the user's own Zotero library.
class ZoteroWork {
  final String key;
  final String title;
  final String? doi;
  final int? year;
  final String? authors;
  final String? journal;
  final String abstractText;
  final String? url;
  final String itemType;

  const ZoteroWork({
    required this.key,
    required this.title,
    this.doi,
    this.year,
    this.authors,
    this.journal,
    this.abstractText = '',
    this.url,
    this.itemType = '',
  });
}

/// Read-only client for the user's own Zotero library (api.zotero.org).
/// The API key is the user's personal key, entered once in the app and
/// stored on-device; calls go straight to Zotero (CORS is open), never
/// through the citation proxy, so the key never transits our servers.
class ZoteroClient {
  ZoteroClient._();

  static final ZoteroClient instance = ZoteroClient._();

  static const _base = 'https://api.zotero.org';

  /// True when [userId]/[apiKey] can read the library. False on 401/403/404
  /// or any network/parse failure. Never throws.
  Future<bool> validate({
    required String userId,
    required String apiKey,
  }) async {
    final uid = userId.trim();
    final key = apiKey.trim();
    if (uid.isEmpty || key.isEmpty) return false;
    try {
      final res = await CitationHttp.get(
        Uri.parse('$_base/users/${Uri.encodeComponent(uid)}/items')
            .replace(queryParameters: const {'limit': '1', 'format': 'json'}),
        headers: _headers(key),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Full-text search over the user's library. Empty on any failure.
  Future<List<ZoteroWork>> searchItems({
    required String userId,
    required String apiKey,
    required String query,
    int limit = 10,
  }) async {
    final uid = userId.trim();
    final key = apiKey.trim();
    final q = query.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (uid.isEmpty || key.isEmpty || q.length < 3) return const [];

    final uri =
        Uri.parse('$_base/users/${Uri.encodeComponent(uid)}/items').replace(
      queryParameters: {
        'q': q,
        'qmode': 'everything',
        'format': 'json',
        'limit': '${limit.clamp(1, 50)}',
      },
    );
    http.Response res;
    try {
      res = await CitationHttp.get(uri, headers: _headers(key));
    } catch (_) {
      return const [];
    }
    if (res.statusCode != 200) return const [];
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is! List) return const [];
      final works = <ZoteroWork>[];
      for (final item in decoded) {
        final work = _parseItem(item);
        if (work != null) works.add(work);
      }
      return works;
    } catch (_) {
      return const [];
    }
  }

  static Map<String, String> _headers(String apiKey) => {
        'Zotero-API-Key': apiKey,
        'Zotero-API-Version': '3',
      };

  static ZoteroWork? _parseItem(dynamic item) {
    if (item is! Map) return null;
    final data = item['data'];
    if (data is! Map) return null;
    final itemType = data['itemType']?.toString() ?? '';
    if (itemType == 'attachment' || itemType == 'note') return null;
    final title = data['title']?.toString().trim() ?? '';
    if (title.isEmpty) return null;

    return ZoteroWork(
      key: data['key']?.toString() ?? '',
      title: title,
      doi: _nonEmpty(data['DOI']),
      year: _year(data['date']),
      authors: _authors(data['creators']),
      journal: _nonEmpty(data['publicationTitle']),
      abstractText: data['abstractNote']?.toString().trim() ?? '',
      url: _nonEmpty(data['url']),
      itemType: itemType,
    );
  }

  static String? _nonEmpty(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  /// Zotero dates are free-form ("2017", "May 2017", "2017-05-01").
  static int? _year(dynamic dateNode) {
    final s = dateNode?.toString() ?? '';
    final match = RegExp(r'(19|20)\d{2}').firstMatch(s);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  static String? _authors(dynamic creatorsNode) {
    if (creatorsNode is! List) return null;
    final names = <String>[];
    for (final c in creatorsNode) {
      if (c is! Map) continue;
      final type = c['creatorType']?.toString() ?? 'author';
      if (type != 'author') continue;
      final single = c['name']?.toString().trim() ?? '';
      final combined =
          '${c['firstName']?.toString().trim() ?? ''} ${c['lastName']?.toString().trim() ?? ''}'
              .trim();
      final name = single.isNotEmpty ? single : combined;
      if (name.isNotEmpty) names.add(name);
      if (names.length >= 4) break;
    }
    if (names.isEmpty) return null;
    return names.join('; ');
  }
}
