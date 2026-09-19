import '../profile/academic_profile.dart';
import 'store_catalog_service.dart';
import 'store_categories.dart';

/// ترشيح منتجات من الملف الأكاديمي + كلمات موضوع البحث.
class StoreRecommendationEngine {
  StoreRecommendationEngine._();
  static final StoreRecommendationEngine instance =
      StoreRecommendationEngine._();

  List<StoreCatalogProduct> recommend({
    required List<StoreCatalogProduct> products,
    AcademicProfile? profile,
    String topic = '',
    int limit = 12,
  }) {
    final tokens = _tokens([
      topic,
      profile?.researchInterest ?? '',
      profile?.specialization ?? '',
      profile?.resolvedFacultyCategory ?? '',
      ...?profile?.skills,
    ]);
    if (tokens.isEmpty || products.isEmpty) {
      return products
          .where((p) => p.orderCount > 0)
          .take(limit)
          .toList();
    }

    final faculty = profile?.resolvedFacultyCategory?.trim() ?? '';
    final scored = <({StoreCatalogProduct p, int score})>[];

    for (final p in products) {
      if (p.isDirectoryListing && p.price <= 0) {
        // still allow directory if text matches strongly
      }
      var score = 0;
      final hay = [
        p.name,
        p.description,
        p.brand,
        p.grade,
        p.categoryCanonical,
        p.categoryRaw,
        p.storeName,
        ...p.certifications,
        ...p.badges,
      ].join(' ').toLowerCase();

      for (final t in tokens) {
        if (hay.contains(t)) score += t.length >= 4 ? 3 : 2;
      }

      final cat = p.category;
      if (faculty.isNotEmpty && cat != null) {
        if (_facultyMatchesCategory(faculty, cat)) score += 8;
      }

      if (p.isVerifiedSeller) score += 1;
      if (p.orderCount > 0) score += 1;
      if (score > 0) scored.add((p: p, score: score));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.p.orderCount.compareTo(a.p.orderCount);
    });
    return scored.take(limit).map((e) => e.p).toList();
  }

  bool _facultyMatchesCategory(String faculty, StoreCategory cat) {
    final f = faculty.toLowerCase();
    final id = cat.id.toLowerCase();
    final title = cat.title.toLowerCase();
    if (id.contains(f) || f.contains(id)) return true;
    if (title.contains(f)) return true;
    // loose maps
    if (f.contains('engin') && id.contains('engine')) return true;
    if (f.contains('med') && (id.contains('med') || id.contains('pharm'))) {
      return true;
    }
    if (f.contains('chem') && id.contains('chem')) return true;
    if ((f.contains('cs') || f.contains('comput')) &&
        (id.contains('comput') || id.contains('electr'))) {
      return true;
    }
    if (f.contains('agri') && id.contains('agri')) return true;
    return false;
  }

  Set<String> _tokens(List<String> parts) {
    final out = <String>{};
    for (final part in parts) {
      final cleaned = part
          .toLowerCase()
          .replaceAll(RegExp(r'[^\u0600-\u06FFa-z0-9\s]'), ' ');
      for (final w in cleaned.split(RegExp(r'\s+'))) {
        if (w.length < 3) continue;
        out.add(w);
      }
    }
    return out;
  }
}
