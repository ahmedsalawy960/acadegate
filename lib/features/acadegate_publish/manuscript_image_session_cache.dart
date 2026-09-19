/// In-memory image bytes so formatted Word export does not depend on Storage HTTP.
class ManuscriptImageSessionCache {
  ManuscriptImageSessionCache._();

  static final instance = ManuscriptImageSessionCache._();

  final _byKey = <String, String>{};

  void register(String key, String dataUri) {
    if (key.isEmpty || !dataUri.startsWith('data:')) return;
    _byKey[key] = dataUri;
  }

  String? resolve(String placeholder) {
    final trimmed = placeholder.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('data:')) return trimmed;
    final match = RegExp(r'^\{\{img:(.+)\}\}$').firstMatch(trimmed);
    if (match != null) {
      final key = match.group(1)?.trim() ?? '';
      if (key.isEmpty) return null;
      return _byKey[key];
    }
    return _byKey[trimmed];
  }

  void clear() => _byKey.clear();
}
