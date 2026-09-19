import 'dart:convert';

import 'citation_http.dart';

class EuropePmcWork {
  final String title;
  final String? doi;
  final int? year;
  final String authors;
  final String journal;
  final String abstractText;
  final String url;

  const EuropePmcWork({
    required this.title,
    this.doi,
    this.year,
    this.authors = '',
    this.journal = '',
    this.abstractText = '',
    this.url = '',
  });
}

/// Open abstracts + free-text search via Europe PMC.
class EuropePmcClient {
  EuropePmcClient._();

  static final EuropePmcClient instance = EuropePmcClient._();

  static const _base = 'https://www.ebi.ac.uk/europepmc/webservices/rest/search';

  Future<String> abstractForDoi(String doi) async {
    final normalized = doi
        .trim()
        .replaceAll(RegExp(r'^https?://(dx\.)?doi\.org/'), '');
    if (normalized.length < 6) return '';
    final works = await search('DOI:"$normalized"', pageSize: 1);
    if (works.isEmpty) return '';
    return works.first.abstractText;
  }

  Future<List<EuropePmcWork>> search(
    String query, {
    int pageSize = 20,
  }) async {
    final q = query.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (q.length < 3) return const [];

    final uri = Uri.parse(_base).replace(
      queryParameters: {
        'query': q,
        'format': 'json',
        'resultType': 'core',
        'pageSize': '${pageSize.clamp(1, 50)}',
      },
    );
    try {
      final response = await CitationHttp.get(
        uri,
        headers: const {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) return const [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final resultList =
          data['resultList'] as Map<String, dynamic>? ?? const {};
      final results = resultList['result'] as List<dynamic>? ?? const [];
      return [
        for (final raw in results)
          if (raw is Map) _fromMap(Map<String, dynamic>.from(raw)),
      ].where((w) => w.title.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  EuropePmcWork _fromMap(Map<String, dynamic> map) {
    final doi = (map['doi'] ?? '').toString().trim();
    final pmid = (map['pmid'] ?? '').toString().trim();
    final pmcid = (map['pmcid'] ?? '').toString().trim();
    final yearRaw = map['pubYear']?.toString() ?? '';
    final year = int.tryParse(yearRaw);
    String url = '';
    if (doi.isNotEmpty) {
      url = 'https://doi.org/$doi';
    } else if (pmcid.isNotEmpty) {
      url = 'https://europepmc.org/article/PMC/$pmcid';
    } else if (pmid.isNotEmpty) {
      url = 'https://europepmc.org/article/MED/$pmid';
    }
    return EuropePmcWork(
      title: (map['title'] ?? '').toString().trim(),
      doi: doi.isEmpty ? null : doi,
      year: year,
      authors: (map['authorString'] ?? '').toString().trim(),
      journal: (map['journalTitle'] ?? '').toString().trim(),
      abstractText: (map['abstractText'] ?? '').toString().trim(),
      url: url,
    );
  }
}
