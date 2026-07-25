import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../locale/app_translate.dart';

/// Unified messages for common Firebase errors.
class FirebaseSecurityMessages {
  FirebaseSecurityMessages._();

  static String fromException(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return appTr(
            'ليس لديك صلاحية لهذا الإجراء. تأكد من تسجيل الدخول أو تواصل مع الدعم.',
            'You do not have permission for this action. Sign in or contact support.',
          );
        case 'unauthenticated':
          return appTr('يجب تسجيل الدخول أولاً.', 'You must sign in first.');
        case 'not-found':
          return appTr(
            'البيانات المطلوبة غير موجودة.',
            'The requested data was not found.',
          );
        case 'failed-precondition':
          return appTr(
            'تعذر تنفيذ العملية — تحقق من القواعد أو البيانات.',
            'Could not complete the operation — check rules or data.',
          );
        default:
          return error.message ??
              appTr(
                'حدث خطأ في Firebase (${error.code})',
                'Firebase error (${error.code})',
              );
      }
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
