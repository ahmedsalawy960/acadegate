import 'package:flutter/foundation.dart';

/// مسارات ويب مباشرة للتسجيل/الدخول، مثل:
/// https://acadegate-new.web.app/register
class AuthWebDeepLink {
  AuthWebDeepLink._();

  /// `register` | `login` | null
  static String? actionFromUri([Uri? uri]) {
    if (!kIsWeb) return null;
    final u = uri ?? Uri.base;
    final candidates = <String>[
      u.path,
      if (u.fragment.isNotEmpty) u.fragment,
    ];
    for (final raw in candidates) {
      final p = raw
          .toLowerCase()
          .trim()
          .replaceFirst(RegExp(r'^/+'), '')
          .replaceFirst(RegExp(r'/+$'), '')
          .split('/')
          .firstWhere((e) => e.isNotEmpty, orElse: () => '');
      if (p == 'register' || p == 'signup' || p == 'sign-up') {
        return 'register';
      }
      if (p == 'login' || p == 'signin' || p == 'sign-in') {
        return 'login';
      }
    }
    return null;
  }

  static const registerUrl = 'https://acadegate-new.web.app/register';
  static const loginUrl = 'https://acadegate-new.web.app/login';
  static const appUrl = 'https://acadegate-new.web.app/';
}
