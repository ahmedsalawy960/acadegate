import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
export 'app_translate.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
