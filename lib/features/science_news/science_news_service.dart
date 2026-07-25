import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../../core/locale/locale_service.dart';
import '../moderation/approval_status.dart';
import 'science_news_feeds.dart';
import 'science_news_models.dart';

class ScienceNewsService {
  ScienceNewsService._();

  static final ScienceNewsService instance = ScienceNewsService._();

  static const _cloudNewsUrl =
      'https://us-central1-acadegate-new.cloudfunctions.net/scienceNewsRssHttp';

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, List<ScienceNewsItem>> _rssCache = {};
  final Map<String, DateTime> _rssCacheTime = {};

  static const _cacheDuration = Duration(minutes: 30);
  static const _itemsPerFeed = 12;
  static const _maxMergedItems = 200;

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
    final isEnglish = LocaleService.instance.isEnglish;
    final cacheKey = isEnglish ? 'en' : 'ar';
    final now = DateTime.now();

    if (!forceRefresh &&
        _rssCache[cacheKey] != null &&
        _rssCacheTime[cacheKey] != null &&
        now.difference(_rssCacheTime[cacheKey]!) < _cacheDuration) {
      return _rssCache[cacheKey]!;
    }

    final curated = await _fetchCuratedOnce(isEnglish: isEnglish);

    var fromRss = await _fetchViaCloud(isEnglish: isEnglish);
    if (fromRss.isEmpty && !kIsWeb) {
      fromRss = await _fetchAllFeedsDirect(isEnglish: isEnglish);
    }

    final merged = <ScienceNewsItem>[...curated, ...fromRss];
    merged.sort((a, b) {
      final ad = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    var deduped = _dedupe(merged);
    if (deduped.length > _maxMergedItems) {
      deduped = deduped.take(_maxMergedItems).toList();
    }

    if (deduped.isEmpty) {
      return const [];
    }

    _rssCache[cacheKey] = deduped;
    _rssCacheTime[cacheKey] = now;
    return deduped;
  }

  Future<List<ScienceNewsItem>> _fetchViaCloud({
    required bool isEnglish,
  }) async {
    try {
      final lang = isEnglish ? 'en' : 'ar';
      final uri = Uri.parse('$_cloudNewsUrl?lang=$lang');
      final response = await http.get(uri).timeout(const Duration(seconds: 90));
      if (response.statusCode != 200) return const [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final rawItems = body['items'];
      if (rawItems is! List) return const [];

      return rawItems
          .whereType<Map>()
          .map((m) => _itemFromCloudMap(Map<String, dynamic>.from(m)))
          .whereType<ScienceNewsItem>()
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('scienceNewsRssHttp failed: $e');
      return const [];
    }
  }

  ScienceNewsItem? _itemFromCloudMap(Map<String, dynamic> map) {
    final title = map['title']?.toString().trim() ?? '';
    final url = map['url']?.toString().trim() ?? '';
    if (title.isEmpty || url.isEmpty) return null;

    DateTime? published;
    final rawDate = map['publishedAt']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      published = DateTime.tryParse(rawDate);
    }

    return ScienceNewsItem(
      title: title,
      summary: map['summary']?.toString() ?? '',
      source: map['source']?.toString() ?? 'Science',
      category: map['category']?.toString() ?? ScienceNewsCategory.general,
      url: url,
      publishedAt: published,
      language: map['language']?.toString(),
    );
  }

  Future<List<ScienceNewsItem>> _fetchCuratedOnce({
    required bool isEnglish,
  }) async {
    try {
      final snapshot = await _db
          .collection('science_news')
          .where('approvalStatus', isEqualTo: ApprovalStatus.approved)
          .orderBy('publishedAt', descending: true)
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => ScienceNewsItem.fromMap(doc.data(), id: doc.id))
          .where((item) => _matchesLocale(item, isEnglish: isEnglish))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  bool _matchesLocale(ScienceNewsItem item, {required bool isEnglish}) {
    if (item.language == null) return true;
    return isEnglish ? item.language == 'en' : item.language == 'ar';
  }

  Future<List<ScienceNewsItem>> _fetchAllFeedsDirect({
    required bool isEnglish,
  }) async {
    final feeds = scienceNewsFeedsForLocale(isEnglish: isEnglish);
    final results = await Future.wait(feeds.map(_fetchFeed));
    return results.expand((items) => items).toList();
  }

  Future<List<ScienceNewsItem>> _fetchFeed(ScienceNewsFeed feed) async {
    try {
      final response = await http
          .get(Uri.parse(feed.url))
          .timeout(const Duration(seconds: 18));

      if (response.statusCode != 200) return const [];

      final document = XmlDocument.parse(response.body);
      final items = document.findAllElements('item');
      if (items.isEmpty) {
        return _parseAtomEntries(document, feed);
      }

      return items
          .take(_itemsPerFeed)
          .map((node) => _parseRssItem(node, feed))
          .whereType<ScienceNewsItem>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<ScienceNewsItem> _parseAtomEntries(
    XmlDocument document,
    ScienceNewsFeed feed,
  ) {
    final entries = document.findAllElements('entry');
    return entries
        .take(_itemsPerFeed)
        .map((node) => _parseAtomEntry(node, feed))
        .whereType<ScienceNewsItem>()
        .toList();
  }

  String _resolveCategory(String text, ScienceNewsFeed feed) {
    if (feed.defaultCategory != ScienceNewsCategory.general) {
      return feed.defaultCategory;
    }
    return _detectCategory(text, feed.defaultCategory);
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
      source: feed.displaySource,
      category: _resolveCategory('$title $description', feed),
      url: link.trim(),
      publishedAt: _parseDate(_elementText(node, 'pubDate')),
      language: feed.language,
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
      source: feed.displaySource,
      category: _resolveCategory('$title $summary', feed),
      url: link.trim(),
      publishedAt: _parseDate(_elementText(node, 'updated')),
      language: feed.language,
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

    if (_containsAny(lower, ['medical', 'health', 'clinical', 'cancer', 'virus'])) {
      return ScienceNewsCategory.medicine;
    }
    if (_containsAny(lower, ['engineer', 'material', 'robot', 'ieee'])) {
      return ScienceNewsCategory.engineering;
    }
    if (_containsAny(lower, ['physics', 'quantum', 'particle', 'laser'])) {
      return ScienceNewsCategory.physics;
    }
    if (_containsAny(lower, ['chemistry', 'chemical', 'molecule', 'catalyst'])) {
      return ScienceNewsCategory.chemistry;
    }
    if (_containsAny(lower, ['biology', 'cell', 'gene', 'genome', 'protein'])) {
      return ScienceNewsCategory.biology;
    }
    if (_containsAny(lower, ['climate', 'environment', 'pollution', 'carbon'])) {
      return ScienceNewsCategory.environment;
    }
    if (_containsAny(lower, ['agriculture', 'crop', 'farm', 'soil'])) {
      return ScienceNewsCategory.agriculture;
    }
    if (_containsAny(lower, ['psychology', 'brain', 'mental', 'cognitive'])) {
      return ScienceNewsCategory.psychology;
    }
    if (_containsAny(lower, ['space', 'nasa', 'galaxy', 'telescope', 'planet'])) {
      return ScienceNewsCategory.astronomy;
    }
    if (_containsAny(lower, ['math', 'algorithm', 'statistics', 'theorem'])) {
      return ScienceNewsCategory.mathematics;
    }
    if (_containsAny(lower, ['ai', 'computer', 'software', 'digital', 'chip'])) {
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
