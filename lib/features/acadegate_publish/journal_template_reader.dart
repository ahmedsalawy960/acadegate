import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'journal_format_rules.dart';
import 'journal_guidelines_heuristic.dart';

/// Reads an official journal Word template on-device.
///
/// Publisher websites often block automated fetching (JavaScript, login,
/// PDF-only pages). The template file is the reliable source.
class JournalTemplateRead {
  final String name;
  final String text;
  final Map<String, dynamic> layout;
  final JournalFormatRules rules;

  const JournalTemplateRead({
    required this.name,
    required this.text,
    required this.layout,
    required this.rules,
  });
}

class JournalTemplateReader {
  JournalTemplateReader._();

  static JournalTemplateRead? read({
    required Uint8List bytes,
    required String filename,
    required String journalName,
    String publisher = '',
    JournalFormatRules? fallback,
  }) {
    if (bytes.isEmpty) return null;
    final lower = filename.toLowerCase();
    if (!lower.endsWith('.docx') && !lower.endsWith('.doc')) return null;

    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final text = _plainText(archive);
      final layout = _layoutFromStyles(archive);
      final heuristic = text.length >= 15
          ? JournalGuidelinesHeuristic.extract(text) ?? <String, dynamic>{}
          : <String, dynamic>{};
      final merged = <String, dynamic>{
        'found': true,
        'confidence': 'high',
        ...heuristic,
        ...layout,
      };
      if ((merged['excerpt']?.toString() ?? '').trim().isEmpty) {
        merged['excerpt'] = text.length > 400 ? text.substring(0, 400) : text;
      }
      final rules = JournalFormatRules.fromExtracted(
        journalName: journalName,
        publisher: publisher,
        sourceUrl: 'template:$filename',
        extracted: merged,
        fallback: fallback,
      );
      return JournalTemplateRead(
        name: filename,
        text: text,
        layout: layout,
        rules: rules.copyWith(extractedFromGuide: true),
      );
    } catch (_) {
      return null;
    }
  }

  static String _plainText(Archive archive) {
    final buffer = StringBuffer();
    for (final path in ['word/document.xml', 'word/footnotes.xml']) {
      final entry = archive.findFile(path);
      if (entry == null) continue;
      try {
        final doc = XmlDocument.parse(utf8.decode(entry.content as List<int>));
        for (final p in doc.findAllElements('w:p')) {
          final line = p.findAllElements('w:t').map((t) => t.innerText).join();
          if (line.trim().isNotEmpty) buffer.writeln(line);
        }
      } catch (_) {}
    }
    return buffer.toString().trim();
  }

  static Map<String, dynamic> _layoutFromStyles(Archive archive) {
    final out = <String, dynamic>{};
    _readSectPr(archive, out);
    _readStyles(archive, out);
    return out;
  }

  static void _readSectPr(Archive archive, Map<String, dynamic> out) {
    final entry = archive.findFile('word/document.xml');
    if (entry == null) return;
    try {
      final doc = XmlDocument.parse(utf8.decode(entry.content as List<int>));
      final sects = doc.findAllElements('w:sectPr').toList();
      if (sects.isEmpty) return;
      final sect = sects.last;
      final pgSz = sect.findElements('w:pgSz').toList();
      if (pgSz.isNotEmpty) {
        final w = int.tryParse(pgSz.first.getAttribute('w:w') ?? '') ?? 0;
        if (w >= 12000 && w <= 12500) out['paperSize'] = 'letter';
        if (w >= 11800 && w <= 12050) out['paperSize'] = 'a4';
      }
      final pgMar = sect.findElements('w:pgMar').toList();
      if (pgMar.isNotEmpty) {
        final top = int.tryParse(pgMar.first.getAttribute('w:top') ?? '') ?? 0;
        if (top > 200) out['marginCm'] = (top / 567).clamp(1.0, 4.0);
      }
      final cols = sect.findElements('w:cols').toList();
      final num = int.tryParse(
        cols.isEmpty ? '' : (cols.first.getAttribute('w:num') ?? ''),
      );
      if (num != null && num >= 1) out['columns'] = num >= 2 ? 2 : 1;
    } catch (_) {}
  }

  static void _readStyles(Archive archive, Map<String, dynamic> out) {
    final entry = archive.findFile('word/styles.xml');
    if (entry == null) return;
    try {
      final doc = XmlDocument.parse(utf8.decode(entry.content as List<int>));
      final defaults = doc.findAllElements('w:rPrDefault').toList();
      final rPrList = defaults.isNotEmpty
          ? defaults.first.findElements('w:rPr').toList()
          : doc.findAllElements('w:rPr').toList();
      if (rPrList.isNotEmpty) {
        final rPr = rPrList.first;
        final font = rPr.findElements('w:rFonts').toList();
        final name = font.isEmpty
            ? ''
            : (font.first.getAttribute('w:ascii') ??
                font.first.getAttribute('w:hAnsi') ??
                '');
        if (name.trim().isNotEmpty) out['fontFamily'] = name.trim();
        final sz = rPr.findElements('w:sz').toList();
        final half = sz.isEmpty
            ? null
            : int.tryParse(sz.first.getAttribute('w:val') ?? '');
        if (half != null && half >= 16 && half <= 72) {
          out['bodyFontSizePt'] = half / 2.0;
        }
      }
      for (final spacing in doc.findAllElements('w:spacing')) {
        final line = int.tryParse(spacing.getAttribute('w:line') ?? '');
        if (line == null) continue;
        if (line >= 450) {
          out['lineSpacing'] = 2.0;
          out['lineSpacingLabel'] = 'double';
          break;
        }
        if (line >= 330 && line < 450) {
          out['lineSpacing'] = 1.5;
          out['lineSpacingLabel'] = '1.5';
          break;
        }
        if (line >= 200 && line <= 280) {
          out['lineSpacing'] = 1.0;
          out['lineSpacingLabel'] = 'single';
          break;
        }
      }
    } catch (_) {}
  }
}
