import 'package:flutter/material.dart';

import 'academic_text.dart';
import 'bibliography_match.dart';
import 'citation_cues.dart';
import 'publish_models.dart';

class BibliographySpan {
  final String text;
  final bool italic;

  const BibliographySpan(this.text, {this.italic = false});
}

class BibliographyEntry {
  final List<BibliographySpan> spans;

  const BibliographyEntry(this.spans);

  String get plain => spans.map((s) => s.text).join();
}

class CitationFormatter {
  CitationFormatter._();

  static String formatBibliography({
    required List<PublishReference> references,
    required PublishCitationStyle style,
  }) {
    if (references.isEmpty) return '';

    final ordered = orderForStyle(references, style);
    final buffer = StringBuffer();
    for (var i = 0; i < ordered.length; i++) {
      buffer.writeln(buildBibliographyEntry(
        reference: ordered[i],
        style: style,
        index: bibliographyIndex(ordered[i], i + 1),
      ).plain);
      if (i < references.length - 1) buffer.writeln();
    }
    return buffer.toString().trim();
  }

  static List<BibliographyEntry> buildBibliographyEntries({
    required List<PublishReference> references,
    required PublishCitationStyle style,
    bool plainNumberList = false,
  }) {
    final ordered = orderForStyle(references, style);
    return [
      for (var i = 0; i < ordered.length; i++)
        buildBibliographyEntry(
          reference: ordered[i],
          style: style,
          index: bibliographyIndex(ordered[i], i + 1),
          plainNumberList: plainNumberList,
        ),
    ];
  }

  /// Printed `[n]` for a numbered style: the imported file number, never list position.
  static int bibliographyIndex(PublishReference reference, int position) {
    return reference.importedNumber ?? position;
  }

  static BibliographyEntry buildBibliographyEntry({
    required PublishReference reference,
    required PublishCitationStyle style,
    required int index,
    bool plainNumberList = false,
  }) {
    final prepared = _prepareForStyle(reference);
    final fromOriginal = _authorDateEntryFromOriginal(reference, style);
    if (fromOriginal != null) return fromOriginal;
    if (_qualityOk(prepared) && !_authorsLookMangled(prepared.authors)) {
      return _structuredEntry(
        prepared,
        style: style,
        index: index,
        plainNumberList: plainNumberList,
      );
    }
    final raw = AcademicText.sanitize(reference.rawText.trim());
    if (raw.isNotEmpty) {
      return _rawBibliographyEntry(
        raw,
        style: style,
        index: index,
        plainNumberList: plainNumberList,
      );
    }
    return _structuredEntry(
      prepared,
      style: style,
      index: index,
      plainNumberList: plainNumberList,
    );
  }

  static List<PublishReference> orderForStyle(
    List<PublishReference> references,
    PublishCitationStyle style,
  ) {
    if (references.length < 2) return references;
    final hasImported = references.any((r) => r.importedNumber != null);
    if (!hasImported) return references;
    final copy = [...references];
    copy.sort((a, b) {
      final na = a.importedNumber ?? (1 << 20);
      final nb = b.importedNumber ?? (1 << 20);
      final byNumber = na.compareTo(nb);
      if (byNumber != 0) return byNumber;
      return references.indexOf(a).compareTo(references.indexOf(b));
    });
    return copy;
  }

  /// Rebuild only when authors/title/year look like a real bibliographic record.
  static bool _qualityOk(PublishReference ref) {
    final title = ref.title.trim();
    final year = ref.year.trim();
    final authors = ref.authors.where((a) => a.trim().isNotEmpty).toList();
    final container = ref.container.trim();
    if (year.length < 4 || authors.isEmpty) return false;
    if (title.length < 8 && container.length < 6) return false;
    for (final author in authors) {
      final t = author.trim();
      if (t.length < 2 || t.length > 80) return false;
      if (RegExp(
        r'vol\.|pp\.|doi\b|https?://|^["“]|journal|proceedings',
        caseSensitive: false,
      ).hasMatch(t)) {
        return false;
      }
      if (_looksLikeInitialsNotSurname(_authorLastName(t))) return false;
    }
    if (_authorsLookMangled(authors)) return false;
    final last = _authorLastName(authors.first).toLowerCase();
    if (last.length >= 3 && title.toLowerCase() == last) return false;
    if (RegExp(
      r'^(?:,?\s*(?:and|&)\s*)?[A-Z][A-Za-z\-]+,\s*[A-Z]',
    ).hasMatch(title)) {
      return false;
    }
    if (title.startsWith('(') ||
        title.startsWith(',') ||
        title.startsWith('"') ||
        title.startsWith('“') ||
        title.toLowerCase().startsWith('http') ||
        title.toLowerCase().startsWith('doi')) {
      return false;
    }
    if (RegExp(r'^\(?\s*Eds?\.?', caseSensitive: false).hasMatch(title)) {
      return false;
    }
    return true;
  }

  static PublishReference _prepareForStyle(PublishReference reference) {
    final parsed = parseBibliographicLine(reference.rawText);
    var merged = enrichReference(reference);
    merged = merged.copyWith(authors: normalizeAuthors(merged.authors));
    if (parsed == null) return merged;
    return merged.copyWith(
      type: parsed.type,
      authors: parsed.authors.isNotEmpty
          ? normalizeAuthors(parsed.authors)
          : merged.authors,
      title: parsed.title.isNotEmpty ? parsed.title : merged.title,
      container:
          parsed.container.isNotEmpty ? parsed.container : merged.container,
      year: parsed.year.isNotEmpty ? parsed.year : merged.year,
      volume: parsed.volume.isNotEmpty ? parsed.volume : merged.volume,
      issue: parsed.issue.isNotEmpty ? parsed.issue : merged.issue,
      pages: parsed.pages.isNotEmpty ? parsed.pages : merged.pages,
      doi: parsed.doi.isNotEmpty ? parsed.doi : merged.doi,
      url: parsed.url.isNotEmpty ? parsed.url : merged.url,
      publisher:
          parsed.publisher.isNotEmpty ? parsed.publisher : merged.publisher,
    );
  }

  /// Parse an imported IEEE / Vancouver / APA / ACS line into structured fields.
  static PublishReference? parseBibliographicLine(String raw) {
    var s = AcademicText.sanitize(raw).trim();
    if (s.length < 20) return null;
    s = _cleanRawCitation(s);
    if (s.length < 16) return null;

    if (RegExp(r'"[^"]{8,}"|“[^”]{8,}”').hasMatch(s)) {
      final ieee = _parseIeeeLikeLine(s);
      if (ieee != null) return ieee;
    }
    final acs = _parseAcsLikeLine(s);
    if (acs != null) return acs;
    final ieee = _parseIeeeLikeLine(s);
    if (ieee != null) return ieee;
    return _parseApaLikeLine(s);
  }

  static BibliographyEntry _structuredEntry(
    PublishReference reference, {
    required PublishCitationStyle style,
    required int index,
    required bool plainNumberList,
  }) {
    return switch (style) {
      PublishCitationStyle.ieee ||
      PublishCitationStyle.vancouver =>
        _buildIeeeEntry(reference, index, plainNumberList: plainNumberList),
      PublishCitationStyle.apa => _buildApaEntry(reference),
      PublishCitationStyle.harvard => _buildHarvardEntry(reference),
      PublishCitationStyle.chicago => _buildChicagoEntry(reference),
      PublishCitationStyle.acs =>
        _buildIeeeEntry(reference, index, plainNumberList: true),
    };
  }

  static PublishReference enrichReference(PublishReference ref) {
    final raw = ref.rawText.trim();
    if (raw.isEmpty) return ref;

    var volume = ref.volume.trim();
    var issue = ref.issue.trim();
    var pages = ref.pages.trim();
    var doi = ref.doi.trim();
    var container = ref.container.trim();
    var url = ref.url.trim();

    if (volume.isEmpty) {
      volume = RegExp(
            r'\bvol\.?\s*(\d+)',
            caseSensitive: false,
          ).firstMatch(raw)?.group(1) ??
          RegExp(r',\s*(\d{1,4})\s*\(').firstMatch(raw)?.group(1) ??
          '';
    }
    if (issue.isEmpty) {
      issue = RegExp(
            r'\bno\.?\s*(\d{1,4})\b',
            caseSensitive: false,
          ).firstMatch(raw)?.group(1) ??
          '';
      if (issue.isEmpty) {
        final fromParen = RegExp(r'\((\d{1,3})\)').firstMatch(raw)?.group(1);
        if (fromParen != null && !RegExp(r'^(?:19|20)\d{2}$').hasMatch(fromParen)) {
          issue = fromParen;
        }
      }
      if (RegExp(r'^(?:19|20)\d{2}$').hasMatch(issue)) {
        issue = '';
      }
    }
    if (pages.isEmpty) {
      pages = RegExp(
            r'\bpp?\.?\s*(\d+\s*[-–]\s*\d+)',
            caseSensitive: false,
          ).firstMatch(raw)?.group(1)?.replaceAll(' ', '') ??
          RegExp(r':\s*(\d+\s*[-–]\s*\d+)').firstMatch(raw)?.group(1) ??
          '';
    }
    if (doi.isEmpty) {
      doi = RegExp(
            r'(?:doi[:\s]*|https?://doi\.org/)([^\s,]+)',
            caseSensitive: false,
          ).firstMatch(raw)?.group(1)?.replaceAll(RegExp(r'[.)]+$'), '') ??
          '';
    }
    if (url.isEmpty) {
      url = RegExp(
            r'https?://[^\s]+',
            caseSensitive: false,
          ).firstMatch(raw)?.group(0)?.replaceAll(RegExp(r'[.)]+$'), '') ??
          '';
    }
    if (container.isEmpty) {
      container = RegExp(
            r'(?:in|,\s*)([A-Z][^,.\n]{4,80}'
            r'(?:Journal|Review|Letters|Science|Research|Bulletin)[^,.\n]*)',
          ).firstMatch(raw)?.group(1)?.trim() ??
          '';
    }

    if (volume == ref.volume &&
        issue == ref.issue &&
        pages == ref.pages &&
        doi == ref.doi &&
        url == ref.url &&
        container == ref.container) {
      return ref;
    }
    return ref.copyWith(
      volume: volume,
      issue: issue,
      pages: pages,
      doi: doi,
      url: url,
      container: container,
    );
  }

  static String formatInText({
    required PublishReference reference,
    required PublishCitationStyle style,
    required int index,
    InTextCitationForm form = InTextCitationForm.auto,
  }) {
    final resolved = resolveInTextForm(style, form);
    return switch (resolved) {
      InTextCitationForm.numbered => '[$index]',
      InTextCitationForm.superscript => _toSuperscriptDigits(index),
      InTextCitationForm.narrative => _formatNarrativeInText(reference, style),
      InTextCitationForm.parenthetical ||
      InTextCitationForm.auto =>
        _formatParentheticalInText(reference, style),
    };
  }

  static InTextCitationForm resolveInTextForm(
    PublishCitationStyle style,
    InTextCitationForm form,
  ) {
    if (form != InTextCitationForm.auto) return form;
    return switch (style) {
      PublishCitationStyle.ieee ||
      PublishCitationStyle.vancouver ||
      PublishCitationStyle.acs =>
        InTextCitationForm.numbered,
      PublishCitationStyle.apa ||
      PublishCitationStyle.harvard ||
      PublishCitationStyle.chicago =>
        InTextCitationForm.parenthetical,
    };
  }

  static bool isNumberedStyle(PublishCitationStyle style) =>
      style == PublishCitationStyle.ieee ||
      style == PublishCitationStyle.vancouver ||
      style == PublishCitationStyle.acs;

  static TextSpan buildBibliographyInlineSpan({
    required BibliographyEntry entry,
    TextStyle? baseStyle,
  }) {
    final style = baseStyle ?? const TextStyle(height: 1.6, fontSize: 13);
    return TextSpan(
      children: entry.spans
          .map(
            (s) => TextSpan(
              text: s.text,
              style: s.italic ? style.copyWith(fontStyle: FontStyle.italic) : style,
            ),
          )
          .toList(),
    );
  }

  static InTextCitationForm? parseFormToken(String? token) {
    if (token == null || token.trim().isEmpty) return null;
    return switch (token.trim().toLowerCase()) {
      'p' || 'paren' || 'parenthetical' => InTextCitationForm.parenthetical,
      'n' || 'narr' || 'narrative' => InTextCitationForm.narrative,
      'num' || 'numbered' || '#' => InTextCitationForm.numbered,
      'sup' || 'super' || 'superscript' => InTextCitationForm.superscript,
      'auto' || 'a' => InTextCitationForm.auto,
      _ => null,
    };
  }

  static String formToken(InTextCitationForm form) => switch (form) {
        InTextCitationForm.auto => 'auto',
        InTextCitationForm.parenthetical => 'p',
        InTextCitationForm.narrative => 'n',
        InTextCitationForm.numbered => 'num',
        InTextCitationForm.superscript => 'sup',
      };

  static String styleLabel(PublishCitationStyle style) => switch (style) {
        PublishCitationStyle.apa => 'APA',
        PublishCitationStyle.ieee => 'IEEE',
        PublishCitationStyle.vancouver => 'Vancouver',
        PublishCitationStyle.harvard => 'Harvard',
        PublishCitationStyle.chicago => 'Chicago',
        PublishCitationStyle.acs => 'ACS',
      };

  static String styleShortDescription(
    PublishCitationStyle style, {
    required bool arabic,
  }) {
    if (arabic) {
      return switch (style) {
        PublishCitationStyle.apa => '(مؤلف، سنة) في النص — قائمة أبجدية',
        PublishCitationStyle.ieee => '[1] في النص والقائمة',
        PublishCitationStyle.vancouver => 'أرقام في النص — 1. في القائمة',
        PublishCitationStyle.harvard => 'مؤلف وسنة — قائمة أبجدية',
        PublishCitationStyle.chicago => 'مؤلف. سنة. — قائمة أبجدية',
        PublishCitationStyle.acs => 'مرقّم 1. 2. 3. في القائمة',
      };
    }
    return switch (style) {
      PublishCitationStyle.apa => '(Author, Year) in text — alphabetical list',
      PublishCitationStyle.ieee => '[1] in text and reference list',
      PublishCitationStyle.vancouver => 'Numbered in text — 1. in the list',
      PublishCitationStyle.harvard => 'Author–year — alphabetical list',
      PublishCitationStyle.chicago => 'Author. Year. — alphabetical list',
      PublishCitationStyle.acs => 'Numbered 1. 2. 3. in the list',
    };
  }

  static String styleMenuLabel(
    PublishCitationStyle style, {
    required bool arabic,
  }) =>
      '${styleLabel(style)} — ${styleShortDescription(style, arabic: arabic)}';

  static String formLabel(InTextCitationForm form, {bool arabic = false}) {
    if (arabic) {
      return switch (form) {
        InTextCitationForm.auto => 'تلقائي حسب النمط',
        InTextCitationForm.parenthetical => '(مؤلف، سنة)',
        InTextCitationForm.narrative => 'مؤلف (سنة)',
        InTextCitationForm.numbered => '[رقم]',
        InTextCitationForm.superscript => 'رقم علوي',
      };
    }
    return switch (form) {
      InTextCitationForm.auto => 'Auto (match style)',
      InTextCitationForm.parenthetical => '(Author, Year)',
      InTextCitationForm.narrative => 'Author (Year)',
      InTextCitationForm.numbered => '[n]',
      InTextCitationForm.superscript => 'Superscript n',
    };
  }

  /// Detect IEEE numbered vs APA author-date from imported reference list.
  static PublishCitationStyle detectReferenceStyle(
    List<PublishReference> references,
  ) {
    if (references.isEmpty) return PublishCitationStyle.apa;

    var ieee = 0;
    var apa = 0;
    for (final ref in references) {
      final raw = ref.rawText.trim();
      if (raw.isEmpty) continue;
      if (RegExp(r'^\[\d+\]').hasMatch(raw) ||
          RegExp(r'^\d+[.)]\s+\w').hasMatch(raw)) {
        ieee++;
        continue;
      }
      if (RegExp(r'\(\d{4}[a-z]?\)').hasMatch(raw) ||
          RegExp(r'\bet al\.').hasMatch(raw)) {
        apa++;
      }
    }

    if (ieee >= apa && ieee >= 2) return PublishCitationStyle.ieee;
    if (apa > ieee) return PublishCitationStyle.apa;
    return ieee > 0 ? PublishCitationStyle.ieee : PublishCitationStyle.apa;
  }

  static String detectedStyleLabel(
    PublishCitationStyle style, {
    bool plainNumberList = false,
  }) {
    if (plainNumberList) {
      return 'Numbered (1. 2. 3. in list)';
    }
    return styleLabel(style);
  }

  static BibliographyEntry _rawBibliographyEntry(
    String raw, {
    required PublishCitationStyle style,
    required int index,
    required bool plainNumberList,
  }) {
    final body = _cleanRawCitation(AcademicText.sanitize(raw));
    if (body.isEmpty) {
      return BibliographyEntry([BibliographySpan(_listPrefix(index, plainNumberList).trim())]);
    }
    if (isNumberedStyle(style)) {
      var line = body;
      if (!RegExp(r'^\[\d+\]').hasMatch(line)) {
        line = '${_listPrefix(index, plainNumberList)}$line';
      } else {
        line = line.replaceFirst(RegExp(r'^\[\d+\]\s*'), _listPrefix(index, plainNumberList));
      }
      return BibliographyEntry([BibliographySpan(line)]);
    }
    return BibliographyEntry([BibliographySpan(body)]);
  }

  static String _formatParentheticalInText(
    PublishReference ref,
    PublishCitationStyle style,
  ) {
    final year = ref.year.trim().isNotEmpty ? ref.year.trim() : 'n.d.';
    final names = _inTextSurnames(ref);
    if (names.isEmpty) {
      return _yearCiteFromRawNames(ref, year, parenthetical: true) ?? '';
    }
    if (names.length == 1) {
      return '(${names.first}, $year)';
    }
    if (names.length == 2) {
      final sep = style == PublishCitationStyle.harvard ? ' and ' : ' & ';
      return '(${names[0]}$sep${names[1]}, $year)';
    }
    return '(${names.first} et al., $year)';
  }

  static String _formatNarrativeInText(
    PublishReference ref,
    PublishCitationStyle style,
  ) {
    final year = ref.year.trim().isNotEmpty ? ref.year.trim() : 'n.d.';
    final names = _inTextSurnames(ref);
    if (names.isEmpty) {
      return _yearCiteFromRawNames(ref, year, parenthetical: false) ?? '';
    }
    if (names.length == 1) {
      return '${names.first} ($year)';
    }
    if (names.length == 2) {
      return '${names[0]} and ${names[1]} ($year)';
    }
    return '${names.first} et al. ($year)';
  }

  /// Broken parses emit ALL-CAPS tokens (LB, AM). Real surnames like Li stay.
  static bool _looksLikeInitialsNotSurname(String last) {
    final t = last.replaceAll(RegExp(r'[.\s]'), '');
    if (t.length < 2 || t.length > 3) return false;
    if (!RegExp(r'^[A-Za-z]+$').hasMatch(t)) return false;
    return t == t.toUpperCase();
  }

  static List<String> _inTextSurnames(PublishReference ref) {
    final org = _standardsInTextName(ref);
    if (org != null) return [org];

    final out = <String>[];
    void add(String raw) {
      final t = raw.trim();
      if (t.isEmpty || _looksLikeInitialsNotSurname(t)) return;
      if (t.toLowerCase() == 'official' || t.toLowerCase() == 'methods') {
        return;
      }
      if (out.any((x) => x.toLowerCase() == t.toLowerCase())) return;
      out.add(t);
    }

    for (final author in ref.authors) {
      add(_authorLastName(author));
    }
    if (out.isNotEmpty && !_authorsLookMangled(ref.authors)) return out;
    out.clear();
    for (final n in BibliographyMatch.lastNamesFromRaw(ref.rawText)) {
      add(_displayLastName(n));
    }
    return out;
  }

  /// AOAC/AOCS manuals are cited by the organization, not the word "Official".
  static String? _standardsInTextName(PublishReference ref) {
    final lead = ref.authors.isEmpty
        ? ''
        : _authorLastName(ref.authors.first).toLowerCase();
    final raw = AcademicText.westernDigits(ref.rawText).trim();
    final looksOfficial = lead == 'official' ||
        lead == 'methods' ||
        CitationCues.standardsOrgLead.hasMatch(raw);
    if (!looksOfficial) return null;
    final blob = '${ref.authors.join(' ')} ${ref.title} $raw';
    final m = RegExp(
      r'\b(AOAC|AOCS|WHO|ISO|FAO|USDA|ASTM|IUPAC|EPA|NIST|OECD|CODEX|AACC|ICC)\b',
      caseSensitive: false,
    ).firstMatch(blob);
    return m?.group(1)?.toUpperCase();
  }

  static bool _authorsLookMangled(List<String> authors) {
    for (final author in authors) {
      if (_looksLikeInitialsNotSurname(_authorLastName(author))) return true;
    }
    return false;
  }

  /// APA/Harvard/Chicago from the imported line so the list stays the same works.
  static BibliographyEntry? _authorDateEntryFromOriginal(
    PublishReference reference,
    PublishCitationStyle style,
  ) {
    if (isNumberedStyle(style)) return null;
    var raw = _cleanRawCitation(AcademicText.sanitize(reference.rawText));
    if (raw.length < 20) return null;
    final year = BibliographyMatch.yearOf(reference);
    if (year.length < 4) return null;
    if (!_yearLeadsTitle(raw, year)) return null;

    final headEnd = raw.indexOf(year);
    final head = headEnd > 0
        ? raw
            .substring(0, headEnd)
            .replaceAll(RegExp(r'\(\s*$'), '')
            .trim()
        : raw;
    var authors = parseVancouverCompactAuthors(head);
    if (authors.isEmpty) authors = _parseApaAuthorNames(head);
    if (authors.isEmpty) authors = _parseIeeeAuthorNames(head);
    authors = normalizeAuthors(authors);
    if (authors.isEmpty || _authorsLookMangled(authors)) return null;

    var rest = raw.substring(headEnd + year.length).replaceFirst(
          RegExp(r'^[a-z]?[).\s,;]+'),
          '',
        );
    rest = rest.trim();
    if (rest.length < 8) return null;

    final joined = switch (style) {
      PublishCitationStyle.harvard => _joinAuthorsHarvard(authors),
      PublishCitationStyle.chicago => _joinAuthorsChicago(authors),
      _ => _joinAuthorsApa(authors),
    };
    final yearBit =
        style == PublishCitationStyle.chicago ? '$year. ' : '($year). ';
    return BibliographyEntry([
      BibliographySpan('$joined $yearBit'),
      BibliographySpan(rest),
    ]);
  }

  static bool _yearLeadsTitle(String raw, String year) {
    return RegExp(
          '\\(\\s*$year[a-z]?\\s*\\)\\s*[.\\s]*[A-Za-z"“]',
        ).hasMatch(raw) ||
        RegExp('$year\\)\\s+[A-Za-z"“]').hasMatch(raw);
  }

  static List<String> parseVancouverCompactAuthors(String authorsPart) {
    var s = authorsPart.trim();
    s = s.replaceFirst(RegExp(r'^\[\d+\]\s*'), '');
    s = s.replaceFirst(RegExp(r'^\d+[.)]\s+'), '');
    if (s.contains(';')) return const [];
    s = s.replaceAll(RegExp(r'\s+and\s+', caseSensitive: false), ', ');
    s = s.replaceAll(RegExp(r'\s+&\s+'), ', ');
    s = s.replaceAll(RegExp(r'\bet\s+al\.?', caseSensitive: false), '');
    final parts = s.split(RegExp(r'\s*,\s*')).where((p) => p.trim().isNotEmpty);
    final out = <String>[];
    for (final p in parts) {
      final words = p.trim().split(RegExp(r'\s+'));
      if (words.length < 2) return const [];
      final surname = words.first.replaceAll(',', '');
      if (surname.length < 2 || _looksLikeInitialsNotSurname(surname)) {
        return const [];
      }
      if (!RegExp(r"^[A-Z][a-zA-Z'\-]+$").hasMatch(surname)) return const [];
      final rest = words.sublist(1);
      if (rest.isEmpty || !rest.every(_isInitialsToken)) return const [];
      out.add('$surname ${rest.join(' ')}');
    }
    return out.take(12).toList();
  }

  static String? _yearCiteFromRawNames(
    PublishReference ref,
    String year, {
    required bool parenthetical,
  }) {
    final names = BibliographyMatch.lastNamesOf(ref);
    if (names.isEmpty) return null;
    final lead = _displayLastName(names.first);
    final body = names.length == 1 ? '$lead, $year' : '$lead et al., $year';
    if (parenthetical) return '($body)';
    return names.length == 1 ? '$lead ($year)' : '$lead et al. ($year)';
  }

  static String _displayLastName(String folded) {
    if (folded.isEmpty) return folded;
    return '${folded[0].toUpperCase()}${folded.substring(1)}';
  }

  static String _authorLastName(String author) {
    final split = _splitAuthorName(author);
    if (split != null) return split.surname;
    final trimmed = author.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.contains(',')) {
      final head = trimmed.split(',').first.trim();
      if (_looksLikeInitialsNotSurname(head)) return '';
      return head;
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.last : trimmed;
  }

  static bool _isInitialsToken(String word) {
    final t = word.replaceAll('.', '').trim();
    if (t.isEmpty || t.length > 3 || !RegExp(r'^[A-Za-z]+$').hasMatch(t)) {
      return false;
    }
    if (t.length == 1) return true;
    return t == t.toUpperCase();
  }

  /// Family name plus initials from APA, IEEE, or Vancouver (`Dotto GL`).
  static ({String surname, List<String> initialTokens})? _splitAuthorName(
    String author,
  ) {
    var trimmed = author.trim().replaceFirst(RegExp(r'^[.\s]+'), '');
    if (trimmed.isEmpty) return null;

    if (trimmed.contains(',')) {
      final parts = trimmed.split(',').map((s) => s.trim()).toList();
      final last = parts[0];
      if (last.isEmpty || _looksLikeInitialsNotSurname(last)) return null;
      final fromHead = _vancouverCompact(last.split(RegExp(r'\s+')));
      if (fromHead != null) return fromHead;
      final given = parts.sublist(1).join(' ').trim();
      final initials = given
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      return (surname: last, initialTokens: initials);
    }

    final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length < 2) return null;
    final vancouver = _vancouverCompact(words);
    if (vancouver != null) return vancouver;
    final surname = words.last;
    if (_looksLikeInitialsNotSurname(surname)) return null;
    return (
      surname: surname,
      initialTokens: words.sublist(0, words.length - 1),
    );
  }

  /// `Jia L` / `Dotto GL` / `Shah MUH` — surname first, compact initials after.
  static ({String surname, List<String> initialTokens})? _vancouverCompact(
    List<String> words,
  ) {
    if (words.length < 2) return null;
    final surname = words.first.replaceAll(',', '');
    if (surname.length < 2 || _looksLikeInitialsNotSurname(surname)) {
      return null;
    }
    if (!RegExp(r"^[A-Z][a-zA-Z'\-]+$").hasMatch(surname)) return null;
    final rest = words.sublist(1);
    if (rest.isEmpty || !rest.every(_isInitialsToken)) return null;
    return (surname: surname, initialTokens: rest);
  }

  static String _initialsFromTokens(List<String> tokens) {
    return tokens
        .where((w) => w.isNotEmpty)
        .map((w) {
          if (_isInitialsToken(w) || w.contains('.')) {
            final letters = w.replaceAll('.', '');
            if (letters.isEmpty) return '';
            return letters.split('').map((c) => '${c.toUpperCase()}.').join(' ');
          }
          return '${w[0].toUpperCase()}.';
        })
        .where((s) => s.isNotEmpty)
        .join(' ');
  }

  static String _cleanRawCitation(String raw) {
    return raw
        .replaceAll(RegExp(r'^\[\d+\]\s*'), '')
        .replaceAll(RegExp(r'^\d+[.)]\s+'), '')
        .trim();
  }

  static String _authorSortKey(PublishReference ref) {
    if (ref.authors.isNotEmpty) {
      return _authorLastName(ref.authors.first).toLowerCase();
    }
    final parsed = parseBibliographicLine(ref.rawText);
    if (parsed != null && parsed.authors.isNotEmpty) {
      return _authorLastName(parsed.authors.first).toLowerCase();
    }
    return _cleanRawCitation(ref.rawText).toLowerCase();
  }

  /// ACS / many chemistry journals: Last, F.; Last, F. Title. J. Name Year, vol, pages.
  static PublishReference? _parseAcsLikeLine(String s) {
    // ACS authors are semicolon-separated. APA lines must not go through here
    // or remaining authors are misread as the title.
    if (!s.contains(';')) return null;
    final yearM = RegExp(r'\b((?:19|20)\d{2})\b').firstMatch(s);
    if (yearM == null) return null;
    if (RegExp(r'"[^"]{8,}"|“[^”]{8,}”').hasMatch(s) &&
        !s.contains(';')) {
      return null;
    }

    final parsedAuthors = _splitAcsAuthors(s);
    if (parsedAuthors.authors.isEmpty) return null;
    var rest = parsedAuthors.rest.trim().replaceFirst(RegExp(r'^[\s.]+'), '');
    if (rest.length < 8) return null;

    final restYear = RegExp(r'\b((?:19|20)\d{2})\b').firstMatch(rest);
    if (restYear == null) return null;
    final beforeYear = rest.substring(0, restYear.start).trim().replaceAll(
          RegExp(r'[.,]+$'),
          '',
        );
    var afterYear = rest.substring(restYear.end).trim();
    final year = restYear.group(1)!;

    String title = beforeYear;
    String container = '';
    final journal = RegExp(
      r'((?:[A-Z][a-z]{0,10}\.\s*){1,8}[A-Za-z. ]{2,50}|'
      r'[A-Z][^.]{3,80}(?:Journal|Letters|Review|Science|Chemistry|Chem\.))$',
    ).firstMatch(beforeYear);
    if (journal != null) {
      container = journal.group(1)!.trim();
      title = beforeYear.substring(0, journal.start).trim().replaceAll(
            RegExp(r'[.]+$'),
            '',
          );
    } else {
      final lastDot = beforeYear.lastIndexOf('. ');
      if (lastDot > 8) {
        title = beforeYear.substring(0, lastDot).trim();
        container = beforeYear.substring(lastDot + 2).trim();
      }
    }

    afterYear = afterYear.replaceFirst(RegExp(r'^,\s*'), '');
    final volume = RegExp(r'^(\d+)').firstMatch(afterYear)?.group(1) ?? '';
    final issue = RegExp(r'\((\d+)\)').firstMatch(afterYear)?.group(1) ?? '';
    final pages = RegExp(r'(\d+\s*[-–]\s*\d+)')
            .firstMatch(afterYear)
            ?.group(1)
            ?.replaceAll(' ', '') ??
        '';
    final doi = RegExp(
          r'(?:doi[:\s]*|https?://doi\.org/)([^\s,]+)',
          caseSensitive: false,
        ).firstMatch(s)?.group(1)?.replaceAll(RegExp(r'[.)]+$'), '') ??
        '';

    if (parsedAuthors.authors.isEmpty ||
        (title.length < 8 && container.length < 6)) {
      return null;
    }

    return PublishReference(
      id: '',
      type: ReferenceType.journal,
      authors: parsedAuthors.authors,
      title: title.isNotEmpty ? title : container,
      container: container,
      year: year,
      volume: volume,
      issue: issue,
      pages: pages,
      doi: doi,
    );
  }

  static ({List<String> authors, String rest}) _splitAcsAuthors(String s) {
    final authors = <String>[];
    var cursor = 0;
    final authorRe = RegExp(
      r"^[\p{Lu}][\p{L}'\-]*,\s*(?:[A-Z]\.\s*)+",
      unicode: true,
    );
    while (cursor < s.length) {
      final slice = s.substring(cursor).trimLeft();
      final skipped = s.length - cursor - slice.length;
      cursor += skipped;
      final m = authorRe.matchAsPrefix(slice);
      if (m == null) break;
      authors.add(m.group(0)!.trim().replaceAll(RegExp(r'[;,\s]+$'), ''));
      cursor += m.end;
      final next = s.substring(cursor).trimLeft();
      if (next.startsWith(';')) {
        cursor = s.length - next.length + 1;
        continue;
      }
      break;
    }
    if (authors.isEmpty) return (authors: const <String>[], rest: s);
    return (authors: authors.take(12).toList(), rest: s.substring(cursor));
  }

  static PublishReference? _parseIeeeLikeLine(String s) {
    final quoted = RegExp(r'"([^"]{8,400})"').firstMatch(s) ??
        RegExp(r'“([^”]{8,400})”').firstMatch(s);
    if (quoted == null) return null;
    final title = quoted.group(1)!.trim().replaceAll(RegExp(r'[.,]+$'), '');
    if (title.startsWith(',') ||
        RegExp(r'^\(?\s*Eds?\.?', caseSensitive: false).hasMatch(title) ||
        RegExp(r'^[A-Z][A-Za-z\-]+,\s*[A-Z]').hasMatch(title)) {
      return null;
    }
    final authors = _parseIeeeAuthorNames(s.substring(0, quoted.start));
    if (authors.isEmpty) return null;

    var rest = s.substring(quoted.end).replaceFirst(RegExp(r'^[\s,]+'), '');
    rest = rest.replaceFirst(RegExp(r'^in\s+', caseSensitive: false), '');

    final doi = RegExp(
          r'(?:doi[:\s]*|https?://doi\.org/)([^\s,]+)',
          caseSensitive: false,
        ).firstMatch(rest)?.group(1)?.replaceAll(RegExp(r'[.)]+$'), '') ??
        '';
    final url = RegExp(r'https?://[^\s]+')
            .firstMatch(rest)
            ?.group(0)
            ?.replaceAll(RegExp(r'[.)]+$'), '') ??
        '';
    final volume = RegExp(r'\bvol\.?\s*(\d+)', caseSensitive: false)
            .firstMatch(rest)
            ?.group(1) ??
        '';
    final issue = RegExp(r'\bno\.?\s*(\d+)', caseSensitive: false)
            .firstMatch(rest)
            ?.group(1) ??
        '';
    final pages = RegExp(
          r'\bpp?\.?\s*(\d+\s*[-–]\s*\d+)',
          caseSensitive: false,
        ).firstMatch(rest)?.group(1)?.replaceAll(' ', '') ??
        '';
    final years = RegExp(r'\b((?:19|20)\d{2})\b')
        .allMatches(rest)
        .map((m) => m.group(1)!)
        .toList();
    final year = years.isEmpty ? '' : years.last;

    var container = '';
    final cut = RegExp(
      r',\s*(?:vol\.?|no\.?|pp?\.?|(?:19|20)\d{2}\b)',
      caseSensitive: false,
    ).firstMatch(rest);
    if (cut != null) {
      container = rest.substring(0, cut.start).trim().replaceAll(RegExp(r'[.,]+$'), '');
    } else if (year.isNotEmpty) {
      final y = rest.indexOf(year);
      if (y > 0) {
        container = rest.substring(0, y).trim().replaceAll(RegExp(r'[.,]+$'), '');
      }
    }

    final isConf = RegExp(r'proc\.|conference|symposium|workshop',
            caseSensitive: false)
        .hasMatch(rest);
    return PublishReference(
      id: '',
      type: isConf ? ReferenceType.conference : ReferenceType.journal,
      authors: authors,
      title: title,
      container: container,
      conference: isConf ? container : '',
      year: year,
      volume: volume,
      issue: issue,
      pages: pages,
      doi: doi,
      url: doi.isEmpty ? url : '',
    );
  }

  static PublishReference? _parseApaLikeLine(String s) {
    final m = RegExp(
      r'^(.+?)\s*\(((?:19|20)\d{2})[a-z]?\)\.?\s+(.+)$',
    ).firstMatch(s);
    if (m == null) return null;
    final authors = _parseApaAuthorNames(m.group(1)!);
    if (authors.isEmpty) return null;
    final year = m.group(2)!;
    var rest = m.group(3)!.trim();

    String title = rest;
    String container = '';
    final firstDot = rest.indexOf('. ');
    if (firstDot > 8) {
      title = rest.substring(0, firstDot).trim();
      rest = rest.substring(firstDot + 2).trim();
      final journalCut = RegExp(r',\s*\d').firstMatch(rest);
      if (journalCut != null) {
        container = rest.substring(0, journalCut.start).trim();
        rest = rest.substring(journalCut.start + 1).trim();
      } else {
        container = rest.split('.').first.trim();
      }
    }

    final volume = RegExp(r'^(\d+)').firstMatch(rest)?.group(1) ?? '';
    final issue = RegExp(r'\((\d+)\)').firstMatch(rest)?.group(1) ?? '';
    final pages = RegExp(r'(\d+\s*[-–]\s*\d+)').firstMatch(rest)?.group(1)?.replaceAll(' ', '') ??
        '';
    final doi = RegExp(
          r'(?:doi[:\s]*|https?://doi\.org/)([^\s,]+)',
          caseSensitive: false,
        ).firstMatch(s)?.group(1)?.replaceAll(RegExp(r'[.)]+$'), '') ??
        '';

    return PublishReference(
      id: '',
      type: ReferenceType.journal,
      authors: authors,
      title: title.replaceAll(RegExp(r'\.$'), ''),
      container: container.replaceAll(RegExp(r'[.,]+$'), ''),
      year: year,
      volume: volume,
      issue: issue,
      pages: pages,
      doi: doi,
    );
  }

  static List<String> _parseIeeeAuthorNames(String beforeTitle) {
    var s = beforeTitle.trim().replaceAll(RegExp(r',\s*$'), '');
    s = s.replaceFirst(RegExp(r'^[.\s]+'), '');
    final vancouver = parseVancouverCompactAuthors(s);
    if (vancouver.length >= 2) return vancouver;
    if (s.contains(';')) {
      final acs = _splitAcsAuthors(s).authors;
      if (acs.isNotEmpty) return acs;
    }
    if (RegExp(r"^[A-Z][A-Za-z'\-]+,\s*[A-Z]\.").hasMatch(s)) {
      final apa = _parseApaAuthorNames(s);
      if (apa.isNotEmpty) return apa;
    }
    s = s.replaceAll(RegExp(r'\s+and\s+', caseSensitive: false), ', ');
    s = s.replaceAll(RegExp(r'\s+&\s+'), ', ');
    s = s.replaceAll(RegExp(r'\bet\s+al\.?', caseSensitive: false), '');
    final ieee = RegExp(r"(?:[A-Z]\.\s*)+[A-Z][A-Za-z'\-]{2,}")
        .allMatches(s)
        .map((m) => m.group(0)!.trim())
        .where((n) => n.length >= 3 && n.length <= 60)
        .where((n) => !RegExp(r'^(?:J|Chem|Food|Agric|Proc)\b').hasMatch(n))
        .toList();
    if (ieee.isNotEmpty) return ieee.take(12).toList();
    return _parseApaAuthorNames(s);
  }

  static List<String> normalizeAuthors(List<String> authors) {
    final out = <String>[];
    for (final raw in authors) {
      var a = raw.trim().replaceFirst(RegExp(r'^[.\s,"]+'), '');
      a = a.replaceAll(RegExp(r'[,"]+$'), '').trim();
      if (a.length < 2) continue;
      if (RegExp(r'^[A-Z]\.?$').hasMatch(a)) continue;
      if (RegExp(r'vol\.|pp\.|doi\b|https?://', caseSensitive: false)
          .hasMatch(a)) {
        continue;
      }
      out.add(a);
    }
    return out.take(12).toList();
  }

  static List<String> _parseApaAuthorNames(String authorsPart) {
    var s = authorsPart.trim().replaceAll(RegExp(r'[.,]\s*$'), '');
    s = s.replaceAll(
      RegExp(r'\s*\((?:[Ee]ds?\.?)\)\s*', caseSensitive: false),
      ' ',
    );
    s = s.replaceAll(RegExp(r'\s+&\s+'), ', ');
    s = s.replaceAll(RegExp(r'\s+and\s+', caseSensitive: false), ', ');
    s = s.replaceAll(RegExp(r'\bet\s+al\.?', caseSensitive: false), '');
    final pairs = RegExp(
      r"([A-Z][a-z][A-Za-z'\-]*),\s*"
      r"((?:[A-Z](?:[a-z]+|\.)?)(?:\s+[A-Z](?:[a-z]+|\.)?)*)",
    )
        .allMatches(s)
        .map((m) => '${m.group(1)!.trim()}, ${m.group(2)!.trim()}')
        .where((n) => n.length >= 4)
        .toList();
    if (pairs.isNotEmpty) return pairs.take(12).toList();
    final vancouver = parseVancouverCompactAuthors(s);
    if (vancouver.isNotEmpty) return vancouver;
    final org = s.replaceAll(RegExp(r'[.]+$'), '').trim();
    if (RegExp(r'^[A-Z]{2,8}$').hasMatch(org)) return [org];
    return const [];
  }

  static String _listPrefix(int index, bool plainNumberList) =>
      plainNumberList ? '$index. ' : '[$index] ';

  static String _toSuperscriptDigits(int n) {
    const map = {
      '0': '⁰',
      '1': '¹',
      '2': '²',
      '3': '³',
      '4': '⁴',
      '5': '⁵',
      '6': '⁶',
      '7': '⁷',
      '8': '⁸',
      '9': '⁹',
    };
    return n.toString().split('').map((c) => map[c] ?? c).join();
  }

  static BibliographyEntry _buildIeeeEntry(
    PublishReference ref,
    int index, {
    bool plainNumberList = false,
  }) {
    final authors = _joinAuthorsIeee(ref.authors);
    final title = ref.title.trim();
    final year = ref.year.trim();

    final spans = <BibliographySpan>[
      BibliographySpan('${_listPrefix(index, plainNumberList)}$authors, '),
    ];

    return switch (ref.type) {
      ReferenceType.journal => () {
          if (title.isNotEmpty) {
            spans.add(BibliographySpan('"$title," '));
          }
          if (ref.container.isNotEmpty) {
            spans.add(BibliographySpan(ref.container.trim(), italic: true));
          }
          if (ref.volume.isNotEmpty) {
            spans.add(BibliographySpan(
              '${ref.container.isNotEmpty ? ',' : ''} vol. ${ref.volume.trim()}',
            ));
          }
          if (ref.issue.isNotEmpty) {
            spans.add(BibliographySpan(', no. ${ref.issue.trim()}'));
          }
          if (ref.pages.isNotEmpty) {
            spans.add(BibliographySpan(', pp. ${ref.pages.trim()}'));
          }
          if (year.isNotEmpty) spans.add(BibliographySpan(', $year'));
          spans.add(const BibliographySpan('.'));
          if (ref.doi.isNotEmpty) {
            spans.add(BibliographySpan(' doi: ${ref.doi.trim()}.'));
          }
          return BibliographyEntry(spans);
        }(),
      ReferenceType.book => () {
          spans.addAll([
            BibliographySpan(title, italic: true),
            if (ref.publisher.isNotEmpty) BibliographySpan('. ${ref.publisher.trim()}'),
            if (year.isNotEmpty) BibliographySpan(', $year'),
            BibliographySpan('.'),
          ]);
          return BibliographyEntry(spans);
        }(),
      ReferenceType.web => () {
          spans.addAll([
            BibliographySpan('"$title," '),
            if (ref.container.isNotEmpty) BibliographySpan('${ref.container.trim()}, '),
            if (year.isNotEmpty) BibliographySpan('$year. '),
            if (ref.url.isNotEmpty)
              BibliographySpan('[Online]. Available: ${ref.url.trim()}'),
            BibliographySpan('.'),
          ]);
          return BibliographyEntry(spans);
        }(),
      ReferenceType.conference => () {
          spans.addAll([
            BibliographySpan('"$title," in '),
            if (ref.conference.isNotEmpty)
              BibliographySpan(ref.conference.trim(), italic: true),
            if (ref.pages.isNotEmpty) BibliographySpan(', pp. ${ref.pages.trim()}'),
            if (year.isNotEmpty) BibliographySpan(', $year'),
            BibliographySpan('.'),
          ]);
          return BibliographyEntry(spans);
        }(),
    };
  }

  static BibliographyEntry _buildApaEntry(PublishReference ref) {
    final authors = _joinAuthorsApa(ref.authors);
    final title = ref.title.trim();
    final year = ref.year.trim().isNotEmpty ? ref.year.trim() : 'n.d.';

    final spans = <BibliographySpan>[BibliographySpan('$authors ($year). ')];

    return switch (ref.type) {
      ReferenceType.journal => () {
          spans.add(BibliographySpan('$title. '));
          if (ref.container.isNotEmpty) {
            spans.add(BibliographySpan(ref.container.trim(), italic: true));
          }
          if (ref.volume.isNotEmpty) {
            spans.add(BibliographySpan(', ${ref.volume.trim()}', italic: true));
          }
          if (ref.issue.isNotEmpty) {
            spans.add(BibliographySpan('(${ref.issue.trim()})'));
          }
          if (ref.pages.isNotEmpty) {
            spans.add(BibliographySpan(', ${ref.pages.trim()}'));
          }
          if (ref.doi.isNotEmpty) {
            spans.add(BibliographySpan('. https://doi.org/${ref.doi.trim()}'));
          } else if (ref.url.isNotEmpty) {
            spans.add(BibliographySpan('. ${ref.url.trim()}'));
          }
          spans.add(BibliographySpan('.'));
          return BibliographyEntry(spans);
        }(),
      ReferenceType.book => () {
          spans.add(BibliographySpan(title, italic: true));
          if (ref.publisher.isNotEmpty) {
            spans.add(BibliographySpan('. ${ref.publisher.trim()}'));
          }
          spans.add(BibliographySpan('.'));
          return BibliographyEntry(spans);
        }(),
      ReferenceType.web => () {
          spans.add(BibliographySpan('$title. '));
          final site =
              ref.container.trim().isNotEmpty ? ref.container.trim() : 'Website';
          spans.add(BibliographySpan(site, italic: true));
          if (ref.url.isNotEmpty) spans.add(BibliographySpan('. ${ref.url.trim()}'));
          spans.add(BibliographySpan('.'));
          return BibliographyEntry(spans);
        }(),
      ReferenceType.conference => () {
          spans.add(BibliographySpan('$title. '));
          if (ref.conference.isNotEmpty) {
            spans.add(BibliographySpan('In ', italic: false));
            spans.add(BibliographySpan(ref.conference.trim(), italic: true));
          }
          if (ref.pages.isNotEmpty) {
            spans.add(BibliographySpan(' (pp. ${ref.pages.trim()})'));
          }
          spans.add(BibliographySpan('.'));
          return BibliographyEntry(spans);
        }(),
    };
  }

  static BibliographyEntry _buildHarvardEntry(PublishReference ref) {
    final authors = _joinAuthorsHarvard(ref.authors);
    final title = ref.title.trim();
    final year = ref.year.trim().isNotEmpty ? ref.year.trim() : 'n.d.';
    final spans = <BibliographySpan>[BibliographySpan('$authors ($year) ')];

    return switch (ref.type) {
      ReferenceType.journal => () {
          spans.add(BibliographySpan("'$title', "));
          if (ref.container.isNotEmpty) {
            spans.add(BibliographySpan(ref.container.trim(), italic: true));
          }
          if (ref.volume.isNotEmpty) {
            spans.add(BibliographySpan(', ${ref.volume.trim()}'));
          }
          if (ref.issue.isNotEmpty) {
            spans.add(BibliographySpan('(${ref.issue.trim()})'));
          }
          if (ref.pages.isNotEmpty) {
            spans.add(BibliographySpan(', pp. ${ref.pages.trim()}'));
          }
          spans.add(BibliographySpan('.'));
          return BibliographyEntry(spans);
        }(),
      ReferenceType.book => () {
          spans.add(BibliographySpan(title, italic: true));
          if (ref.publisher.isNotEmpty) {
            spans.add(BibliographySpan('. ${ref.publisher.trim()}'));
          }
          spans.add(BibliographySpan('.'));
          return BibliographyEntry(spans);
        }(),
      ReferenceType.web => () {
          spans.add(BibliographySpan("'$title' "));
          if (ref.url.isNotEmpty) {
            spans.add(BibliographySpan('Available at: ${ref.url.trim()}.'));
          } else {
            spans.add(BibliographySpan('.'));
          }
          return BibliographyEntry(spans);
        }(),
      ReferenceType.conference => () {
          spans.add(BibliographySpan("'$title', "));
          if (ref.conference.isNotEmpty) {
            spans.add(BibliographySpan('in ${ref.conference.trim()}'));
          }
          if (ref.pages.isNotEmpty) {
            spans.add(BibliographySpan(', pp. ${ref.pages.trim()}'));
          }
          spans.add(BibliographySpan('.'));
          return BibliographyEntry(spans);
        }(),
    };
  }

  static BibliographyEntry _buildChicagoEntry(PublishReference ref) {
    final authors = _joinAuthorsChicago(ref.authors);
    final title = ref.title.trim();
    final year = ref.year.trim().isNotEmpty ? ref.year.trim() : 'n.d.';
    final spans = <BibliographySpan>[BibliographySpan('$authors. $year. ')];

    return switch (ref.type) {
      ReferenceType.journal => () {
          spans.add(BibliographySpan('"$title." '));
          if (ref.container.isNotEmpty) {
            spans.add(BibliographySpan(ref.container.trim(), italic: true));
          }
          if (ref.volume.isNotEmpty) {
            spans.add(BibliographySpan(' ${ref.volume.trim()}'));
          }
          if (ref.issue.isNotEmpty) {
            spans.add(BibliographySpan(', no. ${ref.issue.trim()}'));
          }
          if (ref.pages.isNotEmpty) {
            spans.add(BibliographySpan(': ${ref.pages.trim()}'));
          }
          spans.add(BibliographySpan('.'));
          return BibliographyEntry(spans);
        }(),
      ReferenceType.book => () {
          spans.add(BibliographySpan(title, italic: true));
          if (ref.publisher.isNotEmpty) {
            spans.add(BibliographySpan('. ${ref.publisher.trim()}'));
          }
          spans.add(BibliographySpan('.'));
          return BibliographyEntry(spans);
        }(),
      ReferenceType.web => () {
          spans.add(BibliographySpan('"$title." '));
          if (ref.url.isNotEmpty) {
            spans.add(BibliographySpan(ref.url.trim()));
          }
          spans.add(BibliographySpan('.'));
          return BibliographyEntry(spans);
        }(),
      ReferenceType.conference => () {
          spans.add(BibliographySpan('"$title." '));
          if (ref.conference.isNotEmpty) {
            spans.add(BibliographySpan('In ${ref.conference.trim()}'));
          }
          if (ref.pages.isNotEmpty) {
            spans.add(BibliographySpan(', ${ref.pages.trim()}'));
          }
          spans.add(BibliographySpan('.'));
          return BibliographyEntry(spans);
        }(),
    };
  }

  static String _joinAuthorsIeee(List<String> authors) {
    final formatted =
        authors.where((a) => a.trim().isNotEmpty).map(_formatAuthorIeee).toList();
    if (formatted.isEmpty) return 'Unknown Author';
    if (formatted.length == 1) return formatted.first;
    if (formatted.length == 2) return '${formatted[0]} and ${formatted[1]}';
    return '${formatted.sublist(0, formatted.length - 1).join(', ')}, and ${formatted.last}';
  }

  static String _joinAuthorsApa(List<String> authors) {
    final formatted =
        authors.where((a) => a.trim().isNotEmpty).map(_formatAuthorApa).toList();
    if (formatted.isEmpty) return 'Unknown Author';
    if (formatted.length == 1) return formatted.first;
    if (formatted.length == 2) return '${formatted[0]}, & ${formatted[1]}';
    if (formatted.length <= 20) {
      return '${formatted.sublist(0, formatted.length - 1).join(', ')}, & ${formatted.last}';
    }
    return '${formatted.take(19).join(', ')}, ... ${formatted.last}';
  }

  static String _joinAuthorsHarvard(List<String> authors) {
    final formatted =
        authors.where((a) => a.trim().isNotEmpty).map(_formatAuthorApa).toList();
    if (formatted.isEmpty) return 'Unknown Author';
    if (formatted.length == 1) return formatted.first;
    if (formatted.length == 2) return '${formatted[0]} and ${formatted[1]}';
    return '${formatted.first} et al.';
  }

  static String _joinAuthorsChicago(List<String> authors) {
    final formatted =
        authors.where((a) => a.trim().isNotEmpty).map(_formatAuthorChicago).toList();
    if (formatted.isEmpty) return 'Unknown Author';
    if (formatted.length == 1) return formatted.first;
    if (formatted.length == 2) return '${formatted[0]}, and ${formatted[1]}';
    return '${formatted.sublist(0, formatted.length - 1).join(', ')}, and ${formatted.last}';
  }

  static String _formatAuthorIeee(String author) {
    var trimmed = author.trim().replaceFirst(RegExp(r'^[.\s]+'), '');
    if (trimmed.isEmpty) return '';
    final split = _splitAuthorName(trimmed);
    if (split != null) {
      final initials = _initialsFromTokens(split.initialTokens);
      return initials.isEmpty ? split.surname : '$initials ${split.surname}';
    }
    if (trimmed.contains(',')) {
      final last = trimmed.split(',').first.trim();
      if (_looksLikeInitialsNotSurname(last)) return trimmed;
    }
    return trimmed;
  }

  static String _formatAuthorApa(String author) {
    var trimmed = author.trim().replaceFirst(RegExp(r'^[.\s]+'), '');
    if (trimmed.isEmpty) return '';
    final split = _splitAuthorName(trimmed);
    if (split != null) {
      final initials = _initialsFromTokens(split.initialTokens);
      return initials.isEmpty ? split.surname : '${split.surname}, $initials';
    }
    if (trimmed.contains(',')) {
      final last = trimmed.split(',').first.trim();
      if (_looksLikeInitialsNotSurname(last)) return trimmed;
    }
    return trimmed;
  }

  static String _formatAuthorChicago(String author) {
    final trimmed = author.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.contains(',')) return trimmed;
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words.last}, ${words.sublist(0, words.length - 1).join(' ')}';
    }
    return trimmed;
  }
}
