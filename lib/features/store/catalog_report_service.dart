import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_contact_info.dart';
import '../../core/locale/app_translate.dart';
import '../notifications/admin_recipient_service.dart';

class CatalogReportService {
  CatalogReportService._();
  static final CatalogReportService instance = CatalogReportService._();

  final _col = FirebaseFirestore.instance.collection('catalog_reports');

  Future<String> submit({
    required String targetType,
    required String reason,
    required String details,
    String? productId,
    String? supplierId,
    String? storeName,
    String? sourceUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError(
        appTr('سجّل الدخول للإبلاغ.', 'Sign in to report an issue.'),
      );
    }

    final trimmed = details.trim();
    if (trimmed.length < 10) {
      throw StateError(
        appTr('أضف تفاصيل أوضح (١٠ أحرف على الأقل).', 'Add more details (at least 10 characters).'),
      );
    }

    final ref = await _col.add({
      'userId': user.uid,
      'email': user.email ?? '',
      'targetType': targetType,
      if (productId != null && productId.isNotEmpty) 'productId': productId,
      if (supplierId != null && supplierId.isNotEmpty) 'supplierId': supplierId,
      if (storeName != null && storeName.isNotEmpty) 'storeName': storeName,
      if (sourceUrl != null && sourceUrl.isNotEmpty) 'sourceUrl': sourceUrl,
      'reason': reason,
      'details': trimmed.length > 4000 ? trimmed.substring(0, 4000) : trimmed,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await AdminRecipientService.instance.notifyAllAdmins(
      title: appTr('بلاغ كتالوج', 'Catalog report'),
      body: appTr(
        '$reason — ${storeName ?? supplierId ?? productId ?? ref.id}',
        '$reason — ${storeName ?? supplierId ?? productId ?? ref.id}',
      ),
      type: 'catalog_report',
      contextId: ref.id,
      contextType: 'catalog_report',
    );

    final mail = Uri(
      scheme: 'mailto',
      path: AppContactInfo.supportEmail,
      queryParameters: {
        'subject': appTr(
          'بلاغ كتالوج — ${ref.id}',
          'Catalog report — ${ref.id}',
        ),
        'body': trimmed,
      },
    );
    try {
      if (await canLaunchUrl(mail)) await launchUrl(mail);
    } catch (_) {}

    return ref.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOpenForAdmin() {
    return _col.orderBy('createdAt', descending: true).limit(80).snapshots();
  }

  Future<void> setStatus(String id, String status) async {
    await _col.doc(id).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
