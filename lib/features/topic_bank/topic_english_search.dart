import 'dart:convert';

import '../academic/faculty_departments.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import '../research_supply_chain/research_goal.dart';

/// English bibliographic queries for topic adoption / prior studies.
/// Arabic titles alone return almost nothing from Scholar / OpenAlex.
class TopicEnglishSearchPlan {
  final List<String> queries;
  final String englishTopic;
  final bool usedAi;
  final bool translatedFromArabic;

  const TopicEnglishSearchPlan({
    required this.queries,
    required this.englishTopic,
    this.usedAi = false,
    this.translatedFromArabic = false,
  });
}

class TopicEnglishSearch {
  TopicEnglishSearch._();
  static final TopicEnglishSearch instance = TopicEnglishSearch._();

  Future<TopicEnglishSearchPlan> build({
    required String title,
    String details = '',
    String category = '',
    List<String> tags = const [],
  }) async {
    final t = title.trim();
    final d = details.trim();
    final arabic = ResearchGoalParser.containsArabic(t) ||
        ResearchGoalParser.containsArabic(d);
    final latinBits = ResearchGoalParser.englishQueriesFromText(
      '$t\n$d\n${tags.join(' ')}',
    );
    final facultyEn = _facultyEn(category);

    if (!arabic) {
      final qs = <String>[
        t,
        if (d.length > 24)
          d.length > 140 ? d.substring(0, 140) : d,
        if (facultyEn.isNotEmpty) '$t $facultyEn',
        ...latinBits,
      ];
      return TopicEnglishSearchPlan(
        queries: _unique(qs),
        englishTopic: t,
      );
    }

    if (GeminiAdvisorClient.isAvailable) {
      try {
        final ai = await _aiPlan(
          title: t,
          details: d,
          category: category,
          facultyEn: facultyEn,
          latinBits: latinBits,
          tags: tags,
        );
        if (ai != null && ai.queries.isNotEmpty) return ai;
      } catch (_) {}
    }

    return _offlinePlan(
      title: t,
      details: d,
      facultyEn: facultyEn,
      latinBits: latinBits,
      tags: tags,
    );
  }

  Future<TopicEnglishSearchPlan?> _aiPlan({
    required String title,
    required String details,
    required String category,
    required String facultyEn,
    required List<String> latinBits,
    required List<String> tags,
  }) async {
    final cut = details.length > 900 ? details.substring(0, 900) : details;
    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: '''
You are a bilingual scientific librarian (Arabic ↔ English).
Convert an Arabic (or mixed) research-idea title into ENGLISH bibliographic search queries
for Google Scholar, OpenAlex, Crossref, and Semantic Scholar.
Return JSON only:
{"topic":"short ENGLISH topic 6-14 words","queries":["q1","q2","q3","q4","q5"]}
Rules:
- Understand Arabic academic wording; translate the scientific object, method, and context accurately.
- Prefer standard scholarly English; keep Egypt/local context when present (e.g. Egypt, Nile, Cairo).
- Keep the SAME research object — do not invent a different topic.
- Each query: 5–16 English words, specific enough for Scholar (include distinctive nouns).
- Produce VARIED queries: (1) core topic, (2) topic + Egypt, (3) topic + method words if present, (4) topic + review/empirical, (5) topic + faculty field terms.
- No Arabic script in topic or queries.
- Append discipline keywords from the faculty when helpful.
''',
      userMessage: '''
Faculty / category: $category ${facultyEn.isEmpty ? '' : '($facultyEn)'}
Tags: ${tags.join(', ')}
Latin phrases already in text: ${latinBits.join(', ')}

Arabic title:
$title

Details (context):
$cut
''',
      maxOutputTokens: 700,
      preferPro: true,
    );
    if (!result.isSuccess || result.text == null) return null;
    final text = result.text!.trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final map =
          jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      final topic = (map['topic']?.toString() ?? '').trim();
      final rawQs = (map['queries'] as List<dynamic>? ?? const [])
          .map((e) => e.toString().trim())
          .where(
            (e) =>
                e.length >= 6 && !ResearchGoalParser.containsArabic(e),
          )
          .toList();
      final englishTopic = topic.isNotEmpty &&
              !ResearchGoalParser.containsArabic(topic)
          ? topic
          : (rawQs.isNotEmpty ? rawQs.first : facultyEn);
      final queries = _unique([
        ...rawQs,
        if (englishTopic.isNotEmpty) englishTopic,
        if (englishTopic.isNotEmpty)
          '$englishTopic thesis OR dissertation',
        if (facultyEn.isNotEmpty && englishTopic.isNotEmpty)
          '$englishTopic $facultyEn',
        ...latinBits,
      ]);
      if (queries.isEmpty) return null;
      return TopicEnglishSearchPlan(
        queries: queries,
        englishTopic: englishTopic.isNotEmpty ? englishTopic : queries.first,
        usedAi: true,
        translatedFromArabic: true,
      );
    } catch (_) {
      return null;
    }
  }

  TopicEnglishSearchPlan _offlinePlan({
    required String title,
    required String details,
    required String facultyEn,
    required List<String> latinBits,
    required List<String> tags,
  }) {
    final glossaryHits = <String>[];
    final hay = '$title\n$details\n${tags.join(' ')}';
    for (final e in _glossary.entries) {
      if (hay.contains(e.key)) glossaryHits.add(e.value);
    }

    final core = _unique([
      ...latinBits,
      ...glossaryHits,
      if (facultyEn.isNotEmpty) facultyEn,
    ]);

    String topic;
    if (latinBits.isNotEmpty) {
      topic = latinBits.take(4).join(' ');
    } else if (glossaryHits.isNotEmpty) {
      topic = glossaryHits.take(5).join(' ');
      if (facultyEn.isNotEmpty && !topic.toLowerCase().contains(facultyEn.toLowerCase())) {
        topic = '$topic $facultyEn';
      }
    } else if (facultyEn.isNotEmpty) {
      topic = '$facultyEn research Egypt';
    } else {
      topic = 'Egypt research thesis';
    }

    final queries = _unique([
      topic,
      '$topic Egypt',
      '$topic thesis OR dissertation',
      if (glossaryHits.length >= 2)
        '${glossaryHits.take(4).join(' ')} Egypt',
      ...core,
    ]);

    return TopicEnglishSearchPlan(
      queries: queries,
      englishTopic: topic,
      translatedFromArabic: true,
    );
  }

  static String _facultyEn(String category) {
    final id = category.trim();
    if (id.isEmpty) return '';
    var en = FacultyDepartments.facultyTitleEn(id);
    en = en
        .replaceFirst(RegExp(r'^Faculty of\s+', caseSensitive: false), '')
        .trim();
    if (en.isNotEmpty && en != id) return en;
    if (RegExp(r'^[A-Za-z]').hasMatch(id)) {
      return id.replaceAll(RegExp(r'(?<=[a-z])(?=[A-Z])'), ' ');
    }
    return '';
  }

  static List<String> _unique(Iterable<String> raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final q in raw) {
      final t = q.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (t.length < 4) continue;
      if (ResearchGoalParser.containsArabic(t)) continue;
      if (seen.add(t.toLowerCase())) out.add(t);
    }
    return out.take(6).toList();
  }

  /// Frequent academic Arabic → English for offline Scholar queries.
  static const Map<String, String> _glossary = {
    'توأم رقمي': 'digital twin',
    'ذكاء اصطناعي': 'artificial intelligence',
    'تعلم الآلة': 'machine learning',
    'تعلّم الآلة': 'machine learning',
    'تحلية': 'desalination',
    'طاقة شمسية': 'solar energy',
    'ميكروبلاستيك': 'microplastic',
    'النيل': 'Nile',
    'خرسانة': 'concrete',
    'انبعاثات': 'emissions',
    'ازدحام': 'traffic congestion',
    'اهتزاز': 'vibration',
    'جسور': 'bridges',
    'مياه': 'water',
    'تسرب': 'leak detection',
    'تربية خاصة': 'special education',
    'تكنولوجيا مساعدة': 'assistive technology',
    'الدمج': 'inclusive education',
    'مناهج': 'curriculum',
    'معلمين': 'teachers',
    'طلاب': 'students',
    'قانون': 'law',
    'تشريع': 'legislation',
    'قضائي': 'judicial',
    'حقوق': 'rights',
    'إعلام': 'media',
    'صحافة': 'journalism',
    'أدب': 'literature',
    'لغة': 'language',
    'ترجمة': 'translation',
    'سياحة': 'tourism',
    'إدارة': 'management',
    'محاسبة': 'accounting',
    'تمويل': 'finance',
    'تسويق': 'marketing',
    'زراعة': 'agriculture',
    'طب': 'medicine',
    'صيدلة': 'pharmacy',
    'تمريض': 'nursing',
    'هندسة': 'engineering',
    'برمجيات': 'software',
    'أمن سيبراني': 'cybersecurity',
    'بيانات': 'data',
    'استدامة': 'sustainability',
    'مناخ': 'climate',
    'تلوث': 'pollution',
    'صحة': 'health',
    'نفسي': 'psychological',
    'اجتماعي': 'social',
    'تعليمي': 'educational',
    'تربوي': 'educational',
    'تحصيل': 'academic achievement',
    'دافعية': 'motivation',
    'استبانة': 'questionnaire',
    'مقابلة': 'interview',
    'تحليل مضمون': 'content analysis',
    'تعلم إلكتروني': 'e-learning',
    'فصل مقلوب': 'flipped classroom',
    'كفايات': 'competencies',
    'معلم': 'teacher',
    'طالب': 'student',
    'مدرسة': 'school',
    'جامعة': 'university',
    'دستوري': 'constitutional',
    'مدني': 'civil law',
    'جنائي': 'criminal law',
    'إداري': 'administrative law',
    'عقد': 'contract',
    'مسؤولية': 'liability',
    'خطاب': 'discourse',
    'رواية': 'novel',
    'شعر': 'poetry',
    'لسانيات': 'linguistics',
    'نقد أدبي': 'literary criticism',
    'رأي عام': 'public opinion',
    'شبكات اجتماعية': 'social media',
    'فندق': 'hotel',
    'رضا': 'satisfaction',
    'أداء': 'performance',
    'حوكمة': 'governance',
    'مصر': 'Egypt',
    'القاهرة': 'Cairo',
    'رسالة': 'thesis',
    'ماجستير': 'masters thesis',
    'دكتوراه': 'doctoral dissertation',
  };
}
