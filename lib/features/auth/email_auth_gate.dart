import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/app_environment.dart';

/// Email/password accounts must verify ownership before using the app.
/// Google / Apple / Facebook users are treated as already verified.
class EmailAuthGate {
  EmailAuthGate._();

  static const firebaseAuthDomain = 'acadegate-new.firebaseapp.com';
  static const verificationEmailSender =
      'noreply@acadegate-new.firebaseapp.com';

  static const _oauthProviders = {
    'google.com',
    'facebook.com',
    'apple.com',
  };

  /// Closed-beta QA seeds (`tool/seed_qa_accounts*.js`) use this domain.
  static bool isQaSeedEmail(String? email) {
    final e = (email ?? '').trim().toLowerCase();
    return e.endsWith('@acadegate.test');
  }

  /// True when the signed-in user must confirm email before PortalGateway.
  static bool requiresVerification(User? user) {
    if (user == null) return false;
    if (user.emailVerified) return false;

    // Debug / beta only: allow seeded QA accounts without inbox access.
    if ((kDebugMode || AppEnvironment.isBeta) && isQaSeedEmail(user.email)) {
      return false;
    }

    final providers =
        user.providerData.map((p) => p.providerId).toSet();

    final oauthOnly = providers.isNotEmpty &&
        providers.every(_oauthProviders.contains) &&
        !providers.contains('password');
    if (oauthOnly) return false;

    if (providers.contains('password') || providers.isEmpty) {
      final email = user.email?.trim() ?? '';
      return email.isNotEmpty;
    }

    return providers.contains('password');
  }

  /// Sends the Firebase verification email (Console → Authentication → Templates).
  ///
  /// Mirrors [AuthPasswordResetService]: ActionCodeSettings only on web, using
  /// the auth domain (always authorized) so send does not fail with
  /// `unauthorized-continue-uri`.
  static Future<void> sendVerificationEmail({
    String languageCode = 'ar',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user to verify',
      );
    }

    await FirebaseAuth.instance.setLanguageCode(languageCode);

    ActionCodeSettings? actionCodeSettings;
    if (kIsWeb) {
      actionCodeSettings = ActionCodeSettings(
        url: 'https://$firebaseAuthDomain',
        handleCodeInApp: false,
      );
    }

    debugPrint(
      'Sending email verification to ${user.email} (lang=$languageCode)',
    );

    await user.sendEmailVerification(actionCodeSettings);

    debugPrint('Email verification request accepted for ${user.email}');
  }

  static Future<bool> reloadAndCheckVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    return refreshed != null && !requiresVerification(refreshed);
  }

  static String describeSendError(FirebaseAuthException e) {
    switch (e.code) {
      case 'too-many-requests':
        return 'too-many-requests';
      case 'network-request-failed':
        return 'network';
      case 'unauthorized-continue-uri':
      case 'invalid-continue-uri':
      case 'missing-continue-uri':
        return 'continue-uri';
      default:
        return e.code;
    }
  }
}
