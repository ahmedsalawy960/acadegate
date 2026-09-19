import '../../core/locale/app_translate.dart';
import '../academic/faculty_categories.dart';
import '../profile/academic_profile.dart';
import '../supervisor_metrics/scimago_quartile_service.dart';
import 'journal_pick_item.dart';
import 'publish_models.dart';

class JournalMatch {
  final JournalPickItem journal;
  final int score;
  final List<String> reasons;

  const JournalMatch({
    required this.journal,
    required this.score,
    required this.reasons,
  });
}

/// يرشّح عدة مجلات من Scimago + الشركاء وفق عنوان/ملخص المخطوطة
/// وتخصص واهتمام الطالب الأكاديمي.
class JournalRecommendationEngine {
  JournalRecommendationEngine._();

  static List<JournalMatch> recommend({
    required PublishManuscript? manuscript,
    required AcademicProfile? profile,
    required List<PublishJournal> partners,
    String? quartileFilter,
    int limit = 8,
  }) {
    final ctx = _RecommendationContext.from(manuscript, profile);
    if (ctx.isWeak) return const [];

    final partnerTitles = partners
        .map((j) => j.name.trim().toLowerCase())
        .where((n) => n.isNotEmpty)
        .toSet();

    final candidates = <JournalPickItem>[
      ...partners.map(JournalPickItem.fromFirebase),
      ...ScimagoQuartileService.instance.catalog
          .where(
            (j) => !partnerTitles.contains(j.title.trim().toLowerCase()),
          )
          .where(
            (j) =>
                quartileFilter == null ||
                quartileFilter.isEmpty ||
                j.quartile == quartileFilter,
          )
          .map(JournalPickItem.fromScimago),
    ];

    if (quartileFilter != null && quartileFilter.isNotEmpty) {
      candidates.removeWhere(
        (j) => !j.isPartner && j.quartile != quartileFilter,
      );
    }

    // تسريع: ركّز على مرشحين يلمسون حقول الكلية أو رموز الموضوع
    final focused = _narrowPool(candidates, ctx);
    final pool = focused.isNotEmpty ? focused : candidates;

    final scored = <JournalMatch>[];
    for (final journal in pool) {
      final match = _score(journal, ctx);
      if (match.score > 0) scored.add(match);
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final aSjr = a.journal.sjr ?? 0;
      final bSjr = b.journal.sjr ?? 0;
      return bSjr.compareTo(aSjr);
    });

    // تنويع: لا تكرّر نفس العنوان
    final seen = <String>{};
    final unique = <JournalMatch>[];
    for (final m in scored) {
      final key = m.journal.name.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      unique.add(m);
      if (unique.length >= limit) break;
    }
    return unique;
  }

  static List<JournalPickItem> _narrowPool(
    List<JournalPickItem> candidates,
    _RecommendationContext ctx,
  ) {
    if (ctx.fieldTerms.isEmpty && ctx.topicTokens.isEmpty) {
      return candidates;
    }

    final narrowed = candidates.where((j) {
      final hay = _haystack(j);
      for (final term in ctx.fieldTerms) {
        if (hay.contains(term)) return true;
      }
      var hits = 0;
      for (final token in ctx.topicTokens) {
        if (token.length < 3) continue;
        if (hay.contains(token)) {
          hits++;
          if (hits >= 1) return true;
        }
      }
      return j.isPartner; // الشركاء دائماً ضمن التقييم
    }).toList();

    // حد أقصى معقول للأداء على كتالوج Scimago الكامل
    if (narrowed.length > 1200) {
      return narrowed.take(1200).toList();
    }
    return narrowed;
  }

  static JournalMatch _score(
    JournalPickItem journal,
    _RecommendationContext ctx,
  ) {
    var score = 0;
    final reasons = <String>[];
    final hay = _haystack(journal);

    var fieldHits = 0;
    for (final term in ctx.fieldTerms) {
      if (hay.contains(term)) fieldHits++;
    }
    if (fieldHits > 0) {
      score += (28 + fieldHits * 6).clamp(28, 48);
      reasons.add(
        appTr(
          'مجال المجلة قريب من كليتك/تخصصك',
          'Journal field aligns with your faculty/specialization',
        ),
      );
    }

    var topicHits = 0;
    final matchedTopics = <String>[];
    for (final token in ctx.topicTokens) {
      if (token.length < 3) continue;
      if (hay.contains(token)) {
        topicHits++;
        if (matchedTopics.length < 3) matchedTopics.add(token);
      }
    }
    if (topicHits > 0) {
      score += (topicHits * 10).clamp(12, 42);
      reasons.add(
        appTr(
          'تطابق مع نقطة بحثك: ${matchedTopics.join(' · ')}',
          'Matches your research focus: ${matchedTopics.join(' · ')}',
        ),
      );
    }

    // تطابق عبارات أطول من العنوان/الاهتمام
    for (final phrase in ctx.phrases) {
      if (phrase.length < 5) continue;
      if (hay.contains(phrase)) {
        score += 18;
        reasons.add(
          appTr(
            'عبارة بحثك تظهر في تصنيف المجلة',
            'Your research phrase appears in the journal scope',
          ),
        );
        break;
      }
    }

    if (journal.isPartner) {
      score += 12;
      reasons.add(
        appTr('مجلة شريكة على AcadeGate', 'Partner journal on AcadeGate'),
      );
    }

    // تفضيل طفيف للجودة دون إخفاء Q2–Q4 المناسبة للتخصص
    score += switch (journal.quartile) {
      'Q1' => 6,
      'Q2' => 4,
      'Q3' => 2,
      _ => 0,
    };

    if (journal.sjr != null && journal.sjr! > 1.0) {
      score += 2;
    }

    return JournalMatch(
      journal: journal,
      score: score.clamp(0, 100),
      reasons: reasons.toSet().take(3).toList(),
    );
  }

  static String _haystack(JournalPickItem j) {
    return _normalize(
      [
        j.name,
        j.publisher,
        j.categories,
        j.partnerUniversity ?? '',
      ].join(' '),
    );
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _RecommendationContext {
  final Set<String> topicTokens;
  final Set<String> fieldTerms;
  final Set<String> phrases;
  final bool isWeak;

  const _RecommendationContext({
    required this.topicTokens,
    required this.fieldTerms,
    required this.phrases,
    required this.isWeak,
  });

  factory _RecommendationContext.from(
    PublishManuscript? manuscript,
    AcademicProfile? profile,
  ) {
    final topicTokens = <String>{};
    final fieldTerms = <String>{};
    final phrases = <String>{};

    void addText(String? raw, {bool asPhrase = false}) {
      final text = (raw ?? '').trim();
      if (text.isEmpty) return;
      final normalized = JournalRecommendationEngine._normalize(text);
      if (asPhrase && normalized.length >= 5) {
        phrases.add(normalized);
      }
      for (final token in normalized.split(' ')) {
        if (token.length >= 3 && !_stopWords.contains(token)) {
          topicTokens.add(token);
        }
      }
      // توسيع عربي → إنجليزي لمطابقة Categories في Scimago
      for (final en in _expandToEnglish(text)) {
        fieldTerms.add(en);
        topicTokens.add(en);
      }
    }

    if (manuscript != null) {
      addText(manuscript.title, asPhrase: true);
      addText(manuscript.abstractText);
      final bodySnippet = manuscript.plainBodyFromBlocks;
      if (bodySnippet.length > 40) {
        addText(
          bodySnippet.length > 600
              ? bodySnippet.substring(0, 600)
              : bodySnippet,
        );
      }
    }

    if (profile != null) {
      addText(profile.specialization, asPhrase: true);
      addText(profile.researchInterest, asPhrase: true);
      for (final skill in profile.skills) {
        addText(skill);
      }
      final facultyId = profile.resolvedFacultyCategory;
      if (facultyId != null) {
        fieldTerms.addAll(_facultyFieldTerms[facultyId] ?? const {});
        addText(facultyTitleForCategory(facultyId));
      }
    }

    // إن وُجدت كلية مستنتجة من عنوان المخطوطة فقط
    final inferred = inferFacultyCategoryFromText(
      [
        manuscript?.title ?? '',
        manuscript?.abstractText ?? '',
        profile?.specialization ?? '',
        profile?.researchInterest ?? '',
      ].join(' '),
    );
    if (inferred != null) {
      fieldTerms.addAll(_facultyFieldTerms[inferred] ?? const {});
    }

    final isWeak = topicTokens.length < 2 && fieldTerms.isEmpty;
    return _RecommendationContext(
      topicTokens: topicTokens,
      fieldTerms: fieldTerms,
      phrases: phrases,
      isWeak: isWeak,
    );
  }
}

/// مصطلحات Scimago الشائعة لكل كلية.
const _facultyFieldTerms = <String, Set<String>>{
  'Engineering': {
    'engineering',
    'electrical',
    'mechanical',
    'civil',
    'materials',
    'chemical engineering',
    'industrial',
    'control',
    'energy',
  },
  'Science': {
    'chemistry',
    'physics',
    'biology',
    'mathematics',
    'biochemistry',
    'geology',
    'ecology',
    'astronomy',
    'multidisciplinary',
  },
  'Medicine': {
    'medicine',
    'medical',
    'clinical',
    'health',
    'surgery',
    'cardiology',
    'oncology',
    'public health',
  },
  'Dentistry': {'dentistry', 'dental', 'oral'},
  'Pharmacy': {
    'pharmacy',
    'pharmacology',
    'pharmaceutical',
    'drug',
    'toxicology',
  },
  'Nursing': {'nursing', 'midwifery', 'care'},
  'Veterinary': {'veterinary', 'animal', 'zoonotic'},
  'Law': {'law', 'legal', 'criminology', 'justice'},
  'CS': {
    'computer science',
    'artificial intelligence',
    'software',
    'information systems',
    'machine learning',
    'data',
    'cyber',
    'computational',
  },
  'Agriculture': {
    'agriculture',
    'agronomy',
    'food science',
    'horticulture',
    'soil',
    'plant',
  },
  'Business': {
    'business',
    'management',
    'economics',
    'finance',
    'accounting',
    'marketing',
  },
  'Education': {
    'education',
    'educational',
    'teaching',
    'learning',
    'pedagogy',
  },
  'Arts': {
    'literature',
    'history',
    'linguistics',
    'philosophy',
    'sociology',
    'humanities',
  },
  'Architecture': {'architecture', 'urban', 'building', 'planning'},
  'MassCommunication': {
    'communication',
    'media',
    'journalism',
    'broadcasting',
  },
  'Tourism': {'tourism', 'hospitality', 'leisure'},
  'PhysicalEducation': {'sport', 'sports', 'physical education', 'exercise'},
  'FineArts': {'art', 'design', 'visual', 'performing'},
};

/// توسيع كلمات عربية/شائعة إلى مصطلحات إنجليزية تظهر في Scimago.
Set<String> _expandToEnglish(String text) {
  final lower = text.toLowerCase();
  final out = <String>{};
  const map = <String, List<String>>{
    'ذكاء اصطناعي': ['artificial intelligence', 'machine learning', 'computer science'],
    'تعلم آلي': ['machine learning', 'artificial intelligence'],
    'علم بيانات': ['data', 'computer science', 'information systems'],
    'برمج': ['software', 'computer science'],
    'حاسب': ['computer science', 'information systems'],
    'كيمياء': ['chemistry', 'chemical'],
    'فيزياء': ['physics'],
    'أحياء': ['biology', 'biological'],
    'بيولوجيا': ['biology'],
    'رياضيات': ['mathematics', 'mathematical'],
    'صيدل': ['pharmacy', 'pharmacology', 'pharmaceutical'],
    'طب': ['medicine', 'medical', 'clinical'],
    'أسنان': ['dentistry', 'dental'],
    'تمريض': ['nursing'],
    'بيطر': ['veterinary'],
    'هندسة': ['engineering'],
    'كهرب': ['electrical', 'engineering'],
    'ميكانيك': ['mechanical', 'engineering'],
    'مدني': ['civil', 'engineering'],
    'زراع': ['agriculture', 'agronomy'],
    'تعليم': ['education', 'educational'],
    'تربية': ['education'],
    'قانون': ['law', 'legal'],
    'إدارة': ['management', 'business'],
    'محاسب': ['accounting', 'finance'],
    'اقتصاد': ['economics'],
    'إعلام': ['communication', 'media', 'journalism'],
    'عمارة': ['architecture'],
    'نانو': ['nanotechnology', 'materials', 'nanoscience'],
    'بيئة': ['environmental', 'ecology'],
    'طاقة': ['energy', 'renewable'],
    'مواد': ['materials'],
    'إحصاء': ['statistics', 'mathematics'],
    'نفس': ['psychology'],
    'اجتماع': ['sociology'],
    'لغو': ['linguistics', 'language'],
    'تاريخ': ['history'],
    'أدب': ['literature'],
    'machine learning': ['machine learning', 'artificial intelligence'],
    'deep learning': ['machine learning', 'artificial intelligence'],
    'neural': ['artificial intelligence', 'computer science'],
    'iot': ['internet of things', 'engineering', 'computer science'],
    'blockchain': ['computer science', 'information systems'],
  };

  for (final entry in map.entries) {
    if (lower.contains(entry.key)) {
      out.addAll(entry.value.map(JournalRecommendationEngine._normalize));
    }
  }
  return out;
}

const _stopWords = <String>{
  'the', 'and', 'for', 'with', 'from', 'this', 'that', 'into', 'using',
  'based', 'study', 'research', 'paper', 'article', 'journal', 'of', 'in',
  'on', 'to', 'a', 'an', 'or', 'by', 'as', 'at', 'is', 'are', 'be',
  'من', 'في', 'على', 'إلى', 'عن', 'مع', 'هذا', 'هذه', 'التي', 'الذي',
  'دراسة', 'بحث', 'ورقة', 'مقالة', 'مجلة', 'باستخدام', 'نحو', 'بين',
};
