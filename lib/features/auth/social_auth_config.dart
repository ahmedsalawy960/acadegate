import 'package:flutter/foundation.dart';

/// Centralized configuration for social sign-in providers.
///
/// Values are provided via `--dart-define=...` at build/run time.
///
/// Notes:
/// - Google on web/desktop needs `GOOGLE_WEB_CLIENT_ID` (already handled by `GoogleAuthService`).
/// - Facebook on web uses Firebase Auth popup (configure in Firebase Console).
/// - Facebook on mobile needs `FACEBOOK_APP_ID` for the native SDK.
/// - Apple is supported mainly on iOS/macOS; web requires Apple Service ID + redirect URL.
class SocialAuthConfig {
  SocialAuthConfig._();

  static const _facebookAppIdRaw = String.fromEnvironment(
    'FACEBOOK_APP_ID',
    defaultValue: '',
  );

  static String get facebookAppId => _facebookAppIdRaw.trim();

  static const appleServiceId = String.fromEnvironment(
    'APPLE_SERVICE_ID',
    defaultValue: '',
  );

  static const appleRedirectUri = String.fromEnvironment(
    'APPLE_REDIRECT_URI',
    defaultValue: '',
  );

  static bool get isFacebookConfigured =>
      kIsWeb || facebookAppId.isNotEmpty;

  static bool get isAppleWebConfigured =>
      kIsWeb && appleServiceId.isNotEmpty && appleRedirectUri.isNotEmpty;
}

