import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/locale/app_translate.dart';
import '../auth/user_account_service.dart';
import '../notifications/admin_recipient_service.dart';
import '../analytics/kpi_analytics_service.dart';

/// Central bug / error intake for researchers, providers, and auto crashes.
class BugReportService {
  BugReportService._();
  static final BugReportService instance = BugReportService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('bug_reports');

  static const sourceAutoFlutter = 'auto_flutter';
  static const sourceAutoPlatform = 'auto_platform';
  static const sourceCaught = 'caught';
  static const sourceUser = 'user_report';
  static const sourceProvider = 'provider_report';

  static const statusOpen = 'open';
  static const statusInvestigating = 'investigating';
  static const statusResolved = 'resolved';
  static const statusWontFix = 'wontfix';
  static const statusDuplicate = 'duplicate';

  /// Last auto fingerprint → time (local throttle).
  final Map<String, DateTime> _recentAuto = {};

  String fingerprint(String message) {
    final cleaned = message
        .replaceAll(RegExp(r'0x[0-9a-fA-F]+'), '0x…')
        .replaceAll(RegExp(r'\d{4,}'), '#')
        .trim();
    final slice =
        cleaned.length > 180 ? cleaned.substring(0, 180) : cleaned;
    return slice.hashCode.toRadixString(16);
  }

  bool _shouldThrottleAuto(String fp) {
    final now = DateTime.now();
    final last = _recentAuto[fp];
    if (last != null && now.difference(last) < const Duration(minutes: 2)) {
      return true;
    }
    _recentAuto[fp] = now;
    if (_recentAuto.length > 80) {
      _recentAuto.remove(_recentAuto.keys.first);
    }
    return false;
  }

  Future<void> logAutoError({
    required String source,
    required String message,
    String? stack,
    String severity = 'high',
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    final fp = fingerprint(trimmed);
    if (_shouldThrottleAuto(fp)) return;

    // Keep KPI weekly counter in sync.
    // ignore: unawaited_futures
    KpiAnalyticsService.instance.logCriticalError(
      source: source,
      message: trimmed,
    );

    await _write(
      source: source,
      message: trimmed,
      stack: stack,
      severity: severity,
      category: 'crash',
      portal: _guessPortal(),
      notifyAdmins: false,
      fingerprint: fp,
    );
  }

  /// Catch-block helper — never throws.
  Future<void> capture(
    Object error, {
    StackTrace? stack,
    String category = 'other',
    String? screen,
    String? portal,
    String severity = 'medium',
    Map<String, dynamic>? meta,
  }) async {
    try {
      await _write(
        source: sourceCaught,
        message: error.toString(),
        stack: stack?.toString(),
        severity: severity,
        category: category,
        screen: screen,
        portal: portal ?? _guessPortal(),
        meta: meta,
        notifyAdmins: false,
        fingerprint: fingerprint(error.toString()),
      );
    } catch (e, st) {
      debugPrint('BugReportService.capture failed: $e\n$st');
    }
  }

  /// Manual report from researcher or provider UI.
  Future<String> submitUserReport({
    required String description,
    required String category,
    required String portal,
    String? screen,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError(
        appTr('سجّل الدخول للإبلاغ عن مشكلة.', 'Sign in to report a problem.'),
      );
    }
    final trimmed = description.trim();
    if (trimmed.length < 10) {
      throw StateError(
        appTr(
          'اكتب تفاصيل أوضح (١٠ أحرف على الأقل).',
          'Add more details (at least 10 characters).',
        ),
      );
    }
    final source =
        portal == 'provider' ? sourceProvider : sourceUser;
    final id = await _write(
      source: source,
      message: trimmed,
      severity: 'medium',
      category: category,
      portal: portal,
      screen: screen,
      notifyAdmins: true,
      fingerprint: fingerprint('$category|$trimmed'),
      userDescription: trimmed,
    );
    if (id == null) {
      throw StateError(
        appTr('تعذّر إرسال البلاغ.', 'Could not submit the report.'),
      );
    }
    return id;
  }

  String _guessPortal() {
    // Best-effort; screens pass explicit portal when known.
    return 'unknown';
  }

  Future<String?> _write({
    required String source,
    required String message,
    String? stack,
    required String severity,
    required String category,
    String portal = 'unknown',
    String? screen,
    String? userDescription,
    Map<String, dynamic>? meta,
    required bool notifyAdmins,
    String? fingerprint,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final isAuto =
          source == sourceAutoFlutter || source == sourceAutoPlatform;
      // Auto logs may occur before sign-in; others require auth.
      if (user == null && !isAuto) return null;

      String role = '';
      String displayName = '';
      if (user != null) {
        try {
          final account =
              await UserAccountService.instance.loadCurrentAccount();
          role = account?.role ?? '';
          displayName = (account?.displayName ?? user.displayName ?? '')
              .trim();
        } catch (_) {}
      }

      final msg = message.length > 2000 ? message.substring(0, 2000) : message;
      final stk = (stack ?? '').trim();
      final stackTrim =
          stk.length > 6000 ? stk.substring(0, 6000) : stk;

      final ref = await _col.add({
        'source': source,
        'status': statusOpen,
        'severity': severity,
        'category': category,
        'portal': portal,
        'message': msg,
        'stack': stackTrim,
        if ((userDescription ?? '').isNotEmpty)
          'userDescription': userDescription!.length > 4000
              ? userDescription.substring(0, 4000)
              : userDescription,
        if ((screen ?? '').isNotEmpty) 'screen': screen,
        'uid': user?.uid ?? '',
        'email': user?.email ?? '',
        'displayName': displayName,
        'role': role,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'fingerprint': fingerprint ?? '',
        'meta': meta ?? {},
        'count': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      });

      if (notifyAdmins) {
        // ignore: unawaited_futures
        AdminRecipientService.instance.notifyAllAdmins(
          title: appTr('بلاغ مشكلة جديد', 'New bug report'),
          body: msg.length > 120 ? '${msg.substring(0, 120)}…' : msg,
          type: 'bug_report',
          contextId: ref.id,
          contextType: 'bug_report',
        );
      }
      return ref.id;
    } catch (e, st) {
      debugPrint('BugReportService._write failed: $e\n$st');
      return null;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchForAdmin({
    String status = statusOpen,
    int limit = 80,
  }) {
    Query<Map<String, dynamic>> q = _col;
    if (status.isNotEmpty && status != 'all') {
      q = q.where('status', isEqualTo: status);
    }
    return q.orderBy('createdAt', descending: true).limit(limit).snapshots();
  }

  Future<void> updateStatus({
    required String id,
    required String status,
    String? adminNote,
  }) async {
    await _col.doc(id).set(
      {
        'status': status,
        if (adminNote != null) 'adminNote': adminNote.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'resolvedAt': status == statusResolved ||
                status == statusWontFix ||
                status == statusDuplicate
            ? FieldValue.serverTimestamp()
            : null,
      },
      SetOptions(merge: true),
    );
  }
}
