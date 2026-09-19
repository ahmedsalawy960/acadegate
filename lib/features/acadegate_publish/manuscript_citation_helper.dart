import 'package:flutter/material.dart';

import 'citation_formatter.dart';
import 'citation_style_converter.dart';
import 'in_text_citation_converter.dart';
import 'academic_text.dart';
import 'publish_models.dart';

class ManuscriptCitationHelper {
  ManuscriptCitationHelper._();

  static String citationMarker(
    String refId, {
    InTextCitationForm form = InTextCitationForm.auto,
  }) {
    if (form == InTextCitationForm.auto) {
      return '{{cite:$refId}}';
    }
    return '{{cite:$refId|${CitationFormatter.formToken(form)}}}';
  }

  static String insertCitationAt(String text, int cursor, String marker) {
    if (cursor < 0) cursor = 0;
    if (cursor > text.length) cursor = text.length;
    return text.substring(0, cursor) + marker + text.substring(cursor);
  }

  static List<InlineSpan> buildInlineSpans({
    required String text,
    required PublishManuscript manuscript,
    required PublishCitationStyle style,
    TextStyle? baseStyle,
  }) {
    final styleBase = baseStyle ?? const TextStyle(height: 1.5);
    final prepared = resolvePlainText(
      text: text,
      manuscript: manuscript,
      style: style,
      applyNumberedInText: CitationFormatter.isNumberedStyle(style),
    );
    return _spansWithBoldBracketCites(prepared, styleBase);
  }

  static String resolvePlainText({
    required String text,
    required PublishManuscript manuscript,
    required PublishCitationStyle style,
    bool applyNumberedInText = false,
  }) {
    var source = _resolveCiteMarkers(
      AcademicText.westernDigits(text),
      manuscript,
      style,
    );
    final numbered = CitationFormatter.isNumberedStyle(style) ||
        applyNumberedInText;
    if (numbered) {
      return AcademicText.sanitize(
        InTextCitationConverter.applyNumberedCitations(
          text: source,
          references: manuscript.references,
          targetStyle: style,
        ),
      );
    }
    return AcademicText.sanitize(
      InTextCitationConverter.applyAuthorDateCitations(
        text: source,
        references: manuscript.references,
        targetStyle: style,
      ),
    );
  }

  /// Editor inserts `{{cite:id}}`. Turn that into `[n]` or `(Author, Year)`
  /// of the same stored reference — never a guessed other work.
  static String _resolveCiteMarkers(
    String text,
    PublishManuscript manuscript,
    PublishCitationStyle style,
  ) {
    if (!text.contains('{{cite:')) return text;
    final numbered = CitationFormatter.isNumberedStyle(style);
    return text.replaceAllMapped(RegExp(citeMarkerPattern), (m) {
      final id = m.group(1) ?? '';
      final ref = manuscript.referenceById(id);
      final n = manuscript.referenceIndex(id);
      if (ref == null || n < 1) return m.group(0)!;
      if (numbered) return '[$n]';
      final formatted = CitationFormatter.formatInText(
        reference: ref,
        style: style,
        index: n,
        form: InTextCitationForm.parenthetical,
      );
      return formatted.trim().isEmpty ? '[$n]' : formatted;
    });
  }

  static List<PublishReference> bibliographyReferences(
    PublishManuscript manuscript, {
    bool citedOnly = false,
    PublishCitationStyle? style,
  }) {
    final target = style ?? manuscript.effectiveStyle;
    final ordered = CitationStyleConverter.bibliographyForStyle(
      manuscript,
      target,
    );
    if (!citedOnly) return ordered;
    final cited = {for (final r in manuscript.onlyCitedReferences()) r.id};
    if (cited.isEmpty) return ordered;
    return [for (final r in ordered) if (cited.contains(r.id)) r];
  }

  static final _bracketCite = RegExp(r'\[\d{1,3}(?:,\d{1,3})*\]');

  /// Uploaded Word files bold `[n]`. Keep that in the preview.
  static List<InlineSpan> _spansWithBoldBracketCites(String text, TextStyle base) {
    final matches = _bracketCite.allMatches(text).toList();
    if (matches.isEmpty) return [TextSpan(text: text, style: base)];
    final out = <InlineSpan>[];
    var i = 0;
    for (final m in matches) {
      if (m.start > i) {
        out.add(TextSpan(text: text.substring(i, m.start), style: base));
      }
      out.add(
        TextSpan(
          text: m.group(0),
          style: base.copyWith(fontWeight: FontWeight.bold),
        ),
      );
      i = m.end;
    }
    if (i < text.length) {
      out.add(TextSpan(text: text.substring(i), style: base));
    }
    return out;
  }
}
