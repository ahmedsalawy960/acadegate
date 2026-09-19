import 'citation_formatter.dart';
import 'in_text_citation_converter.dart';
import 'publish_models.dart';

/// Two conversions, nothing else:
///
/// * Author–year style: `[n]` → `(Author, Year)` of bibliography item n.
/// * Numbered style: `(Author, Year)` → `[n]` of that same bibliography row.
///
/// The imported list order is never shuffled.
class CitationStyleConverter {
  CitationStyleConverter._();

  static PublishManuscript apply({
    required PublishManuscript manuscript,
    required PublishCitationStyle style,
  }) {
    final refs = CitationFormatter.orderForStyle(manuscript.references, style);

    String convert(String text) {
      if (text.trim().isEmpty) return text;
      if (CitationFormatter.isNumberedStyle(style)) {
        return InTextCitationConverter.applyNumberedCitations(
          text: text,
          references: refs,
          targetStyle: style,
        );
      }
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
          block.type == ManuscriptBlockType.paragraph
              ? block.copyWith(text: convert(block.text))
              : block,
      ],
    );
  }

  static List<PublishReference> bibliographyForStyle(
    PublishManuscript manuscript,
    PublishCitationStyle style,
  ) {
    return CitationFormatter.orderForStyle(manuscript.references, style);
  }
}
