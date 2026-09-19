import '../acadegate_publish/citation_cues.dart';
import 'citation_models.dart';

class CitationParser {
  CitationParser._();

  static final CitationParser instance = CitationParser._();

  static final doiPattern = RegExp(
    r'10\.\d{4,9}/[-._;()/:A-Za-z0-9]+',
    caseSensitive: false,
  );

  static final _doiPattern = doiPattern;

  static final _referenceHeader = RegExp(
    r'^(references|bibliography|works cited|المراجع|قائمة المراجع|المصادر)\s*$',
    caseSensitive: false,
  );

  static final _numberedOrBullet = RegExp(
    r'^(\[\d{1,3}\]|\d{1,3}[.)]|[•●▪\-–—])\s+',
  );

  /// APA / Harvard: `Surname, I.` optionally after `[12]` or a dash.
  static final _authorLead = RegExp(
    r"^(?:\[\d{1,3}\]\s+|\d{1,3}[.)]\s+|[•●▪\-–—]\s+)?"
    r"[\p{Lu}][\p{L}\p{M}'’.\-]{1,40}"
    r"(?:\s+[\p{Lu}][\p{L}\p{M}'’.\-]{1,40}){0,3}"
    r",\s*[\p{Lu}]",
    unicode: true,
  );

  static final _arabicAuthorYear = RegExp(
    r'^[أ-ي]{2,}.{2,60}\(\s*(?:19|20)\d{2}',
  );

  /// Next APA work glued after the previous one ended with `.`
  static final _gluedApa = RegExp(
    r'(?<=[.\u2026\]])\s+(?='
    r"[\p{Lu}][\p{L}\p{M}'’.\-]{1,40},\s*[\p{Lu}]\."
    r'.{0,160}\(\s*(?:19|20)\d{2})',
    unicode: true,
  );

  List<ParsedCitation> parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const [];

    final lines = _splitIntoReferenceLines(text);
    final citations = <ParsedCitation>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.length < 12) continue;

      final doiMatch = _doiPattern.firstMatch(line);
      final doi = doiMatch?.group(0)?.replaceAll(RegExp(r'[.,;)\]]+$'), '');
      final year = _guessYear(line);
      final title = _guessTitle(line, doi);

      citations.add(
        ParsedCitation(
          index: i + 1,
          rawText: line,
          doi: doi,
          titleGuess: title,
          yearGuess: year,
          searchQuery: _buildSearchQuery(line, doi, title),
        ),
      );
    }

    return citations;
  }

  List<String> _splitIntoReferenceLines(String text) {
    final normalized = text.replaceAll('\r\n', '\n');
    final pieces = <String>[];
    final buffer = StringBuffer();

    void flush() {
      final t = buffer.toString().trim();
      if (t.length >= 12) pieces.add(t);
      buffer.clear();
    }

    for (final rawLine in normalized.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) {
        if (buffer.isNotEmpty && _hasYear(buffer.toString())) flush();
        continue;
      }
      if (_referenceHeader.hasMatch(trimmed)) continue;
      if (CitationCues.isRunningMatterLine(trimmed)) continue;

      if (buffer.isEmpty) {
        buffer.write(trimmed);
        continue;
      }

      final current = buffer.toString();
      if (CitationCues.bibliographyLineContinues(current, trimmed)) {
        buffer.write(' ');
        buffer.write(trimmed);
        continue;
      }
      if (_looksLikeNewReference(trimmed) && _hasYear(current)) {
        flush();
        buffer.write(trimmed);
        continue;
      }
      buffer.write(' ');
      buffer.write(trimmed);
    }
    flush();

    final exploded = <String>[];
    for (final piece in pieces) {
      exploded.addAll(_explodeGlued(piece));
    }
    if (exploded.length >= 2) return exploded;

    final numbered = normalized
        .split(RegExp(r'(?=\s*(?:\[\d+\]|\d+\.|\d+\))\s+)'))
        .map((s) => s.replaceFirst(RegExp(r'^\[\d+\]|\d+\.|\d+\)\s*'), '').trim())
        .where((s) => s.length >= 12)
        .toList();
    if (numbered.length > exploded.length) return numbered;
    return exploded;
  }

  List<String> _explodeGlued(String piece) {
    if (!_gluedApa.hasMatch(piece)) return [piece];
    return piece
        .split(_gluedApa)
        .map((s) => s.trim())
        .where((s) => s.length >= 12)
        .toList();
  }

  bool _looksLikeNewReference(String line) {
    if (_numberedOrBullet.hasMatch(line)) return true;
    if (_arabicAuthorYear.hasMatch(line)) return true;
    if (CitationCues.standardsOrgLead.hasMatch(line)) return true;
    if (RegExp(r'^\((?:19|20)\d{2}[a-z]?\)').hasMatch(line)) return false;
    return _authorLead.hasMatch(line);
  }

  bool _hasYear(String text) =>
      RegExp(r'\b(?:19|20)\d{2}\b').hasMatch(text);

  String _buildSearchQuery(String line, String? doi, String title) {
    var work = line;
    if (doi != null) {
      work = work.replaceAll(RegExp('doi[:\\s]*$doi', caseSensitive: false), '');
      work = work.replaceAll(doi, '');
    }
    work = work.replaceAll(_doiPattern, '');
    work = work.replaceAll(RegExp(r'^\[\d+\]|\d+\.|\d+\)\s*'), '');
    work = work.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (title.length >= 12 && title.length <= 220) {
      return title;
    }
    if (work.length > 280) {
      return work.substring(0, 280).trim();
    }
    return work;
  }

  int? _guessYear(String line) {
    final parenYear = RegExp(r'\(\s*((?:19|20)\d{2})\s*\)').firstMatch(line);
    if (parenYear != null) {
      return int.tryParse(parenYear.group(1)!);
    }
    final plainYear = RegExp(r'\b((?:19|20)\d{2})\b').firstMatch(line);
    return plainYear != null ? int.tryParse(plainYear.group(1)!) : null;
  }

  String _guessTitle(String line, String? doi) {
    var work = line;
    if (doi != null) {
      work = work.replaceAll(RegExp('doi[:\\s]*$doi', caseSensitive: false), '');
      work = work.replaceAll(doi, '');
    }

    work = work.replaceAll(_doiPattern, '');
    work = work.replaceAll(RegExp(r'^\[\d+\]|\d+\.|\d+\)\s*'), '');
    work = work.replaceAll(RegExp(r'^[•●▪\-–—]\s+'), '');

    final quoted = RegExp(
      r'[«""„]([^»""]+)[»""]',
      dotAll: true,
    ).firstMatch(work);
    if (quoted != null) {
      final title = quoted.group(1)!.trim();
      if (title.length >= 8) return title;
    }

    final apa = RegExp(
      r'\(\s*(?:19|20)\d{2}\s*\)\s*[.:]\s*(.+?)\s*\.',
      dotAll: true,
    ).firstMatch(work);
    if (apa != null) {
      final title = apa.group(1)!.trim();
      if (title.length >= 8 && !_looksLikeAuthorFragment(title)) {
        return title;
      }
    }

    final yearDot = RegExp(
      r'(?:^|[\s,])(?:19|20)\d{2}\s*\.\s*(.+?)\s*\.',
      dotAll: true,
    ).firstMatch(work);
    if (yearDot != null) {
      final title = yearDot.group(1)!.trim();
      if (title.length >= 8 && !_looksLikeAuthorFragment(title)) {
        return title;
      }
    }

    final ieee = RegExp(
      r'^[^.]+\.\s+(.+?)\s*\.\s+(?:In\s|Proc\.|IEEE|Journal|Vol\.|pp\.)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(work);
    if (ieee != null) {
      final title = ieee.group(1)!.trim();
      if (title.length >= 8) return title;
    }

    final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(work);
    if (yearMatch != null && yearMatch.start > 10) {
      final beforeYear = work.substring(0, yearMatch.start).trim();
      final afterAuthors = beforeYear.replaceFirst(RegExp(r'^[^.]+\.\s*'), '');
      if (afterAuthors.length >= 8 && afterAuthors != beforeYear) {
        final cleaned = afterAuthors.replaceAll(RegExp(r'^\(\s*|\s*\)$'), '');
        if (cleaned.length >= 8) return cleaned;
      }
    }

    if (work.length > 200) {
      return work.substring(0, 200).trim();
    }
    return work.trim();
  }

  bool _looksLikeAuthorFragment(String text) {
    if (text.length > 80) return false;
    return RegExp(r'^[A-Z][a-z]+,\s*[A-Z]\.').hasMatch(text) ||
        RegExp(r'^[أ-ي]{2,}\s+[أ-ي]').hasMatch(text);
  }
}
