import 'community_models.dart';

/// How many room posts one page loads.
const int kCommunityFeedPageSize = 20;
const int kCommunityMaxTags = 10;
const int kCommunityTagMaxLength = 30;

/// A page of room posts and whether more may exist.
class CommunityFeed {
  const CommunityFeed({required this.posts, required this.hasMore});

  final List<CommunityPost> posts;
  final bool hasMore;
}

enum CommunityFeedView { latest, mostActive, unanswered }

/// Orders and filters the loaded posts of a room. Pure, so it is easy to test.
List<CommunityPost> applyCommunityFeedView(
  List<CommunityPost> posts,
  CommunityFeedView view,
) {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  int byNewest(CommunityPost a, CommunityPost b) =>
      (b.createdAt ?? epoch).compareTo(a.createdAt ?? epoch);

  switch (view) {
    case CommunityFeedView.latest:
      return [...posts]..sort(byNewest);
    case CommunityFeedView.mostActive:
      return [...posts]..sort((a, b) {
          final byReplies = b.repliesCount.compareTo(a.repliesCount);
          return byReplies != 0 ? byReplies : byNewest(a, b);
        });
    case CommunityFeedView.unanswered:
      return posts.where((p) => p.repliesCount == 0).toList()..sort(byNewest);
  }
}

/// Splits a tags field on "," "،" ";" "؛" and new lines. Trims, drops empty
/// and repeated tags (ignoring case), cuts long tags and keeps the first
/// [kCommunityMaxTags].
List<String> parseCommunityTags(String raw) {
  final seen = <String>{};
  final tags = <String>[];
  for (final part in raw.split(RegExp(r'[,،;؛\n\r]'))) {
    var tag = part.trim();
    if (tag.isEmpty) continue;
    if (tag.length > kCommunityTagMaxLength) {
      tag = tag.substring(0, kCommunityTagMaxLength).trim();
    }
    if (seen.add(tag.toLowerCase())) tags.add(tag);
    if (tags.length >= kCommunityMaxTags) break;
  }
  return tags;
}

/// Reply order: the best answer first, then most helpful votes, then oldest.
/// A [bestReplyId] that matches no reply (deleted) is ignored.
List<CommunityReply> orderCommunityReplies(
  List<CommunityReply> replies,
  String bestReplyId,
) {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  final sorted = [...replies];
  sorted.sort((a, b) {
    final aBest = bestReplyId.isNotEmpty && a.id == bestReplyId;
    final bBest = bestReplyId.isNotEmpty && b.id == bestReplyId;
    if (aBest != bBest) return aBest ? -1 : 1;
    final byVotes = b.upvotesCount.compareTo(a.upvotesCount);
    if (byVotes != 0) return byVotes;
    return (a.createdAt ?? epoch).compareTo(b.createdAt ?? epoch);
  });
  return sorted;
}
