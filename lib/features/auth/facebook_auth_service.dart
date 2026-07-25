import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import 'social_auth_config.dart';
import 'user_account_service.dart';

class FacebookAuthService {
  FacebookAuthService._();

  static final FacebookAuthService instance = FacebookAuthService._();

  static bool _initialized = false;

  /// On web, Facebook is configured in Firebase Console (App ID + Secret).
  /// On mobile, `FACEBOOK_APP_ID` is required for the native SDK.
  static bool get isAvailable =>
      kIsWeb || SocialAuthConfig.facebookAppId.isNotEmpty;

  static String get configurationHint =>
      '--dart-define=FACEBOOK_APP_ID=YOUR_FACEBOOK_APP_ID';

  Future<void> _ensureNativeInitialized() async {
    if (_initialized || kIsWeb) return;

    if (SocialAuthConfig.facebookAppId.isEmpty) {
      throw Exception(
        'Facebook يحتاج إعداد FACEBOOK_APP_ID:\n$configurationHint',
      );
    }

    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      await FacebookAuth.instance.webAndDesktopInitialize(
        appId: SocialAuthConfig.facebookAppId,
        cookie: true,
        xfbml: true,
        version: 'v21.0',
      );
    }

    _initialized = true;
  }

  Future<User?> signInWithFacebook() async {
    if (kIsWeb) {
      return _signInWithFacebookWeb();
    }
    return _signInWithFacebookNative();
  }

  Future<User?> _signInWithFacebookWeb() async {
    try {
      final provider = FacebookAuthProvider()..addScope('email');
      final result = await FirebaseAuth.instance.signInWithPopup(provider);
      final user = result.user;
      if (user == null) return null;
      await UserAccountService.instance.ensureAccountExists(user);
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(
        e.message ??
            'فشل تسجيل Facebook — تأكد من تفعيله في Firebase وإضافة Redirect URI',
      );
    }
  }

  Future<User?> _signInWithFacebookNative() async {
    await _ensureNativeInitialized();

    final result = await FacebookAuth.instance.login(
      permissions: const ['email', 'public_profile'],
    );

    if (result.status != LoginStatus.success) {
      throw Exception('تم إلغاء تسجيل Facebook أو فشل');
    }

    final accessToken = result.accessToken;
    if (accessToken == null) {
      throw Exception('تعذر الحصول على رمز Facebook');
    }

    final credential = FacebookAuthProvider.credential(accessToken.tokenString);
    final authResult =
        await FirebaseAuth.instance.signInWithCredential(credential);
    await UserAccountService.instance.ensureAccountExists(authResult.user!);
    return authResult.user;
  }
}
