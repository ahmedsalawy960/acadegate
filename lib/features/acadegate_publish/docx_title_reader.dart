import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Source-order evidence for a title, before paragraph merging loses its role.
/// It never searches the bibliography or replaces an explicitly entered title.
class DocxTitleReader {
  static String? read(Uint8List bytes) {
    try {
      final entry = ZipDecoder()
          .decodeBytes(bytes)
          .findFile('word/document.xml');
      if (entry == null) return null;
      final doc = XmlDocument.parse(utf8.decode(entry.content as List<int>));
      final lines = <_TitleLine>[];
      for (final p in doc.descendants.whereType<XmlElement>().where(
        (e) => e.localName == 'p',
      )) {
        final runs = p.descendants.whereType<XmlElement>().where(
          (e) => e.localName == 'r',
        );
        final pieces = <(String, int)>[];
        for (final r in runs) {
          final text = r.descendants
              .whereType<XmlElement>()
              .where((e) => e.localName == 't')
              .map((e) => e.innerText)
              .join();
          final size = r.descendants
              .whereType<XmlElement>()
              .where((e) => e.localName == 'sz')
              .map(
                (e) =>
                    int.tryParse(
                      e.attributes
                              .where((a) => a.name.local == 'val')
                              .firstOrNull
                              ?.value ??
                          '',
                    ) ??
                    0,
              )
              .fold<int>(0, math.max);
          if (text.isNotEmpty) pieces.add((text, size));
        }
        final full = pieces
            .map((e) => e.$1)
            .join()
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (full.isEmpty) continue;
        if (_bodyBoundary(full)) break;
        final maxSize = pieces.fold<int>(0, (a, b) => math.max(a, b.$2));
        // A publisher's article-type label can share the paragraph with its
        // larger title. Use only distinctly larger runs, never guess words.
        final prominent = maxSize >= 26
            ? pieces
                  .where((e) => e.$2 >= maxSize - 1)
                  .map((e) => e.$1)
                  .join()
                  .trim()
            : full;
        final selected =
            prominent.length >= 24 && prominent.length >= full.length * .5
            ? prominent
            : full;
        lines.add(_TitleLine(selected, maxSize));
        if (lines.length >= 100) break;
      }
      String? best;
      var bestScore = -1e9;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!_candidate(line.text)) continue;
        var text = line.text;
        var end = i;
        if (line.size >= 26) {
          var skipped = 0;
          for (var j = i + 1; j < lines.length && j <= i + 5; j++) {
            final next = lines[j];
            if ((next.size - line.size).abs() <= 1 &&
                _continuation(next.text) &&
                text.length + next.text.length < 350) {
              text = '$text ${next.text}';
              end = j;
              skipped = 0;
            } else if (_metadata(next.text) && skipped < 2) {
              skipped++;
            } else {
              break;
            }
          }
        }
        final words = text.split(RegExp(r'\s+')).length;
        var score =
            math.min(line.size, 60).toDouble() + math.min(words, 14) - i * .65;
        if (i < 3) score += 12;
        if (end + 1 < lines.length && _byline(lines[end + 1].text)) score += 14;
        if (line.size == 0) score += 24;
        if (score > bestScore) {
          bestScore = score;
          best = text;
        }
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  static bool _bodyBoundary(String t) =>
      RegExp(
        r'^(?:\d+(?:\.\d+)*[.)]?\s+)?(?:Abstract|Summary|Introduction|Background|Methods|Materials and Methods|Results|Discussion|Conclusion|Conclusions|References|Bibliography|الملخص|المقدمة|المراجع)\s*[:.]?$',
        caseSensitive: false,
      ).hasMatch(t) ||
      RegExp(r'^(?:Abstract|الملخص)\s*[:.]', caseSensitive: false).hasMatch(t);

  static bool _candidate(String t) =>
      t.length >= 25 &&
      t.length <= 350 &&
      !_metadata(t) &&
      !_byline(t) &&
      !RegExp(r'[.!?]\s+[A-Z]|https?://|@|\{\{').hasMatch(t) &&
      (t.split(RegExp(r'\s+')).length >= 4 || t.length >= 35);
  static bool _continuation(String t) =>
      t.length >= 8 &&
      !_metadata(t) &&
      !_byline(t) &&
      !RegExp(r'@|https?://|[.!?]\s+[A-Z]').hasMatch(t);
  static bool _metadata(String t) =>
      RegExp(
        r'^(?:[/\s]*(?:preprint|submitted manuscript)|running\s+(?:head|title)|short\s+title|word\s+count|key\s*words|authors?\s*:|research\s+article|original\s+(?:research|article)|review\s*$|open\s+access|type\b|published\b|received\b|accepted\b|revised\b|edited\s+by|reviewed\s+by|doi\b|digital\s+object|citation\b|downloaded\b|document\s+(?:version|license)|publication\s+status|terms\s+and|link\s+to|copyright|©|p-?issn|e-?issn|correspond|abstract\s*[:.]|summary\s*[:.]|references\s*[:.]|table\s+\d|fig(?:ure)?\.?\s*\d)',
        caseSensitive: false,
      ).hasMatch(t) ||
      RegExp(
        r'\b(?:research information portal|journal of|jurnal|journal\s+pendidikan)\b',
        caseSensitive: false,
      ).hasMatch(t);
  static bool _byline(String t) {
    if (RegExp(
      r'@|\b(?:department|faculty|university|college|institute|laboratory|corresponding|PhD|Prof)\b',
      caseSensitive: false,
    ).hasMatch(t)) {
      return true;
    }
    // Affiliation marks attach to names, unlike standalone measurements or
    // years in research titles. Do not classify every numeric title as a name.
    final marked = RegExp(
      r'[A-Za-z][¹²³⁴⁵⁶⁷⁸⁹*]+|[A-Za-z][1-9](?:[, *]|$)',
    ).hasMatch(t);
    return marked &&
        !RegExp(
          r'\b(?:of|for|with|in|using|on|during|between)\b',
          caseSensitive: false,
        ).hasMatch(t) &&
        t.split(RegExp(r'\s+')).length >= 3;
  }
}

class _TitleLine {
  final String text;
  final int size;
  _TitleLine(this.text, this.size);
}
