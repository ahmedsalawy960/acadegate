import 'package:flutter/material.dart';

import 'citation_formatter.dart';
import 'in_text_citation_converter.dart';
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
    final spans = <InlineSpan>[];
    final regex = RegExp(citeMarkerPattern);
    var last = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(
          text: text.substring(last, match.start),
          style: styleBase,
        ));
      }
      final refId = match.group(1) ?? '';
      final form = CitationFormatter.parseFormToken(match.group(2)) ??
          InTextCitationForm.auto;
      final ref = manuscript.referenceById(refId);
      final label = ref == null
          ? '[?]'
          : CitationFormatter.formatInText(
              reference: ref,
              style: style,
              index: manuscript.referenceIndex(refId),
              form: form,
            );
      spans.add(TextSpan(
        text: label,
        style: styleBase.copyWith(
          color: Colors.indigo.shade700,
          fontWeight: FontWeight.w600,
        ),
      ));
      last = match.end;
    }

    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: styleBase));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: styleBase));
    }
    return spans;
  }

  static String resolvePlainText({
    required String text,
    required PublishManuscript manuscript,
    required PublishCitationStyle style,
    bool applyNumberedInText = false,
  }) {
    var resolved = text.replaceAllMapped(RegExp(citeMarkerPattern), (match) {
      final refId = match.group(1) ?? '';
      final form = CitationFormatter.parseFormToken(match.group(2)) ??
          InTextCitationForm.auto;
      final ref = manuscript.referenceById(refId);
      if (ref == null) return '[?]';
      return CitationFormatter.formatInText(
        reference: ref,
        style: style,
        index: manuscript.referenceIndex(refId),
        form: form,
      );
    });

    if (applyNumberedInText && CitationFormatter.isNumberedStyle(style)) {
      resolved = InTextCitationConverter.applyNumberedCitations(
        text: resolved,
        references: manuscript.citedReferencesInOrder(),
        targetStyle: style,
      );
    }

    return resolved;
  }

  /// Bibliography refs: cited-first order when markers exist; else full list.
  static List<PublishReference> bibliographyReferences(
    PublishManuscript manuscript, {
    bool citedOnly = false,
  }) {
    if (citedOnly) {
      final cited = manuscript.onlyCitedReferences();
      if (cited.isNotEmpty) return cited;
    }
    return manuscript.citedReferencesInOrder();
  }
}
