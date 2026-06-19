import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String? id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.type = 'general',
    this.read = false,
    this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime? created;
    final raw = map['createdAt'];
    if (raw is Timestamp) created = raw.toDate();

    return AppNotification(
      id: id,
      userId: map['userId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      type: map['type']?.toString() ?? 'general',
      read: map['read'] as bool? ?? false,
      createdAt: created,
    );
  }
}
