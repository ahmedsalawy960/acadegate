import '../academic_integrity/crossref_client.dart';
import '../academic_integrity/openalex_works_client.dart';
import '../academic_integrity/semantic_scholar_client.dart';
import 'publish_models.dart';

/// Academic portal hit that can become a [PublishReference].
class AcademicWorkHit {
  final String title;
  final List<String> authors;
  final String year;
  final String doi;
  final String url;
  final String container;
  final String source;

  const AcademicWorkHit({
    required this.title,
    this.authors = const [],
    this.year = '',
    this.doi = '',
    this.url = '',
    this.container = '',
    required this.source,
  });

  PublishReference toReference() {
    final id = doi.isNotEmpty
        ? 'doi_${doi.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}'
        : 'ref_${DateTime.now().millisecondsSinceEpoch}';
    return PublishReference(
      id: id,
      type: ReferenceType.journal,
      authors: authors,
      title: title,
      container: container,
      year: year,
      doi: doi,
      url: url.isNotEmpty
          ? url
          : (doi.isNotEmpty ? 'https://doi.org/$doi' : ''),
    );
  }
}

/// Search Crossref + OpenAlex (+ Semantic Scholar) by author, title, or DOI.
class AcademicReferenceLookupService {
  AcademicReferenceLookupService._();

  static final AcademicReferenceLookupService instance =
      AcademicReferenceLookupService._();

  final _crossref = CrossrefClient.instance;
  final _openAlex = OpenAlexWorksClient.instance;
  final _scholar = SemanticScholarClient.instance;

  Future<List<AcademicWorkHit>> search(String query, {int limit = 8}) async {
    final q = query.trim();
    if (q.length < 3) return const [];

    final doi = _extractDoi(q);
    if (doi != null) {
      final byDoi = await _lookupDoi(doi);
      if (byDoi != null) return [byDoi];
    }

    final results = <AcademicWorkHit>[];
    final seen = <String>{};

    void add(AcademicWorkHit hit) {
      final key = hit.doi.isNotEmpty
          ? hit.doi.toLowerCase()
          : hit.title.toLowerCase().trim();
      if (key.isEmpty || seen.contains(key)) return;
      seen.add(key);
      results.add(hit);
    }

    try {
      final looksLikeAuthor = _looksLikeAuthorQuery(q);
      if (looksLikeAuthor) {
        final byAuthor = await _crossref.searchByAuthor(q, rows: limit);
        for (final w in byAuthor) {
          add(AcademicWorkHit(
            title: w.title,
            authors: _splitAuthors(w.authors),
            year: w.year?.toString() ?? '',
            doi: w.doi ?? '',
            url: w.url ?? '',
            source: 'Crossref',
          ));
        }
      }

      final cross = await _crossref.searchBibliographic(q, rows: limit);
      for (final w in cross) {
        add(AcademicWorkHit(
          title: w.title,
          authors: _splitAuthors(w.authors),
          year: w.year?.toString() ?? '',
          doi: w.doi ?? '',
          url: w.url ?? '',
          source: 'Crossref',
        ));
      }
    } catch (_) {}

    if (results.length < limit) {
      try {
        final open = await _openAlex.searchTitle(q, perPage: limit);
        for (final w in open) {
          add(AcademicWorkHit(
            title: w.title,
            authors: _splitAuthors(w.authors),
            year: w.year?.toString() ?? '',
            doi: w.doi ?? '',
            url: w.url ?? '',
            source: 'OpenAlex',
          ));
        }
      } catch (_) {}
    }

    if (results.length < 3) {
      try {
        final sem = await _scholar.search(q, limit: limit);
        for (final w in sem) {
          add(AcademicWorkHit(
            title: w.title,
            authors: _splitAuthors(w.authors),
            year: w.year?.toString() ?? '',
            doi: w.doi ?? '',
            url: w.url ?? '',
            source: 'Semantic Scholar',
          ));
        }
      } catch (_) {}
    }

    return results.take(limit).toList();
  }

  Future<AcademicWorkHit?> _lookupDoi(String doi) async {
    try {
      final w = await _crossref.lookupDoi(doi);
      if (w != null && w.title.isNotEmpty) {
        return AcademicWorkHit(
          title: w.title,
          authors: _splitAuthors(w.authors),
          year: w.year?.toString() ?? '',
          doi: w.doi ?? doi,
          url: w.url ?? 'https://doi.org/$doi',
          source: 'Crossref',
        );
      }
    } catch (_) {}

    try {
      final w = await _openAlex.lookupDoi(doi);
      if (w != null && w.title.isNotEmpty) {
        return AcademicWorkHit(
          title: w.title,
          authors: _splitAuthors(w.authors),
          year: w.year?.toString() ?? '',
          doi: w.doi ?? doi,
          url: w.url ?? 'https://doi.org/$doi',
          source: 'OpenAlex',
        );
      }
    } catch (_) {}

    try {
      final w = await _scholar.lookupDoi(doi);
      if (w != null && w.title.isNotEmpty) {
        return AcademicWorkHit(
          title: w.title,
          authors: _splitAuthors(w.authors),
          year: w.year?.toString() ?? '',
          doi: w.doi ?? doi,
          url: w.url ?? 'https://doi.org/$doi',
          source: 'Semantic Scholar',
        );
      }
    } catch (_) {}

    return null;
  }

  static String? _extractDoi(String text) {
    final m = RegExp(
      r'(?:doi[:\s]*|https?://(?:dx\.)?doi\.org/)?(10\.\d{4,9}/[-._;()/:A-Z0-9]+)',
      caseSensitive: false,
    ).firstMatch(text.trim());
    return m?.group(1)?.replaceAll(RegExp(r'[.)]+$'), '');
  }

  /// Short queries without journal/title keywords → treat as author search.
  static bool _looksLikeAuthorQuery(String q) {
    final lower = q.toLowerCase();
    if (lower.contains('http') || lower.contains('doi')) return false;
    if (RegExp(r'\b(journal|vol\.|pp\.|proceedings)\b').hasMatch(lower)) {
      return false;
    }
    final words = q.trim().split(RegExp(r'\s+'));
    return words.length <= 6;
  }

  static List<String> _splitAuthors(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(RegExp(r'\s*;\s*|\s+and\s+|\s*,\s*(?=[A-Z])'))
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();
  }

  /// Loose local match: author surname, year, title tokens, DOI.
  static bool matchesLocal(PublishReference ref, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (q.length < 2) return true;

    final hay = [
      ref.title,
      ref.rawText,
      ref.doi,
      ref.year,
      ref.container,
      ...ref.authors,
    ].join(' ').toLowerCase();

    // All significant tokens must appear (order-independent).
    final tokens = q
        .replaceAll(RegExp(r'[^\w\u0600-\u06FF.\-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2)
        .where((t) => !_stopwords.contains(t))
        .toList();
    if (tokens.isEmpty) return hay.contains(q);

    var hits = 0;
    for (final t in tokens) {
      if (hay.contains(t)) hits++;
    }
    // Match if most tokens hit (handles pasted "Daun, J. K., … (2011)")
    return hits >= (tokens.length * 0.55).ceil() || hits >= 2;
  }

  static const _stopwords = {
    'and',
    'the',
    'of',
    'in',
    'et',
    'al',
    'vol',
    'pp',
    'doi',
    'http',
    'https',
    'www',
  };
}
