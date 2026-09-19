/// Strips Markdown / LaTeX leftovers from thesis prose while keeping paragraphs.
class ThesisStudioProse {
  ThesisStudioProse._();

  static final _super = {
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

  static String sanitize(String raw) {
    var t = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    t = _stripLatex(t);
    t = t.replaceAll(RegExp(r'```[\s\S]*?```'), '\n');
    t = t.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1) ?? '');
    t = t.replaceAllMapped(
      RegExp(r'^#{1,6}(?=\s|[A-Za-z\u0600-\u06FF])', multiLine: true),
      (_) => '',
    );
    t = t.replaceAllMapped(RegExp(r'\*\*\*([^*]+)\*\*\*'), (m) => m.group(1)!);
    t = t.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m.group(1)!);
    t = t.replaceAllMapped(
      RegExp(r'(?<!\*)\*([^*\n]{1,200})\*(?!\*)'),
      (m) => m.group(1)!,
    );
    t = t.replaceAllMapped(RegExp(r'__([^_]+)__'), (m) => m.group(1)!);
    t = t.replaceAllMapped(
      RegExp(r'(?<![A-Za-z0-9])_([^_\n]{1,200})_(?![A-Za-z0-9])'),
      (m) => m.group(1)!,
    );
    t = t.replaceAll(RegExp(r'^\s*[*•]\s+', multiLine: true), '');
    t = t.replaceAll(RegExp(r'(^|\s)[*#]{2,}(\s|$)'), ' ');
    t = t.replaceAll(RegExp(r'(^|\s)\*(?=\s|$)'), ' ');
    t = t.replaceAll(RegExp(r'[^\S\n]+'), ' ');
    t = t.replaceAll(RegExp(r' *\n *'), '\n');
    t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return t.trim();
  }

  static bool isFallbackPartHeading(String heading) {
    return RegExp(
      r'\s-\s*(?:part\s+)?\d+\s*$',
      caseSensitive: false,
    ).hasMatch(heading.trim());
  }

  static String _stripLatex(String raw) {
    var t = raw;
    t = t.replaceAllMapped(
      RegExp(r'\$\$([\s\S]+?)\$\$'),
      (m) => _latexInnerToPlain(m.group(1)!),
    );
    t = t.replaceAllMapped(
      RegExp(r'(?<!\$)\$([^$\n]+)\$(?!\$)'),
      (m) => _latexInnerToPlain(m.group(1)!),
    );
    t = t.replaceAllMapped(
      RegExp(r'\\\((.+?)\\\)'),
      (m) => _latexInnerToPlain(m.group(1)!),
    );
    t = t.replaceAllMapped(
      RegExp(r'\\\[(.+?)\\\]'),
      (m) => _latexInnerToPlain(m.group(1)!),
    );
    t = t.replaceAllMapped(
      RegExp(r'\\[a-zA-Z]+\{([^{}]*)\}'),
      (m) => m.group(1) ?? '',
    );
    t = t.replaceAll(RegExp(r'\\[a-zA-Z]+'), ' ');
    t = t.replaceAll(r'$$', ' ');
    t = t.replaceAll(r'$', ' ');
    return t;
  }

  static String _latexInnerToPlain(String inner) {
    var t = inner.trim();
    t = t.replaceAllMapped(
      RegExp(r'([A-Za-z\\]+)\s*\^\s*\{?(\d+)\}?'),
      (m) {
        final base = m.group(1)!.replaceAll('\\', '');
        final exp = (m.group(2) ?? '')
            .split('')
            .map((c) => _super[c] ?? c)
            .join();
        return '$base$exp';
      },
    );
    t = t.replaceAll(r'\times', '×');
    t = t.replaceAll(r'\pm', '±');
    t = t.replaceAll(r'\leq', '≤');
    t = t.replaceAll(r'\geq', '≥');
    t = t.replaceAll('\\', '');
    t = t.replaceAll(RegExp(r'[{}]'), '');
    return t;
  }
}
