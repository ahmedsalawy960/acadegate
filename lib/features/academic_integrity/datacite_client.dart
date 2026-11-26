import 'dart:convert';

import 'package:http/http.dart' as http;

import 'citation_http.dart';

/// One dataset record from the DataCite metadata index.
class DataCiteDataset {
  final String title;
  final String? doi;
  final int? year;
  final String? authors;
  final String? publisher;
  final String abstractText;
  final String? url;
  final int? citationCount;

  const DataCiteDataset({
    required this.title,
    this.doi,
    this.year,
    this.authors,
    this.publisher,
    this.abstractText = '',
    this.url,
    this.citationCount,
  });
}

/// Search over DataCite-registered datasets (api.datacite.org). Free, no
/// key. DataCite covers Zenodo, Dryad, Figshare, institutional repositories.
class DataCiteClient {
  DataCiteClient._();

  static final DataCiteClient instance = DataCiteClient._();

  static const _base = 'https://api.datacite.org/dois';

  Future<List<DataCiteDataset>> searchDatasets(
    String query, {
    int limit = 10,
  }) async {
    final q = query.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (q.length < 3) return const [];

    final uri = Uri.parse(_base).replace(
      queryParameters: {
        'query': q,
        'resource-type-id': 'dataset',
        'page[size]': '${limit.clamp(1, 25)}',
      },
    );
    http.Response res;
    try {
      res = await CitationHttp.get(uri);
    } catch (_) {
      return const [];
    }
    if (res.statusCode != 200) return const [];
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return const [];
      final data = decoded['data'];
      if (data is! List) return const [];
      final out = <DataCiteDataset>[];
      for (final item in data) {
        final parsed = _parse(item);
        if (parsed != null) out.add(parsed);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static DataCiteDataset? _parse(dynamic item) {
    if (item is! Map) return null;
    final attrs = item['attributes'];
    if (attrs is! Map) return null;

    final titles = attrs['titles'];
    var title = '';
    if (titles is List) {
      for (final t in titles) {
        if (t is Map) {
          title = t['title']?.toString().trim() ?? '';
          if (title.isNotEmpty) break;
        }
      }
    }
    if (title.isEmpty) return null;

    String? abstractText;
    final descriptions = attrs['descriptions'];
    if (descriptions is List) {
      for (final d in descriptions) {
        if (d is Map && d['descriptionType'] == 'Abstract') {
          final text = d['description']?.toString().trim() ?? '';
          if (text.isNotEmpty) {
            abstractText = text;
            break;
          }
        }
      }
    }

    final creators = attrs['creators'];
    final names = <String>[];
    if (creators is List) {
      for (final c in creators) {
        if (c is Map) {
          final name = c['name']?.toString().trim() ?? '';
          if (name.isNotEmpty) names.add(name);
          if (names.length >= 4) break;
        }
      }
    }

    return DataCiteDataset(
      title: title,
      doi: _nonEmpty(attrs['doi']),
      year: attrs['publicationYear'] is int
          ? attrs['publicationYear'] as int
          : int.tryParse(attrs['publicationYear']?.toString() ?? ''),
      authors: names.isEmpty ? null : names.join('; '),
      publisher: _nonEmpty(attrs['publisher']),
      abstractText: abstractText ?? '',
      url: _nonEmpty(attrs['url']),
      citationCount: attrs['citationCount'] is int
          ? attrs['citationCount'] as int
          : int.tryParse(attrs['citationCount']?.toString() ?? ''),
    );
  }

  static String? _nonEmpty(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }
}
