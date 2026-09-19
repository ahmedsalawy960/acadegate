import 'academic_text.dart';
import 'publish_models.dart';

/// Canonical in-text and bibliography shapes the formatter recognizes
/// and rebuilds. Bold headings must never match these.
class CitationStyleShape {
  final PublishCitationStyle style;
  final String inTextExample;
  final String bibliographyExample;
  final String inTextDescriptionAr;
  final String inTextDescriptionEn;

  const CitationStyleShape({
    required this.style,
    required this.inTextExample,
    required this.bibliographyExample,
    required this.inTextDescriptionAr,
    required this.inTextDescriptionEn,
  });
}

class CitationStyleShapes {
  CitationStyleShapes._();

  static const apa = CitationStyleShape(
    style: PublishCitationStyle.apa,
    inTextExample: '(Author & Author, Year)',
    bibliographyExample:
        'Author, A., & Author, B. (Year). Article title. '
        'Journal Name, 12(3), 45–67.',
    inTextDescriptionAr: '(المؤلف، السنة) أو المؤلف (السنة)',
    inTextDescriptionEn: '(Author, Year) or Author (Year)',
  );

  static const ieee = CitationStyleShape(
    style: PublishCitationStyle.ieee,
    inTextExample: '[1]',
    bibliographyExample:
        '[1] A. Author and B. Author, "Article title," '
        'J. Abbrev., vol. 12, no. 3, pp. 45–67, Year.',
    inTextDescriptionAr: '[1] أو [1]–[3] داخل النص',
    inTextDescriptionEn: '[1] or [1]–[3] in the text',
  );

  static const vancouver = CitationStyleShape(
    style: PublishCitationStyle.vancouver,
    inTextExample: '[1]',
    bibliographyExample:
        '1. Author A, Author B. Article title. '
        'J Abbrev. Year;12(3):45–67.',
    inTextDescriptionAr: 'رقم بين أقواس مربعة في النص — 1. في القائمة',
    inTextDescriptionEn: 'Numbered [1] in text — 1. in the list',
  );

  static const harvard = CitationStyleShape(
    style: PublishCitationStyle.harvard,
    inTextExample: '(Author and Author, Year)',
    bibliographyExample:
        'Author, A. and Author, B. (Year) '
        "'Article title', Journal Name, "
        '12(3), pp. 45–67.',
    inTextDescriptionAr: '(المؤلف and المؤلف، السنة)',
    inTextDescriptionEn: '(Author and Author, Year)',
  );

  static const chicago = CitationStyleShape(
    style: PublishCitationStyle.chicago,
    inTextExample: '(Author and Author Year)',
    bibliographyExample:
        'Author, A., and B. Author. Year. '
        '"Article title." Journal Name 12, no. 3: 45–67.',
    inTextDescriptionAr: '(المؤلف والسنة) بدون فاصلة قبل السنة',
    inTextDescriptionEn: '(Author Year) without a comma before the year',
  );

  static const acs = CitationStyleShape(
    style: PublishCitationStyle.acs,
    inTextExample: '¹',
    bibliographyExample:
        'Author, A.; Author, B. Article Title. '
        'J. Abbrev. Year, 12, 45–67.',
    inTextDescriptionAr: 'رقم علوي ¹ في النص — Last, F.; Last, F. في القائمة',
    inTextDescriptionEn: 'Superscript ¹ in text — Last, F.; Last, F. in the list',
  );

  static const all = <CitationStyleShape>[
    apa,
    ieee,
    vancouver,
    harvard,
    chicago,
    acs,
  ];

  static CitationStyleShape of(PublishCitationStyle style) => switch (style) {
        PublishCitationStyle.apa => apa,
        PublishCitationStyle.ieee => ieee,
        PublishCitationStyle.vancouver => vancouver,
        PublishCitationStyle.harvard => harvard,
        PublishCitationStyle.chicago => chicago,
        PublishCitationStyle.acs => acs,
      };

  static final headingNames = <String>{
    'abstract',
    'introduction',
    'background',
    'experimental',
    'materials',
    'methods',
    'materials and methods',
    'results',
    'discussion',
    'results and discussion',
    'conclusion',
    'conclusions',
    'references',
    'bibliography',
    'acknowledgements',
    'acknowledgments',
    'keywords',
    'appendix',
    'supplementary',
    'supporting information',
    'table',
    'figure',
    'scheme',
    'الملخص',
    'المقدمة',
    'المواد والطرق',
    'النتائج',
    'المناقشة',
    'الخاتمة',
    'المراجع',
  };

  static bool looksLikeSectionHeading(String raw) {
    var t = raw.trim();
    if (t.isEmpty) return false;
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    t = t.replaceFirst(RegExp(r'^\d+(?:\.\d+)*[.)]\s+'), '');
    t = t.replaceFirst(RegExp(r':+$'), '').trim();
    if (t.isEmpty || t.length > 80) return false;
    final lower = t.toLowerCase();
    if (headingNames.contains(lower)) return true;
    if (RegExp(r'^(table|figure|scheme|fig\.)\s*\d+', caseSensitive: false)
        .hasMatch(t)) {
      return true;
    }
    if (!t.contains('.') &&
        t == t.toUpperCase() &&
        RegExp(r'[A-Z]').hasMatch(t) &&
        t.length < 48) {
      return true;
    }
    if (RegExp(
      r'\b(is|are|was|were|been|have|has|had|using|used|reached|'
      r'produces|produced|showed|shown|reported|prepared)\b',
      caseSensitive: false,
    ).hasMatch(t)) {
      return false;
    }
    final numberedRest = RegExp(r'^\d+[.)]\s+(.+)$').firstMatch(t)?.group(1);
    if (numberedRest != null &&
        (RegExp(r'\b(?:19|20)\d{2}\b').hasMatch(numberedRest) ||
            numberedRest.split(RegExp(r'\s+')).length > 12)) {
      return false;
    }
    if (RegExp(r'\b(?:19|20)\d{2}\b').hasMatch(t)) return false;
    if (t.split(RegExp(r'\s+')).length < 2) return false;
    if (RegExp(
      r'^[A-Z][A-Za-z\-]+(?:\s+and\s+|\s+&\s+)[A-Z][A-Za-z\-]+$',
    ).hasMatch(t)) {
      return false;
    }
    // Printed heading as in the file — not a fixed IMRaD label.
    // "Effect of pH", "Background", "Instruments", "Applications".
    if (t.length >= 3 &&
        t.length <= 90 &&
        !RegExp(r'@').hasMatch(t) &&
        !RegExp(
          r'^(the|this|these|those|in the|according|however)\b',
          caseSensitive: false,
        ).hasMatch(t) &&
        (RegExp(r'^\d+[.)]\s+\S').hasMatch(t) || !t.contains('.')) &&
        t.split(RegExp(r'\s+')).length <= 14 &&
        RegExp(r'^[A-Z0-9\u00C0-\u024F\u0600-\u06FF]').hasMatch(t)) {
      return true;
    }
    return false;
  }

  /// Bold body text that is an author name / author–year cite, not a heading.
  static bool looksLikeAuthorCitation(String raw) {
    final t = raw.trim();
    if (t.isEmpty || t.length > 280) return false;
    if (looksLikeSectionHeading(t)) return false;
    if (RegExp(
      r'\b(the|this|these|those|was|were|are|have|has|using|study|'
      r'results|however|therefore|according|prepared|analyzed|'
      r'samples?|method|shown|reported)\b',
      caseSensitive: false,
    ).hasMatch(t)) {
      return false;
    }

    if (numberedInText.hasMatch(t)) return true;
    if (superscriptInText.hasMatch(t)) return true;
    if (t.contains(';') &&
        RegExp(r'\b(?:19|20)\d{2}\b').allMatches(t).length >= 2) {
      return true;
    }
    if (parentheticalAuthorYear.hasMatch(t)) return true;
    if (narrativeAuthorYear.hasMatch(t)) return true;
    if (bareAuthorYear.hasMatch(t)) return true;
    if (authorNamesOnly.hasMatch(t)) return true;
    return false;
  }

  static final numberedInText = RegExp(
    r'^\[\d{1,3}(?:\s*[,;–-]\s*\d{1,3})*\]$',
  );

  static final superscriptInText = RegExp(
    r'^[\u00B9\u00B2\u00B3\u2070\u2074-\u2079]+$',
  );

  /// (Author, Year) / (Author & Author, Year)
  static final parentheticalAuthorYear = RegExp(
    r'^\('
    r'[A-Z][A-Za-z\-]+(?:\s+[A-Z][A-Za-z\-]+){0,2}'
    r'(?:,\s*(?:[A-Z]\.\s*)+)?'
    r'(?:\s+et\s+al\.?)?'
    r'(?:'
    r'(?:\s*,\s*[A-Z][A-Za-z\-]+(?:\s+[A-Z][A-Za-z\-]+){0,2}(?:,\s*(?:[A-Z]\.\s*)+)?){0,4}'
    r')?'
    r'(?:\s*,?\s*(?:&|and)\s+[A-Z][A-Za-z\-]+(?:\s+[A-Z][A-Za-z\-]+){0,2}'
    r'(?:,\s*(?:[A-Z]\.\s*)+)?'
    r')?'
    r',?\s*(?:19|20)\d{2}[a-z]?'
    r'\)$',
  );

  /// Author (Year) / Author and Author (Year)
  static final narrativeAuthorYear = RegExp(
    r'^[A-Z][A-Za-z\-]+(?:\s+[A-Z][A-Za-z\-]+){0,2}'
    r'(?:,\s*(?:[A-Z]\.\s*)+)?'
    r'(?:\s+et\s+al\.?)?'
    r'(?:\s+(?:and|&)\s+[A-Z][A-Za-z\-]+(?:\s+[A-Z][A-Za-z\-]+){0,2})?'
    r'\s+\((?:19|20)\d{2}[a-z]?\)$',
  );

  /// Author, Year / Author and Author, Year  (bold without parentheses)
  static final bareAuthorYear = RegExp(
    r'^[A-Z][A-Za-z\-]+(?:\s+[A-Z][A-Za-z\-]+){0,2}'
    r'(?:,\s*(?:[A-Z]\.\s*)+)?'
    r'(?:\s+et\s+al\.?)?'
    r'(?:\s+(?:and|&)\s+[A-Z][A-Za-z\-]+(?:\s+[A-Z][A-Za-z\-]+){0,2}'
    r'(?:,\s*(?:[A-Z]\.\s*)+)?'
    r')?'
    r',?\s+(?:19|20)\d{2}[a-z]?$',
  );

  /// Author / Author and Author / Author et al. / Author, A.
  static final authorNamesOnly = RegExp(
    r'^[A-Z][A-Za-z\-]+(?:\s+[A-Z][A-Za-z\-]+){0,2}'
    r'(?:,\s*(?:[A-Z]\.\s*)+)?'
    r'(?:\s+et\s+al\.?)?'
    r'(?:\s+(?:and|&)\s+[A-Z][A-Za-z\-]+(?:\s+[A-Z][A-Za-z\-]+){0,2}'
    r'(?:,\s*(?:[A-Z]\.\s*)+)?'
    r')?$',
  );

  static List<String> lastNamesFromCitation(String raw) {
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'^\(|\)$'), '');
    s = s.replaceAll(RegExp(r'\((?:19|20)\d{2}[a-z]?\)$'), '');
    s = s.replaceAll(RegExp(r',?\s*(?:19|20)\d{2}[a-z]?$'), '');
    s = s.replaceAll(RegExp(r'\s+et\s+al\.?', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s+&\s+'), ' and ');
    final parts = s.split(RegExp(r'\s+and\s+|,')).map((p) => p.trim());
    final names = <String>[];
    for (final part in parts) {
      if (part.isEmpty) continue;
      if (RegExp(r'^(?:[A-Z]\.)+$').hasMatch(part)) continue;
      if (RegExp(r'^[A-Z]{1,3}$').hasMatch(part.trim())) continue;
      if (RegExp(r'^[A-Z][a-z]+\s+[A-Z]{1,3}$').hasMatch(part)) continue;
      final token = part.contains(',')
          ? part.split(',').first.trim()
          : part.split(RegExp(r'\s+')).last.trim();
      if (RegExp(r'^[A-Z]{1,3}$').hasMatch(token)) continue;
      final last = AcademicText.nameKey(token);
      if (last.length >= 2 && !headingNames.contains(last)) names.add(last);
    }
    return names.take(4).toList();
  }

  static String? yearFromCitation(String raw) {
    return RegExp(r'\b((?:19|20)\d{2})[a-z]?\b')
        .firstMatch(raw)
        ?.group(1);
  }
}
