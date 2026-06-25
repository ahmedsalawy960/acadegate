import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// رسائل موحّدة لأخطاء Firebase الشائعة.
class FirebaseSecurityMessages {
  FirebaseSecurityMessages._();

  static String fromException(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'ليس لديك صلاحية لهذا الإجراء. تأكد من تسجيل الدخول أو تواصل مع الدعم.';
        case 'unauthenticated':
          return 'يجب تسجيل الدخول أولاً.';
        case 'not-found':
          return 'البيانات المطلوبة غير موجودة.';
        case 'failed-precondition':
          return 'تعذر تنفيذ العملية — تحقق من القواعد أو البيانات.';
        default:
          return error.message ?? 'حدث خطأ في Firebase (${error.code})';
      }
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
