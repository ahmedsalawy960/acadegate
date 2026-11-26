import 'community_models.dart';

/// Room id used by paper discussions. It is not a faculty room, so these posts
/// never appear inside the faculty room feeds.
const String kPapersRoomId = 'papers';
const int kPaperKeyMaxLength = 200;

/// A paper, identified the same way for everyone who discusses it.
class PaperRef {
  const PaperRef({required this.key, required this.link, this.doi = ''});

  /// "doi:10.1000/xyz" or "url:example.org/path". Same paper = same key.
  final String key;

  /// Link members open. For a DOI this is the doi.org link.
  final String link;
  final String doi;
}

final RegExp _doiPattern = RegExp(r'10\.\d{4,9}/[^\s?#]+', caseSensitive: false);

const Set<String> _trackingParams = {
  'fbclid', 'gclid', 'mc_cid', 'mc_eid', 'igshid', 'ref', 'source', 'spm',
};

/// Reads a DOI or a link and returns the paper identity, or null when the
/// input is neither a DOI nor an http(s) link. DOI wins when one is present
/// (doi.org links, "doi:10....", publisher URLs that contain the DOI).
PaperRef? normalizePaperInput(String raw) {
  final input = raw.trim();
  if (input.isEmpty) return null;

  final doiMatch = _doiPattern.firstMatch(input);
  if (doiMatch != null) {
    var doi = doiMatch.group(0)!;
    try {
      doi = Uri.decodeComponent(doi);
    } catch (_) {}
    doi = doi.toLowerCase().replaceAll(RegExp(r'[.,;:)\]>]+$'), '');
    if (doi.length < 8) return null;
    final key = 'doi:$doi';
    if (key.length > kPaperKeyMaxLength) return null;
    return PaperRef(key: key, link: 'https://doi.org/$doi', doi: doi);
  }

  final uri = Uri.tryParse(input);
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  var host = uri.host.toLowerCase();
  if (host.startsWith('www.')) host = host.substring(4);
  var path = uri.path;
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (path == '/') path = '';

  final kept = <MapEntry<String, String>>[];
  uri.queryParametersAll.forEach((name, values) {
    final lower = name.toLowerCase();
    if (lower.startsWith('utm_') || _trackingParams.contains(lower)) return;
    for (final v in values) {
      kept.add(MapEntry(lower, v));
    }
  });
  kept.sort((a, b) {
    final byName = a.key.compareTo(b.key);
    return byName != 0 ? byName : a.value.compareTo(b.value);
  });
  final query = kept.map((e) => '${e.key}=${e.value}').join('&');

  final key = 'url:$host$path${query.isEmpty ? '' : '?$query'}';
  if (key.length > kPaperKeyMaxLength) return null;
  final link = Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
    query: query.isEmpty ? null : query,
  ).toString();
  return PaperRef(key: key, link: link);
}

/// One paper with its discussion numbers, built from the loaded posts.
class PaperSummary {
  const PaperSummary({
    required this.key,
    required this.title,
    required this.link,
    required this.postsCount,
    required this.repliesCount,
    required this.lastActivity,
  });

  final String key;
  final String title;
  final String link;
  final int postsCount;
  final int repliesCount;
  final DateTime? lastActivity;
}

/// Groups paper posts by paper. The title and link come from the oldest post.
List<PaperSummary> groupPaperPosts(List<CommunityPost> posts) {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  final byKey = <String, List<CommunityPost>>{};
  for (final p in posts) {
    if (p.paperKey.isEmpty) continue;
    byKey.putIfAbsent(p.paperKey, () => []).add(p);
  }
  final out = <PaperSummary>[];
  byKey.forEach((key, list) {
    list.sort((a, b) => (a.createdAt ?? epoch).compareTo(b.createdAt ?? epoch));
    final first = list.first;
    var last = epoch;
    var replies = 0;
    for (final p in list) {
      final at = p.createdAt ?? epoch;
      if (at.isAfter(last)) last = at;
      replies += p.repliesCount;
    }
    out.add(PaperSummary(
      key: key,
      title: (first.academicTitle ?? '').trim().isNotEmpty
          ? first.academicTitle!.trim()
          : first.title,
      link: first.academicLink ?? '',
      postsCount: list.length,
      repliesCount: replies,
      lastActivity: last == epoch ? null : last,
    ));
  });
  out.sort((a, b) => (b.lastActivity ?? epoch).compareTo(a.lastActivity ?? epoch));
  return out;
}

/// Search by title or DOI/link text. Empty query keeps everything.
List<PaperSummary> filterPapers(List<PaperSummary> papers, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return papers;
  return papers
      .where((p) => p.title.toLowerCase().contains(q) || p.key.contains(q))
      .toList();
}
