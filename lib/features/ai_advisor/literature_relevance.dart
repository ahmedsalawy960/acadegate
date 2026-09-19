import 'grounded_work.dart';

/// Rank index hits by the user's own topic tokens — any discipline.
/// Generic words (study, products, development, context, text) do not prove relevance.
class LiteratureRelevance {
  LiteratureRelevance._();

  static final _arabic = RegExp(r'[\u0600-\u06FF]');

  /// Phrases that steal hits unless the user explicitly asked for them.
  static const opportunisticJunk = <String>[
    'covid-19',
    'covid19',
    'coronavirus',
    'sars-cov',
    'pandemic',
    'oxford covid',
    'government response tracker',
    'clinical text data',
    'detecting covid',
    'text data augmentation',
    'blockchain technology in agriculture',
    'literature review as a research methodology',
    'tesol quarterly',
    'social-semiotic',
    'social semiotic',
    'critique of imperialism',
    'postcolonial',
    'post-colonial',
    'powder diffraction',
    'molecular allergology',
    'chronic obstructive pulmonary',
    'copd',
    'political texts',
    'automatic content analysis',
    'correcting words in text',
    'acm computing surveys',
    'weight of evidence approach in scientific assessments',
    'cognition and instruction',
    'critical inquiry',
  ];

  /// Tokens too weak to justify keeping a paper by themselves.
  static const weakAlone = <String>{
    'text',
    'texts',
    'language',
    'context',
    'writing',
    'study',
    'studies',
    'review',
    'analysis',
    'data',
    'method',
    'methods',
    'approach',
    'quality',
    'global',
    'guidance',
    'user',
    'guide',
    'aspects',
    'introduction',
    'نص',
    'نصوص',
    'لغة',
    'سياق',
    'دراسة',
    'تحليل',
    'منهج',
  };

  static List<GroundedWork> rank({
    required List<GroundedWork> works,
    required Iterable<String> corePhrases,
    required Iterable<String> strongTokens,
    bool preferEnglish = false,
    int minYear = 0,
    int limit = 20,
    int minScore = 4,
    bool requireCoreHit = false,
    bool requireTitleCoreHit = false,
    String commandText = '',
    Iterable<String> disciplineTokens = const [],
    Iterable<String> alienTokens = const [],
  }) {
    final cores = corePhrases
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.length >= 4)
        .where((t) => !weakAlone.contains(t))
        .toSet();
    final strong = strongTokens
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.length >= 4)
        .where((t) => !weakAlone.contains(t))
        .toSet();
    final commandHay = commandText.trim().toLowerCase();

    final scored = <({GroundedWork work, int score})>[];
    for (final work in works) {
      final score = _score(
        work,
        cores: cores,
        strong: strong,
        preferEnglish: preferEnglish,
        minYear: minYear,
        requireCoreHit: requireCoreHit,
        requireTitleCoreHit: requireTitleCoreHit,
        commandHay: commandHay,
        discipline: disciplineTokens
            .map((t) => t.trim().toLowerCase())
            .where((t) => t.length >= 4)
            .toSet(),
        aliens: alienTokens
            .map((t) => t.trim().toLowerCase())
            .where((t) => t.length >= 4)
            .toSet(),
      );
      if (score < minScore) continue;
      scored.add((work: work, score: score));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return (b.work.year ?? 0).compareTo(a.work.year ?? 0);
    });
    return scored.map((e) => e.work).take(limit).toList();
  }

  static int _score(
    GroundedWork work, {
    required Set<String> cores,
    required Set<String> strong,
    required bool preferEnglish,
    required int minYear,
    required bool requireCoreHit,
    required bool requireTitleCoreHit,
    required String commandHay,
    Set<String> discipline = const {},
    Set<String> aliens = const {},
  }) {
    final title = work.title.toLowerCase();
    final hay =
        '$title ${work.abstractText.toLowerCase()} ${(work.journal ?? '').toLowerCase()}';

    if (_isOpportunisticJunk(hay, commandHay)) return 0;

    var score = 0;
    var coreHits = 0;
    var titleCoreHits = 0;
    for (final p in cores) {
      if (title.contains(p)) {
        score += 6;
        coreHits++;
        titleCoreHits++;
      } else if (hay.contains(p)) {
        score += 2;
        coreHits++;
      }
    }
    var strongHits = 0;
    for (final t in strong) {
      if (title.contains(t)) {
        score += 2;
        strongHits++;
      } else if (hay.contains(t)) {
        score += 1;
        strongHits++;
      }
    }
    if (cores.isNotEmpty && coreHits == 0) {
      if (requireCoreHit || strongHits == 0) return 0;
      score -= 4;
    }
    if (requireTitleCoreHit && cores.isNotEmpty && titleCoreHits == 0) {
      return 0;
    }
    if (coreHits == 0 && strongHits == 0) return 0;

    var disciplineHits = 0;
    for (final t in discipline) {
      if (title.contains(t) || (work.journal ?? '').toLowerCase().contains(t)) {
        score += 3;
        disciplineHits++;
      } else if (hay.contains(t)) {
        score += 1;
        disciplineHits++;
      }
    }
    var alienHits = 0;
    for (final t in aliens) {
      if (hay.contains(t)) alienHits++;
    }
    if (alienHits > 0 && disciplineHits == 0 && titleCoreHits == 0) {
      return 0;
    }
    if (alienHits > 0) score -= 12;
    if (alienHits > disciplineHits + coreHits) return 0;
    // Soft discipline nudge only — do not zero out on missing faculty jargon
    // when the paper already hit the user's core topic.
    if (discipline.isNotEmpty &&
        disciplineHits == 0 &&
        titleCoreHits == 0 &&
        coreHits == 0) {
      return 0;
    }
    if (discipline.isNotEmpty && disciplineHits == 0) score -= 2;
    if (preferEnglish &&
        _arabic.hasMatch(work.title) &&
        !_mostlyLatin(work.title)) {
      score -= 6;
    }
    final year = work.year ?? 0;
    if (minYear > 0 && year > 0 && year < minYear) score -= 4;
    if (year >= 2010) score += 1;
    if (work.abstractText.trim().length > 80) score += 1;
    return score;
  }

  static bool isOpportunisticJunkWork(GroundedWork work, String commandText) {
    final hay =
        '${work.title} ${work.abstractText} ${work.journal ?? ''}'.toLowerCase();
    return _isOpportunisticJunk(hay, commandText.trim().toLowerCase());
  }

  static bool _isOpportunisticJunk(String hay, String commandHay) {
    for (final junk in opportunisticJunk) {
      if (!hay.contains(junk)) continue;
      if (commandHay.isNotEmpty && commandHay.contains(junk)) continue;
      if (_commandAllowsJunk(junk, commandHay)) continue;
      return true;
    }
    if ((hay.contains('machine learning in agriculture') ||
            hay.contains('deep learning in agriculture')) &&
        !commandHay.contains('machine learning') &&
        !commandHay.contains('deep learning') &&
        !commandHay.contains('تعلم آلي') &&
        !commandHay.contains('تعلم الآلة')) {
      return true;
    }
    return false;
  }

  static bool _commandAllowsJunk(String junk, String commandHay) {
    if (commandHay.isEmpty) return false;
    if (junk.contains('covid') ||
        junk.contains('corona') ||
        junk.contains('pandemic') ||
        junk.contains('sars')) {
      return commandHay.contains('covid') ||
          commandHay.contains('corona') ||
          commandHay.contains('pandemic');
    }
    if (junk.contains('blockchain')) return commandHay.contains('blockchain');
    if (junk.contains('augmentation')) {
      return commandHay.contains('augmentation') ||
          commandHay.contains('deep learning');
    }
    if (junk.contains('tesol') || junk.contains('semiotic')) {
      return commandHay.contains('tesol') ||
          commandHay.contains('semiotic') ||
          commandHay.contains('linguistics');
    }
    if (junk.contains('imperialism') || junk.contains('postcolonial')) {
      return commandHay.contains('postcolonial') ||
          commandHay.contains('imperialism') ||
          commandHay.contains('literary');
    }
    if (junk.contains('copd') || junk.contains('pulmonary')) {
      return commandHay.contains('copd') ||
          commandHay.contains('pulmonary') ||
          commandHay.contains('lung');
    }
    if (junk.contains('allerg')) {
      return commandHay.contains('allerg');
    }
    if (junk.contains('powder diffraction')) {
      return commandHay.contains('diffraction') ||
          commandHay.contains('crystall');
    }
    if (junk.contains('political')) {
      return commandHay.contains('political') ||
          commandHay.contains('content analysis');
    }
    return false;
  }

  static bool _mostlyLatin(String text) {
    final letters = text.replaceAll(RegExp(r'[^A-Za-z\u0600-\u06FF]'), '');
    if (letters.isEmpty) return true;
    final latin = letters.replaceAll(_arabic, '');
    return latin.length >= letters.length * 0.6;
  }
}
