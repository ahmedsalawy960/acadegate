import 'dart:convert';

import '../academic_integrity/citation_http.dart';

/// روابط موثوقة للباحث — Scimago للتصنيف فقط وليس دليل مؤلفين.
class JournalResourceLink {
  final String url;
  final String labelAr;
  final String labelEn;
  final String source;

  const JournalResourceLink({
    required this.url,
    required this.labelAr,
    required this.labelEn,
    required this.source,
  });

  String label({required bool isEnglish}) => isEnglish ? labelEn : labelAr;
}

/// نتيجة البحث المحلي عن صفحات دليل المؤلفين قبل استدعاء السحابة.
class JournalGuidelinesDiscovery {
  final List<String> candidateUrls;
  final String? primaryUrl;
  final List<String> log;

  const JournalGuidelinesDiscovery({
    required this.candidateUrls,
    this.primaryUrl,
    this.log = const [],
  });
}

class JournalGuidelinesService {
  JournalGuidelinesService._();

  static final JournalGuidelinesService instance = JournalGuidelinesService._();

  static String authorGuidelinesSearchUrl(String journalName) {
    final query =
        '"$journalName" "instructions for authors" OR "guide for authors" OR "author guidelines"';
    return 'https://www.google.com/search?q=${Uri.encodeQueryComponent(query)}';
  }

  static String submissionPortalSearchUrl({
    required String journalName,
    String publisher = '',
  }) {
    final parts = <String>[
      '"$journalName"',
      if (publisher.trim().isNotEmpty) publisher.trim(),
      'submit manuscript',
      'online submission',
    ];
    return 'https://www.google.com/search?q=${Uri.encodeQueryComponent(parts.join(' '))}';
  }

  static String scimagoMetricsUrl(String journalName) {
    return 'https://www.scimagojr.com/journalsearch.php?q=${Uri.encodeQueryComponent(journalName)}';
  }

  static String doajSearchUrl(String journalName) {
    return 'https://doaj.org/search/journals?source=%22${Uri.encodeQueryComponent(journalName)}%22';
  }

  Future<List<JournalResourceLink>> resolve({
    required String journalName,
    String issn = '',
    String publisher = '',
    String partnerSubmissionUrl = '',
    bool isPartner = false,
  }) async {
    final links = <JournalResourceLink>[];

    if (isPartner && partnerSubmissionUrl.trim().isNotEmpty) {
      links.add(JournalResourceLink(
        url: partnerSubmissionUrl.trim(),
        labelAr: 'رابط التقديم الرسمي (شريك)',
        labelEn: 'Official submission link (partner)',
        source: 'partner',
      ));
    }

    final homepage = await _fetchCrossrefHomepage(issn);
    if (homepage != null && homepage.isNotEmpty) {
      links.add(JournalResourceLink(
        url: homepage,
        labelAr: 'الموقع الرسمي للمجلة (Crossref)',
        labelEn: 'Official journal website (Crossref)',
        source: 'crossref',
      ));
    }

    final publisherGuide = _publisherAuthorGuideUrl(publisher);
    if (publisherGuide != null) {
      links.add(JournalResourceLink(
        url: publisherGuide,
        labelAr: 'دليل المؤلفين عند الناشر',
        labelEn: 'Publisher author guidelines hub',
        source: 'publisher',
      ));
    }

    links.add(JournalResourceLink(
      url: authorGuidelinesSearchUrl(journalName),
      labelAr: 'بحث دليل المؤلفين (موصى به)',
      labelEn: 'Search author guidelines (recommended)',
      source: 'google_guidelines',
    ));

    if (!isPartner || partnerSubmissionUrl.trim().isEmpty) {
      links.add(JournalResourceLink(
        url: submissionPortalSearchUrl(
          journalName: journalName,
          publisher: publisher,
        ),
        labelAr: 'بحث بوابة التقديم',
        labelEn: 'Search submission portal',
        source: 'google_submit',
      ));
    }

    links.add(JournalResourceLink(
      url: doajSearchUrl(journalName),
      labelAr: 'البحث في DOAJ',
      labelEn: 'Search DOAJ',
      source: 'doaj',
    ));

    links.add(JournalResourceLink(
      url: scimagoMetricsUrl(journalName),
      labelAr: 'تصنيف Scimago (مقاييس فقط)',
      labelEn: 'Scimago metrics (rankings only)',
      source: 'scimago',
    ));

    return links;
  }

  /// يجمع روابط محتملة لدليل المؤلفين من Crossref وDOAJ وOpenAlex وOJS والناشر.
  Future<JournalGuidelinesDiscovery> discoverForExtract({
    required String journalName,
    String issn = '',
    String publisher = '',
    String submissionUrl = '',
  }) async {
    final log = <String>[];
    final urls = <String>[];
    void add(String url, String source) {
      final trimmed = url.trim();
      if (trimmed.isEmpty || !trimmed.startsWith('http')) return;
      if (urls.contains(trimmed)) return;
      urls.add(trimmed);
      log.add('$source → $trimmed');
    }

    final submission = submissionUrl.trim();
    if (submission.isNotEmpty) {
      add(submission, 'submission portal');
      for (final derived in _ojsGuidePathsFromBase(submission)) {
        add(derived, 'submission/OJS path');
      }
    }

    final crossref = await _fetchCrossrefHomepage(issn);
    if (crossref != null) {
      add(crossref, 'Crossref homepage');
      for (final derived in _guidePathsFromHomepage(crossref)) {
        add(derived, 'Crossref derived');
      }
    }

    for (final home in await _fetchDoajHomepages(journalName)) {
      add(home, 'DOAJ homepage');
      for (final derived in _guidePathsFromHomepage(home)) {
        add(derived, 'DOAJ derived');
      }
    }

    for (final home in await _fetchOpenAlexHomepages(journalName, issn)) {
      add(home, 'OpenAlex homepage');
      for (final derived in _guidePathsFromHomepage(home)) {
        add(derived, 'OpenAlex derived');
      }
    }

    final publisherGuide = _publisherAuthorGuideUrl(publisher);
    if (publisherGuide != null) {
      add(publisherGuide, 'publisher hub');
    }

    for (final pattern in _ojsPatternUrls(journalName)) {
      add(pattern, 'OJS pattern');
    }

    final primary = urls.isNotEmpty
        ? urls.firstWhere(
            (u) => _looksLikeGuideUrl(u),
            orElse: () => urls.first,
          )
        : null;

    return JournalGuidelinesDiscovery(
      candidateUrls: urls,
      primaryUrl: primary,
      log: log,
    );
  }

  static const _stopWords = {
    'journal',
    'international',
    'bulletin',
    'review',
    'letters',
    'annals',
    'proceedings',
    'the',
    'and',
    'of',
  };

  List<String> _journalSlugVariants(String journalName) {
    final variants = <String>{};
    final lower = journalName.toLowerCase();

    final acronymInParens = RegExp(r'\(([A-Za-z]{2,8})\)').firstMatch(journalName);
    if (acronymInParens != null) {
      variants.add(acronymInParens.group(1)!.toLowerCase());
    }

    if (lower.contains('chemical society of ethiopia') || lower.contains('bcse')) {
      variants.add('bcse');
    }

    final words = lower
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toList();

    if (words.isNotEmpty) {
      variants.add(words.first);
      if (words.length >= 2 && words.length <= 6) {
        variants.add(words.map((w) => w[0]).join());
      }
    }

    return variants.toList();
  }

  List<String> _ojsPatternUrls(String journalName) {
    final urls = <String>[];
    final slugs = _journalSlugVariants(journalName);
    const hosts = [
      'https://www.ajol.info/index.php',
      'https://ejol.aau.edu.et/index.php',
    ];
    const paths = [
      '/about/submissions',
      '/information/authors',
      '/about',
    ];

    for (final slug in slugs) {
      for (final host in hosts) {
        for (final path in paths) {
          urls.add('$host/$slug$path');
        }
      }
      urls.add('https://bulletin.csechem.org/index.php/$slug/about/submissions');
    }
    return urls;
  }

  bool _looksLikeGuideUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('author') ||
        lower.contains('submission') ||
        lower.contains('instruction') ||
        lower.contains('guide') ||
        lower.contains('for-authors');
  }

  List<String> _ojsGuidePathsFromBase(String baseUrl) {
    final ojsBase = RegExp(r'(https?://[^/]+/index\.php/[^/?#]+)')
        .firstMatch(baseUrl.trim())
        ?.group(1);
    if (ojsBase == null) return const [];
    return [
      '$ojsBase/about/submissions',
      '$ojsBase/information/authors',
      '$ojsBase/about',
    ];
  }

  List<String> _guidePathsFromHomepage(String homepage) {
    final base = homepage.trim().replaceAll(RegExp(r'/+$'), '');
    final paths = <String>[
      '$base/about/submissions',
      '$base/information/authors',
      '$base/about',
      '$base/author-guidelines',
      '$base/guide-for-authors',
      '$base/instructions-for-authors',
    ];
    paths.addAll(_ojsGuidePathsFromBase(base));
    return paths;
  }

  Future<List<String>> _fetchDoajHomepages(String journalName) async {
    final name = journalName.trim();
    if (name.isEmpty) return const [];
    try {
      final uri = Uri.parse(
        'https://doaj.org/api/search/journals/${Uri.encodeComponent('"$name"')}?pageSize=5',
      );
      final response = await CitationHttp.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'AcadeGate/1.0 (mailto:support@acadegate.com)',
        },
      );
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return const [];
      final results = decoded['results'];
      if (results is! List) return const [];

      final urls = <String>[];
      for (final hit in results) {
        if (hit is! Map) continue;
        final bibjson = hit['bibjson'];
        if (bibjson is! Map) continue;
        final links = bibjson['link'];
        if (links is! List) continue;
        for (final link in links) {
          if (link is Map) {
            final href = link['url']?.toString().trim();
            if (href != null && href.startsWith('http')) urls.add(href);
          }
        }
      }
      return urls.toSet().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> _fetchOpenAlexHomepages(
    String journalName,
    String issn,
  ) async {
    try {
      final cleanIssn = issn.replaceAll(RegExp(r'[^0-9Xx]'), '');
      final uri = cleanIssn.length >= 8
          ? Uri.parse(
              'https://api.openalex.org/sources?filter=issn:${Uri.encodeComponent(cleanIssn)}&per_page=3',
            )
          : Uri.parse(
              'https://api.openalex.org/sources?search=${Uri.encodeComponent(journalName)}&per_page=5',
            );
      final response = await CitationHttp.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'AcadeGate/1.0 (mailto:support@acadegate.com)',
        },
      );
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return const [];
      final results = decoded['results'];
      if (results is! List) return const [];

      return results
          .whereType<Map>()
          .map((r) => r['homepage_url']?.toString().trim())
          .whereType<String>()
          .where((u) => u.startsWith('http'))
          .toSet()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<String?> _fetchCrossrefHomepage(String issn) async {
    final normalized = issn.replaceAll(RegExp(r'[^0-9Xx\-]'), '').trim();
    if (normalized.length < 8) return null;

    final primary = normalized.split(RegExp(r'[,\s;]+')).first.trim();
    final digits = primary.replaceAll('-', '');
    if (digits.length < 8) return null;

    try {
      final uri = Uri.parse('https://api.crossref.org/journals/$primary');
      final response = await CitationHttp.get(
        uri,
        headers: {'User-Agent': 'AcadeGate/1.0 (mailto:support@acadegate.com)'},
      );
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final message = decoded['message'];
      if (message is! Map) return null;

      final url = message['URL']?.toString().trim();
      if (url != null && url.isNotEmpty) return url;
    } catch (_) {}

    return null;
  }

  String? _publisherAuthorGuideUrl(String publisher) {
    final p = publisher.toLowerCase();
    if (p.isEmpty) return null;

    if (p.contains('elsevier')) {
      return 'https://www.elsevier.com/researcher/author/policies-and-guidelines';
    }
    if (p.contains('springer') || p.contains('nature publishing')) {
      return 'https://www.springernature.com/gp/authors/campaigns/how-to-publish';
    }
    if (p.contains('ieee')) {
      return 'https://journals.ieeeauthorcenter.ieee.org/create-your-ieee-journal-article/';
    }
    if (p.contains('wiley')) {
      return 'https://authorservices.wiley.com/author-resources/Journal-Authors/index.html';
    }
    if (p.contains('taylor') || p.contains('francis')) {
      return 'https://authorservices.taylorandfrancis.com/publishing-your-research/writing-your-paper/journal-manuscript-layout-guide/';
    }
    if (p.contains('mdpi')) {
      return 'https://www.mdpi.com/authors';
    }
    if (p.contains('acs') || p.contains('american chemical society')) {
      return 'https://publish.acs.org/publish/author_guidelines';
    }
    if (p.contains('royal society of chemistry') || p == 'rsc') {
      return 'https://www.rsc.org/journals-books-databases/journal-authors/';
    }
    if (p.contains('oxford university press') || p.contains('oup')) {
      return 'https://academic.oup.com/pages/author-guidelines';
    }
    if (p.contains('cambridge university press')) {
      return 'https://www.cambridge.org/core/services/authors/journals';
    }
    if (p.contains('sage')) {
      return 'https://journals.sagepub.com/author-instructions';
    }
    if (p.contains('frontiers')) {
      return 'https://www.frontiersin.org/guidelines/author-guidelines';
    }
    if (p.contains('plos')) {
      return 'https://journals.plos.org/plosone/s/submission-guidelines';
    }
    if (p.contains('hindawi')) {
      return 'https://www.hindawi.com/authors/';
    }
    return null;
  }
}
