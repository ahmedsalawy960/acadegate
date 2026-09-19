import 'thesis_studio_kind.dart';
import 'thesis_studio_length.dart';

/// Reads length and instruction from ANY paragraph command — no field-specific words.
class ThesisCommandSpec {
  final String command;
  final int targetWords;
  final int? requestedPages;
  final int? requestedWords;

  const ThesisCommandSpec({
    required this.command,
    required this.targetWords,
    this.requestedPages,
    this.requestedWords,
  });

  int get estimatedPages =>
      (targetWords / ThesisLengthBudget.wordsPerPage)
          .ceil()
          .clamp(1, ThesisLengthBudget.maxCommandPages);

  bool get hasExplicitLength =>
      requestedPages != null || requestedWords != null;

  /// Command with page/word requests removed — used as the literature query.
  String get topicText {
    var t = command;
    t = t.replaceAll(
      RegExp(r'(\d{1,3})\s*(?:صفحات|صفحة|صفحه|pages?)', caseSensitive: false),
      ' ',
    );
    t = t.replaceAll(
      RegExp(r'(\d{3,5})\s*(?:كلمات|كلمة|words?)', caseSensitive: false),
      ' ',
    );
    t = t.replaceAll(
      RegExp(
        r'\b(?:لا تقل عن|at least|minimum of|write|generate|توليد|اكتب)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static ThesisCommandSpec parse(
    String command, {
    required ThesisChapterDepth depth,
    String? chapterId,
  }) {
    final text = _normalizeDigits(command.trim());
    final pages = _parsePages(text);
    final words = _parseWords(text);
    var floor = ThesisLengthBudget.paragraphWords(depth);
    if (chapterId == 'literature' && depth == ThesisChapterDepth.full) {
      floor = ThesisLengthBudget.literatureParagraphWords;
    }
    var target = floor;
    if (pages != null) {
      target = pages * ThesisLengthBudget.wordsPerPage;
    } else if (words != null) {
      target = words;
    }
    if (depth == ThesisChapterDepth.scaffold) {
      target = target.clamp(floor, ThesisLengthBudget.scaffoldCommandWords);
    } else {
      target = target.clamp(floor, ThesisLengthBudget.maxCommandWords);
    }
    return ThesisCommandSpec(
      command: text,
      targetWords: target,
      requestedPages: pages,
      requestedWords: words,
    );
  }

  static String _normalizeDigits(String text) {
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      final e = eastern.indexOf(ch);
      if (e >= 0) {
        buffer.write(e);
        continue;
      }
      final p = persian.indexOf(ch);
      if (p >= 0) {
        buffer.write(p);
        continue;
      }
      buffer.write(ch);
    }
    return buffer.toString();
  }

  static int? _parsePages(String text) {
    final before = RegExp(
      r'(\d{1,3})\s*[-–]?\s*(?:صفحات|صفحة|صفحه|pages?)',
      caseSensitive: false,
    ).firstMatch(text);
    final after = RegExp(
      r'(?:صفحات|صفحة|صفحه|pages?)\s*[-–]?\s*(\d{1,3})',
      caseSensitive: false,
    ).firstMatch(text);
    final match = before ?? after;
    if (match == null) return null;
    final n = int.tryParse(match.group(1) ?? '');
    if (n == null) return null;
    return n.clamp(1, ThesisLengthBudget.maxCommandPages);
  }

  static int? _parseWords(String text) {
    final match = RegExp(
      r'(\d{3,5})\s*(?:كلمات|كلمة|words?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }
}
