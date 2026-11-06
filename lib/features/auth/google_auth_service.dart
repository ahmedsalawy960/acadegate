import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'user_account_service.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  // Needed only for desktop (Windows/macOS/Linux).
  // Prefer --dart-define; fall back to the Firebase Web OAuth client already
  // present in android/app/google-services.json (public client id).
  static const _desktopClientIdDefine = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  static const _firebaseWebClientId =
      '741208597895-q6u2927ta7cpc4jhmtn64qvrqh3f1mm0.apps.googleusercontent.com';

  static String get _desktopClientId {
    final fromDefine = _desktopClientIdDefine.trim();
    if (fromDefine.isNotEmpty) return fromDefine;
    return _firebaseWebClientId;
  }

  static bool _initialized = false;

  static bool get needsDesktopClientId =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  static bool get isConfiguredForCurrentPlatform =>
      !needsDesktopClientId || _desktopClientId.isNotEmpty;

  static String get configurationHint =>
      '--dart-define=GOOGLE_WEB_CLIENT_ID=$_firebaseWebClientId';

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    // On web we use FirebaseAuth popup; no client id is required here.
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    if (needsDesktopClientId && _desktopClientId.isEmpty) {
      throw Exception(
        'لتسجيل Google على سطح المكتب أضف:\n'
        '$configurationHint',
      );
    }

    await GoogleSignIn.instance.initialize(
      // Android/iOS read the client from google-services / GoogleService-Info.
      // Desktop needs the Web OAuth client id explicitly.
      clientId: needsDesktopClientId ? _desktopClientId : null,
      serverClientId: needsDesktopClientId ? null : _firebaseWebClientId,
    );
    _initialized = true;
  }

  Future<User?> signInWithGoogle() async {
    await _ensureInitialized();

    if (kIsWeb) {
      // Correct approach on web: Firebase Auth popup.
      final provider = GoogleAuthProvider();
      final result = await FirebaseAuth.instance.signInWithPopup(provider);
      final user = result.user;
      if (user == null) return null;
      await UserAccountService.instance.ensureAccountExists(user);
      return user;
    } else {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw Exception('تعذر الحصول على رمز Google');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result =
          await FirebaseAuth.instance.signInWithCredential(credential);
      await UserAccountService.instance.ensureAccountExists(result.user!);
      return result.user;
    }
  }
}
