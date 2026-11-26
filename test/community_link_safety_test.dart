import 'package:acadegate/features/community/community_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isSafeCommunityLink', () {
    test('accepts http and https links', () {
      expect(isSafeCommunityLink('https://doi.org/10.1000/xyz'), isTrue);
      expect(isSafeCommunityLink(' http://example.com/paper.pdf '), isTrue);
    });

    test('rejects other schemes and malformed values', () {
      expect(isSafeCommunityLink('javascript:alert(1)'), isFalse);
      expect(isSafeCommunityLink('tel:+201000000000'), isFalse);
      expect(isSafeCommunityLink('intent://scan#Intent;end'), isFalse);
      expect(isSafeCommunityLink('file:///etc/passwd'), isFalse);
      expect(isSafeCommunityLink('doi.org/10.1000/xyz'), isFalse);
      expect(isSafeCommunityLink('https://'), isFalse);
      expect(isSafeCommunityLink(''), isFalse);
    });
  });
}
