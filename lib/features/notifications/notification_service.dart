import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/firebase/callable_http_client.dart';
import '../../core/notifications/push_notification_bootstrap.dart';
import 'notification_models.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('notifications');

  static bool get _preferHttpCallable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Future<void> notifySelf({
    required String title,
    required String body,
    String type = 'general',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await send(userId: user.uid, title: title, body: body, type: type);
  }

  Future<void> send({
    required String userId,
    required String title,
    required String body,
    String type = 'general',
    String contextId = '',
    String contextType = '',
  }) async {
    if (userId.isEmpty) return;

    final sender = FirebaseAuth.instance.currentUser;
    if (sender == null) return;

    final payload = <String, dynamic>{
      'userId': userId,
      'title': title.trim(),
      'body': body.trim(),
      'type': type,
      if (contextId.isNotEmpty) 'contextId': contextId,
      if (contextType.isNotEmpty) 'contextType': contextType,
    };

    try {
      if (_preferHttpCallable) {
        await CallableHttpClient.call(
          name: 'sendAppNotification',
          data: payload,
          timeout: const Duration(seconds: 30),
          callableProtocol: true,
        );
        return;
      }

      final callable = FirebaseFunctions.instance.httpsCallable(
        'sendAppNotification',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      await callable.call(payload);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('sendAppNotification failed: $e');
      }
      // Fallback for channel errors on desktop.
      if (!_preferHttpCallable &&
          e.toString().toLowerCase().contains('channel')) {
        try {
          await CallableHttpClient.call(
            name: 'sendAppNotification',
            data: payload,
            timeout: const Duration(seconds: 30),
            callableProtocol: true,
          );
        } catch (fallbackError) {
          if (kDebugMode) {
            debugPrint('sendAppNotification fallback failed: $fallbackError');
          }
        }
        return;
      }
      // Notifications are best-effort — never block orders/messages on failure.
    }
  }

  /// True if the current user already has a notification of [type] with the same [body].
  Future<bool> hasRecent({
    required String type,
    required String body,
    Duration within = const Duration(days: 30),
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final snapshot = await _notifications
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    final trimmedBody = body.trim();
    final since = DateTime.now().subtract(within);

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['type']?.toString() != type) continue;
      if (data['body']?.toString().trim() != trimmedBody) continue;
      final created = data['createdAt'];
      if (created is Timestamp && created.toDate().isAfter(since)) {
        return true;
      }
    }
    return false;
  }

  Stream<List<AppNotification>> userNotificationsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const []);

    return _notifications
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppNotification.fromMap(doc.data(), id: doc.id))
              .toList(),
        );
  }

  Stream<int> unreadCountStream() {
    return userNotificationsStream().map(
      (list) => list.where((n) => !n.read).length,
    );
  }

  Future<void> markRead(String notificationId) async {
    await _notifications.doc(notificationId).update({'read': true});
  }

  Future<void> markAllRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await _notifications
        .where('userId', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> delete(String notificationId) async {
    if (notificationId.isEmpty) return;
    await _notifications.doc(notificationId).delete();
  }

  Future<void> deleteAll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await _notifications
        .where('userId', isEqualTo: user.uid)
        .get();

    if (snapshot.docs.isEmpty) return;

    const batchLimit = 500;
    for (var i = 0; i < snapshot.docs.length; i += batchLimit) {
      final batch = _db.batch();
      final end = (i + batchLimit < snapshot.docs.length)
          ? i + batchLimit
          : snapshot.docs.length;
      for (var j = i; j < end; j++) {
        batch.delete(snapshot.docs[j].reference);
      }
      await batch.commit();
    }
  }

  Future<void> saveFcmToken(String token) async {
    if (!PushNotificationBootstrap.supportsPush) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || token.isEmpty) return;

    await _db.collection('users').doc(user.uid).set(
      {'fcmToken': token, 'fcmUpdatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }
}
