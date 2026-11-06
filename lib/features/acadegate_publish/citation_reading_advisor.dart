import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../ai_advisor/gemini_advisor_client.dart';
import 'bibliography_match.dart';
import 'citation_linker.dart';
import 'journal_format_rules.dart';
import 'manuscript_structure_advisor.dart';
import 'publish_models.dart';

/// One citation Gemini copied from a paragraph and tied to a bibliography id.
class CitationReading {
  final int blockIndex;
  final String phrase;
  final String referenceId;

  const CitationReading({
    required this.blockIndex,
    required this.phrase,
    required this.referenceId,
  });
}

/// Before a numbered export, Gemini reads each paragraph and names the
/// citations the local pattern missed. It does not rewrite the prose.
class CitationReadingAdvisor {
  CitationReadingAdvisor._();

  static int lastMarkedCount = 0;
  static String? lastDetail;

  static String statusMessage({required bool arabic}) {
    final n = lastMarkedCount;
    return switch (lastDetail) {
      'model' => arabic
          ? 'راجع AcadeGate $n استشهاداً وربطها بالمراجع قبل الترقيم.'
          : 'AcadeGate reviewed $n citations and linked them before numbering.',
      'timeout' => arabic
          ? 'لم تكتمل مراجعة الاستشهادات (انتهت المهلة).'
          : 'Citation review did not finish (timed out).',
      'error' => arabic
          ? 'لم تكتمل مراجعة الاستشهادات (تعذر الاتصال).'
          : 'Citation review did not finish (the request failed).',
      'retired' => arabic
          ? 'لم تكتمل مراجعة الاستشهادات (خدمة AcadeGate قيد التحديث).'
          : 'Citation review did not finish (AcadeGate service is updating).',
      'quota' => arabic
          ? 'لم تكتمل مراجعة الاستشهادات (انتهى رصيد اليوم في AcadeGate).'
          : 'Citation review did not finish (today’s AcadeGate quota is used up).',
      'unavailable' => arabic
          ? 'مراجعة الاستشهادات غير متاحة.'
          : 'Citation review is not available.',
      _ => arabic
          ? 'لم تُربط استشهادات إضافية.'
          : 'No extra citations were linked.',
    };
  }

  static Future<PublishManuscript> insertMarkers(
    PublishManuscript manuscript,
  ) async {
    lastMarkedCount = 0;
    if (manuscript.references.isEmpty) {
      lastDetail = 'empty';
      return manuscript;
    }
    if (!_modelAvailable) {
      lastDetail = 'unavailable';
      return manuscript;
    }
    try {
      final readings = await _ask(manuscript).timeout(const Duration(seconds: 180));
      if (readings.isEmpty) {
        if (lastDetail != 'error' && lastDetail != 'timeout') {
          lastDetail = 'empty';
        }
        return manuscript;
      }
      final applied = applyReadings(manuscript: manuscript, readings: readings);
      lastMarkedCount = applied.marked;
      lastDetail = applied.marked > 0 ? 'model' : 'empty';
      return applied.manuscript;
    } catch (e) {
      debugPrint('citation reading: $e');
      lastDetail = e is TimeoutException ? 'timeout' : 'error';
      return manuscript;
    }
  }

  /// Replace exact phrases with `{{cite:id}}`. Unknown ids and equation
  /// numbers are left as printed.
  static ({PublishManuscript manuscript, int marked}) applyReadings({
    required PublishManuscript manuscript,
    required List<CitationReading> readings,
  }) {
    if (readings.isEmpty) return (manuscript: manuscript, marked: 0);
    final ids = {for (final ref in manuscript.references) ref.id};
    final byBlock = <int, List<CitationReading>>{};
    for (final reading in readings) {
      if (!ids.contains(reading.referenceId)) continue;
      final phrase = reading.phrase.trim();
      if (phrase.length < 8) continue;
      if (!RegExp(r'(?:19|20)\d{2}').hasMatch(phrase)) continue;
      byBlock.putIfAbsent(reading.blockIndex, () => []).add(
            CitationReading(
              blockIndex: reading.blockIndex,
              phrase: phrase,
              referenceId: reading.referenceId,
            ),
          );
    }
    if (byBlock.isEmpty) return (manuscript: manuscript, marked: 0);

    var marked = 0;
    var inReferences = false;
    final blocks = <ManuscriptBlock>[];
    for (var i = 0; i < manuscript.bodyBlocks.length; i++) {
      final block = manuscript.bodyBlocks[i];
      if (block.type == ManuscriptBlockType.heading &&
          JournalSectionLayout.isReferencesHeading(block.text)) {
        inReferences = true;
      }
      final readingsForBlock = byBlock[i];
      if (inReferences ||
          readingsForBlock == null ||
          _frozen(block)) {
        blocks.add(block);
        continue;
      }
      final phrases = [...readingsForBlock]
        ..sort((a, b) => b.phrase.length.compareTo(a.phrase.length));
      final text = _replacePhrases(block.text, phrases);
      final caption = block.caption == null
          ? null
          : _replacePhrases(block.caption!, phrases);
      marked += text.marked + (caption?.marked ?? 0);
      blocks.add(block.copyWith(
        text: text.text,
        caption: caption?.text,
      ));
    }
    return (
      manuscript: manuscript.copyWith(bodyBlocks: blocks),
      marked: marked,
    );
  }

  static List<CitationReading> parseReadings(String raw) {
    final out = <CitationReading>[];
    final seen = <String>{};
    void add(int? p, String? phrase, String? id) {
      if (p == null || phrase == null || id == null || id.isEmpty) return;
      final key = '$p|$id|$phrase';
      if (!seen.add(key)) return;
      out.add(CitationReading(blockIndex: p, phrase: phrase, referenceId: id));
    }

    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final decoded = jsonDecode(raw.substring(start, end + 1));
        if (decoded is Map && decoded['cites'] is List) {
          for (final item in decoded['cites'] as List) {
            if (item is! Map) continue;
            add(
              int.tryParse('${item['p']}'),
              item['phrase']?.toString(),
              item['id']?.toString(),
            );
          }
          if (out.isNotEmpty) return out;
        }
      } catch (_) {}
    }

    for (final m in RegExp(r'\{[^{}]+\}').allMatches(raw)) {
      final obj = m.group(0)!;
      add(
        int.tryParse(RegExp(r'"p"\s*:\s*(\d+)').firstMatch(obj)?.group(1) ?? ''),
        _jsonString(obj, 'phrase'),
        _jsonString(obj, 'id'),
      );
    }
    return out;
  }

  static bool get _modelAvailable {
    try {
      return GeminiAdvisorClient.isAvailable;
    } catch (_) {
      return false;
    }
  }

  static bool _frozen(ManuscriptBlock block) {
    if (block.type == ManuscriptBlockType.equation) return true;
    if (block.type == ManuscriptBlockType.heading) return true;
    final role = ManuscriptStructureAdvisor.numberRoleFor(block.text);
    if (role == 'equation_number' || role == 'float_number') return true;
    if (CitationLinker.isEquationNumberLine(block.text)) return true;
    if (CitationLinker.looksLikeBibliographyLine(block.text)) return true;
    return false;
  }

  static Future<List<CitationReading>> _ask(PublishManuscript manuscript) async {
    final bib = StringBuffer();
    for (final ref in manuscript.references.take(160)) {
      final names = BibliographyMatch.lastNamesOf(ref).take(6).join('; ');
      final year = BibliographyMatch.yearOf(ref);
      bib.writeln('${ref.id}\t$year\t$names');
    }
    final paragraphs = <({int index, String text})>[];
    var inReferences = false;
    for (var i = 0; i < manuscript.bodyBlocks.length; i++) {
      final block = manuscript.bodyBlocks[i];
      if (block.type == ManuscriptBlockType.heading &&
          JournalSectionLayout.isReferencesHeading(block.text)) {
        inReferences = true;
      }
      if (inReferences || block.type != ManuscriptBlockType.paragraph) continue;
      if (_frozen(block)) continue;
      final text = block.text.trim();
      if (text.length < 12) continue;
      if (!RegExp(r'(?:19|20)\d{2}|\[[0-9]').hasMatch(text)) continue;
      paragraphs.add((index: i, text: text));
    }
    if (paragraphs.isEmpty) return const [];

    final out = <CitationReading>[];
    const batch = 4;
    for (var start = 0; start < paragraphs.length; start += batch) {
      final slice = paragraphs.skip(start).take(batch).toList();
      try {
        final found = await _askBatch(bib.toString(), slice)
            .timeout(const Duration(seconds: 45));
        out.addAll(found);
      } catch (e) {
        debugPrint('citation reading batch: $e');
      }
    }
    return out;
  }

  static Future<List<CitationReading>> _askBatch(
    String bibliography,
    List<({int index, String text})> paragraphs,
  ) async {
    final body = StringBuffer();
    for (final paragraph in paragraphs) {
      for (final chunk in _chunks(paragraph.text)) {
        body.writeln('${paragraph.index}\t$chunk');
      }
    }
    final result = await GeminiAdvisorClient.instance.generateResult(
      preferPro: true,
      maxOutputTokens: 8192,
      systemPrompt: '''
You are reading a scientific manuscript immediately before it is exported. Do not rewrite, translate, or add words.

Bibliography lines are: id, tab, year, tab, surnames.
Paragraph lines are: block index, tab, the author's exact text.

Find every in-text citation in the paragraphs. A citation is an author-year such as (Daun et al., 2011), Raghuram Ulu et al. (2003), or (Olabode and Arueva, 2016), including unusual spellings and compound surnames.
Copy phrase exactly from that paragraph, including parentheses.
id must be one bibliography id for that work. If the work is not in the bibliography, omit the citation.
Do not mark equation numbers, dotted equation leaders, or Fig./Figure/Table/Scheme numbers.
Return only JSON: {"cites":[{"p":0,"phrase":"(Daun et al., 2011)","id":"daun"}]}
''',
      userMessage: 'Bibliography:\n$bibliography\nParagraphs:\n$body',
    );
    if (!result.isSuccess) {
      lastDetail = ManuscriptStructureAdvisor.detailForGeminiError(result.error);
      debugPrint('citation reading: ${result.error}');
      return const [];
    }
    return parseReadings(result.text!);
  }

  static List<String> _chunks(String text) {
    if (text.length <= 1800) return [text];
    final out = <String>[];
    var i = 0;
    var guard = 0;
    while (i < text.length && guard < 8) {
      final end = i + 1800 < text.length ? i + 1800 : text.length;
      out.add(text.substring(i, end));
      if (end == text.length) break;
      i = end - 200;
      guard++;
    }
    return out;
  }

  static ({String text, int marked}) _replacePhrases(
    String text,
    List<CitationReading> phrases,
  ) {
    var current = text;
    var marked = 0;
    for (final reading in phrases) {
      final next = _replaceOne(current, reading.phrase, reading.referenceId);
      marked += next.marked;
      current = next.text;
    }
    return (text: current, marked: marked);
  }

  static ({String text, int marked}) _replaceOne(
    String text,
    String phrase,
    String id,
  ) {
    final buffer = StringBuffer();
    var cursor = 0;
    var marked = 0;
    while (cursor < text.length) {
      final at = text.indexOf(phrase, cursor);
      if (at < 0) {
        buffer.write(text.substring(cursor));
        break;
      }
      final before = text.substring(0, at);
      if (CitationLinker.isEquationLeader(before) ||
          CitationLinker.isFloatNumberContext(before) ||
          CitationLinker.isEquationNumberContext(before)) {
        buffer.write(text.substring(cursor, at + phrase.length));
        cursor = at + phrase.length;
        continue;
      }
      buffer.write(text.substring(cursor, at));
      buffer.write('{{cite:$id}}');
      marked++;
      cursor = at + phrase.length;
    }
    return (text: buffer.toString(), marked: marked);
  }

  static String? _jsonString(String object, String key) {
    final m = RegExp(
      '"$key"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"',
    ).firstMatch(object);
    if (m == null) return null;
    try {
      return jsonDecode('"${m.group(1)}"') as String;
    } catch (_) {
      return m.group(1);
    }
  }
}
