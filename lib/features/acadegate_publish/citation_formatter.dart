import 'package:flutter/material.dart';

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

    final buffer = StringBuffer();
    for (var i = 0; i < references.length; i++) {
      buffer.writeln(buildBibliographyEntry(
        reference: references[i],
        style: style,
        index: i + 1,
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
    return [
      for (var i = 0; i < references.length; i++)
        buildBibliographyEntry(
          reference: references[i],
          style: style,
          index: i + 1,
          plainNumberList: plainNumberList,
        ),
    ];
  }

  static BibliographyEntry buildBibliographyEntry({
    required PublishReference reference,
    required PublishCitationStyle style,
    required int index,
    bool plainNumberList = false,
  }) {
    if (reference.rawText.trim().isNotEmpty) {
      return _rawBibliographyEntry(
        reference.rawText.trim(),
        style: style,
        index: index,
        plainNumberList: plainNumberList,
      );
    }

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
    final numbered = isNumberedStyle(style);
    if (!numbered) {
      if (RegExp(r'^\[\d+\]').hasMatch(raw)) {
        return BibliographyEntry([BibliographySpan(_cleanRawCitation(raw))]);
      }
      return BibliographyEntry([BibliographySpan(raw)]);
    }

    if (RegExp(r'^\d+\.\s').hasMatch(raw)) {
      return BibliographyEntry([BibliographySpan(raw)]);
    }
    if (RegExp(r'^\[\d+\]').hasMatch(raw)) {
      return BibliographyEntry([
        BibliographySpan(
          plainNumberList ? '$index. ${_stripLeadingNumber(raw)}' : raw,
        ),
      ]);
    }
    return BibliographyEntry([
      BibliographySpan(_listPrefix(index, plainNumberList)),
      BibliographySpan(_cleanRawCitation(raw)),
    ]);
  }

  static String _formatParentheticalInText(
    PublishReference ref,
    PublishCitationStyle style,
  ) {
    final year = ref.year.trim().isNotEmpty ? ref.year.trim() : 'n.d.';
    final authors = ref.authors.where((a) => a.trim().isNotEmpty).toList();
    if (authors.isEmpty) return '($year)';
    if (authors.length == 1) {
      return '(${_authorLastName(authors.first)}, $year)';
    }
    if (authors.length == 2) {
      final sep = style == PublishCitationStyle.harvard ? ' and ' : ' & ';
      return '(${_authorLastName(authors[0])}$sep${_authorLastName(authors[1])}, $year)';
    }
    return '(${_authorLastName(authors.first)} et al., $year)';
  }

  static String _formatNarrativeInText(
    PublishReference ref,
    PublishCitationStyle style,
  ) {
    final year = ref.year.trim().isNotEmpty ? ref.year.trim() : 'n.d.';
    final authors = ref.authors.where((a) => a.trim().isNotEmpty).toList();
    if (authors.isEmpty) return '($year)';
    if (authors.length == 1) {
      return '${_authorLastName(authors.first)} ($year)';
    }
    if (authors.length == 2) {
      final sep = style == PublishCitationStyle.harvard ? ' and ' : ' and ';
      return '${_authorLastName(authors[0])}$sep${_authorLastName(authors[1])} ($year)';
    }
    return '${_authorLastName(authors.first)} et al. ($year)';
  }

  static String _authorLastName(String author) {
    final trimmed = author.trim();
    if (trimmed.isEmpty) return '—';
    if (trimmed.contains(',')) {
      return trimmed.split(',').first.trim();
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.last : trimmed;
  }

  static String _cleanRawCitation(String raw) {
    return raw
        .replaceAll(RegExp(r'^\[\d+\]\s*'), '')
        .replaceAll(RegExp(r'^\d+[.)]\s+'), '')
        .trim();
  }

  static String _stripLeadingNumber(String raw) => _cleanRawCitation(raw);

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
          spans.addAll([
            BibliographySpan('"$title," '),
            if (ref.container.isNotEmpty)
              BibliographySpan(ref.container.trim(), italic: true),
            if (ref.volume.isNotEmpty) BibliographySpan(', vol. ${ref.volume.trim()}'),
            if (ref.issue.isNotEmpty) BibliographySpan(', no. ${ref.issue.trim()}'),
            if (ref.pages.isNotEmpty) BibliographySpan(', pp. ${ref.pages.trim()}'),
            if (year.isNotEmpty) BibliographySpan(', $year'),
            BibliographySpan('.'),
            if (ref.doi.isNotEmpty) BibliographySpan(' doi: ${ref.doi.trim()}.'),
          ]);
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
    final trimmed = author.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.contains(',')) {
      final parts = trimmed.split(',').map((s) => s.trim()).toList();
      if (parts.length >= 2) {
        final last = parts[0];
        final initials = parts[1]
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .map((w) => '${w[0].toUpperCase()}.')
            .join(' ');
        return initials.isEmpty ? last : '$initials $last';
      }
    }
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      final last = words.last;
      final initials = words
          .sublist(0, words.length - 1)
          .map((w) => '${w[0].toUpperCase()}.')
          .join(' ');
      return '$initials $last';
    }
    return trimmed;
  }

  static String _formatAuthorApa(String author) {
    final trimmed = author.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.contains(',')) {
      final parts = trimmed.split(',').map((s) => s.trim()).toList();
      if (parts.length >= 2) {
        final last = parts[0];
        final initials = parts[1]
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .map((w) => '${w[0].toUpperCase()}.')
            .join(' ');
        return initials.isEmpty ? last : '$last, $initials';
      }
    }
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      final last = words.last;
      final initials = words
          .sublist(0, words.length - 1)
          .map((w) => '${w[0].toUpperCase()}.')
          .join(' ');
      return '$last, $initials';
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
