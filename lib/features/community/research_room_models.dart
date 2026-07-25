import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/locale/app_translate.dart';

class ResearchRoom {
  final String id;
  final String title;
  final String description;
  final String creatorId;
  final String creatorName;
  final String? categoryId;
  final bool isPasswordProtected;
  final String? passwordHash;
  final int discussionsCount;
  final DateTime? createdAt;

  const ResearchRoom({
    required this.id,
    required this.title,
    required this.description,
    required this.creatorId,
    required this.creatorName,
    this.categoryId,
    this.isPasswordProtected = false,
    this.passwordHash,
    this.discussionsCount = 0,
    this.createdAt,
  });

  bool get isCreatorOwned => creatorId.isNotEmpty;

  factory ResearchRoom.fromMap(String id, Map<String, dynamic> map) {
    DateTime? created;
    final raw = map['createdAt'];
    if (raw is Timestamp) created = raw.toDate();

    return ResearchRoom(
      id: id,
      title: map['title']?.toString() ??
          appTr('غرفة بحثية', 'Research room'),
      description: map['description']?.toString() ?? '',
      creatorId: map['creatorId']?.toString() ?? '',
      creatorName: map['creatorName']?.toString() ??
          appTr('باحث', 'Researcher'),
      categoryId: map['categoryId']?.toString(),
      isPasswordProtected: map['isPasswordProtected'] == true,
      passwordHash: map['passwordHash']?.toString(),
      discussionsCount: _parseInt(map['discussionsCount']),
      createdAt: created,
    );
  }
}

class ResearchDiscussion {
  final String id;
  final String roomId;
  final String type;
  final String title;
  final String body;
  final String authorId;
  final String authorName;
  final List<String> tags;
  final String searchText;
  final int repliesCount;
  final DateTime? createdAt;

  const ResearchDiscussion({
    required this.id,
    required this.roomId,
    required this.type,
    required this.title,
    required this.body,
    required this.authorId,
    required this.authorName,
    this.tags = const [],
    this.searchText = '',
    this.repliesCount = 0,
    this.createdAt,
  });

  factory ResearchDiscussion.fromMap(String id, Map<String, dynamic> map) {
    DateTime? created;
    final raw = map['createdAt'];
    if (raw is Timestamp) created = raw.toDate();

    final tags = (map['tags'] as List<dynamic>?)
            ?.map((tag) => tag.toString())
            .toList() ??
        const [];

    return ResearchDiscussion(
      id: id,
      roomId: map['roomId']?.toString() ?? '',
      type: map['type']?.toString() ?? 'discussion',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      authorId: map['authorId']?.toString() ?? '',
      authorName: map['authorName']?.toString() ??
          appTr('باحث', 'Researcher'),
      tags: tags,
      searchText: map['searchText']?.toString() ?? '',
      repliesCount: _parseInt(map['repliesCount']),
      createdAt: created,
    );
  }

  bool matchesQuery(String query) {
    if (query.trim().isEmpty) return true;
    final q = query.trim().toLowerCase();
    return searchText.contains(q) ||
        title.toLowerCase().contains(q) ||
        body.toLowerCase().contains(q) ||
        authorName.toLowerCase().contains(q) ||
        tags.any((tag) => tag.toLowerCase().contains(q));
  }
}

class ResearchDiscussionReply {
  final String id;
  final String discussionId;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime? createdAt;

  const ResearchDiscussionReply({
    required this.id,
    required this.discussionId,
    required this.authorId,
    required this.authorName,
    required this.body,
    this.createdAt,
  });

  factory ResearchDiscussionReply.fromMap(
    String id,
    Map<String, dynamic> map, {
    required String discussionId,
  }) {
    DateTime? created;
    final raw = map['createdAt'];
    if (raw is Timestamp) created = raw.toDate();

    return ResearchDiscussionReply(
      id: id,
      discussionId: discussionId,
      authorId: map['authorId']?.toString() ?? '',
      authorName: map['authorName']?.toString() ??
          appTr('باحث', 'Researcher'),
      body: map['body']?.toString() ?? '',
      createdAt: created,
    );
  }
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
