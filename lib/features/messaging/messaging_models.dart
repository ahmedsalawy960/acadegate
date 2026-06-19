import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String? id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime? createdAt;

  const ChatMessage({
    this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.createdAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime? created;
    final raw = map['createdAt'];
    if (raw is Timestamp) created = raw.toDate();

    return ChatMessage(
      id: id,
      senderId: map['senderId']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      createdAt: created,
    );
  }
}

class Conversation {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final String lastMessage;
  final String contextType;
  final String contextId;
  final DateTime? updatedAt;

  const Conversation({
    required this.id,
    required this.participantIds,
    this.participantNames = const {},
    this.lastMessage = '',
    this.contextType = '',
    this.contextId = '',
    this.updatedAt,
  });

  factory Conversation.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? updated;
    final raw = map['updatedAt'];
    if (raw is Timestamp) updated = raw.toDate();

    final namesRaw = map['participantNames'];
    final names = <String, String>{};
    if (namesRaw is Map) {
      namesRaw.forEach((key, value) {
        names[key.toString()] = value.toString();
      });
    }

    return Conversation(
      id: id,
      participantIds: (map['participantIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      participantNames: names,
      lastMessage: map['lastMessage']?.toString() ?? '',
      contextType: map['contextType']?.toString() ?? '',
      contextId: map['contextId']?.toString() ?? '',
      updatedAt: updated,
    );
  }

  String otherParticipantName(String myUid) {
    for (final entry in participantNames.entries) {
      if (entry.key != myUid) return entry.value;
    }
    return 'محادثة';
  }
}
