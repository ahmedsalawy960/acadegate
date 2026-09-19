import '../../core/locale/app_translate.dart';
import '../acadegate_publish/publish_models.dart';
import '../profile/academic_profile.dart';
import '../research_supply_chain/research_goal.dart';
import 'thesis_studio_discipline.dart';

/// Literary / argumentative vs lab-experimental vs empirical social.
enum ThesisKind { literary, experimental, empirical }

/// Real thesis spines used in Arab universities and English STEM/humanities.
enum ThesisShape {
  /// إطار عام · إطار نظري ودراسات سابقة · مباحث تحليلية · خاتمة
  arabicLiterary,

  /// إطار عام · دراسات سابقة · منهجية · نتائج ومناقشة · استنتاجات
  arabicEmpirical,

  /// Introduction · Literature · Experimental · Results and Discussion · Conclusion
  englishExperimentalMerged,

  /// Introduction · Literature · Experimental · Results · Discussion · Conclusion
  englishExperimentalSplit,

  /// Introduction · scholarship · thematic chapters · Conclusion
  englishHumanities;

  bool get isArabicSpine =>
      this == ThesisShape.arabicLiterary || this == ThesisShape.arabicEmpirical;
}

enum ThesisChapterDepth { full, protocol, scaffold }

class ThesisKindGuess {
  final ThesisKind kind;
  final ThesisShape shape;
  final bool arabic;

  const ThesisKindGuess({
    required this.kind,
    required this.shape,
    required this.arabic,
  });
}

class ThesisPlan {
  final ResearchGoal goal;
  final ThesisKind kind;
  final ThesisShape shape;
  final bool arabic;
  final PublishCitationStyle citationStyle;
  final int targetPages;
  final ThesisDiscipline discipline;

  const ThesisPlan({
    required this.goal,
    required this.kind,
    required this.shape,
    required this.arabic,
    this.citationStyle = PublishCitationStyle.apa,
    this.targetPages = 40,
    this.discipline = ThesisDiscipline.empty,
  });

  ThesisPlan copyWith({
    ResearchGoal? goal,
    ThesisKind? kind,
    ThesisShape? shape,
    bool? arabic,
    PublishCitationStyle? citationStyle,
    int? targetPages,
    ThesisDiscipline? discipline,
  }) {
    return ThesisPlan(
      goal: goal ?? this.goal,
      kind: kind ?? this.kind,
      shape: shape ?? this.shape,
      arabic: arabic ?? this.arabic,
      citationStyle: citationStyle ?? this.citationStyle,
      targetPages: targetPages ?? this.targetPages,
      discipline: discipline ?? this.discipline,
    );
  }

  String get kindLabel => switch (kind) {
        ThesisKind.literary => appTr('رسالة أدبية / إنسانية', 'Literary / humanities'),
        ThesisKind.experimental => appTr('رسالة معملية / تجريبية', 'Lab / experimental'),
        ThesisKind.empirical => appTr('رسالة ميدانية / إحصائية', 'Empirical / statistical'),
      };

  String get shapeLabel => switch (shape) {
        ThesisShape.arabicLiterary =>
          appTr('هيكل عربي أدبي (مباحث موضوعية)', 'Arabic literary (thematic chapters)'),
        ThesisShape.arabicEmpirical =>
          appTr('هيكل عربي خماسي (نتائج ومناقشة)', 'Arabic 5-chapter (results & discussion)'),
        ThesisShape.englishExperimentalMerged =>
          'Introduction · Literature · Experimental · Results and Discussion',
        ThesisShape.englishExperimentalSplit =>
          'Introduction · Literature · Experimental · Results · Discussion',
        ThesisShape.englishHumanities =>
          appTr('هيكل إنجليزي إنساني (فصول موضوعية)', 'English humanities (thematic)'),
      };
}

class ThesisKindDetector {
  ThesisKindDetector._();

  static const literaryFaculties = {
    'Arts',
    'Law',
    'FineArts',
    'MassCommunication',
  };

  static const experimentalFaculties = {
    'Science',
    'Engineering',
    'Medicine',
    'Pharmacy',
    'Agriculture',
    'Veterinary',
    'Dentistry',
    'Nursing',
    'CS',
    'Architecture',
  };

  static const empiricalFaculties = {
    'Education',
    'Business',
    'PhysicalEducation',
    'Tourism',
    'ProfessionalStudies',
  };

  static const _literaryHints = [
    'أدب', 'شعر', 'رواية', 'نقد', 'خطاب', 'لسانيات', 'نحو', 'بلاغة',
    'تاريخ', 'فلسفة', 'فقه', 'قانون', 'مسرح', 'ترجمة أدبية', 'تأويل',
    'literature', 'poetry', 'novel', 'discourse', 'linguistics',
    'historiography', 'philosophy', 'drama', 'hermeneutic', 'close reading',
  ];

  static const _experimentalHints = [
    'تجربة', 'معمل', 'مختبر', 'عملي', 'عيّنة', 'عينة', 'جهاز', 'معايرة',
    'كرومات', 'تحليلية', 'إحصاء', 'hplc', 'gc-ms', 'uv-vis', 'anova',
    'spss', 'analytic', 'chemist', 'experiment', 'laboratory', 'lab ',
    'spectroscop', 'chromatograph', 'assay', 'in vitro', 'in vivo', 'protocol',
  ];

  static const _empiricalHints = [
    'استبيان', 'مقابلة', 'عينة عشوائية', 'تربية', 'إدارة', 'رضا',
    'survey', 'questionnaire', 'interview', 'likert', 'regression',
    'sample size', 'quantitative', 'qualitative',
  ];

  static ThesisKindGuess detect({
    required String raw,
    AcademicProfile? profile,
    ThesisKind? kindOverride,
    ThesisShape? shapeOverride,
    bool? arabicOverride,
  }) {
    final arabic = arabicOverride ?? _preferArabic(raw, profile);
    final kind = kindOverride ??
        _kindFromText(
          '$raw ${profile?.specialization ?? ''} ${profile?.researchInterest ?? ''} ${profile?.facultyCategory ?? ''}',
          profile?.resolvedFacultyCategory,
        );
    final shape = shapeOverride ?? defaultShape(kind: kind, arabic: arabic);
    return ThesisKindGuess(kind: kind, shape: shape, arabic: arabic);
  }

  static ThesisShape defaultShape({
    required ThesisKind kind,
    required bool arabic,
  }) {
    if (kind == ThesisKind.literary) {
      return arabic ? ThesisShape.arabicLiterary : ThesisShape.englishHumanities;
    }
    if (kind == ThesisKind.experimental) {
      return arabic
          ? ThesisShape.arabicEmpirical
          : ThesisShape.englishExperimentalMerged;
    }
    return arabic
        ? ThesisShape.arabicEmpirical
        : ThesisShape.englishExperimentalSplit;
  }

  static List<ThesisShape> shapesFor(ThesisKind kind) {
    return switch (kind) {
      ThesisKind.literary => [
          ThesisShape.arabicLiterary,
          ThesisShape.englishHumanities,
        ],
      ThesisKind.experimental => [
          ThesisShape.arabicEmpirical,
          ThesisShape.englishExperimentalMerged,
          ThesisShape.englishExperimentalSplit,
        ],
      ThesisKind.empirical => [
          ThesisShape.arabicEmpirical,
          ThesisShape.englishExperimentalSplit,
        ],
    };
  }

  static ThesisKind _kindFromText(String haystack, String? facultyId) {
    final lower = haystack.toLowerCase();
    var literaryHits = 0;
    var experimentalHits = 0;
    var empiricalHits = 0;
    for (final h in _literaryHints) {
      if (lower.contains(h.toLowerCase())) literaryHits++;
    }
    for (final h in _experimentalHints) {
      if (lower.contains(h.toLowerCase())) experimentalHits++;
    }
    for (final h in _empiricalHints) {
      if (lower.contains(h.toLowerCase())) empiricalHits++;
    }
    if (experimentalHits >= literaryHits && experimentalHits >= empiricalHits && experimentalHits > 0) {
      return ThesisKind.experimental;
    }
    if (literaryHits > experimentalHits && literaryHits >= empiricalHits) {
      return ThesisKind.literary;
    }
    if (empiricalHits > 0 && empiricalHits >= experimentalHits) {
      return ThesisKind.empirical;
    }
    final faculty = facultyId?.trim() ?? '';
    if (literaryFaculties.contains(faculty)) return ThesisKind.literary;
    if (experimentalFaculties.contains(faculty)) return ThesisKind.experimental;
    if (empiricalFaculties.contains(faculty)) return ThesisKind.empirical;
    return ThesisKind.experimental;
  }

  static bool _preferArabic(String raw, AcademicProfile? profile) {
    final lang = profile?.preferredLanguage.trim() ?? '';
    if (lang.contains('إنجليز') || lang.toLowerCase().contains('english')) {
      return false;
    }
    if (lang.contains('عرب')) return true;
    final arabicChars = RegExp(r'[\u0600-\u06FF]').allMatches(raw).length;
    final latinChars = RegExp(r'[A-Za-z]').allMatches(raw).length;
    if (latinChars >= 12 && latinChars > arabicChars) return false;
    return true;
  }
}
