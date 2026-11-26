import 'package:acadegate/features/community/community_report_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('report id is one per member per post', () {
    expect(communityReportId(uid: 'u1', postId: 'p1'), 'u1_p1');
    expect(communityReportId(uid: 'u1', postId: 'p1', replyId: ''), 'u1_p1');
  });

  test('report id is one per member per reply', () {
    expect(
      communityReportId(uid: 'u1', postId: 'p1', replyId: 'r9'),
      'u1_p1_r9',
    );
  });

  test('only known reasons exist', () {
    expect(CommunityReportReason.all, [
      'spam',
      'abuse',
      'impersonation',
      'other',
    ]);
  });
}
