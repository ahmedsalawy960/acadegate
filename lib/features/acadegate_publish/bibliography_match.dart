import 'academic_text.dart';
import 'citation_style_shapes.dart';
import 'publish_models.dart';

/// One job: an in-text cite is the same work as a bibliography row.
///
/// * `[n]` → the imported list item whose printed/imported number is n
/// * `(Author, Year)` / `Author (Year)` → the row with those surnames + year
///
/// Name order does not matter. Journal abbreviations are not authors.
class BibliographyMatch {
  BibliographyMatch(List<PublishReference> refs)
      : _refs = refs,
        _byNumber = _indexByNumber(refs),
        _rows = [
          for (final ref in refs) _Row.from(ref),
        ].whereType<_Row>().toList();

  final List<PublishReference> _refs;
  final Map<int, PublishReference> _byNumber;
  final List<_Row> _rows;

  PublishReference? byId(String id) {
    for (final ref in _refs) {
      if (ref.id == id) return ref;
    }
    return null;
  }

  static Map<int, PublishReference> _indexByNumber(List<PublishReference> refs) {
    final map = <int, PublishReference>{};
    for (var i = 0; i < refs.length; i++) {
      final n = importedNumberOf(refs[i]) ?? (i + 1);
      map.putIfAbsent(n, () => refs[i]);
    }
    return map;
  }

  /// Bibliography item n from the imported file — never “nth after A–Z”.
  PublishReference? byNumber(int n) => _byNumber[n];

  /// Printed/imported number of this row, or 1-based file order when unnumbered.
  int? numberOf(PublishReference ref) {
    final imported = importedNumberOf(ref);
    if (imported != null) return imported;
    for (final e in _byNumber.entries) {
      if (e.value.id == ref.id) return e.key;
    }
    return null;
  }

  /// Same work as `(Author, Year)` / `Author et al. (Year)`.
  PublishReference? byAuthorYear(String authorPart, String year) {
    final last = leadLastName(authorPart);
    if (last.length < 2) return null;
    final y = _digitsYear(year);
    if (y.length < 4) return null;
    final extras = CitationStyleShapes.lastNamesFromCitation(authorPart)
        .where((n) => n != last)
        .toList();
    final wanted = {last, ...extras};
    return _bestYearHit(y, wanted);
  }

  PublishReference? byLastNames(List<String> names, {String? year}) {
    if (names.isEmpty) return null;
    final wanted = names.map(_normName).where((n) => n.length >= 2).toSet();
    if (wanted.isEmpty) return null;
    final y = year == null || year.isEmpty ? '' : _digitsYear(year);
    return _bestYearHit(y, wanted, yearRequired: y.length == 4);
  }

  PublishReference? _bestYearHit(
    String year,
    Set<String> wanted, {
    bool yearRequired = true,
  }) {
    final hits = <({PublishReference ref, int score})>[];
    for (final row in _rows) {
      if (yearRequired && row.year != year) continue;
      if (!yearRequired && year.length == 4 && row.year != year) continue;
      var score = 0;
      for (final name in wanted) {
        if (row.names.contains(name)) score += 3;
      }
      if (score == 0) continue;
      hits.add((ref: row.ref, score: score));
    }
    if (hits.isEmpty) return null;
    var best = hits.first;
    for (final hit in hits.skip(1)) {
      if (hit.score > best.score) best = hit;
    }
    final tied = hits.where((h) => h.score == best.score).toList();
    if (tied.length == 1) return best.ref;
    // Same surnames+year: keep the imported number if the cite was numbered;
    // otherwise the first file-order row with that score.
    return best.ref;
  }

  static int? importedNumberOf(PublishReference ref) {
    if (ref.importedNumber != null) return ref.importedNumber;
    return PublishReference.numberFromImportedLine(ref.rawText);
  }

  static String yearOf(PublishReference ref) {
    if (ref.year.trim().isNotEmpty) {
      return _digitsYear(ref.year);
    }
    return RegExp(r'\b((?:19|20)\d{2})\b')
            .firstMatch(AcademicText.westernDigits(ref.rawText))
            ?.group(1) ??
        '';
  }

  static List<String> lastNamesOf(PublishReference ref) {
    final names = <String>[];
    void add(String raw) {
      final n = _normName(raw);
      if (n.length >= 2 && !names.contains(n)) names.add(n);
    }

    for (final author in ref.authors) {
      final n = lastNameFromAuthor(author);
      if (n.length >= 2) add(n);
      if (author.contains(',')) {
        final head = author.split(',').first.trim();
        final words = head.split(RegExp(r'\s+'));
        if (words.length >= 2) {
          add(words.last);
          add(words.join());
        }
      }
    }
    if (ref.rawText.isNotEmpty) {
      for (final n in lastNamesFromRaw(ref.rawText)) {
        add(n);
      }
    }

    final authorHead = _authorHead(ref);
    if (RegExp(r'\b(official|aoac)\b').hasMatch(authorHead)) {
      add('official');
      add('aoac');
    }
    return names;
  }

  /// Author segment only — never journal abbreviations from the title.
  static String _authorHead(PublishReference ref) {
    final authors = ref.authors.join(' ').toLowerCase();
    var raw = AcademicText.westernDigits(ref.rawText).toLowerCase();
    raw = raw.replaceFirst(RegExp(r'^\[\d+\]\s*'), '');
    raw = raw.replaceFirst(RegExp(r'^\d+[.)]\s+'), '');
    final year = RegExp(r',?\s*\(?((?:19|20)\d{2})').firstMatch(raw);
    if (year != null) raw = raw.substring(0, year.start);
    return '$authors $raw';
  }

  static List<String> lastNamesFromRaw(String raw) {
    var s = AcademicText.westernDigits(raw.trim());
    s = s.replaceFirst(RegExp(r'^\[\d+\]\s*'), '');
    s = s.replaceFirst(RegExp(r'^\d+[.)]\s+'), '');
    final year = RegExp(r',?\s*\(?((?:19|20)\d{2})').firstMatch(s);
    if (year != null) s = s.substring(0, year.start);
    final quote = RegExp(r'["“]').firstMatch(s);
    if (quote != null) s = s.substring(0, quote.start);
    s = s.replaceAll(RegExp(r'\bet\s+al\.?', caseSensitive: false), ' ');

    final apa = s.split(RegExp(r'\s*;\s*|\s*&\s*|\band\b', caseSensitive: false));
    final out = <String>[];
    for (final part in apa) {
      final n = lastNameFromAuthor(part);
      if (n.length >= 2) out.add(n);
    }
    if (out.isNotEmpty) return out.take(8).toList();

    return RegExp(r"(?:[A-Z]\.\s*)+([A-Z][A-Za-z'\-]{2,})")
        .allMatches(s)
        .map((m) => _normName(m.group(1)!))
        .where((n) => n.length >= 2)
        .take(8)
        .toList();
  }

  static String lastNameFromAuthor(String author) {
    final trimmed = author.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.contains(',')) {
      final head = trimmed.split(',').first.trim();
      if (_isAllCapsInitials(head)) return '';
      return leadLastName(head);
    }
    final ieee = RegExp(r"(?:[A-Z]\.\s*)+([A-Z][A-Za-z'\-]{2,})")
        .firstMatch(trimmed);
    if (ieee != null) return leadLastName(ieee.group(1)!);
    final words = trimmed.split(RegExp(r'\s+'));
    return words.isNotEmpty ? leadLastName(words.join(' ')) : leadLastName(trimmed);
  }

  static bool _isAllCapsInitials(String value) {
    final t = value.replaceAll(RegExp(r'[.\s]'), '');
    return t.length >= 2 &&
        t.length <= 3 &&
        t == t.toUpperCase() &&
        RegExp(r'^[A-Za-z]+$').hasMatch(t);
  }

  static String leadLastName(String authorPart) {
    var s = authorPart
        .replaceAll(RegExp(r'\s+et\s+al\.?', caseSensitive: false), '')
        .trim();
    s = s.split(RegExp(r'\s+(?:&|and)\s+', caseSensitive: false)).first.trim();
    s = s.replaceAll(RegExp(r"['\-]"), '');
    if (s.contains(',')) s = s.split(',').first.trim();
    final words = s.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      final last = words.last.replaceAll('.', '');
      final first = words.first;
      if (_isAllCapsInitials(last) &&
          first.length >= 2 &&
          !_isAllCapsInitials(first)) {
        return _normName(first);
      }
    }
    final word = words.isNotEmpty ? words.last : s;
    return _normName(word);
  }

  static String _normName(String value) {
    final key = AcademicText.nameKey(value);
    return key.isNotEmpty ? key : value.toLowerCase().trim();
  }

  static String _digitsYear(String year) =>
      AcademicText.westernDigits(year).replaceAll(RegExp(r'[a-z]$'), '');
}

class _Row {
  final PublishReference ref;
  final String year;
  final Set<String> names;

  const _Row({required this.ref, required this.year, required this.names});

  static _Row? from(PublishReference ref) {
    final year = BibliographyMatch.yearOf(ref);
    if (year.isEmpty) return null;
    final names = BibliographyMatch.lastNamesOf(ref).toSet();
    if (names.isEmpty) return null;
    return _Row(ref: ref, year: year, names: names);
  }
}
