import 'thesis_studio_kind.dart';
import 'thesis_studio_models.dart';

/// One question's alignment verdict in the thesis consistency matrix.
enum ConsistencyVerdict {
  /// A method pathway and an answering chapter both exist.
  aligned,

  /// A chapter addresses the question but no method pathway was detected.
  noClearMethod,

  /// A method pathway exists but no chapter answers the question yet.
  noAnsweringChapter,

  /// Neither a method pathway nor an answering chapter: a question with no
  /// way to answer it — the case this matrix exists to catch.
  unanswered,
}

class QuestionConsistency {
  final String question;
  final bool hasMethod;

  /// What the method verdict rests on (a goal method keyword or method
  /// chapter prose), '' when no pathway was detected.
  final String methodEvidence;
  final String answeringChapterId;
  final String answeringChapterTitle;
  final ConsistencyVerdict verdict;

  const QuestionConsistency({
    required this.question,
    required this.hasMethod,
    required this.methodEvidence,
    required this.answeringChapterId,
    required this.answeringChapterTitle,
    required this.verdict,
  });
}

class ThesisConsistencyMatrix {
  /// The research problem / aim the questions hang on (from the goal text).
  final String problem;
  final List<QuestionConsistency> rows;

  /// False when every chapter is still empty: the chapter column cannot be
  /// judged yet and the UI should say the matrix fills as chapters are
  /// written, not that every question is unanswerable.
  final bool chaptersHaveProse;

  const ThesisConsistencyMatrix({
    required this.problem,
    required this.rows,
    required this.chaptersHaveProse,
  });

  int get unansweredCount =>
      rows.where((r) => r.verdict == ConsistencyVerdict.unanswered).length;
  int get alignedCount =>
      rows.where((r) => r.verdict == ConsistencyVerdict.aligned).length;
}

/// Deterministic consistency matrix: problem → question → method →
/// answering chapter, by content-word overlap. This is a review guide, not
/// a semantic proof; the UI labels it as such.
class ThesisConsistency {
  ThesisConsistency._();

  static final _token = RegExp('[a-z0-9\u0600-\u06ff]{3,}');
  static const _stop = {
    'the', 'and', 'for', 'with', 'from', 'that', 'this', 'these', 'those',
    'are', 'was', 'were', 'has', 'have', 'had', 'not', 'but', 'its', 'our',
    'their', 'between', 'among', 'into', 'onto', 'than', 'then', 'thus',
    'also', 'such', 'more', 'most', 'less', 'least', 'over', 'under',
    'using', 'used', 'use', 'based', 'via', 'per', 'each', 'all', 'both',
    'can', 'could', 'may', 'might', 'will', 'would', 'should', 'show',
    'what', 'which', 'how', 'does', 'effect', 'effects', 'relationship',
    'impact', 'influence', 'role', 'study', 'studies', 'question',
    'في', 'من', 'على', 'إلى', 'عن', 'أن', 'إن', 'هذا', 'هذه', 'ذلك',
    'التي', 'الذي', 'مع', 'بين', 'قد', 'كما', 'بعد', 'قبل', 'عند', 'خلال',
    'أو', 'ثم', 'لا', 'ما', 'لم', 'لن', 'كل', 'بعض', 'غير', 'أي', 'هل',
    'أثر', 'تأثير', 'علاقة', 'دور', 'فاعلية',
  };

  static String _normalize(String token) {
    var t = token.replaceAll(RegExp('[أإآ]'), 'ا');
    if (t.length > 4 && t.startsWith('ال')) {
      t = t.substring(2);
    }
    return t;
  }

  static Set<String> _tokens(String text) {
    return {
      for (final m in _token.allMatches(text.toLowerCase()))
        if (!_stop.contains(m.group(0)!)) _normalize(m.group(0)!),
    };
  }

  static int _overlap(Set<String> a, Set<String> b) => a.intersection(b).length;

  static bool _isMethodChapter(ThesisChapter chapter) {
    final id = chapter.id.toLowerCase();
    return id.contains('experimental') ||
        id.contains('method') ||
        id.contains('procedur') ||
        chapter.depth == ThesisChapterDepth.protocol;
  }

  static String _chapterProse(ThesisChapter chapter) {
    final buf = StringBuffer()
      ..write(chapter.titleAr)
      ..write(' ')
      ..write(chapter.titleEn)
      ..write(' ')
      ..write(chapter.body);
    for (final p in chapter.paragraphs) {
      buf
        ..write(' ')
        ..write(p.headingAr)
        ..write(' ')
        ..write(p.headingEn)
        ..write(' ')
        ..write(p.body);
    }
    return buf.toString();
  }

  static ThesisConsistencyMatrix analyze(ThesisDraft draft) {
    // Method pathway evidence: the goal's declared method keywords plus the
    // prose of method/protocol chapters.
    final goalMethods = [
      ...draft.goal.methods,
      ...draft.goal.matchKeywords,
      ...draft.goal.searchQueries,
    ].where((m) => m.trim().isNotEmpty).toList();
    final methodChapters = [for (final c in draft.chapters) if (_isMethodChapter(c)) c];
    final methodCorpus = _tokens([
      for (final c in methodChapters) _chapterProse(c),
    ].join(' '));

    final chaptersWithProse = [
      for (final c in draft.chapters)
        if (!_isMethodChapter(c) && _tokens(_chapterProse(c)).length >= 6) c,
    ];

    final rows = <QuestionConsistency>[];
    for (final question in draft.researchQuestions) {
      final qTokens = _tokens(question);

      // Method pathway: a declared goal method sharing a content word, or
      // real overlap with the method chapters' prose.
      String evidence = '';
      for (final m in goalMethods) {
        final shared = _overlap(qTokens, _tokens(m));
        if (shared > 0) {
          evidence = m.trim();
          break;
        }
      }
      if (evidence.isEmpty && _overlap(qTokens, methodCorpus) >= 2) {
        evidence = methodChapters.isEmpty
            ? ''
            : (methodChapters.first.titleEn.trim().isNotEmpty
                ? methodChapters.first.titleEn
                : methodChapters.first.titleAr);
      }
      final hasMethod = evidence.isNotEmpty;

      // Answering chapter: strongest prose overlap, needing at least two
      // shared content words to count.
      var bestId = '';
      var bestTitle = '';
      var bestScore = 1;
      for (final c in chaptersWithProse) {
        final score = _overlap(qTokens, _tokens(_chapterProse(c)));
        if (score > bestScore) {
          bestScore = score;
          bestId = c.id;
          bestTitle = c.titleEn.trim().isNotEmpty ? c.titleEn : c.titleAr;
        }
      }
      final hasChapter = bestId.isNotEmpty;

      final verdict = hasMethod
          ? (hasChapter
              ? ConsistencyVerdict.aligned
              : ConsistencyVerdict.noAnsweringChapter)
          : (hasChapter
              ? ConsistencyVerdict.noClearMethod
              : ConsistencyVerdict.unanswered);

      rows.add(
        QuestionConsistency(
          question: question,
          hasMethod: hasMethod,
          methodEvidence: evidence,
          answeringChapterId: bestId,
          answeringChapterTitle: bestTitle,
          verdict: verdict,
        ),
      );
    }

    return ThesisConsistencyMatrix(
      problem: draft.goal.raw.trim(),
      rows: rows,
      chaptersHaveProse: chaptersWithProse.isNotEmpty,
    );
  }
}
