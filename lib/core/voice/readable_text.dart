/// Cleans model output for on-screen reading and for TTS.
class ReadableText {
  ReadableText._();

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

  static String forDisplay(String raw) {
    var t = _stripLatex(raw);
    t = t.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
    t = t.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1) ?? '');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  static String forSpeech(String raw, {required bool arabic}) {
    var t = forDisplay(raw);
    t = t.replaceAll('\r\n', '\n');
    t = t.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ');
    t = t.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]*\)'),
      (m) => m.group(1) ?? '',
    );
    t = t.replaceAll(RegExp(r'[#*_~>]'), ' ');
    t = t.replaceAll(RegExp(r'^\s*[-•]\s+', multiLine: true), ' ');
    t = t.replaceAll('⚠️', ' ');
    if (arabic) {
      t = t.replaceAllMapped(
        RegExp(r'([A-Za-z])\s*²'),
        (m) => '${_letterNameAr(m.group(1)!)} تربيع',
      );
      t = t.replaceAll('²', ' تربيع ');
      t = t.replaceAll('³', ' تكعيب ');
      t = t.replaceAll('×', ' في ');
      t = t.replaceAll('±', ' زائد أو ناقص ');
      t = t.replaceAll('<', ' أقل من ');
      t = t.replaceAll('>', ' أكبر من ');
    } else {
      t = t.replaceAllMapped(
        RegExp(r'([A-Za-z])\s*²'),
        (m) => '${m.group(1)} squared',
      );
      t = t.replaceAll('²', ' squared ');
      t = t.replaceAll('³', ' cubed ');
    }
    t = t.replaceAll(RegExp(r'[$\\{}]'), ' ');
    t = t.replaceAll(RegExp(r'\n{2,}'), '. ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length > 1400) t = '${t.substring(0, 1400).trim()}…';
    return t;
  }

  static bool hasArabic(String text) =>
      RegExp(r'[\u0600-\u06FF]').hasMatch(text);

  static List<({String text, bool arabic})> speechSegments(String spoken) {
    if (spoken.isEmpty) return const [];
    final matches = RegExp(
      r'[\u0600-\u06FF][^A-Za-z]*|[\u0600-\u06FF]|[A-Za-z][A-Za-z0-9.\-]*',
    ).allMatches(spoken);
    if (matches.isEmpty) {
      return [(text: spoken, arabic: hasArabic(spoken))];
    }
    final out = <({String text, bool arabic})>[];
    for (final m in matches) {
      final piece = m.group(0)!.trim();
      if (piece.isEmpty) continue;
      final arabic = hasArabic(piece);
      if (out.isNotEmpty && out.last.arabic == arabic) {
        out[out.length - 1] = (
          text: '${out.last.text} $piece',
          arabic: arabic,
        );
      } else {
        out.add((text: piece, arabic: arabic));
      }
    }
    return out;
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

  static String _letterNameAr(String letter) {
    const names = {
      'R': 'آر',
      'r': 'آر',
      'P': 'بي',
      'p': 'بي',
      'N': 'إن',
      'n': 'إن',
    };
    return names[letter] ?? letter;
  }
}
