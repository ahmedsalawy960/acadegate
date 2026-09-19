import '../ai_advisor/grounded_work.dart';
import 'thesis_studio_kind.dart';
import 'thesis_studio_models.dart';

/// Sentence-level citation coverage against the harvested bibliography
/// (DOI when available, otherwise title/author/year from free indexes).
/// Unsupported claims are flagged; we do not invent support from unread PDFs.
class ThesisCitationReport {
  final int sourceCount;
  final Set<int> usedIndexes;
  final List<int> unusedIndexes;
  final List<String> unknownMarkers;
  final int citedSentenceCount;
  final int uncitedSentenceCount;
  final int scaffoldSentenceCount;

  const ThesisCitationReport({
    required this.sourceCount,
    required this.usedIndexes,
    required this.unusedIndexes,
    required this.unknownMarkers,
    required this.citedSentenceCount,
    required this.uncitedSentenceCount,
    required this.scaffoldSentenceCount,
  });

  int get reviewedSentences => citedSentenceCount + uncitedSentenceCount;

  double get citationCoverage {
    if (reviewedSentences == 0) return 0;
    return citedSentenceCount / reviewedSentences;
  }

  double get sourceUtilization {
    if (sourceCount == 0) return 0;
    return usedIndexes.length / sourceCount;
  }

  bool get hasUnknownMarkers => unknownMarkers.isNotEmpty;

  static final _marker = RegExp(r'\[(\d+)\]');
  static final _sentenceSplit = RegExp(r'(?<=[.!?؟。])\s+');

  /// Global list for the report card, plus paragraph-local catalogs so
  /// markers written against a paragraph harvest still count as used.
  static List<GroundedWork> bibliographyCatalog(ThesisDraft draft) {
    if (draft.literature.works.isNotEmpty) return draft.literature.works;
    final byKey = <String, GroundedWork>{};
    for (final w in draft.abstractReferences) {
      final key = w.mergeKey;
      if (key.isEmpty || key == 't:|0') continue;
      byKey.putIfAbsent(key, () => w);
    }
    for (final ch in draft.chapters) {
      for (final p in ch.paragraphs) {
        for (final w in p.references) {
          final key = w.mergeKey;
          if (key.isEmpty || key == 't:|0') continue;
          byKey.putIfAbsent(key, () => w);
        }
      }
    }
    return byKey.values.toList();
  }

  static ThesisCitationReport fromDraft(ThesisDraft draft) {
    final catalog = bibliographyCatalog(draft);
    final n = catalog.length;
    final used = <int>{};
    final unknown = <String>{};
    var cited = 0;
    var uncited = 0;
    var scaffold = 0;

    void collectMarkers(String text, {int? localMax}) {
      final max = localMax ?? n;
      for (final m in _marker.allMatches(text)) {
        final i = int.tryParse(m.group(1) ?? '');
        if (i == null) continue;
        if (max > 0 && i >= 1 && i <= max) {
          used.add(i);
        } else {
          unknown.add(m.group(0)!);
        }
      }
    }

    collectMarkers(draft.abstractText, localMax: draft.abstractReferences.isNotEmpty
        ? draft.abstractReferences.length
        : n);
    for (final ch in draft.chapters) {
      if (ch.paragraphs.isEmpty) {
        collectMarkers(ch.body);
        continue;
      }
      for (final p in ch.paragraphs) {
        final local = p.references.isNotEmpty ? p.references.length : n;
        collectMarkers(p.body, localMax: local);
      }
    }

    void scanSentences(String text, {required bool requireCite}) {
      final body = text.trim();
      if (body.isEmpty) return;
      final parts = body.split(_sentenceSplit).where((s) => s.trim().length > 24);
      for (final sentence in parts) {
        final marks = _marker.allMatches(sentence).toList();
        if (!requireCite) {
          scaffold++;
          continue;
        }
        if (marks.isNotEmpty) {
          cited++;
        } else {
          uncited++;
        }
      }
    }

    scanSentences(draft.abstractText, requireCite: true);
    for (final ch in draft.chapters) {
      final requireCite = ch.depth != ThesisChapterDepth.scaffold &&
          ch.id != 'results' &&
          ch.id != 'results_discussion' &&
          ch.id != 'discussion';
      if (ch.paragraphs.isEmpty) {
        scanSentences(ch.body, requireCite: requireCite);
      } else {
        for (final p in ch.paragraphs) {
          scanSentences(p.body, requireCite: requireCite);
        }
      }
    }

    final unused = [
      for (var i = 1; i <= n; i++)
        if (!used.contains(i)) i,
    ];
    return ThesisCitationReport(
      sourceCount: n,
      usedIndexes: used,
      unusedIndexes: unused,
      unknownMarkers: unknown.toList()..sort(),
      citedSentenceCount: cited,
      uncitedSentenceCount: uncited,
      scaffoldSentenceCount: scaffold,
    );
  }

  String asText({required bool arabic}) {
    final buf = StringBuffer();
    if (arabic) {
      buf.writeln('تقرير تحقق الاستشهادات — أكاديجيت');
      buf.writeln('دراسات في القائمة المجلوبة: $sourceCount');
      buf.writeln('مستخدمة في المتن: ${usedIndexes.length}');
      buf.writeln(
        'تغطية الجمل (فصول غير هيكلية): ${(citationCoverage * 100).toStringAsFixed(0)}%',
      );
      buf.writeln(
        'جمل مستشهدة: $citedSentenceCount · بلا استشهاد: $uncitedSentenceCount · هيكل نتائج: $scaffoldSentenceCount',
      );
      if (unusedIndexes.isNotEmpty) {
        buf.writeln('مصادر غير مستخدمة: ${unusedIndexes.map((i) => '[$i]').join(', ')}');
      }
      if (unknownMarkers.isNotEmpty) {
        buf.writeln('علامات غير موجودة في القائمة: ${unknownMarkers.join(', ')}');
      } else {
        buf.writeln('لا توجد علامات [n] خارج قائمة المراجع المجلوبة.');
      }
      buf.writeln(
        'التحقق يطابق العلامة برقم المرجع في القائمة (DOI إن وُجد، وإلا عنوان/رابط من الفهرس). لا ندّعي قراءة النص الكامل لكل ورقة.',
      );
    } else {
      buf.writeln('Citation verification report — AcadeGate');
      buf.writeln('Harvested studies in list: $sourceCount');
      buf.writeln('Cited in the draft: ${usedIndexes.length}');
      buf.writeln(
        'Sentence coverage (non-scaffold chapters): ${(citationCoverage * 100).toStringAsFixed(0)}%',
      );
      buf.writeln(
        'Cited sentences: $citedSentenceCount · uncited: $uncitedSentenceCount · results-frame: $scaffoldSentenceCount',
      );
      if (unusedIndexes.isNotEmpty) {
        buf.writeln(
          'Unused sources: ${unusedIndexes.map((i) => '[$i]').join(', ')}',
        );
      }
      if (unknownMarkers.isNotEmpty) {
        buf.writeln('Unknown markers (not in the list): ${unknownMarkers.join(', ')}');
      } else {
        buf.writeln('No [n] markers fall outside the harvested bibliography.');
      }
      buf.writeln(
        'This check matches markers to list numbers (DOI when present, otherwise title/link from the index). It does not claim the full PDF of every paper was read.',
      );
    }
    return buf.toString().trim();
  }

  List<({int index, GroundedWork work, bool used})> rows(ThesisDraft draft) {
    final catalog = bibliographyCatalog(draft);
    return [
      for (var i = 0; i < catalog.length; i++)
        (
          index: i + 1,
          work: catalog[i],
          used: usedIndexes.contains(i + 1),
        ),
    ];
  }
}
