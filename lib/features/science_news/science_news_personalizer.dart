import '../academic/faculty_categories.dart';
import '../profile/academic_profile.dart';
import 'science_news_feeds.dart';
import 'science_news_models.dart';

class RankedScienceNews {
  final ScienceNewsItem item;
  final int score;
  final List<String> matchedTerms;

  const RankedScienceNews({
    required this.item,
    required this.score,
    this.matchedTerms = const [],
  });
}

class ResearcherNewsDigest {
  final AcademicProfile? profile;
  final String focusLabel;
  final List<String> preferredCategories;
  final List<RankedScienceNews> items;

  const ResearcherNewsDigest({
    this.profile,
    required this.focusLabel,
    required this.preferredCategories,
    required this.items,
  });

  bool get isPersonalized =>
      profile != null &&
      (profile!.specialization.trim().isNotEmpty ||
          profile!.researchInterest.trim().isNotEmpty ||
          (profile!.resolvedFacultyCategory?.isNotEmpty ?? false));
}

/// يربط أخبار العلوم الموجودة بملف الباحث — ليس بموجز عام للمنصة.
class ScienceNewsPersonalizer {
  ScienceNewsPersonalizer._();

  static const forYouCategory = 'for_you';

  static const _stop = {
    'the',
    'and',
    'for',
    'with',
    'from',
    'this',
    'that',
    'into',
    'في',
    'من',
    'على',
    'إلى',
    'عن',
    'مع',
    'أو',
    'ثم',
    'كلية',
    'قسم',
    'علم',
    'علوم',
  };

  static List<String> preferredCategoriesFor(AcademicProfile? profile) {
    final faculty = profile?.resolvedFacultyCategory ?? '';
    final blob =
        '${profile?.specialization ?? ''} ${profile?.researchInterest ?? ''}'
            .toLowerCase();

    if (_hasAny(blob, const [
      'كيمياء',
      'chem',
      'analytical',
      'تحليل',
      'spectro',
      'adsorb',
    ])) {
      return const [
        ScienceNewsCategory.chemistry,
        ScienceNewsCategory.environment,
      ];
    }
    if (_hasAny(blob, const ['فيزياء', 'physics', 'quantum', 'laser'])) {
      return const [
        ScienceNewsCategory.physics,
        ScienceNewsCategory.astronomy,
      ];
    }
    if (_hasAny(blob, const ['أحياء', 'biology', 'gene', 'cell', 'جين'])) {
      return const [
        ScienceNewsCategory.biology,
        ScienceNewsCategory.medicine,
      ];
    }
    if (_hasAny(blob, const ['رياض', 'math', 'إحصاء', 'statist'])) {
      return const [
        ScienceNewsCategory.mathematics,
        ScienceNewsCategory.technology,
      ];
    }

    switch (faculty) {
      case 'Engineering':
      case 'Architecture':
        return const [
          ScienceNewsCategory.engineering,
          ScienceNewsCategory.technology,
        ];
      case 'Medicine':
      case 'Dentistry':
      case 'Pharmacy':
      case 'Nursing':
      case 'Veterinary':
        return const [
          ScienceNewsCategory.medicine,
          ScienceNewsCategory.biology,
        ];
      case 'CS':
        return const [
          ScienceNewsCategory.technology,
          ScienceNewsCategory.mathematics,
        ];
      case 'Agriculture':
        return const [
          ScienceNewsCategory.agriculture,
          ScienceNewsCategory.environment,
        ];
      case 'Education':
      case 'PhysicalEducation':
        return const [ScienceNewsCategory.psychology];
      case 'Science':
        return const [
          ScienceNewsCategory.chemistry,
          ScienceNewsCategory.physics,
          ScienceNewsCategory.biology,
        ];
      default:
        return const [];
    }
  }

  static String focusLabel(AcademicProfile? profile) {
    final spec = profile?.specialization.trim() ?? '';
    if (spec.isNotEmpty) return spec;
    final interest = profile?.researchInterest.trim() ?? '';
    if (interest.isNotEmpty) return interest;
    final faculty = profile?.resolvedFacultyCategory;
    if (faculty != null && faculty.isNotEmpty) {
      return facultyTitleForCategory(faculty);
    }
    return '';
  }

  static List<String> queryTokens(AcademicProfile? profile) {
    if (profile == null) return const [];
    final raw = [
      profile.specialization,
      profile.researchInterest,
      ...profile.skills,
      if (profile.resolvedFacultyCategory != null)
        facultyTitleForCategory(profile.resolvedFacultyCategory!),
    ].join(' ');
    final tokens = <String>{
      ..._tokenize(raw),
      ..._expandSynonyms(raw.toLowerCase()),
    };
    return tokens.toList();
  }

  static List<RankedScienceNews> rank({
    required List<ScienceNewsItem> items,
    AcademicProfile? profile,
    DateTime? now,
  }) {
    if (items.isEmpty) return const [];
    final tokens = queryTokens(profile);
    final cats = preferredCategoriesFor(profile);
    final clock = now ?? DateTime.now();

    final ranked = items.map((item) {
      final hay = '${item.title} ${item.summary} ${item.source} ${item.category}'
          .toLowerCase();
      final matched = <String>[];
      var score = 0;

      if (cats.contains(item.category)) score += 6;

      for (final token in tokens) {
        if (token.length < 3) continue;
        if (hay.contains(token)) {
          matched.add(token);
          score += token.length >= 6 ? 5 : 3;
        }
      }

      final published = item.publishedAt;
      if (published != null) {
        final age = clock.difference(published).inDays;
        if (age <= 7) {
          score += 3;
        } else if (age <= 14) {
          score += 1;
        }
      }

      return RankedScienceNews(
        item: item,
        score: score,
        matchedTerms: matched.take(4).toList(),
      );
    }).toList();

    ranked.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final ad = a.item.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.item.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return ranked;
  }

  static ResearcherNewsDigest weeklyDigest({
    required List<ScienceNewsItem> items,
    AcademicProfile? profile,
    DateTime? now,
    int limit = 8,
  }) {
    final clock = now ?? DateTime.now();
    final ranked = rank(items: items, profile: profile, now: clock);
    final personalized = ranked.where((r) => r.score > 0).toList();
    var weekly = personalized.where((r) {
      final published = r.item.publishedAt;
      if (published == null) return r.score >= 6;
      return clock.difference(published).inDays <= 14;
    }).toList();

    if (weekly.length < 4) {
      weekly = personalized;
    }
    if (weekly.isEmpty) {
      weekly = ranked;
    }

    return ResearcherNewsDigest(
      profile: profile,
      focusLabel: focusLabel(profile),
      preferredCategories: preferredCategoriesFor(profile),
      items: weekly.take(limit).toList(),
    );
  }

  static List<String> _tokenize(String raw) {
    return raw
        .toLowerCase()
        .split(RegExp(r'[\s,،.؛;:/|+\-_()]+'))
        .map((e) => e.trim())
        .where((e) => e.length >= 3 && !_stop.contains(e))
        .toSet()
        .toList();
  }

  static List<String> _expandSynonyms(String blob) {
    final extra = <String>[];
    void addIf(List<String> needles, List<String> syn) {
      if (_hasAny(blob, needles)) extra.addAll(syn);
    }

    addIf(const ['كيمياء', 'chem'], const [
      'chemistry',
      'chemical',
      'molecule',
      'catalyst',
    ]);
    addIf(const ['تحليل', 'analytical'], const [
      'analytical',
      'spectroscop',
      'chromatograph',
      'adsorption',
      'titration',
    ]);
    addIf(const ['فيزياء', 'physics'], const ['physics', 'quantum', 'particle']);
    addIf(const ['أحياء', 'biology', 'جين'], const [
      'biology',
      'genome',
      'protein',
      'cell',
    ]);
    addIf(const ['طب', 'medicine', 'سريري'], const [
      'medical',
      'clinical',
      'patient',
      'health',
    ]);
    addIf(const ['هندس', 'engineer'], const [
      'engineering',
      'material',
      'robot',
    ]);
    addIf(const ['حاسب', 'برمج', 'ذكاء', 'computer', 'ai'], const [
      'algorithm',
      'software',
      'machine learning',
      'neural',
    ]);
    addIf(const ['زراع', 'agricult'], const ['crop', 'soil', 'farm']);
    addIf(const ['بيئ', 'climate', 'تلوث'], const [
      'climate',
      'environment',
      'pollution',
    ]);
    return extra;
  }

  static bool _hasAny(String text, List<String> needles) =>
      needles.any(text.contains);
}
