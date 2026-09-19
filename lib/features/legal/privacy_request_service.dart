import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_contact_info.dart';
import '../../core/locale/app_translate.dart';
import '../notifications/admin_recipient_service.dart';

enum PrivacyRequestType {
  access,
  rectification,
  erasure,
  restriction,
  objection,
  other,
}

extension PrivacyRequestTypeX on PrivacyRequestType {
  String get id => name;

  String label(bool isAr) {
    switch (this) {
      case PrivacyRequestType.access:
        return isAr ? 'اطلاع على البيانات' : 'Access my data';
      case PrivacyRequestType.rectification:
        return isAr ? 'تصحيح بيانات' : 'Correct my data';
      case PrivacyRequestType.erasure:
        return isAr ? 'حذف الحساب / البيانات' : 'Delete account / data';
      case PrivacyRequestType.restriction:
        return isAr ? 'تقييد المعالجة' : 'Restrict processing';
      case PrivacyRequestType.objection:
        return isAr ? 'الاعتراض على معالجة' : 'Object to processing';
      case PrivacyRequestType.other:
        return isAr ? 'طلب آخر' : 'Other request';
    }
  }

  static PrivacyRequestType fromId(String raw) {
    return PrivacyRequestType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => PrivacyRequestType.other,
    );
  }
}

class PrivacyRequestService {
  PrivacyRequestService._();
  static final PrivacyRequestService instance = PrivacyRequestService._();

  final _col = FirebaseFirestore.instance.collection('privacy_requests');

  Future<String> submit({
    required PrivacyRequestType type,
    required String message,
    required String locale,
    String? emailOverride,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError(
        appTr('سجّل الدخول لإرسال طلب الخصوصية.', 'Sign in to submit a privacy request.'),
      );
    }

    final email = (emailOverride ?? user.email ?? '').trim();
    final trimmed = message.trim();
    if (trimmed.length < 10) {
      throw StateError(
        appTr('اكتب تفاصيل أوضح (١٠ أحرف على الأقل).', 'Please add more details (at least 10 characters).'),
      );
    }

    final ref = await _col.add({
      'userId': user.uid,
      'email': email,
      'type': type.id,
      'message': trimmed.length > 4000 ? trimmed.substring(0, 4000) : trimmed,
      'status': 'open',
      'locale': locale == 'ar' ? 'ar' : 'en',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final title = appTr('طلب خصوصية جديد', 'New privacy request');
    final body = appTr(
      '${type.label(true)} — ${user.email ?? user.uid}',
      '${type.label(false)} — ${user.email ?? user.uid}',
    );

    await AdminRecipientService.instance.notifyAllAdmins(
      title: title,
      body: body,
      type: 'privacy_request',
      contextId: ref.id,
      contextType: 'privacy_request',
    );

    final mail = Uri(
      scheme: 'mailto',
      path: AppContactInfo.supportEmail,
      queryParameters: {
        'subject': appTr(
          'طلب خصوصية — ${type.label(true)} — ${ref.id}',
          'Privacy request — ${type.label(false)} — ${ref.id}',
        ),
        'body': appTr(
          'رقم الطلب: ${ref.id}\nالنوع: ${type.label(true)}\nالمستخدم: ${user.uid}\n\n$trimmed',
          'Request ID: ${ref.id}\nType: ${type.label(false)}\nUser: ${user.uid}\n\n$trimmed',
        ),
      },
    );
    try {
      if (await canLaunchUrl(mail)) {
        await launchUrl(mail);
      }
    } catch (_) {}

    return ref.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOpenForAdmin() {
    return _col.orderBy('createdAt', descending: true).limit(80).snapshots();
  }

  Future<void> setStatus({
    required String id,
    required String status,
    String? adminNote,
  }) async {
    await _col.doc(id).update({
      'status': status,
      'adminNote': ?adminNote,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
