import 'academic_text.dart';
import 'citation_cues.dart';

/// Reading order used by journals, Google Scholar PDFs, and major presses
/// (Elsevier, Springer, Wiley, ACS, RSC, IEEE, Nature, Taylor & Francis,
/// Hindawi, MDPI):
///
/// Title → authors with affiliation marks → affiliations → corresponding
/// author → Abstract → Keywords → IMRaD → References.
///
/// Figures, tables, and schemes never sit on the title page. Word often
/// serializes floating drawings first in document.xml; that is a file-order
/// artifact, not the article layout.
///
/// Affiliation marks are superscripts / `[1]` next to author names — not
/// bibliography citations.
///
/// Never encode a specific paper's authors, cities, or topics here.
class ScholarlyLayout {
  ScholarlyLayout._();

  /// Strip bidi marks and a stray leading period (RTL UI / Word).
  static String classificationLead(String text) {
    var t = AcademicText.stripBidi(text).trim();
    t = t.replaceFirst(RegExp(r'^[\.,;:،؛]+'), '');
    return t.trim();
  }

  /// Fig. / Figure / Table / Scheme / Chart / Plate — any publisher, any field.
  static final floatCaptionLead = RegExp(
    r'^(?:Fig(?:ure)?|Scheme|Chart|Plate|Table|شكل|جدول|مخطط)\.?\s*[\d٠-٩]+',
    caseSensitive: false,
  );

  static bool isFloatCaption(String text) {
    final t = classificationLead(text);
    if (t.isEmpty) return false;
    return floatCaptionLead.hasMatch(t);
  }

  static bool isTableCaption(String text) {
    final t = classificationLead(text);
    return RegExp(
      r'^(?:Table|جدول)\.?\s*[\d٠-٩]+',
      caseSensitive: false,
    ).hasMatch(t);
  }

  static bool isFigureCaption(String text) {
    return isFloatCaption(text) && !isTableCaption(text);
  }

  static bool isAuthorByline(String text) {
    final t = classificationLead(text);
    if (t.isEmpty || t.length > 500) return false;
    if (isFloatCaption(t)) return false;
    if (RegExp(
      r'^(Abstract|Introduction|Keywords|References|Results|Discussion|'
      r'الملخص|المقدمة|المراجع)\b',
      caseSensitive: false,
    ).hasMatch(t)) {
      return false;
    }
    // Body sentences and bibliography lines carry a publication year.
    // Title-page bylines never do.
    if (RegExp(r'\b(?:19|20)\d{2}\b').hasMatch(t) &&
        !RegExp(r'corresponding author', caseSensitive: false).hasMatch(t)) {
      return false;
    }
    if (RegExp(
      r'^(The|This|These|Those|According|However|Therefore|Moreover|'
      r'Furthermore|In |For |Using )\b',
      caseSensitive: false,
    ).hasMatch(t)) {
      return false;
    }
    if (RegExp(r'@|corresponding author', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    final hasAnd = RegExp(r'\band\b', caseSensitive: false).hasMatch(t);
    final hasCommaNames = RegExp(
      r'[A-Z][A-Za-z\-]+(?:\s+[A-Z][A-Za-z\-]+)+(?:\s*[,*†‡]+)',
    ).hasMatch(t);
    final hasSuper = RegExp(
      r'[\u00B9\u00B2\u00B3\u2070-\u2079]',
    ).hasMatch(t);
    final hasAffilDigit = RegExp(
      r'[A-Za-z][\u00B9\u00B2\u00B3\u2070-\u2079\*]*\s*,|'
      r'[A-Za-z]\d{1,2}[\*,]?\s*(?:,|and\b)',
    ).hasMatch(t);
    if ((hasAnd || hasCommaNames) && (hasSuper || hasAffilDigit)) {
      return true;
    }
    if (hasSuper &&
        hasAnd &&
        t.length < 280 &&
        !RegExp(r'\b(the|this|were|using)\b', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    return false;
  }

  static bool isAffiliationLine(String text) {
    final t = classificationLead(text);
    if (t.isEmpty) return false;
    if (RegExp(r'\b(?:19|20)\d{2}\b').hasMatch(t) &&
        !RegExp(r'corresponding author', caseSensitive: false).hasMatch(t)) {
      return false;
    }
    if (CitationCues.affiliationNearby.hasMatch(t) && t.length < 800) {
      if (RegExp(
        r'^(?:\d{1,2}|[\u00B9\u00B2\u00B3\u2070-\u2079]+)\s*',
      ).hasMatch(t)) {
        return true;
      }
      if (RegExp(
        r'corresponding author|e-?mail|@',
        caseSensitive: false,
      ).hasMatch(t)) {
        return true;
      }
      if (RegExp(
        r'^(?:Department|Faculty|University|Institute|College|Laboratory)\b',
        caseSensitive: false,
      ).hasMatch(t)) {
        return true;
      }
    }
    return false;
  }

  static bool isFrontMatterLine(String text) =>
      isAuthorByline(text) || isAffiliationLine(text);

  /// Article title — not a caption, byline, or affiliation.
  static bool isArticleTitle(String text) {
    final t = classificationLead(text);
    if (t.length < 25 || t.length > 320) return false;
    if (isFloatCaption(t)) return false;
    if (isAuthorByline(t) || isAffiliationLine(t)) return false;
    if (RegExp(
      r'@|corresponding author|University|Department|Faculty',
      caseSensitive: false,
    ).hasMatch(t)) {
      return false;
    }
    if (RegExp(
      r'^(Abstract|Introduction|Keywords|References|Results|Discussion|'
      r'الملخص|المقدمة|المراجع)\b',
      caseSensitive: false,
    ).hasMatch(t)) {
      return false;
    }
    if (RegExp(
      r'\b(Analysis|Profile|Study|Characterization|Composition|'
      r'Investigation|Review)\b',
      caseSensitive: false,
    ).hasMatch(t)) {
      return true;
    }
    final words = t.split(RegExp(r'\s+'));
    if (words.length >= 7 &&
        RegExp(r'^[A-Z]').hasMatch(t) &&
        !RegExp(r'=\s*[\.\d]').hasMatch(t.substring(0, t.length.clamp(0, 40)))) {
      return true;
    }
    return false;
  }
}
