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
      final styleEntry = ZipDecoder().decodeBytes(bytes).findFile('word/styles.xml');
      final styles = <String, XmlElement>{};
      if (styleEntry != null) {
        final styleDoc = XmlDocument.parse(utf8.decode(styleEntry.content as List<int>));
        for (final style in styleDoc.descendants.whereType<XmlElement>()
            .where((e) => e.localName == 'style')) {
          final id = style.attributes.where((a) => a.name.local == 'styleId').firstOrNull?.value;
          if (id != null) styles[id] = style;
        }
      }
      String value(XmlElement e, String tag) => e.descendants.whereType<XmlElement>()
          .where((n) => n.localName == tag).firstOrNull?.attributes
          .where((a) => a.name.local == 'val').firstOrNull?.value ?? '';
      int styleSize(String id, [Set<String>? visited]) {
        final seen = visited ?? <String>{};
        if (!seen.add(id)) return 0;
        final style = styles[id];
        if (style == null) return 0;
        return int.tryParse(value(style, 'sz')) ?? styleSize(value(style, 'basedOn'), seen);
      }
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
        if (_bodyBoundary(full) || RegExp(r'^Abstract\s+', caseSensitive: false).hasMatch(full)) break;
        final styleId = value(p, 'pStyle');
        final styleName = styles[styleId] == null ? styleId : value(styles[styleId]!, 'name');
        final role = '$styleId $styleName';
        final explicitTitle = RegExp(r'(?:^|[^a-z])title(?:$|[^a-z])', caseSensitive: false)
            .hasMatch(role.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')) &&
            !RegExp('subtitle', caseSensitive: false).hasMatch(role);
        final maxSize = math.max(styleSize(styleId), pieces.fold<int>(0, (a, b) => math.max(a, b.$2)));
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
            prominent.length >= 24 && (prominent.length >= full.length * .5 || _byline(full.substring(full.indexOf(prominent) + prominent.length)))
            ? prominent
            : full;
        lines.add(_TitleLine(selected, maxSize, explicitTitle));
        if (lines.length >= 100) break;
      }
      String? best;
      var bestScore = -1e9;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!_candidate(line.text) && !(i == 0 && line.size >= 36 &&
            line.text.length >= 12 && line.text.length < 25 &&
            !_metadata(line.text) && !_byline(line.text) &&
            line.text.split(RegExp(r'\s+')).length >= 2)) {
          continue;
        }
        var text = line.text;
        var end = i;
        if (line.size >= 26 || (line.size >= 24 && RegExp(r'\b(?:first|second|third|of|for|with|and|in|the|by|to)$', caseSensitive: false).hasMatch(line.text))) {
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
        if (line.explicitTitle) score += 80;
        if (end + 1 < lines.length && _byline(lines[end + 1].text) &&
            (i == 0 || !_candidate(lines[i - 1].text))) {
          score += 14;
        }
        if (line.size == 0 && !lines.any((l) => l.size >= 26 && _candidate(l.text))) {
          score += 24;
        }
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
      RegExp(r'^(?:[:.\s]*)(?:ملخص|الملخص|مستخلص|المستخلص)(?:$|[\s:])').hasMatch(_plainArabic(t)) ||

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
      (t.split(RegExp(r'\s+')).length >= 4 || t.length >= 35 ||
        (!t.contains(' ') && RegExp(r'[a-z][A-Z]').allMatches(t).length >= 3));
  static bool _continuation(String t) =>
      t.length >= 8 &&
      !_metadata(t) &&
      !_byline(t) &&
      !RegExp(r'@|https?://|[.!?]\s+[A-Z]').hasMatch(t);
  static bool _metadata(String t) =>
      _arabicPublicationMetadata(t) ||

      RegExp(
        r'^(?:abstract\s|draft\s*version|print\s+issn|online\s+issn|provided proper attribution|reproduce the tables and figures|scholarly works|arxiv\s*:|[/\s]*(?:preprint|submitted manuscript)|running\s+(?:head|title)|short\s+title|word\s+count|key\s*words|authors?\s*:|research\s+article|original\s+(?:research|article)|review\s*$|open\s+access|type\b|published\b|received\b|accepted\b|revised\b|edited\s+by|reviewed\s+by|doi\b|digital\s+object|citation\b|downloaded\b|document\s+(?:version|license)|publication\s+status|terms\s+and|link\s+to|copyright|©|p-?issn|e-?issn|correspond|abstract\s*[:.]|summary\s*[:.]|references\s*[:.]|table\s+\d|fig(?:ure)?\.?\s*\d)',
        caseSensitive: false,
      ).hasMatch(t) ||
      RegExp(
        r'\b(?:research information portal|journal of|jurnal|journal\s+pendidikan)\b',
        caseSensitive: false,
      ).hasMatch(t);
  static String _plainArabic(String t) => t
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll(RegExp(r'\s+'), ' ').trim();

  static bool _arabicPublicationMetadata(String t) {
    final plain = _plainArabic(t);
    // Publisher names and issue strips, not scientific titles about journals.
    return RegExp(r'^(?:[\d\s()،.,–-]*|.*(?:العدد|المجلد|اجمللد).*)?(?:المجلة|المجله|مجلة|مجله|جملة)\s+(?:العلمية|الدولية|التربوية|ابحاث|احباث)').hasMatch(plain) ||
        RegExp(r'^(?:المجلد|اجمللد|العدد|مسلسل العدد|تاريخ (?:النشر|الارسال|القبول)|رقم الايداع|معرف هذا البحث|بنك المعرفة|موقع المجلة|العنوان البريدي|مصنفة دوليا|محكمة|دورية|CC BY)(?:$|[\s:–-])', caseSensitive: false).hasMatch(plain) ||
        (RegExp(r'(?:العدد|المجلد|اجمللد)').hasMatch(plain) && RegExp(r'\d{4}').hasMatch(plain) && RegExp(r'^(?:[^\p{L}]*\d|[^\p{L}]*لسنة)', unicode: true).hasMatch(plain));
  }

  static bool _byline(String t) {
    final arabic = _plainArabic(t);
    if (arabic.startsWith('&') && arabic.split('&').where((g) => g.trim().isNotEmpty).every((g) => g.trim().split(' ').length <= 5)) { return true; }
    if (RegExp(r'(?:^|[&،]\s*)(?:د[./]|ا[.]|ا\.د|استاذ|استاذة|باحثات?\s|قسم\s|كلية\s|جامعة\s)').hasMatch(arabic) ||
        RegExp(r'(?:^|[\s،/])(?:قسم|كلية|جامعة)\s').hasMatch(arabic)) { return true; }

    if (RegExp(r'(?:observatory|istituto|consiglio|researchcenter)',
        caseSensitive: false).hasMatch(t) &&
        (t.contains(',') || RegExp(r'[a-z][A-Z]').allMatches(t).length >= 3)) {
      return true;
    }
    if (RegExp(r'(?:department|university|observatory)of',
        caseSensitive: false).hasMatch(t)) {
      return true;
    }
    if (RegExp(r'(?:^|[^\p{L}])(?:кафедры|факультета)(?:$|[^\p{L}])',
        unicode: true, caseSensitive: false).hasMatch(t)) {
      return true;
    }
    if (RegExp(
      r'@|\b(?:department|faculty|university|college|institute|laboratory|corresponding|PhD|Prof|professor|research scholar|therapist|specialist|student|кафедры|факультета)\b',
      caseSensitive: false,
    ).hasMatch(t)) {
      return true;
    }
    // An unmarked comma-separated author list is still a byline. Require
    // person-shaped groups, not scientific title phrases separated by commas.
    final compactGroups = t.split(RegExp(r',|;'));
    if (compactGroups.length >= 3 && compactGroups.every((g) =>
        !g.trim().contains(' ') && RegExp(r'[a-z][A-Z]').hasMatch(g))) {
      return true;
    }
    final groups = t.split(RegExp(r',\s*|\s+and\s+'));
    if (groups.length >= 3 && groups.every((g) => RegExp(
      r"^[\p{Lu}][\p{L}'’.-]+(?:\s+[\p{Lu}][\p{L}'’.-]+){1,3}$",
      unicode: true).hasMatch(g.trim()))) {
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
  final bool explicitTitle;
  _TitleLine(this.text, this.size, this.explicitTitle);
}
