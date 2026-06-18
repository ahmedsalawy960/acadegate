import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../auth/login_screen.dart';

Future<bool> ensureLoggedIn(BuildContext context) async {
  if (FirebaseAuth.instance.currentUser != null) return true;

  final shouldLogin = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('تسجيل الدخول مطلوب'),
      content: const Text('يجب تسجيل الدخول لإرسال البيانات للمراجعة.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('تسجيل الدخول'),
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
