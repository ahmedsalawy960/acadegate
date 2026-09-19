import '../store_catalog_service.dart';
import 'store_custom_fit_models.dart';

/// ترتيب محلي سريع قبل/بدل استجابة Gemini — يقلّص الكتالوج للمرشّحين.
class StoreCustomFitMatcher {
  StoreCustomFitMatcher._();
  static final StoreCustomFitMatcher instance = StoreCustomFitMatcher._();

  List<StoreCatalogProduct> rankCandidates({
    required List<StoreCatalogProduct> catalog,
    required String specsText,
    CustomFitRequirements? requirements,
    int limit = 40,
  }) {
    final tokens = _tokens([
      specsText,
      requirements?.summaryAr ?? '',
      requirements?.summaryEn ?? '',
      requirements?.equipmentOrContext ?? '',
      ...?requirements?.criticalSpecs,
      ...?requirements?.materialsHints,
      ...?requirements?.keywords,
    ]);
    // بدون كلمات مستخرجة لا نُرجع منتجات عشوائية من الكتالوج
    if (tokens.isEmpty || catalog.isEmpty) {
      return const [];
    }

    final scored = <({StoreCatalogProduct p, int score})>[];
    for (final p in catalog) {
      final hay = [
        p.name,
        p.description,
        p.brand,
        p.grade,
        p.unit,
        p.sku,
        p.categoryCanonical,
        p.categoryRaw,
        p.storeName,
        ...p.certifications,
        ...p.badges,
      ].join(' ').toLowerCase();

      var score = 0;
      for (final t in tokens) {
        if (hay.contains(t)) {
          score += t.length >= 5 ? 4 : (t.length >= 3 ? 2 : 1);
        }
      }
      if (p.isVerifiedSeller) score += 1;
      if (p.inStock) score += 1;
      if (score > 0) scored.add((p: p, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    if (scored.isEmpty) {
      return const [];
    }
    return scored.take(limit).map((e) => e.p).toList();
  }

  /// مطابقة محلية احتياطية عند فشل/غياب AI.
  List<CustomFitMatchItem> localMatches({
    required List<StoreCatalogProduct> candidates,
    required String specsText,
    CustomFitRequirements? requirements,
    int limit = 8,
  }) {
    final ranked = rankCandidates(
      catalog: candidates,
      specsText: specsText,
      requirements: requirements,
      limit: limit * 3,
    );
    final tokens = _tokens([
      specsText,
      ...?requirements?.keywords,
      ...?requirements?.criticalSpecs,
    ]);
    final out = <CustomFitMatchItem>[];
    for (final p in ranked.take(limit)) {
      final hay = [
        p.name,
        p.description,
        p.grade,
        p.brand,
        p.categoryCanonical,
      ].join(' ').toLowerCase();
      var hits = 0;
      for (final t in tokens) {
        if (hay.contains(t)) hits++;
      }
      final denom = tokens.isEmpty ? 1 : tokens.length;
      final pct = ((hits / denom) * 100).round().clamp(35, 92);
      out.add(
        CustomFitMatchItem(
          productId: p.id,
          productName: p.name,
          matchPercent: pct,
          whyAr: 'تطابق كلمات المواصفات مع وصف المنتج في الكتالوج.',
          whyEn: 'Keyword overlap between your specs and the catalog listing.',
          gapAr: pct < 80
              ? 'تحقق يدوياً من المقاسات والدرجات قبل الشراء.'
              : 'يُفضّل تأكيد التوافق مع جهازك قبل الطلب.',
          gapEn: pct < 80
              ? 'Verify dimensions and grades manually before purchase.'
              : 'Confirm compatibility with your instrument before ordering.',
          product: p,
        ),
      );
    }
    return out;
  }

  Set<String> _tokens(List<String> parts) {
    final out = <String>{};
    for (final part in parts) {
      final cleaned = part
          .toLowerCase()
          .replaceAll(RegExp(r'[^\u0600-\u06FFa-z0-9.\-\s]'), ' ');
      for (final w in cleaned.split(RegExp(r'\s+'))) {
        if (w.length < 2) continue;
        // keep numeric specs like 0.22, 120c, mpa
        out.add(w);
      }
    }
    return out;
  }
}
