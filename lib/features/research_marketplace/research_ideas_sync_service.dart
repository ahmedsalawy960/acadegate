import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/firebase/callable_http_client.dart';
import '../../core/locale/app_translate.dart';

class ResearchIdeasSyncResult {
  final String batchId;
  final int candidates;
  final int openalex;
  final int rss;
  final int imported;
  final int updated;
  final int skipped;
  final bool usedGemini;

  const ResearchIdeasSyncResult({
    required this.batchId,
    required this.candidates,
    required this.openalex,
    required this.rss,
    required this.imported,
    required this.updated,
    required this.skipped,
    required this.usedGemini,
  });

  factory ResearchIdeasSyncResult.fromMap(Map<String, dynamic> map) {
    int n(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    return ResearchIdeasSyncResult(
      batchId: map['batchId']?.toString() ?? '',
      candidates: n(map['candidates']),
      openalex: n(map['openalex']),
      rss: n(map['rss']),
      imported: n(map['imported']),
      updated: n(map['updated']),
      skipped: n(map['skipped']),
      usedGemini: map['usedGemini'] == true,
    );
  }
}

/// Calls Cloud Function `researchIdeasSyncNow` (admin only).
class ResearchIdeasSyncService {
  ResearchIdeasSyncService._();

  static final ResearchIdeasSyncService instance = ResearchIdeasSyncService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static bool get _preferHttpCallable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static bool _isPluginChannelError(String? message) {
    if (message == null) return false;
    final lower = message.toLowerCase();
    return lower.contains('unable to establish connection on channel') ||
        lower.contains('cloudfunctionshostapi') ||
        lower.contains('pigeon');
  }

  Future<DateTime?> loadLastSyncAt() async {
    final snap = await _db.doc('app_meta/research_ideas_sync').get();
    final raw = snap.data()?['syncedAt'];
    if (raw is Timestamp) return raw.toDate();
    return null;
  }

  Future<Map<String, dynamic>?> loadLastSyncMeta() async {
    final snap = await _db.doc('app_meta/research_ideas_sync').get();
    return snap.data();
  }

  Future<ResearchIdeasSyncResult> syncNow({bool autoApprove = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));
    }

    final payload = <String, dynamic>{'autoApprove': autoApprove};

    // Windows cloud_functions pigeon channel often fails; use HTTP like geminiAdvisor.
    if (_preferHttpCallable) {
      return _syncViaHttp(payload);
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'researchIdeasSyncNow',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
      );
      final result = await callable.call(payload);
      final data = result.data;
      if (data is Map) {
        return ResearchIdeasSyncResult.fromMap(
          Map<String, dynamic>.from(data),
        );
      }
      throw Exception(appTr('استجابة غير متوقعة', 'Unexpected response'));
    } on FirebaseFunctionsException catch (e) {
      if (_isPluginChannelError(e.message)) {
        return _syncViaHttp(payload);
      }
      throw Exception(_mapError(e.code, e.message));
    } catch (e) {
      if (_isPluginChannelError(e.toString())) {
        return _syncViaHttp(payload);
      }
      rethrow;
    }
  }

  Future<ResearchIdeasSyncResult> _syncViaHttp(
    Map<String, dynamic> payload,
  ) async {
    try {
      final data = await CallableHttpClient.call(
        name: 'researchIdeasSyncNow',
        data: payload,
        timeout: const Duration(minutes: 9),
        callableProtocol: true,
      );
      return ResearchIdeasSyncResult.fromMap(data);
    } on CallableHttpException catch (e) {
      throw Exception(_mapError(e.code, e.message));
    }
  }

  String _mapError(String code, String? message) {
    final c = code.toLowerCase();
    if (c == 'not-found' ||
        c == 'unimplemented' ||
        (message?.contains('404') ?? false)) {
      return appTr(
        'دالة المزامنة غير منشورة بعد — انشر functions ثم أعد المحاولة',
        'Sync function not deployed yet — deploy functions then retry',
      );
    }
    if (c == 'permission-denied' || c.contains('permission')) {
      return appTr('للمدير فقط', 'Admin only');
    }
    if (c == 'unauthenticated') {
      return appTr(
        'انتهت الجلسة — سجّل الخروج ثم الدخول مجدداً',
        'Session expired — sign out and sign in again',
      );
    }
    return message ?? code;
  }
}
