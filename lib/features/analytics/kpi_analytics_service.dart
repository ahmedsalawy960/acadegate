import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Client-side KPI event logging for weekly performance dashboards.
class KpiAnalyticsService {
  KpiAnalyticsService._();

  static final KpiAnalyticsService instance = KpiAnalyticsService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('kpi_events');

  static const search = 'search';
  static const firstSearch = 'first_search';
  static const contactRequest = 'contact_request';
  static const profileClaim = 'profile_claim';
  static const profileVerified = 'profile_verified';
  static const criticalError = 'critical_error';
  static const partnerActivity = 'partner_activity';
  static const sessionActive = 'session_active';

  String weekId([DateTime? at]) {
    final d = at ?? DateTime.now().toUtc();
    // ISO-8601 week: Monday-based.
    final date = DateTime.utc(d.year, d.month, d.day);
    final thursday = date.add(Duration(days: 3 - ((date.weekday + 6) % 7)));
    final week1 = DateTime.utc(thursday.year, 1, 4);
    final weekNo = 1 +
        ((thursday.difference(week1).inDays -
                    ((week1.weekday + 6) % 7) +
                    3) ~/
                7)
            .floor();
    final year = thursday.year;
    return '$year-W${weekNo.toString().padLeft(2, '0')}';
  }

  Future<void> _writeEvent({
    required String type,
    Map<String, dynamic>? meta,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      // Rules require uid == auth.uid; skip when signed out.
      if (user == null) return;
      await _events.add({
        'type': type,
        'uid': user.uid,
        'weekId': weekId(),
        'meta': meta ?? {},
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      debugPrint('KpiAnalyticsService._writeEvent failed: $e\n$st');
    }
  }

  /// Touch lastActiveAt (throttled) + optional session event.
  DateTime? _lastActiveFlush;

  Future<void> markActive({bool force = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    if (!force &&
        _lastActiveFlush != null &&
        now.difference(_lastActiveFlush!) < const Duration(minutes: 10)) {
      return;
    }
    _lastActiveFlush = now;
    try {
      await _db.collection('users').doc(user.uid).set(
        {
          'lastActiveAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await _writeEvent(type: sessionActive);
    } catch (e, st) {
      debugPrint('KpiAnalyticsService.markActive failed: $e\n$st');
    }
  }

  Future<void> logSearch({
    required String kind,
    String query = '',
    int resultCount = 0,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    await markActive();
    await _writeEvent(
      type: search,
      meta: {
        'kind': kind,
        'queryLen': query.trim().length,
        'resultCount': resultCount,
      },
    );
    if (user == null) return;
    try {
      final ref = _db.collection('users').doc(user.uid);
      final isFirst = await _db.runTransaction<bool>((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data() ?? {};
        if (data['firstSearchAt'] != null) return false;
        tx.set(
          ref,
          {
            'firstSearchAt': FieldValue.serverTimestamp(),
            'lastActiveAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return true;
      });
      if (isFirst) {
        await _writeEvent(type: firstSearch, meta: {'kind': kind});
      }
    } catch (e, st) {
      debugPrint('KpiAnalyticsService.logSearch firstSearch failed: $e\n$st');
    }
  }

  Future<void> logContactRequest({
    required String channel,
    String? targetId,
  }) async {
    await markActive();
    await _writeEvent(
      type: contactRequest,
      meta: {
        'channel': channel,
        if ((targetId ?? '').isNotEmpty) 'targetId': targetId,
      },
    );
  }

  Future<void> logProfileClaim({
    required String targetType,
    required String targetId,
  }) async {
    await markActive();
    await _writeEvent(
      type: profileClaim,
      meta: {'targetType': targetType, 'targetId': targetId},
    );
  }

  Future<void> logProfileVerified({
    required String targetType,
    required String targetId,
    String? claimantUid,
  }) async {
    await _writeEvent(
      type: profileVerified,
      meta: {
        'targetType': targetType,
        'targetId': targetId,
        if ((claimantUid ?? '').isNotEmpty) 'claimantUid': claimantUid,
      },
    );
  }

  Future<void> logCriticalError({
    required String source,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    await _writeEvent(
      type: criticalError,
      meta: {
        'source': source,
        'message': trimmed.length > 400 ? trimmed.substring(0, 400) : trimmed,
      },
    );
  }

  Future<void> logPartnerActivity({required String action}) async {
    await markActive();
    await _writeEvent(
      type: partnerActivity,
      meta: {'action': action},
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchWeek(String id) {
    return _db.collection('kpi_weekly').doc(id).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRecentWeeks({int limit = 12}) {
    return _db
        .collection('kpi_weekly')
        .orderBy('weekStart', descending: true)
        .limit(limit)
        .snapshots();
  }
}
