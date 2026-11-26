import 'package:acadegate/features/community/community_attachment_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only images and pdf are accepted', () {
    for (final ok in ['a.png', 'b.JPG', 'c.jpeg', 'd.webp', 'e.gif', 'f.PDF']) {
      expect(communityAttachmentError(fileName: ok, sizeBytes: 1000), isNull);
    }
    for (final bad in [
      'a.zip',
      'b.docx',
      'c.mp4',
      'd.mp3',
      'e.exe',
      'f.html',
      'g.svg',
      'noext',
      'trailingdot.',
    ]) {
      expect(
        communityAttachmentError(fileName: bad, sizeBytes: 1000),
        isNotNull,
        reason: bad,
      );
    }
  });

  test('size limit is 5 MB and empty files are refused', () {
    expect(kCommunityAttachmentMaxBytes, 5 * 1024 * 1024);
    expect(
      communityAttachmentError(
        fileName: 'a.pdf',
        sizeBytes: kCommunityAttachmentMaxBytes,
      ),
      isNull,
    );
    expect(
      communityAttachmentError(
        fileName: 'a.pdf',
        sizeBytes: kCommunityAttachmentMaxBytes + 1,
      ),
      isNotNull,
    );
    expect(
      communityAttachmentError(fileName: 'a.pdf', sizeBytes: 0),
      isNotNull,
    );
  });

  test('mime follows the extension', () {
    expect(kCommunityAttachmentMimeByExt['pdf'], 'application/pdf');
    expect(kCommunityAttachmentMimeByExt['jpg'], 'image/jpeg');
  });
}
