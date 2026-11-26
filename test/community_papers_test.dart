import 'package:acadegate/features/community/community_models.dart';
import 'package:acadegate/features/community/community_papers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePaperInput', () {
    test('every way of writing one DOI gives the same key', () {
      const inputs = [
        '10.1038/S41586-020-2649-2',
        'doi:10.1038/s41586-020-2649-2',
        'https://doi.org/10.1038/s41586-020-2649-2',
        'http://dx.doi.org/10.1038/s41586-020-2649-2?utm_source=x',
        '  https://www.nature.com/articles/10.1038/s41586-020-2649-2#abstract ',
        'DOI: 10.1038/s41586-020-2649-2.',
      ];
      final keys = inputs.map((i) => normalizePaperInput(i)?.key).toSet();
      expect(keys, {'doi:10.1038/s41586-020-2649-2'});
      expect(normalizePaperInput(inputs.first)!.link,
          'https://doi.org/10.1038/s41586-020-2649-2');
    });

    test('same URL with tracking, www, case, fragment and slash matches', () {
      final a = normalizePaperInput('https://www.Example.org/papers/42/?utm_source=a&id=7#top');
      final b = normalizePaperInput('http://example.org/papers/42?id=7&fbclid=zz');
      expect(a!.key, b!.key);
      expect(a.key, 'url:example.org/papers/42?id=7');
    });

    test('different papers get different keys', () {
      expect(normalizePaperInput('https://example.org/a')!.key,
          isNot(normalizePaperInput('https://example.org/b')!.key));
      expect(normalizePaperInput('https://example.org/p?id=1')!.key,
          isNot(normalizePaperInput('https://example.org/p?id=2')!.key));
    });

    test('rejects empty, non-http and text that is not a link', () {
      expect(normalizePaperInput(''), isNull);
      expect(normalizePaperInput('just some words'), isNull);
      expect(normalizePaperInput('javascript:alert(1)'), isNull);
      expect(normalizePaperInput('ftp://example.org/x'), isNull);
    });

    test('keys are capped', () {
      expect(normalizePaperInput('https://example.org/${'a' * 300}'), isNull);
    });
  });

  group('groupPaperPosts and filterPapers', () {
    CommunityPost p(String id, String key, String paperTitle, int replies, int day) =>
        CommunityPost(
          id: id,
          roomId: kPapersRoomId,
          type: 'question',
          title: 'post $id',
          body: 'b',
          paperKey: key,
          academicTitle: paperTitle,
          academicLink: 'https://doi.org/x',
          repliesCount: replies,
          createdAt: DateTime(2026, 1, day),
        );

    final posts = [
      p('1', 'doi:a', 'Paper A', 2, 1),
      p('2', 'doi:b', 'Paper B', 0, 5),
      p('3', 'doi:a', 'Other name', 1, 9),
      CommunityPost(roomId: 'general', type: 'question', title: 't', body: 'b'),
    ];

    test('groups by paper, counts, newest activity first', () {
      final papers = groupPaperPosts(posts);
      expect(papers.map((e) => e.key).toList(), ['doi:a', 'doi:b']);
      expect(papers.first.postsCount, 2);
      expect(papers.first.repliesCount, 3);
      expect(papers.first.title, 'Paper A');
    });

    test('search by title or doi, empty keeps all', () {
      final papers = groupPaperPosts(posts);
      expect(filterPapers(papers, 'paper b').single.key, 'doi:b');
      expect(filterPapers(papers, 'DOI:A').single.key, 'doi:a');
      expect(filterPapers(papers, ' ').length, 2);
    });
  });
}
