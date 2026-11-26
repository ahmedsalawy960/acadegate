import 'package:acadegate/features/community/community_data.dart';
import 'package:acadegate/features/community/community_starter_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starter posts fit the post rules', () {
    final ids = <String>{};
    for (final p in kStarterPosts) {
      expect(ids.add(p.id), isTrue);
      expect(p.title.length, inInclusiveRange(1, 200));
      expect(p.body.length, inInclusiveRange(1, 10000));
      expect(CommunityPostType.allTypes, contains(p.type));
      expect(p.tags, isNotEmpty);
      expect(p.title, contains(' | '));
    }
    expect(kStarterPosts.length, 3);
  });

  test('starter circles have fixed unique ids and both languages', () {
    final ids = <String>{};
    for (final c in kStarterCircles) {
      expect(ids.add(c.id), isTrue);
      expect(ids.add(c.roomId), isTrue);
      expect(c.title, contains(' | '));
      expect(c.description, contains(c.descriptionAr));
      expect(c.description, contains(c.descriptionEn));
    }
    expect(kStarterCircles.length, 4);
    expect(
      kStarterCircles.map((c) => c.titleAr),
      containsAll([
        'مساعدة الإحصاء: اسأل عن تحليل نتائجك',
        'الكتابة الأكاديمية: نراجع فقراتنا معاً',
        'ابدأ بحثك: أفكار وأسئلة بحثية',
      ]),
    );
  });

  test('no tool or model names in starter texts', () {
    final all = [
      for (final p in kStarterPosts) '${p.title} ${p.body}',
      for (final c in kStarterCircles) '${c.title} ${c.description}',
    ].join(' ').toLowerCase();
    for (final banned in ['gpt', 'openai', 'claude', 'gemini', 'chatgpt']) {
      expect(all.contains(banned), isFalse);
    }
  });
}
