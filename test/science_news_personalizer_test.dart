import 'package:acadegate/features/profile/academic_profile.dart';
import 'package:acadegate/features/science_news/science_news_feeds.dart';
import 'package:acadegate/features/science_news/science_news_models.dart';
import 'package:acadegate/features/science_news/science_news_personalizer.dart';
import 'package:flutter_test/flutter_test.dart';

ScienceNewsItem _item({
  required String title,
  required String category,
  String summary = '',
  DateTime? publishedAt,
}) {
  return ScienceNewsItem(
    title: title,
    summary: summary,
    source: 'ScienceDaily',
    category: category,
    url: 'https://example.com/$title',
    publishedAt: publishedAt,
  );
}

void main() {
  final chemist = AcademicProfile(
    fullName: 'باحث',
    university: 'جامعة الأزهر',
    degree: 'دكتوراه',
    facultyCategory: 'Science',
    specialization: 'كيمياء تحليلية',
    researchInterest: 'امتزاز المعادن الثقيلة والرصاص',
    methodology: 'كمي',
    preferredLanguage: 'العربية',
    city: 'القاهرة',
  );

  test('weekly digest prefers chemistry over generic space news', () {
    final now = DateTime(2026, 9, 5);
    final items = [
      _item(
        title: 'NASA telescope images a distant galaxy',
        category: ScienceNewsCategory.astronomy,
        publishedAt: now.subtract(const Duration(days: 2)),
      ),
      _item(
        title: 'Lead adsorption on biochar measured by spectroscopy',
        category: ScienceNewsCategory.chemistry,
        summary: 'Analytical chemistry batch tests of heavy metals',
        publishedAt: now.subtract(const Duration(days: 1)),
      ),
      _item(
        title: 'A new chess engine ranking',
        category: ScienceNewsCategory.technology,
        publishedAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    final digest = ScienceNewsPersonalizer.weeklyDigest(
      items: items,
      profile: chemist,
      now: now,
    );

    expect(digest.isPersonalized, isTrue);
    expect(digest.focusLabel, contains('كيمياء'));
    expect(digest.items, isNotEmpty);
    expect(digest.items.first.item.title, contains('Lead adsorption'));
    expect(digest.items.first.score, greaterThan(0));
    expect(
      digest.items.first.item.title,
      isNot(contains('galaxy')),
    );
  });

  test('without a profile the digest is not researcher-specific', () {
    final digest = ScienceNewsPersonalizer.weeklyDigest(
      items: [
        _item(
          title: 'Generic platform headline',
          category: ScienceNewsCategory.general,
        ),
      ],
      profile: null,
    );
    expect(digest.isPersonalized, isFalse);
    expect(digest.focusLabel, isEmpty);
  });
}
