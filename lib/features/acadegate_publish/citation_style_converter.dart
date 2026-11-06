import 'bibliography_match.dart';
import 'citation_reading_advisor.dart';
import 'citation_formatter.dart';
import 'citation_linker.dart';
import 'in_text_citation_converter.dart';
import 'journal_format_rules.dart';
import 'manuscript_structure_advisor.dart';
import 'publish_models.dart';

/// Two conversions, nothing else:
///
/// * Author–year style: `[n]` → `(Author, Year)` of bibliography item n.
///   The imported list order stays as stored.
/// * Numbered style: every citation becomes `[n]` in the order it first
///   appears in the paper, and the reference list is rewritten to that order.
class CitationStyleConverter {
  CitationStyleConverter._();

  /// Numbered export: Gemini marks the citations the pattern missed, then
  /// [apply] numbers them in order of appearance.
  static Future<PublishManuscript> applyWithCitationReading({
    required PublishManuscript manuscript,
    required PublishCitationStyle style,
  }) async {
    final prepared = CitationFormatter.isNumberedStyle(style)
        ? await CitationReadingAdvisor.insertMarkers(manuscript)
        : manuscript;
    return apply(manuscript: prepared, style: style);
  }

  static PublishManuscript apply({
    required PublishManuscript manuscript,
    required PublishCitationStyle style,
  }) {
    if (CitationFormatter.isNumberedStyle(style)) {
      return _numberedByAppearance(manuscript, style);
    }
    final refs = CitationFormatter.orderForStyle(manuscript.references, style);

    String convert(String text) {
      if (text.trim().isEmpty) return text;
      return InTextCitationConverter.applyAuthorDateCitations(
        text: text,
        references: refs,
        targetStyle: style,
      );
    }

    return manuscript.copyWith(
      citationStyle: style,
      references: refs,
      abstractText: convert(manuscript.abstractText),
      body: convert(manuscript.body),
      bodyBlocks: [
        for (final block in manuscript.bodyBlocks)
          block.type == ManuscriptBlockType.paragraph &&
                  !CitationLinker.isEquationNumberLine(block.text) &&
                  ManuscriptStructureAdvisor.numberRoleFor(block.text) !=
                      'equation_number'
              ? block.copyWith(text: convert(block.text))
              : block,
      ],
    );
  }

  static List<PublishReference> bibliographyForStyle(
    PublishManuscript manuscript,
    PublishCitationStyle style,
  ) {
    if (CitationFormatter.isNumberedStyle(style) &&
        !_alreadyInCitationOrder(manuscript.references)) {
      return _numberedByAppearance(manuscript, style).references;
    }
    return CitationFormatter.orderForStyle(manuscript.references, style);
  }

  /// After a numbered export the list is already 1..n in citation order.
  /// Scanning it again would treat a leftover unmatched number as a new cite.
  static bool _alreadyInCitationOrder(List<PublishReference> refs) {
    for (var i = 0; i < refs.length; i++) {
      if (refs[i].importedNumber != i + 1) return false;
    }
    return true;
  }

  /// First citation in the paper is [1], even when that work was last in the
  /// imported list. Uncited works stay after the cited ones, still numbered.
  static PublishManuscript _numberedByAppearance(
    PublishManuscript manuscript,
    PublishCitationStyle style,
  ) {
    final match = BibliographyMatch(manuscript.references);
    final order = NumberedCitationOrder();
    final abstract = InTextCitationConverter.rewriteNumberedByAppearance(
      text: manuscript.abstractText,
      match: match,
      order: order,
    );

    var inReferences = false;
    final blocks = <ManuscriptBlock>[];
    for (final block in manuscript.bodyBlocks) {
      if (block.type == ManuscriptBlockType.heading &&
          JournalSectionLayout.isReferencesHeading(block.text)) {
        inReferences = true;
      }
      if (_skipCitationScan(block, inReferences)) {
        blocks.add(block);
        continue;
      }
      final rows = block.type == ManuscriptBlockType.table
          ? [
              for (final row in block.rows)
                [
                  for (final cell in row)
                    InTextCitationConverter.rewriteNumberedByAppearance(
                      text: cell,
                      match: match,
                      order: order,
                    ),
                ],
            ]
          : null;
      blocks.add(
        block.copyWith(
          text: block.type == ManuscriptBlockType.paragraph
              ? InTextCitationConverter.rewriteNumberedByAppearance(
                  text: block.text,
                  match: match,
                  order: order,
                )
              : block.text,
          caption: block.caption == null
              ? null
              : InTextCitationConverter.rewriteNumberedByAppearance(
                  text: block.caption!,
                  match: match,
                  order: order,
                ),
          rows: rows,
        ),
      );
    }

    final body = manuscript.bodyBlocks.isEmpty
        ? _rewriteLooseBody(manuscript.body, match, order)
        : manuscript.body;

    final byId = {for (final ref in manuscript.references) ref.id: ref};
    final cited = <PublishReference>[];
    for (final id in order.ids) {
      final ref = byId[id];
      if (ref == null) continue;
      cited.add(_withCitationNumber(ref, order.numberOf(id)!));
    }
    final seen = {for (final ref in cited) ref.id};
    final rest = <PublishReference>[];
    var next = cited.length;
    for (final ref in manuscript.references) {
      if (seen.contains(ref.id)) continue;
      next++;
      rest.add(_withCitationNumber(ref, next));
    }

    return manuscript.copyWith(
      citationStyle: style,
      references: [...cited, ...rest],
      abstractText: abstract,
      body: body,
      bodyBlocks: blocks,
    );
  }

  static bool _skipCitationScan(ManuscriptBlock block, bool inReferences) {
    if (inReferences) return true;
    if (block.type == ManuscriptBlockType.equation) return true;
    if (block.type == ManuscriptBlockType.heading) return true;
    final role = ManuscriptStructureAdvisor.numberRoleFor(block.text);
    if (role == 'equation_number' || role == 'float_number') return true;
    if (CitationLinker.isEquationNumberLine(block.text)) return true;
    if (CitationLinker.looksLikeBibliographyLine(block.text)) return true;
    return false;
  }

  static String _rewriteLooseBody(
    String body,
    BibliographyMatch match,
    NumberedCitationOrder order,
  ) {
    if (body.trim().isEmpty) return body;
    final lines = body.split('\n');
    final out = <String>[];
    var inReferences = false;
    for (final line in lines) {
      if (JournalSectionLayout.isReferencesHeading(line.trim())) {
        inReferences = true;
      }
      if (inReferences ||
          CitationLinker.isEquationNumberLine(line) ||
          CitationLinker.looksLikeBibliographyLine(line) ||
          ManuscriptStructureAdvisor.numberRoleFor(line) == 'equation_number' ||
          ManuscriptStructureAdvisor.numberRoleFor(line) == 'float_number') {
        out.add(line);
        continue;
      }
      out.add(InTextCitationConverter.rewriteNumberedByAppearance(
        text: line,
        match: match,
        order: order,
      ));
    }
    return out.join('\n');
  }

  static PublishReference _withCitationNumber(PublishReference ref, int n) {
    var raw = ref.rawText;
    if (RegExp(r'^\[\d+\]').hasMatch(raw.trimLeft())) {
      raw = raw.replaceFirst(RegExp(r'^\[\d+\]'), '[$n]');
    } else if (RegExp(r'^\d+[.)]\s').hasMatch(raw.trimLeft())) {
      raw = raw.replaceFirst(RegExp(r'^\d+'), '$n');
    }
    return ref.copyWith(importedNumber: n, rawText: raw);
  }
}
