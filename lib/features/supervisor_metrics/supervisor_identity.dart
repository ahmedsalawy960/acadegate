/// OpenAlex research fingerprint: topics, concept scores, co-authors, affiliations.
class ResearchIdentityTopic {
  final String name;
  final int percent;
  final String source;

  const ResearchIdentityTopic({
    required this.name,
    required this.percent,
    this.source = 'topic',
  });

  String get label => '$name $percent%';
}

class ResearchCollaborator {
  final String name;
  final String openAlexId;
  final String institution;
  final int jointWorks;

  const ResearchCollaborator({
    required this.name,
    this.openAlexId = '',
    this.institution = '',
    this.jointWorks = 0,
  });
}

class ResearchAffiliation {
  final String name;
  final String countryCode;
  final int yearsActive;

  const ResearchAffiliation({
    required this.name,
    this.countryCode = '',
    this.yearsActive = 0,
  });
}

class ResearchWork {
  final String title;
  final int year;
  final String venue;
  final int citedByCount;
  final String doi;
  final String openUrl;
  final bool hasPdf;

  const ResearchWork({
    required this.title,
    this.year = 0,
    this.venue = '',
    this.citedByCount = 0,
    this.doi = '',
    this.openUrl = '',
    this.hasPdf = false,
  });

  bool get canOpen => openUrl.isNotEmpty;
}

class SupervisorIdentity {
  SupervisorIdentity._();

  static int percentFromScore(dynamic score) {
    if (score is! num) return 0;
    final n = score.toDouble();
    if (n <= 0) return 0;
    if (n <= 1) return (n * 100).round().clamp(1, 100);
    if (n <= 100) return n.round().clamp(1, 100);
    return 100;
  }

  static String normalizeOpenAlexId(String raw) {
    return raw
        .trim()
        .replaceFirst('https://openalex.org/', '')
        .replaceFirst('http://openalex.org/', '');
  }

  static List<ResearchIdentityTopic> topicsFromAuthor(
    Map<String, dynamic> author,
  ) {
    final merged = <String, ResearchIdentityTopic>{};

    final topics = author['topics'];
    if (topics is List) {
      final rows = <({String name, int count})>[];
      for (final item in topics) {
        if (item is! Map) continue;
        final name = item['display_name']?.toString().trim() ?? '';
        final count = (item['count'] as num?)?.toInt() ?? 0;
        if (name.length < 2 || count <= 0) continue;
        rows.add((name: name, count: count));
      }
      final maxCount = rows.fold<int>(0, (m, r) => r.count > m ? r.count : m);
      if (maxCount > 0) {
        for (final row in rows) {
          final percent = ((100 * row.count) / maxCount).round().clamp(1, 100);
          merged[_key(row.name)] = ResearchIdentityTopic(
            name: row.name,
            percent: percent,
            source: 'topic',
          );
        }
      }
    }

    final concepts = (author['x_concepts'] as List?) ?? author['concepts'];
    if (concepts is List) {
      for (final item in concepts) {
        if (item is! Map) continue;
        final name = item['display_name']?.toString().trim() ?? '';
        if (name.length < 2) continue;
        final level = (item['level'] as num?)?.toInt();
        if (level == 0) continue;
        final percent = percentFromScore(item['score']);
        if (percent < 20) continue;
        final key = _key(name);
        final existing = merged[key];
        if (existing == null || percent > existing.percent) {
          merged[key] = ResearchIdentityTopic(
            name: name,
            percent: percent,
            source: 'concept',
          );
        }
      }
    }

    final list = merged.values.toList()
      ..sort((a, b) => b.percent.compareTo(a.percent));
    return list.take(8).toList();
  }

  static List<ResearchIdentityTopic> topicsFromWorks(
    List<Map<String, dynamic>> works,
  ) {
    final counts = <String, int>{};
    for (final work in works) {
      final keywords = work['keywords'];
      if (keywords is! List) continue;
      for (final item in keywords) {
        if (item is! Map) continue;
        final name = item['display_name']?.toString().trim() ?? '';
        if (name.length < 2) continue;
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return const [];
    final maxCount = counts.values.fold<int>(0, (m, c) => c > m ? c : m);
    if (maxCount <= 0) return const [];
    final list = counts.entries
        .map(
          (e) => ResearchIdentityTopic(
            name: e.key,
            percent: ((100 * e.value) / maxCount).round().clamp(1, 100),
            source: 'keyword',
          ),
        )
        .toList()
      ..sort((a, b) => b.percent.compareTo(a.percent));
    return list.take(8).toList();
  }

  static List<ResearchIdentityTopic> mergeTopics(
    List<ResearchIdentityTopic> primary,
    List<ResearchIdentityTopic> extra,
  ) {
    final merged = <String, ResearchIdentityTopic>{
      for (final t in primary) _key(t.name): t,
    };
    for (final t in extra) {
      final key = _key(t.name);
      if (merged.containsKey(key)) continue;
      if (merged.length >= 8) break;
      merged[key] = t;
    }
    final list = merged.values.toList()
      ..sort((a, b) => b.percent.compareTo(a.percent));
    return list.take(8).toList();
  }

  static List<ResearchCollaborator> collaboratorsFromWorks({
    required List<Map<String, dynamic>> works,
    required String selfOpenAlexId,
  }) {
    final self = normalizeOpenAlexId(selfOpenAlexId);
    final counts = <String, _CollabAcc>{};

    for (final work in works) {
      final authorships = work['authorships'];
      if (authorships is! List) continue;
      for (final raw in authorships) {
        if (raw is! Map) continue;
        final author = raw['author'];
        if (author is! Map) continue;
        final id = normalizeOpenAlexId(author['id']?.toString() ?? '');
        final name = author['display_name']?.toString().trim() ?? '';
        if (name.length < 2) continue;
        if (id.isNotEmpty && id == self) continue;
        final key = id.isNotEmpty ? id : name.toLowerCase();
        final acc = counts.putIfAbsent(
          key,
          () => _CollabAcc(name: name, openAlexId: id),
        );
        acc.jointWorks++;
        if (acc.institution.isEmpty) {
          final institutions = raw['institutions'];
          if (institutions is List && institutions.isNotEmpty) {
            final first = institutions.first;
            if (first is Map) {
              acc.institution = first['display_name']?.toString().trim() ?? '';
            }
          }
        }
      }
    }

    final list = counts.values
        .map(
          (a) => ResearchCollaborator(
            name: a.name,
            openAlexId: a.openAlexId,
            institution: a.institution,
            jointWorks: a.jointWorks,
          ),
        )
        .toList()
      ..sort((a, b) => b.jointWorks.compareTo(a.jointWorks));
    return list.take(8).toList();
  }

  static List<ResearchAffiliation> affiliationsFromAuthor(
    Map<String, dynamic> author,
  ) {
    final affiliations = author['affiliations'];
    if (affiliations is! List) return const [];

    final list = <ResearchAffiliation>[];
    for (final item in affiliations) {
      if (item is! Map) continue;
      final institution = item['institution'];
      if (institution is! Map) continue;
      final name = institution['display_name']?.toString().trim() ?? '';
      if (name.length < 2) continue;
      final years = item['years'];
      list.add(
        ResearchAffiliation(
          name: name,
          countryCode: institution['country_code']?.toString() ?? '',
          yearsActive: years is List ? years.length : 0,
        ),
      );
    }
    list.sort((a, b) => b.yearsActive.compareTo(a.yearsActive));
    return list.take(8).toList();
  }

  static List<ResearchWork> worksFromOpenAlex(
    List<Map<String, dynamic>> works, {
    int limit = 20,
  }) {
    final parsed = <ResearchWork>[];
    for (final work in works) {
      final title = (work['display_name'] ?? work['title'])?.toString().trim() ??
          '';
      if (title.length < 3) continue;

      final primary = work['primary_location'] is Map
          ? Map<String, dynamic>.from(work['primary_location'] as Map)
          : const <String, dynamic>{};
      final bestOa = work['best_oa_location'] is Map
          ? Map<String, dynamic>.from(work['best_oa_location'] as Map)
          : const <String, dynamic>{};
      final openAccess = work['open_access'] is Map
          ? Map<String, dynamic>.from(work['open_access'] as Map)
          : const <String, dynamic>{};
      final source = primary['source'] is Map
          ? Map<String, dynamic>.from(primary['source'] as Map)
          : const <String, dynamic>{};

      final doi = _doiUrl(work['doi']?.toString());
      final pdf = _httpUrl(bestOa['pdf_url']?.toString()) ??
          _httpUrl(primary['pdf_url']?.toString()) ??
          _pdfFromOa(openAccess['oa_url']?.toString());
      final landing = _httpUrl(bestOa['landing_page_url']?.toString()) ??
          _httpUrl(primary['landing_page_url']?.toString()) ??
          _httpUrl(openAccess['oa_url']?.toString());
      final openAlex = _httpUrl(work['id']?.toString());
      final openUrl = pdf ?? doi ?? landing ?? openAlex ?? '';

      parsed.add(
        ResearchWork(
          title: title,
          year: (work['publication_year'] as num?)?.toInt() ?? 0,
          venue: source['display_name']?.toString().trim() ?? '',
          citedByCount: (work['cited_by_count'] as num?)?.toInt() ?? 0,
          doi: doi ?? '',
          openUrl: openUrl,
          hasPdf: pdf != null,
        ),
      );
      if (parsed.length >= limit) break;
    }
    return parsed;
  }

  static String? _doiUrl(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return _httpUrl(value);
    }
    final doi = value.replaceFirst(RegExp(r'^doi:', caseSensitive: false), '');
    if (!doi.startsWith('10.')) return null;
    return 'https://doi.org/$doi';
  }

  static String? _pdfFromOa(String? raw) {
    final url = _httpUrl(raw);
    if (url == null) return null;
    if (url.toLowerCase().contains('.pdf')) return url;
    return null;
  }

  static String? _httpUrl(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || !uri.host.contains('.')) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return value;
  }

  static String _key(String name) => name.trim().toLowerCase();
}

class _CollabAcc {
  final String name;
  final String openAlexId;
  String institution = '';
  int jointWorks = 0;

  _CollabAcc({required this.name, required this.openAlexId});
}
