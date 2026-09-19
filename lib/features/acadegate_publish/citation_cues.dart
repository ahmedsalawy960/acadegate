/// Cues that apply to **any** scholarly file.
///
/// Never put a specific paper's authors, title words, cities, or topics here.
/// Matching is by bibliography shape: `[n]` / `n.` / `(Author, Year)`.
class CitationCues {
  CitationCues._();

  /// Campus / lab / corresponding-author lines, any country.
  static const affiliationOrg =
      r'University|Universit[eé]|Department|Faculty|Institute|College|'
      r'Laboratory|School|Hospital|Centre|Center|Corresponding|'
      r'Affiliation';

  static final affiliationNearby = RegExp(
    '($affiliationOrg|e-?mail|@)',
    caseSensitive: false,
  );

  /// `[1] Chemistry Department…` — subject word optional, org required nearby.
  static final affiliationAfterBracket = RegExp(
    r'^\s*.{0,48}(?:Department|Faculty|University|Institute|'
    r'College|Laboratory|School|Hospital|Centre|Center)',
    caseSensitive: false,
  );

  /// English sentence starters — not a bibliographic author.
  static const sentenceLead =
      r'The|This|These|Those|It |We |Our |In |For |Using |According|'
      r'However|Therefore|Moreover|Furthermore|Additionally|'
      r'Thus|Hence|Figure|Table|Many |It is';

  static final sentenceLeadLine = RegExp(
    '^($sentenceLead)\\b',
    caseSensitive: false,
  );

  /// Venue / imprint tokens found in bibliographies of every field.
  static const bibliographicVenue =
      r'doi\.org|DOI:|vol\.|pp\.|\bet al\.|J\.\s|Soc\.|Press|Wiley|'
      r'Springer|Elsevier|CRC|ed\.|University|Organization|'
      r'Chem\.|Sci\.|https?://|Official Method|Proceedings|Journal';

  /// Corporate / standards authors (not one paper's names).
  static const standardsOrg =
      r'AOAC|AOCS|WHO|ISO|FAO|USDA|ASTM|IUPAC|EPA|NIST|OECD|CODEX|'
      r'AACC|ICC';

  static final standardsOrgLead = RegExp(
    '^(?:\\[\\d{1,3}\\]\\s+|\\d{1,3}[.)]\\s+)?(?:$standardsOrg|Official)\\b',
    caseSensitive: false,
  );

  /// Function words and section names — never treat as a cited surname.
  static const notAuthorSurnames = {
    'abstract',
    'according',
    'additionally',
    'affiliation',
    'analysis',
    'april',
    'august',
    'based',
    'chapter',
    'conclusion',
    'data',
    'december',
    'department',
    'discussion',
    'equation',
    'faculty',
    'february',
    'figure',
    'furthermore',
    'however',
    'institute',
    'introduction',
    'january',
    'july',
    'june',
    'laboratory',
    'major',
    'march',
    'method',
    'methods',
    'minor',
    'moreover',
    'november',
    'october',
    'page',
    'results',
    'sample',
    'samples',
    'section',
    'september',
    'studies',
    'study',
    'table',
    'therefore',
    'thus',
    'total',
    'university',
    'using',
    'volume',
  };

  /// Journal running header / footer / copyright — not a bibliography row.
  static bool isRunningMatterLine(String line) {
    final t = line.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty || t.length > 220) return false;
    if (RegExp(
      r'©|ISSN\s*:|Open Access|Cite this:|Creative Commons|'
      r'All rights reserved',
      caseSensitive: false,
    ).hasMatch(t)) {
      return true;
    }
    if (RegExp(r'\|\s*\d{1,3}\s*$').hasMatch(t) &&
        RegExp(r'\b(?:19|20)\d{2}\b').hasMatch(t)) {
      return true;
    }
    return t.length < 64 &&
        RegExp(
          r"^[A-Za-z]{2,14}\s+[A-Z]\.\s+[\p{L}'\-]+"
          r"(?:\s+[\p{L}'\-]+)?\s+et\s+al\.?\s*$",
          unicode: true,
          caseSensitive: false,
        ).hasMatch(t);
  }

  /// PDF/Word wrap of "Author, A. & Author, B." then "(Year). Title…"
  static bool bibliographyLineContinues(String current, String line) {
    final t = line.trim();
    if (t.isEmpty || current.trim().isEmpty) return false;
    if (isRunningMatterLine(t)) return false;
    final cur = current.trim();
    if (RegExp(r'^\((?:19|20)\d{2}[a-z]?\)').hasMatch(t)) return true;
    if (RegExp(r'^(?:19|20)\d{2}[a-z]?\.').hasMatch(t)) return true;
    if (RegExp(r'^https?://|^doi\b', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    if (RegExp(r'^[&,]').hasMatch(t) ||
        RegExp(r'^and\s+', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    if (RegExp(r'[,&]\s*$').hasMatch(cur) ||
        RegExp(r'\b(?:and|&)\s*$', caseSensitive: false).hasMatch(cur)) {
      return true;
    }
    if (RegExp(r'^(?:[A-Z]\.\s*)+\(?\s*(?:19|20)\d{2}').hasMatch(t)) {
      return true;
    }
    if (RegExp(r'^[a-z]').hasMatch(t)) return true;
    if (!RegExp(r'\b(?:19|20)\d{2}\b').hasMatch(cur) &&
        looksLikeAuthorListFragment(cur)) {
      return true;
    }
    return false;
  }

  /// Author names only — the year wrapped onto the next line.
  static bool looksLikeAuthorListFragment(String raw) {
    final t = raw.trim();
    if (t.length < 8 || t.length > 400) return false;
    if (isRunningMatterLine(t)) return false;
    if (RegExp(r'\((?:19|20)\d{2}').hasMatch(t) &&
        RegExp(r'\.\s+\S').hasMatch(t)) {
      return false;
    }
    return RegExp(
          r"[\p{Lu}][\p{L}\p{M}'’.\-]*(?:\s+[\p{L}\p{M}'’.\-]+)*"
          r",\s*[\p{Lu}]",
          unicode: true,
        ).hasMatch(t) &&
        (t.contains('&') ||
            RegExp(r'\band\b', caseSensitive: false).hasMatch(t) ||
            t.contains(',') ||
            t.endsWith(','));
  }
}
