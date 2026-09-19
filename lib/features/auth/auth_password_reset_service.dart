import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Sends Firebase password-reset emails with locale-aware templates.
class AuthPasswordResetService {
  AuthPasswordResetService._();

  static final AuthPasswordResetService instance = AuthPasswordResetService._();

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static const String firebaseAuthDomain = 'acadegate-new.firebaseapp.com';

  static const String resetEmailSender =
      'noreply@acadegate-new.firebaseapp.com';

  bool isValidEmail(String email) => _emailPattern.hasMatch(email.trim());

  String normalizeEmail(String email) => email.trim().toLowerCase();

  Future<void> sendResetEmail({
    required String email,
    String languageCode = 'ar',
  }) async {
    final normalized = normalizeEmail(email);
    if (normalized.isEmpty || !isValidEmail(normalized)) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Invalid email address',
      );
    }

    await FirebaseAuth.instance.setLanguageCode(languageCode);

    // On localhost / http, ActionCodeSettings often breaks delivery or hits
    // unauthorized-continue-uri. Use the default Firebase email template.
    // On HTTPS production hosts, deep-link back to the app origin.
    ActionCodeSettings? actionCodeSettings;
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.startsWith('https://') &&
          !origin.contains('localhost') &&
          !origin.contains('127.0.0.1')) {
        actionCodeSettings = ActionCodeSettings(
          url: origin,
          handleCodeInApp: false,
        );
      }
    }

    debugPrint(
      'Password reset requested for $normalized '
      '(lang=$languageCode, continue=${actionCodeSettings?.url ?? 'default'})',
    );

    await FirebaseAuth.instance.sendPasswordResetEmail(
      email: normalized,
      actionCodeSettings: actionCodeSettings,
    );

    debugPrint('Password reset request accepted for $normalized');
  }
}
