import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/locale/app_translate.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import '../ai_advisor/grounded_reference_service.dart';
import '../ai_advisor/grounded_work.dart';
import '../academic/academic_models.dart';
import 'topic_duplication_service.dart';
import 'topic_english_search.dart';
import 'topic_similarity.dart';

class TopicAdoptionPack {
  final String title;
  final String details;
  final String category;
  final String englishSearchTopic;
  final List<String> searchQueries;
  final TopicDuplicationReport duplication;
  final List<GroundedWork> starterReferences;
  final List<String> suggestedQuestionsAr;
  final List<String> suggestedQuestionsEn;
  final List<String> nextStepsAr;
  final List<String> nextStepsEn;
  final bool usedAi;
  final DateTime createdAt;

  const TopicAdoptionPack({
    required this.title,
    required this.details,
    required this.category,
    this.englishSearchTopic = '',
    this.searchQueries = const [],
    required this.duplication,
    required this.starterReferences,
    required this.suggestedQuestionsAr,
    required this.suggestedQuestionsEn,
    required this.nextStepsAr,
    required this.nextStepsEn,
    required this.usedAi,
    required this.createdAt,
  });

  String summaryText({required bool arabic}) {
    final b = StringBuffer();
    b.writeln(arabic ? 'اعتماد نقطة بحث' : 'Research point adoption');
    b.writeln(title);
    if (englishSearchTopic.isNotEmpty &&
        englishSearchTopic.trim().toLowerCase() != title.trim().toLowerCase()) {
      b.writeln(
        arabic
            ? 'استعلام البحث الإنجليزي: $englishSearchTopic'
            : 'English search topic: $englishSearchTopic',
      );
    }
    b.writeln('');
    b.writeln(arabic ? 'فحص التكرار (تقريبي):' : 'Duplication check (approx.):');
    b.writeln(arabic ? duplication.overallRiskAr() : duplication.overallRiskEn());
    if (duplication.marketplaceHits.isNotEmpty) {
      b.writeln(arabic ? 'أقرب عناوين داخل التطبيق:' : 'Closest in-app titles:');
      for (final h in duplication.marketplaceHits.take(5)) {
        b.writeln(
          '- (${(h.score * 100).round()}%) ${h.title} · ${h.source}',
        );
      }
    }
    b.writeln('');
    b.writeln(arabic ? 'مراجع أولية:' : 'Starter references:');
    for (final w in starterReferences.take(8)) {
      b.writeln('- ${w.apaLine}');
      if (!w.hasDoi && w.primaryUrl.isNotEmpty) {
        b.writeln(
          arabic
              ? '  (بدون DOI — رابط: ${w.primaryUrl})'
              : '  (no DOI — link: ${w.primaryUrl})',
        );
      }
    }
    b.writeln('');
    b.writeln(arabic ? 'أسئلة مقترحة:' : 'Suggested questions:');
    final qs = arabic ? suggestedQuestionsAr : suggestedQuestionsEn;
    for (var i = 0; i < qs.length; i++) {
      b.writeln('${i + 1}) ${qs[i]}');
    }
    b.writeln('');
    b.writeln(arabic ? 'خطوات تالية:' : 'Next steps:');
    final steps = arabic ? nextStepsAr : nextStepsEn;
    for (final s in steps) {
      b.writeln('• $s');
    }
    b.writeln('');
    b.writeln(
      arabic
          ? 'تنبيه: فحص التكرار تقريبي ولا يغني عن مراجعة دار المنظومة/EKB/مستودع الكلية.'
          : 'Note: duplication check is approximate and does not replace Mandumah/EKB/faculty repository review.',
    );
    return b.toString().trim();
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'details': details,
        'category': category,
        'englishSearchTopic': englishSearchTopic,
        'searchQueries': searchQueries,
        'usedAi': usedAi,
        'createdAt': createdAt.toIso8601String(),
        'questionsAr': suggestedQuestionsAr,
        'questionsEn': suggestedQuestionsEn,
        'nextAr': nextStepsAr,
        'nextEn': nextStepsEn,
        'refs': starterReferences
            .map(
              (w) => {
                'title': w.title,
                'doi': w.doi,
                'year': w.year,
                'authors': w.authors,
                'source': w.source,
                'journal': w.journal,
                'url': w.primaryUrl,
              },
            )
            .toList(),
        'dupRiskAr': duplication.overallRiskAr(),
        'dupRiskEn': duplication.overallRiskEn(),
      };
}

class TopicAdoptionService {
  TopicAdoptionService._();
  static final TopicAdoptionService instance = TopicAdoptionService._();

  static const _kLastPack = 'topic_adoption_last_pack_v1';

  Future<TopicAdoptionPack> buildPack({
    required String title,
    String details = '',
    String category = '',
    AcademicResearchIdea? idea,
  }) async {
    final tags = idea?.tags ?? const <String>[];
    final enPlan = await TopicEnglishSearch.instance.build(
      title: title,
      details: details,
      category: category,
      tags: tags,
    );

    final duplication = await TopicDuplicationService.instance.check(
      title: title,
      details: details,
      excludeIdea: idea,
      englishSearch: enPlan,
    );

    GroundedReferenceBundle refs = const GroundedReferenceBundle(topic: '');
    try {
      final scoreAgainst = enPlan.englishTopic.isNotEmpty
          ? enPlan.englishTopic
          : title;
      refs = await GroundedReferenceService.instance.searchScientific(
        queries: enPlan.queries,
        limit: 12,
        preferEnglish: true,
        minYear: 0,
        includeTheses: true,
        requireDoi: false,
        minScore: 2,
        commandText: '$scoreAgainst\n$details'.trim(),
        corePhrases: TopicSimilarity.tokens(scoreAgainst).take(8),
        strongTokens:
            TopicSimilarity.tokens('$scoreAgainst $details').take(12),
      );
    } catch (_) {
      try {
        refs = await GroundedReferenceService.instance.searchTopic(
          enPlan.englishTopic.isNotEmpty
              ? enPlan.englishTopic
              : '$title\n$details'.trim(),
          limit: 12,
          byRelevance: true,
        );
      } catch (_) {}
    }

    var questionsAr = _localQuestionsAr(title, details, category);
    var questionsEn = _localQuestionsEn(
      enPlan.englishTopic.isNotEmpty ? enPlan.englishTopic : title,
      details,
      category,
    );
    var usedAi = enPlan.usedAi;

    if (GeminiAdvisorClient.isAvailable) {
      try {
        final ai = await _aiQuestions(
          title: title,
          details: details,
          category: category,
        );
        if (ai.$1.isNotEmpty) {
          questionsAr = ai.$1;
          questionsEn = ai.$2.isNotEmpty ? ai.$2 : questionsEn;
          usedAi = true;
        }
      } catch (_) {}
    }

    final pack = TopicAdoptionPack(
      title: title.trim(),
      details: details.trim(),
      category: category,
      englishSearchTopic: enPlan.englishTopic,
      searchQueries: enPlan.queries,
      duplication: duplication,
      starterReferences: refs.works,
      suggestedQuestionsAr: questionsAr,
      suggestedQuestionsEn: questionsEn,
      nextStepsAr: _nextAr(duplication),
      nextStepsEn: _nextEn(duplication),
      usedAi: usedAi,
      createdAt: DateTime.now(),
    );

    await _saveLast(pack);
    return pack;
  }

  Future<void> _saveLast(TopicAdoptionPack pack) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastPack, jsonEncode(pack.toJson()));
  }

  List<String> _localQuestionsAr(String title, String details, String cat) {
    final focus = title.trim().isEmpty ? 'الظاهرة موضع البحث' : title.trim();
    return [
      'ما الفجوة البحثية الدقيقة التي يسدّها موضوع «$focus» مقارنة بالدراسات المصرية الحديثة؟',
      'ما أسئلة البحث الرئيسية والفرعية القابلة للقياس أو التحليل في هذا الموضوع؟',
      'ما المنهج الأنسب (كمّي / نوعي / مختلط / وثائقي) ولماذا يناسب مجتمع الدراسة؟',
      if (cat == 'Education' || details.contains('تربي'))
        'ما المتغيرات أو الأبعاد التربوية الحاكمة، وكيف تُقاس بأدوات ذات صدق وثبات؟',
      if (cat == 'Law' || details.contains('قانون') || details.contains('حقوق'))
        'ما الأسانيد التشريعية والقضائية الحاكمة، وأين موضع المقارنة التشريعية؟',
      'ما حدود الدراسة، وما الذي لن تدّعيه النتائج؟',
      'ما الإسهام المتوقع (نظري / تطبيقي / منهجي) لصنّاع القرار أو الحقل الأكاديمي؟',
    ];
  }

  List<String> _localQuestionsEn(String title, String details, String cat) {
    final focus = title.trim().isEmpty ? 'the phenomenon' : title.trim();
    return [
      'What precise research gap does “$focus” fill versus recent Egyptian studies?',
      'What are the main and sub research questions that are measurable or analysable?',
      'Which methodology fits best (quantitative / qualitative / mixed / doctrinal) and why?',
      if (cat == 'Education')
        'Which educational variables/dimensions matter, and how will they be measured validly?',
      if (cat == 'Law')
        'Which statutes/cases govern the issue, and where is comparative law useful?',
      'What are the study limits — what will findings not claim?',
      'What theoretical/practical/methodological contribution is expected?',
    ];
  }

  List<String> _nextAr(TopicDuplicationReport dup) => [
        'راجع أقرب العناوين المتشابهة وعدّل الزاوية إن لزم.',
        'افتح دار المنظومة/EKB بالروابط الخارجية وأكّد عدم التكرار داخل كليتك.',
        'اعتمد الموضوع (حجز) بعد الاتفاق مع المشرف.',
        'انقل المراجع الأولية إلى استوديو الرسالة أو كاشف المنهجية.',
        if (dup.maxMarketplaceScore >= 0.55)
          'لأن التشابه متوسط/مرتفع: غيّر العينة أو السياق أو الفترة أو الإطار النظري.',
      ];

  List<String> _nextEn(TopicDuplicationReport dup) => [
        'Review closest similar titles and refine the angle if needed.',
        'Open Mandumah/EKB via external links and confirm non-duplication in your faculty.',
        'Claim the topic after supervisor agreement.',
        'Carry starter references into Thesis Studio or methodology check.',
        if (dup.maxMarketplaceScore >= 0.55)
          'Because similarity is medium/high: change sample, context, period, or theory frame.',
      ];

  Future<(List<String>, List<String>)> _aiQuestions({
    required String title,
    required String details,
    required String category,
  }) async {
    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt:
          'You help Egyptian graduate students adopt a thesis topic. '
          'Return JSON only: {"ar":["..."],"en":["..."]} with 5-7 concise research questions. '
          'No fabricated citations. Questions must be specific to the topic.',
      userMessage:
          'Category: $category\nTitle: $title\nDetails:\n${details.length > 1200 ? details.substring(0, 1200) : details}',
      maxOutputTokens: 1200,
    );
    if (!result.isSuccess) return (const <String>[], const <String>[]);
    final text = result.text!.trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return (const <String>[], const <String>[]);
    try {
      final map = jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      final ar = (map['ar'] as List<dynamic>? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final en = (map['en'] as List<dynamic>? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      return (ar, en);
    } catch (_) {
      return (const <String>[], const <String>[]);
    }
  }

  String emptyAiHint() => appTr(
        'الأسئلة المحلية جاهزة دائماً. سجّل الدخول لتحسينها.',
        'Local questions are always ready. Sign in to refine them.',
      );
}
