import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'user_account_service.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  static const _webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  static bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    final needsClientId = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;

    if (needsClientId && _webClientId.isEmpty) {
      throw Exception(
        'لتسجيل Google على سطح المكتب أضف:\n'
        '--dart-define=GOOGLE_WEB_CLIENT_ID=معرّف_عميل_الويب_من_Firebase',
      );
    }

    await GoogleSignIn.instance.initialize(
      clientId: _webClientId.isEmpty ? null : _webClientId,
    );
    _initialized = true;
  }

  Future<User?> signInWithGoogle() async {
    await _ensureInitialized();

    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw Exception('تعذر الحصول على رمز Google');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    await UserAccountService.instance.ensureAccountExists(result.user!);
    return result.user;
  }
}
