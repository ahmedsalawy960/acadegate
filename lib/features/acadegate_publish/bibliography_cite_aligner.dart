import 'academic_text.dart';
import 'bibliography_match.dart';
import 'citation_cues.dart';
import 'citation_formatter.dart';
import 'citation_style_shapes.dart';
import 'publish_models.dart';

/// Names and numbers in the paper body are the same works as the end list.
/// Use those keys to split glued rows and recover dropped bibliography lines.
class InTextCiteKeys {
  InTextCiteKeys({
    required this.numbers,
    required this.authorYears,
  });

  final Set<int> numbers;
  final List<AuthorYearCite> authorYears;

  static const _blockedLead = CitationCues.notAuthorSurnames;

  factory InTextCiteKeys.fromBody(String body) {
    final text = AcademicText.westernDigits(body);
    final numbers = <int>{};
    for (final m in _bracket.allMatches(text)) {
      if (_affiliationBefore(text, m.start)) continue;
      numbers.addAll(_parseNumberList(m.group(1)!));
    }

    final years = <AuthorYearCite>[];
    void addParts(String group) {
      for (final raw in group.split(';')) {
        final cite = AuthorYearCite.parse(raw);
        if (cite != null) years.add(cite);
      }
    }

    for (final m in _parenGroup.allMatches(text)) {
      addParts(m.group(1)!);
    }
    for (final m in _narrative.allMatches(text)) {
      final cite = AuthorYearCite.parse('${m.group(1)!}, ${m.group(2)!}');
      if (cite != null) years.add(cite);
    }

    return InTextCiteKeys(numbers: numbers, authorYears: years);
  }

  bool get isEmpty => numbers.isEmpty && authorYears.isEmpty;

  Iterable<AuthorYearCite> matchingLine(String line) =>
      authorYears.where((c) => c.appearsIn(line));

  bool citesThisLine(String line) {
    final n = PublishReference.numberFromImportedLine(line);
    if (n != null && numbers.contains(n)) return true;
    return matchingLine(line).isNotEmpty;
  }

  bool lineStartsNewCitedWork(String previous, String line) {
    final lineHits = matchingLine(line).toList();
    if (lineHits.isEmpty) return false;
    final prevHits = matchingLine(previous).toList();
    return lineHits.any(
      (hit) => !prevHits.any((prev) => prev.sameWork(hit)),
    );
  }

  static bool _affiliationBefore(String text, int start) {
    final from = start > 240 ? start - 240 : 0;
    final tail = text.substring(from, start);
    return CitationCues.affiliationNearby.hasMatch(tail);
  }

  static List<int> _parseNumberList(String raw) {
    final out = <int>[];
    for (final part in raw.split(RegExp(r'\s*[,;]\s*'))) {
      final range = part.split(RegExp(r'\s*[–-]\s*'));
      if (range.length == 2) {
        final a = int.tryParse(range[0].trim());
        final b = int.tryParse(range[1].trim());
        if (a != null && b != null && b >= a && b - a < 40) {
          for (var n = a; n <= b; n++) {
            out.add(n);
          }
          continue;
        }
      }
      final n = int.tryParse(part.trim());
      if (n != null && n >= 1 && n <= 500) out.add(n);
    }
    return out;
  }

  static final _bracket = RegExp(
    r'\[(\d{1,3}(?:\s*[,;–-]\s*\d{1,3})*)\]',
  );
  static final _parenGroup = RegExp(
    r'\(([^()]{3,220}?\b(?:19|20)\d{2}[a-z]?)\)',
  );
  static final _narrative = RegExp(
    r"((?:[\p{Lu}][\p{L}\p{M}'\-]{1,}(?:\s+[\p{L}\p{M}'\-]{2,}){0,2}"
    r"(?:\s+[\p{Lu}][\p{L}\p{M}'\-]{1,}){0,3}"
    r"(?:\s*,\s*[\p{Lu}][\p{L}'\-]{1,}){0,6})"
    r"(?:\s+et\s+al\.?)?"
    r"(?:\s+(?:and|&)\s+[\p{Lu}][\p{L}'\-]{1,})?)"
    r"\s*\(\s*((?:19|20)\d{2})[a-z]?\s*\)",
    unicode: true,
  );
}

class AuthorYearCite {
  AuthorYearCite({
    required this.year,
    required this.lastNames,
    required this.aliases,
  });

  final String year;
  final Set<String> lastNames;
  final Set<String> aliases;

  static AuthorYearCite? parse(String raw) {
    final year = CitationStyleShapes.yearFromCitation(raw);
    if (year == null || year.length < 4) return null;
    var names = CitationStyleShapes.lastNamesFromCitation(raw)
        .map(AcademicText.nameKey)
        .where((n) => n.length >= 2)
        .toSet();
    if (names.isEmpty) {
      final lead = AcademicText.nameKey(
        raw.split(RegExp(r'[,()]')).first,
      );
      if (lead.length >= 2) names = {lead};
    }
    names.removeWhere((n) => InTextCiteKeys._blockedLead.contains(n));
    if (names.isEmpty) return null;
    final aliases = <String>{};
    if (names.contains('official') || names.contains('aoac')) {
      aliases.addAll({'official', 'aoac'});
    }
    if (names.contains('official') || names.contains('aocs')) {
      aliases.addAll({'official', 'aocs'});
    }
    return AuthorYearCite(year: year, lastNames: names, aliases: aliases);
  }

  bool sameWork(AuthorYearCite other) =>
      year == other.year && lastNames.intersection(other.lastNames).isNotEmpty;

  bool appearsIn(String line) {
    final folded = AcademicText.foldLatin(line);
    if (!folded.contains(year)) return false;
    final compact = AcademicText.nameKey(line);
    for (final name in {...lastNames, ...aliases}) {
      if (name.length >= 3 && compact.contains(name)) return true;
    }
    return false;
  }
}

class BibliographyCiteAligner {
  BibliographyCiteAligner._();

  /// Cut a glued bibliography line wherever a *different* in-text work starts.
  static List<String> splitByCitedWorks(String line, InTextCiteKeys? keys) {
    final t = line.trim();
    if (t.isEmpty) return const [];
    if (keys == null || keys.authorYears.isEmpty) return [t];

    final cuts = <int>{0};
    for (final cite in keys.authorYears) {
      final at = _authorStart(t, cite);
      if (at != null && at > 16) cuts.add(at);
    }
    if (cuts.length < 2) return [t];
    final starts = cuts.toList()..sort();
    final out = <String>[];
    for (var i = 0; i < starts.length; i++) {
      final end = i + 1 < starts.length ? starts[i + 1] : t.length;
      final piece = t.substring(starts[i], end).trim();
      if (piece.length >= 20) out.add(piece);
    }
    return out.isEmpty ? [t] : out;
  }

  /// Keep every imported row, and bring back any cited work the parser dropped.
  static List<PublishReference> complete({
    required String bodyText,
    required String bibliographyText,
    required List<PublishReference> parsed,
    InTextCiteKeys? keys,
  }) {
    final citeKeys = keys ?? InTextCiteKeys.fromBody(bodyText);
    var refs = <PublishReference>[];
    for (final ref in parsed) {
      final raw = ref.rawText.trim().isNotEmpty ? ref.rawText : ref.title;
      final parts = splitByCitedWorks(raw, citeKeys);
      if (parts.length <= 1) {
        refs.add(ref);
        continue;
      }
      for (var i = 0; i < parts.length; i++) {
        refs.add(
          _fromLine(
            parts[i],
            importedNumber: i == 0 ? ref.importedNumber : null,
          ),
        );
      }
    }

    if (bibliographyText.trim().length >= 40) {
      for (final piece in _bibliographyPieces(bibliographyText, citeKeys)) {
        if (!_looksBibliographic(piece)) continue;
        if (_haveWork(refs, piece)) continue;
        if (!citeKeys.citesThisLine(piece) &&
            !_startsLikeBibliographyEntry(piece)) {
          continue;
        }
        refs.add(_fromLine(piece));
      }
    }

    for (final cite in citeKeys.authorYears) {
      if (_haveCite(refs, cite)) continue;
      final recovered = _findInBibliography(bibliographyText, cite, citeKeys);
      if (recovered != null) refs.add(_fromLine(recovered));
    }
    for (final n in citeKeys.numbers) {
      if (BibliographyMatch(refs).byNumber(n) != null) continue;
      final recovered = _findNumberedLine(bibliographyText, n);
      if (recovered != null) refs.add(_fromLine(recovered, importedNumber: n));
    }

    return _uniqueKeepingOrder(refs);
  }

  static int coverage(List<PublishReference> refs, InTextCiteKeys keys) {
    if (refs.isEmpty || keys.isEmpty) return 0;
    final match = BibliographyMatch(refs);
    var hits = 0;
    for (final n in keys.numbers) {
      if (match.byNumber(n) != null) hits++;
    }
    for (final cite in keys.authorYears) {
      if (match.byLastNames(cite.lastNames.toList(), year: cite.year) != null) {
        hits++;
      }
    }
    return hits;
  }

  static int? _authorStart(String blob, AuthorYearCite cite) {
    if (!AcademicText.foldLatin(blob).contains(cite.year)) return null;
    final needles = {
      ...cite.lastNames.where((n) => n.length >= 3),
      ...cite.aliases,
    };
    if (needles.isEmpty) return null;
    final words = RegExp(r"[\p{L}][\p{L}'\-]{1,}", unicode: true);
    for (final m in words.allMatches(blob)) {
      final folded = AcademicText.nameKey(m.group(0)!);
      final hit = needles.any(
        (n) =>
            folded == n ||
            (n.length >= 4 && folded.startsWith(n)) ||
            (folded.length >= 4 && n.startsWith(folded)),
      );
      if (!hit) continue;
      if (m.start == 0) return 0;
      final before = blob.substring(0, m.start);
      final ended = RegExp(r'\b(?:19|20)\d{2}[a-z]?\s*[.;]?\s*$').hasMatch(before) ||
          RegExp(
            r'(?:doi\.org/\S+|https?://\S+)\s*$',
            caseSensitive: false,
          ).hasMatch(before) ||
          RegExp(r'\.\s+$').hasMatch(before);
      if (ended) return m.start;
    }
    return null;
  }

  static List<String> _bibliographyPieces(String text, InTextCiteKeys keys) {
    final out = <String>[];
    for (final raw in text.replaceAll('\r\n', '\n').split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      out.addAll(splitByCitedWorks(line, keys));
    }
    return out;
  }

  static String? _findInBibliography(
    String bibliography,
    AuthorYearCite cite,
    InTextCiteKeys keys,
  ) {
    String? best;
    for (final piece in _bibliographyPieces(bibliography, keys)) {
      if (!cite.appearsIn(piece) || !_looksBibliographic(piece)) continue;
      if (best == null || piece.length > best.length) best = piece;
    }
    return best;
  }

  static String? _findNumberedLine(String bibliography, int n) {
    final re = RegExp(
      '(?:^|\\n)\\s*(?:\\[$n\\]|$n[.)])\\s+(\\S[^\\n]{20,})',
      multiLine: true,
    );
    final m = re.firstMatch(bibliography);
    if (m == null) return null;
    final line = '${m.group(0)!.trim()}';
    return _looksBibliographic(line) ? line.trim() : null;
  }

  static bool _looksBibliographic(String line) {
    final t = line.trim();
    if (t.length < 28 || t.length > 2500) return false;
    if (CitationCues.isRunningMatterLine(t)) return false;
    if (RegExp(r'^\((?:19|20)\d{2}[a-z]?\)').hasMatch(t)) return false;
    if (RegExp(r'^[&,]').hasMatch(t)) return false;
    if (!RegExp(r'\b(?:19|20)\d{2}\b').hasMatch(t)) return false;
    if (CitationCues.sentenceLeadLine.hasMatch(t)) {
      return false;
    }
    if (RegExp(
      r'\b(was|were|using the|measured|according to)\b',
      caseSensitive: false,
    ).hasMatch(t) &&
        !RegExp(r';\s*[\p{Lu}]', unicode: true).hasMatch(t)) {
      return false;
    }
    return true;
  }

  static bool _startsLikeBibliographyEntry(String line) {
    final t = line.trim();
    if (CitationCues.standardsOrgLead.hasMatch(t)) {
      return true;
    }
    return RegExp(
      r"^(?:\[\d{1,3}\]\s+|\d{1,3}[.)]\s+)?"
      r"[\p{Lu}][\p{L}'\-]{1,}(?:\s+[\p{Lu}][\p{L}'\-]{1,}){0,3},\s*[\p{Lu}]",
      unicode: true,
    ).hasMatch(t);
  }

  static bool _haveWork(List<PublishReference> refs, String piece) {
    final n = PublishReference.numberFromImportedLine(piece);
    if (n != null) {
      final existing = BibliographyMatch(refs).byNumber(n);
      if (existing != null && _rawOverlap(existing.rawText, piece)) {
        return true;
      }
    }
    final year = BibliographyMatch.yearOf(
      PublishReference(
        id: 'probe',
        type: ReferenceType.journal,
        title: piece,
        rawText: piece,
      ),
    );
    final names = BibliographyMatch.lastNamesFromRaw(piece);
    if (year.length == 4 && names.isNotEmpty) {
      final hit = BibliographyMatch(refs).byLastNames(names, year: year);
      if (hit != null) return true;
    }
    return refs.any((r) => _rawOverlap(r.rawText, piece));
  }

  static bool _haveCite(List<PublishReference> refs, AuthorYearCite cite) {
    return BibliographyMatch(refs).byLastNames(
          cite.lastNames.toList(),
          year: cite.year,
        ) !=
        null;
  }

  static bool _rawOverlap(String a, String b) {
    String compact(String s) =>
        AcademicText.foldLatin(s).replaceAll(RegExp(r'[^a-z0-9]+'), '');
    final ka = compact(a);
    final kb = compact(b);
    if (ka.length < 24 || kb.length < 24) return ka == kb && ka.isNotEmpty;
    final n = ka.length < kb.length ? ka.length : kb.length;
    final take = n > 64 ? 64 : n;
    return ka.substring(0, take) == kb.substring(0, take);
  }

  static PublishReference _fromLine(String line, {int? importedNumber}) {
    final t = line.trim();
    final n = importedNumber ?? PublishReference.numberFromImportedLine(t);
    final parsed = CitationFormatter.parseBibliographicLine(t);
    if (parsed != null) {
      return parsed.copyWith(
        id: 'ref_${n ?? parsed.id}',
        rawText: t,
        importedNumber: n,
      );
    }
    return PublishReference(
      id: 'ref_${n ?? t.hashCode}',
      type: ReferenceType.journal,
      title: t,
      rawText: t,
      importedNumber: n,
    );
  }

  static List<PublishReference> _uniqueKeepingOrder(
    List<PublishReference> refs,
  ) {
    final out = <PublishReference>[];
    for (final ref in refs) {
      final raw = ref.rawText.trim().isNotEmpty ? ref.rawText : ref.title;
      if (out.any((r) => _rawOverlap(
            r.rawText.trim().isNotEmpty ? r.rawText : r.title,
            raw,
          ))) {
        continue;
      }
      out.add(ref);
    }
    return out;
  }
}
