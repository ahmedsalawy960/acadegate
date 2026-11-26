import 'dart:convert';

import 'package:http/http.dart' as http;

import 'citation_http.dart';

/// One dataset record from Zenodo's own repository.
class ZenodoDataset {
  final String title;
  final String? doi;
  final int? year;
  final String? authors;
  final String abstractText;
  final String? url;
  final String? accessRight;

  const ZenodoDataset({
    required this.title,
    this.doi,
    this.year,
    this.authors,
    this.abstractText = '',
    this.url,
    this.accessRight,
  });
}

/// Search over Zenodo-hosted datasets (zenodo.org/api/records). Free, no
/// key. Zenodo is strong in EU/Arab-world repository deposits and Arabic
/// research outputs.
class ZenodoClient {
  ZenodoClient._();

  static final ZenodoClient instance = ZenodoClient._();

  static const _base = 'https://zenodo.org/api/records';

  Future<List<ZenodoDataset>> searchDatasets(
    String query, {
    int limit = 10,
  }) async {
    final q = query.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (q.length < 3) return const [];

    final uri = Uri.parse(_base).replace(
      queryParameters: {
        'q': q,
        'type': 'dataset',
        'size': '${limit.clamp(1, 25)}',
        'sort': 'bestmatch',
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
      final hits = decoded['hits'];
      if (hits is! Map) return const [];
      final items = hits['hits'];
      if (items is! List) return const [];
      final out = <ZenodoDataset>[];
      for (final item in items) {
        final parsed = _parse(item);
        if (parsed != null) out.add(parsed);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static ZenodoDataset? _parse(dynamic item) {
    if (item is! Map) return null;
    final metadata = item['metadata'];
    if (metadata is! Map) return null;
    final title = metadata['title']?.toString().trim() ?? '';
    if (title.isEmpty) return null;

    final creators = metadata['creators'];
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

    final links = item['links'];
    String? url;
    if (links is Map) {
      url = _nonEmpty(links['self_html']);
    }

    return ZenodoDataset(
      title: title,
      doi: _nonEmpty(item['doi']) ?? _nonEmpty(metadata['doi']),
      year: _year(metadata['publication_date']),
      authors: names.isEmpty ? null : names.join('; '),
      abstractText: _stripHtml(metadata['description']?.toString() ?? ''),
      url: url,
      accessRight: _nonEmpty(metadata['access_right']),
    );
  }

  static int? _year(dynamic dateNode) {
    final s = dateNode?.toString() ?? '';
    final match = RegExp(r'(19|20)\d{2}').firstMatch(s);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  /// Zenodo descriptions are HTML; reduce to plain text for abstracts.
  static String _stripHtml(String html) {
    final noTags = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
    return noTags.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String? _nonEmpty(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }
}
