import 'package:shared_preferences/shared_preferences.dart';

/// User choice for the Academic Assistant reply language.
enum AssistantReplyLanguage { auto, arabic, english }

class AssistantReplyLanguagePrefs {
  AssistantReplyLanguagePrefs._();

  static const _key = 'assistant_reply_language';

  static Future<AssistantReplyLanguage> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return AssistantReplyLanguage.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => AssistantReplyLanguage.auto,
    );
  }

  static Future<void> save(AssistantReplyLanguage value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.name);
  }

  static final _arabic = RegExp('[\u0600-\u06FF]');
  static final _latin = RegExp('[A-Za-z]');

  /// Resolves [AssistantReplyLanguage.auto] by the dominant script of [message];
  /// technical English terms inside an Arabic question still count as Arabic.
  static AssistantReplyLanguage resolve(
    AssistantReplyLanguage choice,
    String message,
  ) {
    if (choice != AssistantReplyLanguage.auto) return choice;
    final arabic = _arabic.allMatches(message).length;
    final latin = _latin.allMatches(message).length;
    if (arabic == 0 && latin == 0) return AssistantReplyLanguage.arabic;
    return arabic * 2 >= latin
        ? AssistantReplyLanguage.arabic
        : AssistantReplyLanguage.english;
  }
}
