import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Reconstructs Word auto-numbers (`1.` `2.` …) that live in numbering.xml
/// instead of the paragraph text.
class DocxListNumbering {
  DocxListNumbering._(this._levels, this._numToAbstract, this._styleNumPr);

  final Map<String, Map<int, _DocxLvl>> _levels;
  final Map<String, String> _numToAbstract;
  final Map<String, ({String numId, int ilvl})> _styleNumPr;
  final Map<String, Map<int, int>> _counters = {};

  static ArchiveFile? _part(Archive archive, String path) {
    final direct = archive.findFile(path);
    if (direct != null) return direct;
    final wanted = path.replaceAll('\\', '/').toLowerCase();
    for (final file in archive.files) {
      if (file.name.replaceAll('\\', '/').toLowerCase() == wanted) return file;
    }
    return null;
  }

  static DocxListNumbering fromArchive(Archive archive) {
    final empty = DocxListNumbering._(const {}, const {}, const {});
    final entry = _part(archive, 'word/numbering.xml');
    if (entry == null) return empty;
    try {
      final doc = XmlDocument.parse(utf8.decode(entry.content as List<int>));
      final levels = <String, Map<int, _DocxLvl>>{};
      for (final abs in doc.findAllElements('abstractNum')) {
        final id = abs.getAttribute('abstractNumId') ??
            abs.getAttribute('w:abstractNumId') ??
            '';
        if (id.isEmpty) continue;
        final byIlvl = <int, _DocxLvl>{};
        for (final lvl in abs.findAllElements('lvl')) {
          final ilvl = int.tryParse(
                lvl.getAttribute('ilvl') ?? lvl.getAttribute('w:ilvl') ?? '0',
              ) ??
              0;
          var fmt = 'decimal';
          var start = 1;
          for (final child in lvl.childElements) {
            if (child.localName == 'numFmt') {
              fmt = child.getAttribute('val') ??
                  child.getAttribute('w:val') ??
                  fmt;
            } else if (child.localName == 'start') {
              start = int.tryParse(
                    child.getAttribute('val') ??
                        child.getAttribute('w:val') ??
                        '1',
                  ) ??
                  1;
            }
          }
          byIlvl[ilvl] = _DocxLvl(fmt: fmt, start: start);
        }
        levels[id] = byIlvl;
      }
      final numToAbs = <String, String>{};
      for (final num in doc.findAllElements('num')) {
        final numId =
            num.getAttribute('numId') ?? num.getAttribute('w:numId') ?? '';
        if (numId.isEmpty) continue;
        for (final child in num.childElements) {
          if (child.localName != 'abstractNumId') continue;
          final absId = child.getAttribute('val') ??
              child.getAttribute('w:val') ??
              '';
          if (absId.isNotEmpty) numToAbs[numId] = absId;
        }
      }
      return DocxListNumbering._(
        levels,
        numToAbs,
        _loadStyleNumPr(archive),
      );
    } catch (_) {
      return empty;
    }
  }

  static Map<String, ({String numId, int ilvl})> _loadStyleNumPr(Archive archive) {
    final entry = _part(archive, 'word/styles.xml');
    if (entry == null) return const {};
    try {
      final doc = XmlDocument.parse(utf8.decode(entry.content as List<int>));
      final out = <String, ({String numId, int ilvl})>{};
      final basedOn = <String, String>{};
      for (final style in doc.findAllElements('style')) {
        final id = style.getAttribute('styleId') ??
            style.getAttribute('w:styleId') ??
            '';
        if (id.isEmpty) continue;
        for (final child in style.childElements) {
          if (child.localName == 'basedOn') {
            basedOn[id] = child.getAttribute('val') ??
                child.getAttribute('w:val') ??
                '';
          }
        }
        for (final pPr in style.findAllElements('pPr')) {
          for (final numPr in pPr.childElements) {
            if (numPr.localName != 'numPr') continue;
            var numId = '';
            var ilvl = 0;
            for (final n in numPr.childElements) {
              if (n.localName == 'ilvl') {
                ilvl = int.tryParse(
                      n.getAttribute('val') ?? n.getAttribute('w:val') ?? '0',
                    ) ??
                    0;
              } else if (n.localName == 'numId') {
                numId = n.getAttribute('val') ?? n.getAttribute('w:val') ?? '';
              }
            }
            if (numId.isNotEmpty && numId != '0') {
              out[id] = (numId: numId, ilvl: ilvl);
            }
          }
        }
      }
      for (final id in basedOn.keys) {
        if (out.containsKey(id)) continue;
        var walk = basedOn[id];
        final seen = <String>{};
        while (walk != null && walk.isNotEmpty && seen.add(walk)) {
          final hit = out[walk];
          if (hit != null) {
            out[id] = hit;
            break;
          }
          walk = basedOn[walk];
        }
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  String? consume(XmlElement paragraph) {
    final pr = _numPr(paragraph) ?? _numPrFromStyle(paragraph);
    if (pr == null) return null;
    final absId = _numToAbstract[pr.numId];
    if (absId == null) return null;
    final lvl = _levels[absId]?[pr.ilvl];
    if (lvl == null) return null;
    final fmt = lvl.fmt.toLowerCase();
    if (fmt != 'decimal' &&
        fmt != 'decimalzero' &&
        fmt != 'arabic' &&
        !fmt.contains('decimal')) {
      return null;
    }
    final counters = _counters.putIfAbsent(pr.numId, () => <int, int>{});
    counters.removeWhere((k, _) => k > pr.ilvl);
    final n = (counters[pr.ilvl] ?? (lvl.start - 1)) + 1;
    counters[pr.ilvl] = n;
    return '$n. ';
  }

  static ({String numId, int ilvl})? _numPr(XmlElement paragraph) {
    XmlElement? numPr;
    for (final pPr in paragraph.childElements) {
      if (pPr.localName != 'pPr') continue;
      for (final child in pPr.childElements) {
        if (child.localName == 'numPr') {
          numPr = child;
          break;
        }
      }
    }
    if (numPr == null) return null;
    var numId = '';
    var ilvl = 0;
    for (final child in numPr.childElements) {
      if (child.localName == 'ilvl') {
        ilvl = int.tryParse(
              child.getAttribute('val') ?? child.getAttribute('w:val') ?? '0',
            ) ??
            0;
      } else if (child.localName == 'numId') {
        numId = child.getAttribute('val') ?? child.getAttribute('w:val') ?? '';
      }
    }
    if (numId.isEmpty || numId == '0') return null;
    return (numId: numId, ilvl: ilvl);
  }

  ({String numId, int ilvl})? _numPrFromStyle(XmlElement paragraph) {
    for (final pPr in paragraph.childElements) {
      if (pPr.localName != 'pPr') continue;
      for (final child in pPr.childElements) {
        if (child.localName != 'pStyle') continue;
        final id = child.getAttribute('val') ?? child.getAttribute('w:val') ?? '';
        if (id.isEmpty) continue;
        return _styleNumPr[id];
      }
    }
    return null;
  }
}

class _DocxLvl {
  final String fmt;
  final int start;
  const _DocxLvl({required this.fmt, required this.start});
}
