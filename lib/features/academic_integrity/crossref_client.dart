import 'dart:convert';

import 'citation_http.dart';

class CrossrefWork {
  final String title;
  final String? doi;
  final int? year;
  final String? authors;
  final String? url;

  const CrossrefWork({
    required this.title,
    this.doi,
    this.year,
    this.authors,
    this.url,
  });
}

class CrossrefClient {
  CrossrefClient._();

  static final CrossrefClient instance = CrossrefClient._();

  static const _base = 'https://api.crossref.org/works';
  static const _headers = {
    'Accept': 'application/json',
    'User-Agent': 'AcadeGate/1.0 (mailto:support@acadegate.app)',
  };

  Future<CrossrefWork?> lookupDoi(String doi) async {
    final normalized = doi.trim().replaceAll(RegExp(r'^https?://(dx\.)?doi\.org/'), '');
    final uri = Uri.parse('$_base/${Uri.encodeComponent(normalized)}');
    final response = await CitationHttp.get(uri, headers: _headers).timeout(
          const Duration(seconds: 20),
        );

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Crossref: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final message = data['message'] as Map<String, dynamic>?;
    if (message == null) return null;
    return _fromMessage(message);
  }

  Future<List<CrossrefWork>> searchBibliographic(String query, {int rows = 5}) async {
    if (query.trim().length < 3) return const [];

    final uri = Uri.parse(_base).replace(
      queryParameters: {
        'query.bibliographic': query.trim(),
        'rows': '$rows',
      },
    );

    final response = await CitationHttp.get(uri, headers: _headers).timeout(
          const Duration(seconds: 25),
        );

    if (response.statusCode != 200) return const [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final message = data['message'] as Map<String, dynamic>?;
    final items = message?['items'] as List<dynamic>? ?? [];

    return items
        .whereType<Map<String, dynamic>>()
        .map(_fromMessage)
        .where((w) => w.title.isNotEmpty)
        .toList();
  }

  Future<List<CrossrefWork>> searchByAuthor(String author, {int rows = 8}) async {
    if (author.trim().length < 2) return const [];

    final uri = Uri.parse(_base).replace(
      queryParameters: {
        'query.author': author.trim(),
        'rows': '$rows',
      },
    );

    final response = await CitationHttp.get(uri, headers: _headers).timeout(
          const Duration(seconds: 25),
        );

    if (response.statusCode != 200) return const [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final message = data['message'] as Map<String, dynamic>?;
    final items = message?['items'] as List<dynamic>? ?? [];

    return items
        .whereType<Map<String, dynamic>>()
        .map(_fromMessage)
        .where((w) => w.title.isNotEmpty)
        .toList();
  }

  CrossrefWork _fromMessage(Map<String, dynamic> message) {
    final titles = message['title'] as List<dynamic>?;
    final title = titles?.isNotEmpty == true ? titles!.first.toString() : '';

    final authorsList = message['author'] as List<dynamic>? ?? [];
    final authors = authorsList
        .map((a) {
          final map = a as Map<String, dynamic>;
          final family = map['family']?.toString() ?? '';
          final given = map['given']?.toString() ?? '';
          return '$given $family'.trim();
        })
        .where((s) => s.isNotEmpty)
        .take(4)
        .join('; ');

    final issued = message['issued'] as Map<String, dynamic>?;
    final dateParts = issued?['date-parts'] as List<dynamic>?;
    int? year;
    if (dateParts != null && dateParts.isNotEmpty) {
      final first = dateParts.first as List<dynamic>?;
      if (first != null && first.isNotEmpty) {
        year = int.tryParse(first.first.toString());
      }
    }

    final doi = message['DOI']?.toString();
    final url = doi != null ? 'https://doi.org/$doi' : null;

    return CrossrefWork(
      title: title,
      doi: doi,
      year: year,
      authors: authors.isEmpty ? null : authors,
      url: url,
    );
  }
}
