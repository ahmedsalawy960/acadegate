/// In-memory image bytes for Windows import (Firestore strips data URIs).
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
    final match = RegExp(r'^\{\{img:(.+)\}\}$').firstMatch(trimmed);
    if (match == null) return null;
    final key = match.group(1)?.trim() ?? '';
    if (key.isEmpty) return null;
    return _byKey[key];
  }

  void clear() => _byKey.clear();
}
