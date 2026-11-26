import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';

/// Reasons a member can give when reporting a community post or reply.
class CommunityReportReason {
  static const spam = 'spam';
  static const abuse = 'abuse';
  static const impersonation = 'impersonation';
  static const other = 'other';

  static const all = [spam, abuse, impersonation, other];

  static String label(String reason) {
    switch (reason) {
      case spam:
        return appTr('سبام أو إعلان', 'Spam or advertising');
      case abuse:
        return appTr('إساءة أو محتوى غير لائق', 'Abusive or inappropriate');
      case impersonation:
        return appTr('انتحال شخصية', 'Impersonation');
      default:
        return appTr('سبب آخر', 'Other');
    }
  }
}

const int kCommunityReportNoteMaxLength = 500;

/// One report per member per post/reply: the document id is deterministic, so
/// reporting twice only repeats the same document.
String communityReportId({
  required String uid,
  required String postId,
  String? replyId,
}) {
  final reply = (replyId ?? '').trim();
  return reply.isEmpty ? '${uid}_$postId' : '${uid}_${postId}_$reply';
}

class CommunityReportService {
  CommunityReportService._();

  static final CommunityReportService instance = CommunityReportService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('community_reports');

  Future<String?> submit({
    required String postId,
    String? replyId,
    required String reason,
    String note = '',
    String postTitle = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return appTr('يجب تسجيل الدخول أولاً', 'You must sign in first');
    }
    if (!CommunityReportReason.all.contains(reason)) {
      return appTr('اختر سبب البلاغ', 'Choose a reason');
    }
    final trimmedNote = note.trim();
    if (trimmedNote.length > kCommunityReportNoteMaxLength) {
      return appTr('الملاحظة طويلة', 'The note is too long');
    }
    final title = postTitle.trim();
    final reply = (replyId ?? '').trim();
    try {
      await _reports
          .doc(communityReportId(uid: user.uid, postId: postId, replyId: reply))
          .set({
        'reporterId': user.uid,
        'postId': postId,
        'replyId': reply,
        'reason': reason,
        'note': trimmedNote,
        'postTitle': title.length > 200 ? title.substring(0, 200) : title,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Reporting the same item twice is refused by the rules (no update).
        return appTr('سبق أن بلّغت عن هذا المحتوى', 'You already reported this');
      }
      return e.message ?? e.code;
    }
    return null;
  }

  Future<void> setStatus(String reportId, String status) {
    return _reports.doc(reportId).update({
      'status': status,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOpen() {
    return _reports.where('status', isEqualTo: 'open').limit(100).snapshots();
  }
}
