import '../acadegate_publish/in_text_citation_converter.dart';
import '../ai_advisor/grounded_work.dart';
import 'thesis_studio_citations.dart';
import 'thesis_studio_models.dart';
import 'thesis_studio_prose.dart';

/// How much of a cited work AcadeGate actually read for this claim.
/// The app harvests metadata and abstracts from scholarly indexes; it never
/// claims to have read the full paper.
enum ClaimEvidenceLevel {
  /// An abstract exists, so a supporting excerpt can be shown — but the
  /// excerpt comes from the abstract only, not the full text.
  abstractOnly,

  /// Title/venue/year only; nothing to quote. Verify via the source link.
  metadataOnly,

  /// The marker does not resolve to any harvested reference.
  unknownMarker,
}

/// One [n] marker in a sentence, resolved against the reference list the
/// sentence's text was written against.
class ClaimSource {
  final int marker;
  final GroundedWork? work;
  final ClaimEvidenceLevel level;

  /// The abstract sentence that best matches the claim ('' when none).
  final String quote;

  const ClaimSource({
    required this.marker,
    required this.work,
    required this.level,
    this.quote = '',
  });
}

/// One draft sentence with its resolved citations, ready to display and tap.
class ClaimSentence {
  /// Sentence text as stored (markers as written by the model).
  final String raw;

  /// Sentence text styled for reading: for author–date styles the [n]
  /// markers render as (Author, Year); numbered styles keep [n].
  final String display;

  final List<ClaimSource> sources;

  const ClaimSentence({
    required this.raw,
    required this.display,
    required this.sources,
  });

  bool get hasMarkers => sources.isNotEmpty;
  bool get cited => sources.any((s) => s.work != null);
  bool get hasUnknown => sources.any((s) => s.work == null);
}

/// Maps draft sentences to their cited sources with an honest evidence
/// level. A `[n]` marker only says the model placed a number there — this
/// mapper resolves the number to a real harvested work and shows what the
/// abstract supports, without claiming the reference proves the sentence.
class ThesisClaimMapper {
  ThesisClaimMapper._();

  static final _markerGroup =
      RegExp(r'\[(\d{1,3}(?:\s*[,;]\s*\d{1,3})*)\]');
  static final _range = RegExp(r'\[(\d{1,3})\s*[–-]\s*(\d{1,3})\]');
  static final _sentenceSplit = RegExp(r'(?<=[.!?؟。])\s+');

  /// Splits a draft body into sentences and resolves each sentence's
  /// markers against the same list the citation report uses
  /// (paragraph-local harvest first, then the global list).
  static List<ClaimSentence> mapBody({
    required String body,
    required ThesisDraft draft,
    ThesisParagraph? paragraph,
    bool isAbstract = false,
  }) {
    final list = ThesisStudioCitations.citationListFor(
      draft,
      paragraph: paragraph,
      isAbstract: isAbstract,
    );
    final sentences = splitSentences(body);
    return [
      for (final raw in sentences)
        ClaimSentence(
          raw: raw,
          display: styleSentence(raw, draft: draft, list: list),
          sources: resolveMarkers(raw, list),
        ),
    ];
  }

  static List<String> splitSentences(String body) {
    final out = <String>[];
    for (final line in body.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      for (final part in trimmed.split(_sentenceSplit)) {
        final s = part.trim();
        if (s.isNotEmpty) out.add(s);
      }
    }
    return out;
  }

  /// Marker numbers in one sentence, ranges expanded, order kept, deduped.
  static List<int> markersIn(String sentence) {
    final expanded = sentence.replaceAllMapped(_range, (m) {
      final a = int.tryParse(m.group(1) ?? '');
      final b = int.tryParse(m.group(2) ?? '');
      if (a == null || b == null || b < a || b - a > 30) return m.group(0)!;
      return '[${[for (var i = a; i <= b; i++) i].join(', ')}]';
    });
    final seen = <int>{};
    final out = <int>[];
    for (final m in _markerGroup.allMatches(expanded)) {
      for (final part in m.group(1)!.split(RegExp(r'\s*[,;]\s*'))) {
        final n = int.tryParse(part.trim());
        if (n != null && n > 0 && seen.add(n)) out.add(n);
      }
    }
    return out;
  }

  static List<ClaimSource> resolveMarkers(
    String sentence,
    List<GroundedWork> list,
  ) {
    return [
      for (final n in markersIn(sentence))
        _resolve(n, n >= 1 && n <= list.length ? list[n - 1] : null, sentence),
    ];
  }

  static ClaimSource _resolve(int marker, GroundedWork? work, String sentence) {
    if (work == null) {
      return ClaimSource(
        marker: marker,
        work: null,
        level: ClaimEvidenceLevel.unknownMarker,
      );
    }
    if (work.abstractText.trim().isEmpty) {
      return ClaimSource(
        marker: marker,
        work: work,
        level: ClaimEvidenceLevel.metadataOnly,
      );
    }
    return ClaimSource(
      marker: marker,
      work: work,
      level: ClaimEvidenceLevel.abstractOnly,
      quote: bestQuote(sentence: sentence, abstractText: work.abstractText),
    );
  }

  /// Renders one sentence for reading, mirroring
  /// [ThesisStudioCitations.styledProse]: sanitize, expand ranges, then
  /// convert [n] to (Author, Year) for author–date styles. Applying the
  /// converter per sentence is equivalent to whole-text conversion because
  /// the conversion is marker-local.
  static String styleSentence(
    String sentence, {
    required ThesisDraft draft,
    required List<GroundedWork> list,
  }) {
    var text = ThesisStudioProse.sanitize(sentence);
    text = text.replaceAllMapped(_range, (m) {
      final a = int.tryParse(m.group(1) ?? '');
      final b = int.tryParse(m.group(2) ?? '');
      if (a == null || b == null || b < a || b - a > 30) return m.group(0)!;
      return '[${[for (var i = a; i <= b; i++) i].join(', ')}]';
    });
    if (list.isEmpty) return text;
    final refs = [
      for (var i = 0; i < list.length; i++)
        ThesisStudioCitations.toReference(list[i], i + 1),
    ];
    return InTextCitationConverter.applyAuthorDateCitations(
      text: text,
      references: refs,
      targetStyle: draft.plan.citationStyle,
    );
  }

  static final _token = RegExp('[a-z0-9\u0600-\u06ff]{3,}');
  static const _stop = {
    'the', 'and', 'for', 'with', 'from', 'that', 'this', 'these', 'those',
    'are', 'was', 'were', 'has', 'have', 'had', 'not', 'but', 'its', 'our',
    'their', 'between', 'among', 'into', 'onto', 'than', 'then', 'thus',
    'also', 'such', 'more', 'most', 'less', 'least', 'over', 'under',
    'using', 'used', 'use', 'based', 'via', 'per', 'each', 'all', 'both',
    'can', 'could', 'may', 'might', 'will', 'would', 'should', 'show',
    'shows', 'shown', 'study', 'studies', 'results', 'result', 'paper',
    'في', 'من', 'على', 'إلى', 'عن', 'أن', 'إن', 'هذا', 'هذه', 'ذلك',
    'التي', 'الذي', 'مع', 'بين', 'قد', 'كما', 'بعد', 'قبل', 'عند', 'خلال',
    'أو', 'ثم', 'لا', 'ما', 'لم', 'لن', 'كل', 'بعض', 'غير', 'أي',
  };

  /// The abstract sentence that shares the most content tokens with the
  /// claim sentence. Returns '' when nothing overlaps enough to quote
  /// honestly (the UI then says so instead of inventing support).
  static String bestQuote({
    required String sentence,
    required String abstractText,
  }) {
    Set<String> tokens(String text) {
      final lowered = text.toLowerCase().replaceAll(_markerGroup, ' ');
      return {
        for (final m in _token.allMatches(lowered))
          if (!_stop.contains(m.group(0)!)) m.group(0)!,
      };
    }

    final claimTokens = tokens(sentence);
    if (claimTokens.isEmpty) return '';
    var best = '';
    var bestScore = 0;
    for (final part in splitSentences(abstractText.replaceAll('\n', ' '))) {
      final score = tokens(part).intersection(claimTokens).length;
      if (score > bestScore) {
        bestScore = score;
        best = part;
      }
    }
    // One shared token is too weak to present as support.
    return bestScore >= 2 ? best.trim() : '';
  }
}
