import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and broadcasts the active app locale (ar / en).
class LocaleService extends ChangeNotifier {
  LocaleService._();

  static final LocaleService instance = LocaleService._();

  static const _prefKey = 'app_locale_code';
  static const supportedLocales = [Locale('ar'), Locale('en')];

  Locale? _locale;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  Locale? get locale => _locale;
  bool get hasChosenLocale => _locale != null;

  bool get isArabic => _locale?.languageCode != 'en';
  bool get isEnglish => _locale?.languageCode == 'en';

  TextDirection get textDirection =>
      isEnglish ? TextDirection.ltr : TextDirection.rtl;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKey);
    if (code == 'ar' || code == 'en') {
      _locale = Locale(code!);
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, locale.languageCode);
  }

  Future<void> setArabic() => setLocale(const Locale('ar'));
  Future<void> setEnglish() => setLocale(const Locale('en'));
}
