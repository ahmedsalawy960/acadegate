import 'package:cloud_firestore/cloud_firestore.dart';



import '../../core/locale/app_translate.dart';

import 'science_news_feeds.dart';



class ScienceNewsItem {

  final String? id;

  final String title;

  final String summary;

  final String source;

  final String category;

  final String url;

  final DateTime? publishedAt;

  final bool isCurated;

  final String? language;



  const ScienceNewsItem({

    this.id,

    required this.title,

    required this.summary,

    required this.source,

    required this.category,

    required this.url,

    this.publishedAt,

    this.isCurated = false,

    this.language,

  });



  factory ScienceNewsItem.fromMap(Map<String, dynamic> map, {String? id}) {

    DateTime? published;

    final raw = map['publishedAt'];

    if (raw is Timestamp) {

      published = raw.toDate();

    } else if (raw is String) {

      published = DateTime.tryParse(raw);

    }



    return ScienceNewsItem(

      id: id,

      title: map['title']?.toString() ?? appTr('خبر علمي', 'Science news'),

      summary: map['summary']?.toString() ?? '',

      source: map['source']?.toString() ?? 'AcadeGate',

      category: map['category']?.toString() ?? ScienceNewsCategory.general,

      url: map['url']?.toString() ?? '',

      publishedAt: published,

      isCurated: true,

      language: map['language']?.toString(),

    );

  }

}

