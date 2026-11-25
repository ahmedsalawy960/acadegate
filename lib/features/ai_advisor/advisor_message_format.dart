import 'package:flutter/widgets.dart';

import 'advisor_branding.dart';

/// Prepares an assistant/user message body for the plain-text chat bubble.
///
/// The bubble renders a [Text] widget, not a markdown widget, so markers
/// that survive to the screen read as literal characters (a reply heading
/// showed as "### ...", a rule as "---", emphasis as *stars*). Strip or
/// simplify the markers the model emits: headings, **bold**, *italic*,
/// `code`, ``` fences, horizontal rules, pipe-table syntax, $...$ math
/// delimiters, and "* " bullets. Paired markers only, so legitimate uses
/// (2*3, #5, $50) survive. Pure functions, unit-tested in
/// test/advisor_message_rendering_test.dart.
String formatAdvisorMessageContent(String content) {
  var text = content
      .replaceAll(AdvisorBranding.planMarker, '')
      .replaceAll('```', '');

  final out = <String>[];
  for (final rawLine in text.split('\n')) {
    final line = rawLine;
    final trimmed = line.trim();

    // Horizontal rule: a line of only -, *, or _ (3+).
    if (RegExp(r'^[-*_]\s*([-*_]\s*){2,}$').hasMatch(trimmed)) continue;

    // Pipe-table separator row: cells of only - and : (e.g. | --- | ---: |).
    if (_isTableSeparator(trimmed)) continue;

    var processed = line;

    // Pipe-table row: strip the outer pipes, keep the cells readable.
    if (_isTableRow(trimmed)) {
      processed = trimmed
          .substring(1, trimmed.length - 1)
          .split('|')
          .map((cell) => cell.trim())
          .join(' — ');
    }

    // Heading hashes at line start.
    processed = processed.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), '');

    // "* " bullet at line start becomes a real bullet.
    processed = processed.replaceFirst(RegExp(r'^(\s*)\*\s+'), '\$1• ');

    // Inline paired markers: **bold**, *italic*, `code`; then drop any
    // leftover lone backticks (backtick has no plain-text prose use).
    processed = processed
        .replaceAllMapped(RegExp(r'\*\*([^*\n]+)\*\*'), (m) => '${m[1]}')
        .replaceAllMapped(RegExp(r'\*([^*\n]+)\*'), (m) => '${m[1]}')
        .replaceAllMapped(RegExp(r'`([^`\n]+)`'), (m) => '${m[1]}')
        .replaceAll('`', '');

    // $...$ math delimiters, only when the content is clearly math: a
    // math operator/symbol, or a single short symbol like $WP$ or $x_i$.
    // Currency pairs like "$50 ... $60" keep their dollars.
    processed = processed.replaceAllMapped(
      RegExp(r'\$([^$\n]+)\$'),
      (m) => _looksLikeMath(m[1]!) ? m[1]! : m[0]!,
    );

    out.add(processed);
  }
  return out.join('\n');
}

bool _isTableSeparator(String trimmedLine) {
  if (!trimmedLine.startsWith('|') || !trimmedLine.endsWith('|')) {
    return false;
  }
  final cells = trimmedLine.substring(1, trimmedLine.length - 1).split('|');
  if (cells.isEmpty) return false;
  return cells.every((cell) => RegExp(r'^\s*:?-+:?\s*$').hasMatch(cell));
}

bool _isTableRow(String trimmedLine) {
  return trimmedLine.length > 2 &&
      trimmedLine.startsWith('|') &&
      trimmedLine.endsWith('|');
}

bool _looksLikeMath(String inner) {
  if (RegExp(r'[<>=_^{}\\]').hasMatch(inner)) return true;
  // Single short symbol such as WP, p, x1.
  return RegExp(r'^[A-Za-z][A-Za-z0-9]{0,15}$').hasMatch(inner.trim());
}

/// Picks the paragraph direction for a chat message from its dominant
/// script. The app shell is RTL, so without this an English reply renders
/// with flipped punctuation and reversed list numbers.
TextDirection advisorTextDirectionFor(String text) {
  var arabic = 0;
  var latin = 0;
  for (final unit in text.runes) {
    if ((unit >= 0x0600 && unit <= 0x06FF) ||
        (unit >= 0xFB50 && unit <= 0xFEFF)) {
      arabic++;
    } else if ((unit >= 0x41 && unit <= 0x5A) ||
        (unit >= 0x61 && unit <= 0x7A)) {
      latin++;
    }
  }
  return latin > arabic ? TextDirection.ltr : TextDirection.rtl;
}
