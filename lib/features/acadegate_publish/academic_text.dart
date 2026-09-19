/// Western digits and bibliographic text cleanup for English scientific export.
class AcademicText {
  AcademicText._();

  static const _eastern = '٠١٢٣٤٥٦٧٨٩';
  static const _persian = '۰۱۲۳۴۵۶۷۸۹';
  static const _western = '0123456789';

  /// Drop RTL/LTR marks that Word and Arabic UI inject around English.
  static String stripBidi(String input) {
    return input.replaceAll(
      RegExp(r'[\u200e\u200f\u202a-\u202e\u2066-\u2069]'),
      '',
    );
  }

  static String westernDigits(String input) {
    var t = input;
    for (var i = 0; i < 10; i++) {
      t = t.replaceAll(_eastern[i], _western[i]);
      t = t.replaceAll(_persian[i], _western[i]);
    }
    return t;
  }

  /// DOI `10,1021` (Arabic decimal comma) → `10.1021`.
  static String fixDoiCommas(String input) {
    return input.replaceAllMapped(
      RegExp(
        r'((?:doi[:\s]*|https?://doi\.org/|10\.\d{3,}))([^\s]*)',
        caseSensitive: false,
      ),
      (m) {
        final prefix = m.group(1)!;
        final rest = (m.group(2) ?? '').replaceAll(',', '.');
        return '$prefix$rest';
      },
    );
  }

  static String sanitize(String input) {
    if (input.isEmpty) return input;
    return fixDoiCommas(westernDigits(stripBidi(input)));
  }

  /// Accents and punctuation do not affect author matching.
  static String foldLatin(String input) {
    const map = {
      'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
      'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
      'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
      'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
      'ý': 'y', 'ÿ': 'y', 'ñ': 'n', 'ç': 'c', 'ø': 'o',
    };
    final buffer = StringBuffer();
    for (final unit in westernDigits(input).toLowerCase().split('')) {
      buffer.write(map[unit] ?? unit);
    }
    return buffer.toString();
  }

  static String nameKey(String input) =>
      foldLatin(input)
          .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
          .replaceAll(RegExp(r'[^a-z]'), '');

  /// Drop a trailing person name glued onto a paper title.
  static String stripTrailingAuthorFromTitle(String title) {
    var t = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    t = t.replaceFirst(
      RegExp(
        r'\s+[A-Z][a-z]{2,}\s+[A-Z][a-z]{2,}(?:\s+\d+\*?)?$',
      ),
      '',
    );
    t = t.replaceFirst(
      RegExp(r'\s+\*Corresponding author:.*$', caseSensitive: false),
      '',
    );
    return t.trim();
  }

  static bool looksLikeAuthorLine(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    return RegExp(
      r'@|corresponding author|university|department|faculty of',
      caseSensitive: false,
    ).hasMatch(t);
  }
}
