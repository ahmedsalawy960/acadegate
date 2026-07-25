import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'social_auth_config.dart';
import 'user_account_service.dart';

class AppleAuthService {
  AppleAuthService._();

  static final AppleAuthService instance = AppleAuthService._();

  static bool get isAvailable {
    if (kIsWeb) return SocialAuthConfig.isAppleWebConfigured;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<User?> signInWithApple() async {
    if (!isAvailable) {
      throw Exception(
        kIsWeb
            ? 'Apple على الويب يحتاج APPLE_SERVICE_ID و APPLE_REDIRECT_URI'
            : 'Apple متاح على iOS/macOS فقط',
      );
    }

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      webAuthenticationOptions: kIsWeb
          ? WebAuthenticationOptions(
              clientId: SocialAuthConfig.appleServiceId,
              redirectUri: Uri.parse(SocialAuthConfig.appleRedirectUri),
            )
          : null,
    );

    final oauth = OAuthProvider('apple.com').credential(
      idToken: credential.identityToken,
      accessToken: credential.authorizationCode,
    );

    final authResult = await FirebaseAuth.instance.signInWithCredential(oauth);
    await UserAccountService.instance.ensureAccountExists(authResult.user!);
    return authResult.user;
  }
}

