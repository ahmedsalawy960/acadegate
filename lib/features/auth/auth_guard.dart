import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/locale/app_translate.dart';
import '../auth/login_screen.dart';

Future<bool> ensureLoggedIn(BuildContext context) async {
  if (FirebaseAuth.instance.currentUser != null) return true;

  final shouldLogin = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.t('تسجيل الدخول مطلوب', 'Sign-in required')),
      content: Text(
        dialogContext.t(
          'يجب تسجيل الدخول لإرسال البيانات للمراجعة.',
          'You must sign in to submit data for review.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(dialogContext.t('إلغاء', 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(dialogContext.t('تسجيل الدخول', 'Sign in')),
        ),
      ],
    ),
  );

  if (shouldLogin != true || !context.mounted) return false;

  await Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const LoginScreen()),
  );

  return FirebaseAuth.instance.currentUser != null;
}
