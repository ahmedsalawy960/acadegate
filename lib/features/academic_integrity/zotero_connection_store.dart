import 'package:shared_preferences/shared_preferences.dart';

/// On-device storage of the user's own Zotero connection (user ID + personal
/// API key). The key never leaves the device: Zotero calls go straight to
/// api.zotero.org, never through the citation proxy.
class ZoteroConnection {
  final String userId;
  final String apiKey;

  const ZoteroConnection({required this.userId, required this.apiKey});
}

class ZoteroConnectionStore {
  ZoteroConnectionStore._();

  static final ZoteroConnectionStore instance = ZoteroConnectionStore._();

  static const _userIdKey = 'zotero_user_id';
  static const _apiKeyKey = 'zotero_api_key';

  Future<ZoteroConnection?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey)?.trim() ?? '';
    final apiKey = prefs.getString(_apiKeyKey)?.trim() ?? '';
    if (userId.isEmpty || apiKey.isEmpty) return null;
    return ZoteroConnection(userId: userId, apiKey: apiKey);
  }

  Future<void> save({required String userId, required String apiKey}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId.trim());
    await prefs.setString(_apiKeyKey, apiKey.trim());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_apiKeyKey);
  }
}
