import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/locale/app_translate.dart';
import '../moderation/approval_status.dart';
import 'community_data.dart';

class CommunityPost {
  final String? id;
  final String roomId;
  final String type;
  final String title;
  final String body;
  final String authorId;
  final String authorName;
  final List<String> tags;
  final int upvotesCount;
  final int repliesCount;
  final String approvalStatus;
  final String? eventDate;
  final String? university;
  final String? academicLink;
  final String? academicTitle;
  /// [PostAudienceScope.faculty] | [PostAudienceScope.specialization] | [PostAudienceScope.app]
  final String audienceScope;
  final String? facultyCategory;
  final String? targetSpecialization;
  final DateTime? createdAt;

  const CommunityPost({
    this.id,
    required this.roomId,
    required this.type,
    required this.title,
    required this.body,
    this.authorId = '',
    this.authorName = '',
    this.tags = const [],
    this.upvotesCount = 0,
    this.repliesCount = 0,
    this.approvalStatus = ApprovalStatus.approved,
    this.eventDate,
    this.university,
    this.academicLink,
    this.academicTitle,
    this.audienceScope = PostAudienceScope.faculty,
    this.facultyCategory,
    this.targetSpecialization,
    this.createdAt,
  });

  bool get isFromFirebase => id != null && id!.isNotEmpty;
  bool get isPubliclyVisible => ApprovalStatus.isPublic(approvalStatus);

  /// Whether [viewerUid] with optional profile fields may see this post in a feed.
  bool isVisibleToViewer({
    required String? viewerUid,
    String? viewerFaculty,
    String? viewerSpecialization,
  }) {
    if (viewerUid != null && authorId == viewerUid) return true;
    if (!isPubliclyVisible) return false;

    switch (audienceScope) {
      case PostAudienceScope.app:
        return true;
      case PostAudienceScope.specialization:
        final target = targetSpecialization?.trim() ?? '';
        if (target.isEmpty) return true;
        return PostAudienceScope.specializationMatches(
          viewerSpecialization ?? '',
          target,
        );
      case PostAudienceScope.faculty:
      default:
        return true;
    }
  }

  factory CommunityPost.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime? created;
    final rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      created = rawDate.toDate();
    }

    List<String> tags = const [];
    final rawTags = map['tags'];
    if (rawTags is List) {
      tags = rawTags.map((e) => e.toString()).toList();
    }

    final rawScope = map['audienceScope']?.toString() ?? PostAudienceScope.faculty;
    final scope = PostAudienceScope.all.contains(rawScope)
        ? rawScope
        : PostAudienceScope.faculty;

    return CommunityPost(
      id: id,
      roomId: map['roomId']?.toString() ?? 'general',
      type: map['type']?.toString() ?? CommunityPostType.discussion,
      title: map['title']?.toString() ??
          appTr('بدون عنوان', 'Untitled'),
      body: map['body']?.toString() ?? '',
      authorId: map['authorId']?.toString() ?? '',
      authorName: map['authorName']?.toString() ??
          appTr('طالب', 'Student'),
      tags: tags,
      upvotesCount: _parseInt(map['upvotesCount']),
      repliesCount: _parseInt(map['repliesCount']),
      approvalStatus:
          map['approvalStatus']?.toString() ?? ApprovalStatus.approved,
      eventDate: map['eventDate']?.toString(),
      university: map['university']?.toString(),
      academicLink: map['academicLink']?.toString(),
      academicTitle: map['academicTitle']?.toString(),
      audienceScope: scope,
      facultyCategory: map['facultyCategory']?.toString(),
      targetSpecialization: map['targetSpecialization']?.toString(),
      createdAt: created,
    );
  }
}

class CommunityReply {
  final String? id;
  final String postId;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime? createdAt;

  const CommunityReply({
    this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.body,
    this.createdAt,
  });

  factory CommunityReply.fromMap(
    Map<String, dynamic> map, {
    String? id,
    required String postId,
  }) {
    DateTime? created;
    final rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      created = rawDate.toDate();
    }

    return CommunityReply(
      id: id,
      postId: postId,
      authorId: map['authorId']?.toString() ?? '',
      authorName: map['authorName']?.toString() ??
          appTr('طالب', 'Student'),
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
