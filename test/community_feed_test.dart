import 'package:acadegate/features/community/community_feed.dart';
import 'package:acadegate/features/community/community_models.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityPost _p(String id, int replies, int day) => CommunityPost(
      id: id,
      roomId: 'general',
      type: 'question',
      title: id,
      body: 'b',
      repliesCount: replies,
      createdAt: DateTime(2026, 1, day),
    );

void main() {
  final posts = [_p('a', 0, 1), _p('b', 5, 2), _p('c', 5, 3), _p('d', 0, 4)];

  test('latest sorts newest first', () {
    final ids = applyCommunityFeedView(posts, CommunityFeedView.latest)
        .map((p) => p.id)
        .toList();
    expect(ids, ['d', 'c', 'b', 'a']);
  });

  test('most active sorts by replies then newest', () {
    final ids = applyCommunityFeedView(posts, CommunityFeedView.mostActive)
        .map((p) => p.id)
        .toList();
    expect(ids, ['c', 'b', 'd', 'a']);
  });

  test('unanswered keeps only posts with no replies', () {
    final ids = applyCommunityFeedView(posts, CommunityFeedView.unanswered)
        .map((p) => p.id)
        .toList();
    expect(ids, ['d', 'a']);
  });

  test('views do not change the input list', () {
    applyCommunityFeedView(posts, CommunityFeedView.mostActive);
    expect(posts.first.id, 'a');
  });

  group('parseCommunityTags', () {
    test('splits on Latin and Arabic commas, semicolons and new lines', () {
      expect(parseCommunityTags('ذكاء, بيانات،إحصاء;طب\nكيمياء'),
          ['ذكاء', 'بيانات', 'إحصاء', 'طب', 'كيمياء']);
    });
    test('trims, drops empties and repeats', () {
      expect(parseCommunityTags(' a , ,A,b ,, '), ['a', 'b']);
    });
    test('caps count and length', () {
      final many = List.generate(15, (i) => 't$i').join(',');
      expect(parseCommunityTags(many).length, kCommunityMaxTags);
      expect(parseCommunityTags('x' * 80).single.length, kCommunityTagMaxLength);
    });
    test('empty input gives no tags', () {
      expect(parseCommunityTags('  ، , '), isEmpty);
    });
  });

  group('orderCommunityReplies', () {
    CommunityReply r(String id, int votes, int day) => CommunityReply(
          id: id,
          postId: 'p',
          authorId: 'u$id',
          authorName: id,
          body: 'b',
          upvotesCount: votes,
          createdAt: DateTime(2026, 1, day),
        );
    final replies = [r('a', 0, 1), r('b', 3, 2), r('c', 3, 3), r('d', 1, 4)];

    test('best answer first, then votes, then oldest', () {
      expect(orderCommunityReplies(replies, 'd').map((e) => e.id).toList(),
          ['d', 'b', 'c', 'a']);
    });
    test('without a best answer it orders by votes then oldest', () {
      expect(orderCommunityReplies(replies, '').map((e) => e.id).toList(),
          ['b', 'c', 'd', 'a']);
    });
    test('a best id that matches no reply is ignored', () {
      expect(orderCommunityReplies(replies, 'gone').map((e) => e.id).toList(),
          ['b', 'c', 'd', 'a']);
    });
  });
}
