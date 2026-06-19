import 'package:cloud_firestore/cloud_firestore.dart';

class ScienceNewsItem {
  final String? id;
  final String title;
  final String summary;
  final String source;
  final String category;
  final String url;
  final DateTime? publishedAt;
  final bool isCurated;

  const ScienceNewsItem({
    this.id,
    required this.title,
    required this.summary,
    required this.source,
    required this.category,
    required this.url,
    this.publishedAt,
    this.isCurated = false,
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
      title: map['title']?.toString() ?? 'خبر علمي',
      summary: map['summary']?.toString() ?? '',
      source: map['source']?.toString() ?? 'AcadeGate',
      category: map['category']?.toString() ?? 'general',
      url: map['url']?.toString() ?? '',
      publishedAt: published,
      isCurated: true,
    );
  }
}

const fallbackScienceNews = <ScienceNewsItem>[
  ScienceNewsItem(
    title: 'تقدم في خلايا الوقود الهيدروجينية بكفاءة أعلى',
    summary:
        'باحثون يطوّرون مواد محفّزة جديدة تقلل تكلفة إنتاج الهيدروجين الأخضر — مهم لرسائل الطاقة والهندسة الكيميائية.',
    source: 'ScienceDaily',
    category: 'engineering',
    url: 'https://www.sciencedaily.com',
  ),
  ScienceNewsItem(
    title: 'ذكاء اصطناعي يتنبأ بالمضاعفات بعد الجراحة',
    summary:
        'دراسة سريرية تستخدم نماذج تعلم آلي على بيانات المرضى لتحسين المتابعة بعد العمليات.',
    source: 'Nature Medicine',
    category: 'medicine',
    url: 'https://www.nature.com',
  ),
  ScienceNewsItem(
    title: 'اكتشاف مادة فائقة التوصيل تعمل في ضغط أقل',
    summary:
        'فريق فيزياء يبلغ عن نتائج قابلة للتكرار في مواد التوصيل — موضوع ساخن للدكتوراه في الفيزياء.',
    source: 'Phys.org',
    category: 'physics',
    url: 'https://phys.org',
  ),
];
