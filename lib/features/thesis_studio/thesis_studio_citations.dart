import '../acadegate_publish/citation_formatter.dart';
import '../acadegate_publish/in_text_citation_converter.dart';
import '../acadegate_publish/publish_models.dart';
import '../ai_advisor/grounded_work.dart';
import 'thesis_studio_models.dart';
import 'thesis_studio_prose.dart';

class ThesisStudioCitations {
  ThesisStudioCitations._();

  static PublishReference toReference(GroundedWork work, int index) {
    return PublishReference(
      id: 'doi-$index',
      type: ReferenceType.journal,
      authors: _authors(work.authors),
      title: work.title,
      container: work.journal ?? '',
      year: work.year?.toString() ?? '',
      doi: work.doi,
      url: work.primaryUrl.isNotEmpty ? work.primaryUrl : work.doiUrl,
      importedNumber: index,
      rawText: work.apaLine,
    );
  }

  static String bibliographyLine(
    GroundedWork work, {
    required int index,
    required PublishCitationStyle style,
  }) {
    final entry = CitationFormatter.buildBibliographyEntry(
      reference: toReference(work, index),
      style: style,
      index: index,
      plainNumberList: CitationFormatter.isNumberedStyle(style),
    );
    return entry.plain;
  }

  static String bibliography(
    List<GroundedWork> works, {
    required PublishCitationStyle style,
  }) {
    if (works.isEmpty) return '';
    final refs = [
      for (var i = 0; i < works.length; i++) toReference(works[i], i + 1),
    ];
    return CitationFormatter.formatBibliography(references: refs, style: style);
  }

  /// Model writes verified `[n]`. Author–year styles (APA/Harvard/Chicago)
  /// are rendered for the reader; IEEE/Vancouver/ACS stay numbered.
  static String styledProse(
    String text,
    ThesisDraft draft, {
    List<GroundedWork>? works,
  }) {
    final list = (works != null && works.isNotEmpty)
        ? works
        : (draft.literature.works.isNotEmpty
            ? draft.literature.works
            : _fallbackWorks(draft));
    final cleaned = ThesisStudioProse.sanitize(text);
    if (cleaned.trim().isEmpty || list.isEmpty) return cleaned;
    final refs = [
      for (var i = 0; i < list.length; i++) toReference(list[i], i + 1),
    ];
    return InTextCitationConverter.applyAuthorDateCitations(
      text: _expandNumericRanges(cleaned),
      references: refs,
      targetStyle: draft.plan.citationStyle,
    );
  }

  static List<GroundedWork> _fallbackWorks(ThesisDraft draft) {
    final byDoi = <String, GroundedWork>{};
    for (final w in draft.abstractReferences) {
      final key = w.doi.trim().toLowerCase();
      if (key.isEmpty) continue;
      byDoi.putIfAbsent(key, () => w);
    }
    for (final ch in draft.chapters) {
      for (final p in ch.paragraphs) {
        for (final w in p.references) {
          final key = w.doi.trim().toLowerCase();
          if (key.isEmpty) continue;
          byDoi.putIfAbsent(key, () => w);
        }
      }
    }
    return byDoi.values.toList();
  }

  static String _expandNumericRanges(String text) {
    return text.replaceAllMapped(
      RegExp(r'\[(\d{1,3})\s*[–-]\s*(\d{1,3})\]'),
      (m) {
        final a = int.tryParse(m.group(1) ?? '');
        final b = int.tryParse(m.group(2) ?? '');
        if (a == null || b == null || b < a || b - a > 30) return m.group(0)!;
        return '[${[for (var i = a; i <= b; i++) i].join(', ')}]';
      },
    );
  }

  static List<String> _authors(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const [];
    return text
        .split(RegExp(r'\s*;\s*|\s+and\s+|\s+و\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
