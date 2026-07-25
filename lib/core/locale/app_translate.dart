import 'package:flutter/widgets.dart';
import 'locale_service.dart';

/// Bilingual helper for strings not yet in ARB files.
String appTr(String ar, String en) =>
    LocaleService.instance.isEnglish ? en : ar;

extension AppTranslateX on BuildContext {
  /// Arabic [ar] / English [en] — switches with app language.
  String t(String ar, String en) => appTr(ar, en);
}
