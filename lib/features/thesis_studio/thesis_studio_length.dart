import 'thesis_studio_kind.dart';
import 'thesis_studio_models.dart';

/// Page slider → word budget. Academic page ≈ 280 words.
class ThesisLengthBudget {
  ThesisLengthBudget._();

  static const minPages = 12;
  static const maxPages = 80;
  static const defaultPages = 40;
  static const wordsPerPage = 280;

  static int clampPages(int pages) => pages.clamp(minPages, maxPages);

  /// How many DOI works to keep in the draft (scales with length).
  static int sourceLimit(int pages) {
    return (clampPages(pages) * 1.1).round().clamp(28, 80);
  }

  /// Candidates fetched before the AI relevance gate.
  static int harvestPool(int pages) {
    return (sourceLimit(pages) * 2.2).round().clamp(48, 120);
  }

  /// DOI works kept for one paragraph command (not the whole thesis).
  static int paragraphSourceLimit(int pages) {
    return (clampPages(pages) * 0.55).round().clamp(20, 48);
  }

  static int paragraphHarvestPool(int pages) {
    return (paragraphSourceLimit(pages) * 2.5).round().clamp(40, 100);
  }

  static int paragraphWords(ThesisChapterDepth depth) {
    return switch (depth) {
      ThesisChapterDepth.full => 320,
      ThesisChapterDepth.protocol => 220,
      ThesisChapterDepth.scaffold => 90,
    };
  }

  /// Default size for one literature-review subsection when the user did not
  /// request pages/words (~5 academic pages). Thesis LR chapters are multi-page.
  static const literatureParagraphWords = 1400;

  /// One Gemini pass cannot emit a long chapter; we grow in slices.
  static const wordsPerGrowPass = 1400;
  static const maxCommandPages = 80;
  static const maxCommandWords = 22400; // ≈ 80 pages
  static const scaffoldCommandWords = 400;
  static const maxGrowPasses = 36;

  static int commandSourceLimit(int targetWords) {
    final pages = (targetWords / wordsPerPage).ceil();
    return (pages * 3.2).round().clamp(40, 220);
  }

  static int commandHarvestPool(int targetWords) {
    return (commandSourceLimit(targetWords) * 2).clamp(60, 400);
  }

  static int estimatedPagesOf(String text) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (words <= 0) return 0;
    return (words / wordsPerPage).ceil();
  }

  static int wordCount(String text) =>
      text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  static int totalWords(int pages) => clampPages(pages) * wordsPerPage;

  static Map<String, int> chapterWordTargets(
    ThesisPlan plan,
    List<ThesisChapterTemplate> templates,
  ) {
    final bodyWords = (totalWords(plan.targetPages) * 0.90).round();
    final weights = <String, double>{
      for (final t in templates) t.id: _weight(t),
    };
    final sum = weights.values.fold<double>(0, (a, b) => a + b);
    if (sum <= 0) {
      return {for (final t in templates) t.id: 400};
    }
    return {
      for (final t in templates)
        t.id: ((bodyWords * (weights[t.id]! / sum)).round()).clamp(
          t.depth == ThesisChapterDepth.scaffold ? 80 : 500,
          9000,
        ),
    };
  }

  static double _weight(ThesisChapterTemplate t) {
    if (t.id == 'literature') return 3.6;
    return switch (t.depth) {
      ThesisChapterDepth.full => 2.8,
      ThesisChapterDepth.protocol => 2.0,
      ThesisChapterDepth.scaffold => 0.45,
    };
  }
}
