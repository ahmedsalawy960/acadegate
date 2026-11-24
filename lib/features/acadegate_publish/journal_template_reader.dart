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
    if (!lower.endsWith('.docx')) return null;

    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentEntry = archive.findFile('word/document.xml');
      if (documentEntry == null) return null;
      final document = XmlDocument.parse(
        utf8.decode(documentEntry.content as List<int>),
      );
      const wordNamespace =
          'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
      final root = document.rootElement;
      if (root.name.local != 'document' ||
          root.namespaceUri != wordNamespace ||
          root.getElement('body', namespace: wordNamespace) == null) {
        return null;
      }
      final text = _plainText(archive);
      final layout = _layoutFromStyles(archive);
      final heuristic = text.length >= 15
          ? JournalGuidelinesHeuristic.extract(text) ?? <String, dynamic>{}
          : <String, dynamic>{};
      // A readable ZIP or placeholder text does not prove extracted rules.
      if (layout.isEmpty && heuristic['found'] != true) return null;
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
      // Only document defaults and the declared default paragraph style can
      // establish whole-body defaults. Heading/caption/character styles cannot.
      final defaults = doc.rootElement.getElement('w:docDefaults');
      final styles = doc.rootElement.findElements('w:style').toList();
      final bodyStyles = styles.where((style) =>
          style.getAttribute('w:type') == 'paragraph' &&
          const ['1', 'true', 'on'].contains(style.getAttribute('w:default')));
      final chain = <XmlElement>[];
      final seen = <String>{};
      XmlElement? current = bodyStyles.length == 1 ? bodyStyles.single : null;
      while (current != null) {
        final id = current.getAttribute('w:styleId') ?? '';
        if (id.isEmpty || !seen.add(id)) {
          chain.clear();
          break;
        }
        chain.insert(0, current);
        final parent = current.getElement('w:basedOn')?.getAttribute('w:val');
        final matches = styles.where((style) =>
            style.getAttribute('w:type') == 'paragraph' &&
            style.getAttribute('w:styleId') == parent).toList();
        current = matches.length == 1 ? matches.single : null;
      }
      final runProperties = <XmlElement>[];
      final defaultRun = defaults?.getElement('w:rPrDefault')?.getElement('w:rPr');
      if (defaultRun != null) runProperties.add(defaultRun);
      for (final style in chain) {
        final run = style.getElement('w:rPr');
        if (run != null) runProperties.add(run);
      }
      for (final rPr in runProperties) {
        final font = rPr.getElement('w:rFonts');
        final name = font?.getAttribute('w:ascii') ??
            font?.getAttribute('w:hAnsi');
        if (name != null && name.trim().isNotEmpty) {
          out['fontFamily'] = name.trim();
        }
        final half = int.tryParse(
          rPr.getElement('w:sz')?.getAttribute('w:val') ?? '',
        );
        if (half != null && half >= 16 && half <= 72) {
          out['bodyFontSizePt'] = half / 2.0;
        }
      }
      // Merge spacing attributes before interpreting them. In Word, omitted
      // lineRule means auto; exact/atLeast values are twips, not multiples.
      final spacingAttributes = <String, String>{};
      final paragraphProperties = <XmlElement>[];
      final defaultParagraph =
          defaults?.getElement('w:pPrDefault')?.getElement('w:pPr');
      if (defaultParagraph != null) paragraphProperties.add(defaultParagraph);
      for (final style in chain) {
        final paragraph = style.getElement('w:pPr');
        if (paragraph != null) paragraphProperties.add(paragraph);
      }
      for (final pPr in paragraphProperties) {
        final spacing = pPr.getElement('w:spacing');
        for (final key in ['w:line', 'w:lineRule']) {
          final value = spacing?.getAttribute(key);
          if (value != null) spacingAttributes[key] = value;
        }
      }
      final line = int.tryParse(spacingAttributes['w:line'] ?? '');
      final lineRule = spacingAttributes['w:lineRule'] ?? 'auto';
      if (lineRule == 'auto' && const [240, 360, 480].contains(line)) {
        out['lineSpacing'] = line! / 240.0;
        out['lineSpacingLabel'] = switch (line) {
          240 => 'single',
          360 => '1.5',
          _ => 'double',
        };
      }
    } catch (_) {}
  }
}
