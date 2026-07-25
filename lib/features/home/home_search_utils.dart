/// أدوات مطابقة البحث — تدعم العربية والإنجليزية وكلمات متعددة.
String normalizeSearchText(String input) {
  return input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool homeSearchMatches(String query, List<String> fields) {
  final normalizedQuery = normalizeSearchText(query);
  if (normalizedQuery.isEmpty) return false;

  final haystack = normalizeSearchText(fields.join(' '));
  if (haystack.isEmpty) return false;

  if (haystack.contains(normalizedQuery)) return true;

  final tokens = normalizedQuery
      .split(RegExp(r'[\s,،]+'))
      .where((token) => token.length >= 2)
      .toList();

  if (tokens.isEmpty) {
    return haystack.contains(normalizedQuery);
  }

  return tokens.every((token) => haystack.contains(token));
}
