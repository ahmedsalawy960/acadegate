import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../moderation/approval_status.dart';
import 'science_news_feeds.dart';
import 'science_news_models.dart';

class ScienceNewsService {
  ScienceNewsService._();

  static final ScienceNewsService instance = ScienceNewsService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<ScienceNewsItem>? _rssCache;
  DateTime? _rssCacheTime;

  static const _cacheDuration = Duration(minutes: 30);

  Stream<List<ScienceNewsItem>> watchCurated() {
    return _db
        .collection('science_news')
        .where('approvalStatus', isEqualTo: ApprovalStatus.approved)
        .orderBy('publishedAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ScienceNewsItem.fromMap(doc.data(), id: doc.id))
              .toList(),
        );
  }

  Future<List<ScienceNewsItem>> fetchLiveNews({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _rssCache != null &&
        _rssCacheTime != null &&
        now.difference(_rssCacheTime!) < _cacheDuration) {
      return _rssCache!;
    }

    final curated = await _fetchCuratedOnce();
    final fromRss = await _fetchAllFeeds();

    final merged = <ScienceNewsItem>[...curated, ...fromRss];
    merged.sort((a, b) {
      final ad = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    final deduped = _dedupe(merged);

    if (deduped.isEmpty) {
      return List<ScienceNewsItem>.from(fallbackScienceNews);
    }

    _rssCache = deduped;
    _rssCacheTime = now;
    return deduped;
  }

  Future<List<ScienceNewsItem>> _fetchCuratedOnce() async {
    try {
      final snapshot = await _db
          .collection('science_news')
          .where('approvalStatus', isEqualTo: ApprovalStatus.approved)
          .orderBy('publishedAt', descending: true)
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => ScienceNewsItem.fromMap(doc.data(), id: doc.id))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<ScienceNewsItem>> _fetchAllFeeds() async {
    final results = await Future.wait(
      scienceNewsFeeds.map(_fetchFeed),
    );

    return results.expand((items) => items).toList();
  }

  Future<List<ScienceNewsItem>> _fetchFeed(ScienceNewsFeed feed) async {
    try {
      final response = await http
          .get(Uri.parse(feed.url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return const [];

      final document = XmlDocument.parse(response.body);
      final items = document.findAllElements('item');
      if (items.isEmpty) {
        return _parseAtomEntries(document, feed);
      }

      return items
          .take(8)
          .map((node) => _parseRssItem(node, feed))
          .whereType<ScienceNewsItem>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<ScienceNewsItem> _parseAtomEntries(XmlDocument document, ScienceNewsFeed feed) {
    final entries = document.findAllElements('entry');
    return entries
        .take(8)
        .map((node) => _parseAtomEntry(node, feed))
        .whereType<ScienceNewsItem>()
        .toList();
  }

  ScienceNewsItem? _parseRssItem(XmlElement node, ScienceNewsFeed feed) {
    final title = _elementText(node, 'title');
    final link = _elementText(node, 'link') ?? _linkHref(node);
    if (title == null || title.isEmpty || link == null || link.isEmpty) {
      return null;
    }

    final description = _cleanHtml(
      _elementText(node, 'description') ?? _elementText(node, 'summary') ?? '',
    );

    return ScienceNewsItem(
      title: title.trim(),
      summary: description,
      source: feed.sourceName,
      category: _detectCategory('$title $description', feed.defaultCategory),
      url: link.trim(),
      publishedAt: _parseDate(_elementText(node, 'pubDate')),
    );
  }

  ScienceNewsItem? _parseAtomEntry(XmlElement node, ScienceNewsFeed feed) {
    final title = _elementText(node, 'title');
    final link = _linkHref(node) ?? _elementText(node, 'id');
    if (title == null || title.isEmpty || link == null || link.isEmpty) {
      return null;
    }

    final summary = _cleanHtml(
      _elementText(node, 'summary') ?? _elementText(node, 'content') ?? '',
    );

    return ScienceNewsItem(
      title: title.trim(),
      summary: summary,
      source: feed.sourceName,
      category: _detectCategory('$title $summary', feed.defaultCategory),
      url: link.trim(),
      publishedAt: _parseDate(_elementText(node, 'updated')),
    );
  }

  String? _elementText(XmlElement parent, String localName) {
    final element = parent.getElement(localName);
    return element?.innerText.trim();
  }

  String? _linkHref(XmlElement parent) {
    for (final link in parent.findElements('link')) {
      final href = link.getAttribute('href');
      if (href != null && href.isNotEmpty) return href;
    }
    return null;
  }

  String _cleanHtml(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _detectCategory(String text, String fallback) {
    final lower = text.toLowerCase();
    if (_containsAny(lower, ['medical', 'health', 'clinical', 'طب', 'سريري'])) {
      return ScienceNewsCategory.medicine;
    }
    if (_containsAny(lower, ['engineer', 'material', 'civil', 'هندسة', 'مواد'])) {
      return ScienceNewsCategory.engineering;
    }
    if (_containsAny(lower, ['physics', 'quantum', 'فيزياء', 'كم'])) {
      return ScienceNewsCategory.physics;
    }
    if (_containsAny(lower, ['biology', 'cell', 'gene', 'أحياء', 'خلية'])) {
      return ScienceNewsCategory.biology;
    }
    if (_containsAny(lower, ['ai', 'computer', 'software', 'ذكاء', 'حاسوب'])) {
      return ScienceNewsCategory.technology;
    }
    return fallback;
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any(text.contains);
  }

  List<ScienceNewsItem> _dedupe(List<ScienceNewsItem> items) {
    final seen = <String>{};
    final output = <ScienceNewsItem>[];

    for (final item in items) {
      final key = item.title.toLowerCase().trim();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      output.add(item);
    }

    return output;
  }

  List<ScienceNewsItem> filterByCategory(
    List<ScienceNewsItem> items,
    String category,
  ) {
    if (category == ScienceNewsCategory.all) return items;
    return items.where((item) => item.category == category).toList();
  }
}
