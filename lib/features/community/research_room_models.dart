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
  final int membersCount;
  final String? lastChannelActivity;
  final DateTime? lastActivityAt;
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
    this.membersCount = 0,
    this.lastChannelActivity,
    this.lastActivityAt,
    this.createdAt,
  });

  bool get isCreatorOwned => creatorId.isNotEmpty;

  factory ResearchRoom.fromMap(String id, Map<String, dynamic> map) {
    DateTime? created;
    final raw = map['createdAt'];
    if (raw is Timestamp) created = raw.toDate();
    DateTime? lastActivity;
    final lastRaw = map['lastActivityAt'];
    if (lastRaw is Timestamp) lastActivity = lastRaw.toDate();

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
      membersCount: _parseInt(map['membersCount']),
      lastChannelActivity: map['lastChannelActivity']?.toString(),
      lastActivityAt: lastActivity,
      createdAt: created,
    );
  }
}

class ResearchRoomMember {
  final String uid;
  final String role;
  final DateTime? joinedAt;

  const ResearchRoomMember({
    required this.uid,
    required this.role,
    this.joinedAt,
  });

  bool get isOwner => role == 'owner';
  bool get isModerator => role == 'moderator';

  factory ResearchRoomMember.fromMap(String uid, Map<String, dynamic> map) {
    DateTime? joined;
    final raw = map['joinedAt'] ?? map['grantedAt'];
    if (raw is Timestamp) joined = raw.toDate();
    final role = map['role']?.toString() ?? 'member';
    return ResearchRoomMember(
      uid: uid,
      role: role == 'owner' || role == 'moderator' || role == 'member'
          ? role
          : 'member',
      joinedAt: joined,
    );
  }
}

class ResearchRoomChannel {
  final String id;
  final String nameAr;
  final String nameEn;
  final int sortOrder;

  const ResearchRoomChannel({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.sortOrder = 0,
  });

  String label(bool isEnglish) => isEnglish ? nameEn : nameAr;

  factory ResearchRoomChannel.fromMap(String id, Map<String, dynamic> map) {
    return ResearchRoomChannel(
      id: id,
      nameAr: map['nameAr']?.toString() ?? id,
      nameEn: map['nameEn']?.toString() ?? id,
      sortOrder: _parseInt(map['sortOrder']),
    );
  }

  static const defaults = <ResearchRoomChannel>[
    ResearchRoomChannel(
      id: 'general',
      nameAr: 'عام',
      nameEn: 'General',
      sortOrder: 0,
    ),
    ResearchRoomChannel(
      id: 'references',
      nameAr: 'مراجع',
      nameEn: 'References',
      sortOrder: 1,
    ),
    ResearchRoomChannel(
      id: 'methodology',
      nameAr: 'منهجية',
      nameEn: 'Methodology',
      sortOrder: 2,
    ),
    ResearchRoomChannel(
      id: 'results',
      nameAr: 'نتائج',
      nameEn: 'Results',
      sortOrder: 3,
    ),
  ];
}

class ResearchChannelMessage {
  final String id;
  final String channelId;
  final String authorId;
  final String authorName;
  final String text;
  final String? academicLink;
  final String? academicTitle;
  final DateTime? createdAt;

  const ResearchChannelMessage({
    required this.id,
    required this.channelId,
    required this.authorId,
    required this.authorName,
    required this.text,
    this.academicLink,
    this.academicTitle,
    this.createdAt,
  });

  factory ResearchChannelMessage.fromMap(
    String id,
    Map<String, dynamic> map, {
    required String channelId,
  }) {
    DateTime? created;
    final raw = map['createdAt'];
    if (raw is Timestamp) created = raw.toDate();

    return ResearchChannelMessage(
      id: id,
      channelId: channelId,
      authorId: map['authorId']?.toString() ?? '',
      authorName: map['authorName']?.toString() ??
          appTr('باحث', 'Researcher'),
      text: map['text']?.toString() ?? '',
      academicLink: map['academicLink']?.toString(),
      academicTitle: map['academicTitle']?.toString(),
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
  final String? academicLink;
  final String? academicTitle;
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
    this.academicLink,
    this.academicTitle,
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
      academicLink: map['academicLink']?.toString(),
      academicTitle: map['academicTitle']?.toString(),
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
        (academicTitle?.toLowerCase().contains(q) ?? false) ||
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
