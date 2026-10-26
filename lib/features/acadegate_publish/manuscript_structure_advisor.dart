import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../ai_advisor/advisor_attachment.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import 'publish_models.dart';

/// Labels scholarly structure. Never rewrites the researcher's words.
class ManuscriptStructureAdvisor {
  ManuscriptStructureAdvisor._();

  static final _cache = <String, Map<int, String>>{};

  /// A short line that names a product, model, or maker — not a section.
  static bool isCatalogLine(String raw) {
    final t = raw.trim();
    if (t.length < 8 || t.length > 180) return false;
    if (RegExp(r'^\d+(\.\d+)*\.?\s+\S').hasMatch(t)) return false;
    final paren = RegExp(r'\(([^)\n]{2,90})\)\s*[.,;]?\s*$').firstMatch(t);
    if (paren != null) {
      final inner = paren.group(1)!.trim();
      if (inner.contains(RegExp(r'\s')) || RegExp(r'\d').hasMatch(inner)) {
        return true;
      }
    }
    final commas = ','.allMatches(t).length;
    final words = t.split(RegExp(r'\s+')).length;
    final hasDigit = RegExp(r'\d').hasMatch(t);
    if (commas >= 2 &&
        words >= 6 &&
        hasDigit &&
        !RegExp(r'\.\s').hasMatch(t)) {
      return true;
    }
    return false;
  }

  /// A real section label: numbered outline, IMRaD name, or a short title
  /// with no model specification.
  static bool isStableSectionLabel(String raw) {
    final t = raw.trim();
    if (t.isEmpty || t.length > 90 || isCatalogLine(t)) return false;
    if (RegExp(
      r'^(?:\d+\.?\s*)?(abstract|introduction|background|experimental|'
      r'materials(\s+and\s+methods)?|methods?|results?|discussion|'
      r'conclusions?|references?|acknowledgments?|keywords?)\s*:?\s*$',
      caseSensitive: false,
    ).hasMatch(t)) {
      return true;
    }
    if (RegExp(
      r'^(الملخص|المقدمة|الخلفية|التجريبي|المنهجية?|المواد والطرق|المواد|'
      r'النتائج|المناقشة|الخاتمة|الاستنتاجات?|المراجع|'
      r'كلمات مفتاحية|الكلمات المفتاحية|الكلمات الدالة)\s*:?\s*$',
    ).hasMatch(t)) {
      return true;
    }
    if (RegExp(r'^\d+(\.\d+)*\.?\s+\S').hasMatch(t) &&
        t.split(RegExp(r'\s+')).length <= 16 &&
        !t.endsWith('.')) {
      return true;
    }
    final words = t.split(RegExp(r'\s+')).length;
    return words >= 1 &&
        words <= 6 &&
        t.length <= 70 &&
        !t.contains('(') &&
        ','.allMatches(t).length < 2 &&
        !t.endsWith('.');
  }

  /// A one-word label is not the article title when the next line is the title.
  static String readingTitle({
    required String title,
    required List<ManuscriptBlock> blocks,
  }) {
    final current = title.trim();
    final words =
        current.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
    if (current.isEmpty || words > 3 || current.length > 40) return current;
    for (final block in blocks) {
      if (block.type != ManuscriptBlockType.heading &&
          block.type != ManuscriptBlockType.paragraph) {
        continue;
      }
      final text = block.text.trim();
      if (text.isEmpty || text == current) continue;
      final count = text.split(RegExp(r'\s+')).length;
      if (count >= 8 &&
          text.length >= 40 &&
          text.length <= 320 &&
          !text.contains('. ')) {
        return text;
      }
      break;
    }
    return current;
  }

  static List<ManuscriptBlock> demoteCatalogHeadings(
    List<ManuscriptBlock> blocks,
  ) {
    return [
      for (final block in blocks)
        if (block.type == ManuscriptBlockType.heading &&
            isCatalogLine(block.text))
          block.copyWith(type: ManuscriptBlockType.paragraph)
        else
          block,
    ];
  }

  /// One scientific-model pass over text, figures, tables, and equations.
  /// On failure, catalog lines are still paragraphs.
  static Future<List<ManuscriptBlock>> align(
    List<ManuscriptBlock> blocks,
  ) async {
    final local = demoteCatalogHeadings(blocks);
    if (local.length < 4) return local;
    if (!_modelAvailable) return local;
    final key = _signature(local);
    final cached = _cache[key];
    if (cached != null) return _apply(local, cached);
    try {
      final labels = await _ask(local).timeout(const Duration(seconds: 50));
      if (labels == null || labels.isEmpty) return local;
      _cache[key] = labels;
      if (_cache.length > 6) {
        _cache.remove(_cache.keys.first);
      }
      return _apply(local, labels);
    } catch (e) {
      debugPrint('structure advisor: $e');
      return local;
    }
  }

  static bool get _modelAvailable {
    try {
      return GeminiAdvisorClient.isAvailable;
    } catch (_) {
      return false;
    }
  }

  static String _signature(List<ManuscriptBlock> blocks) {
    final buf = StringBuffer();
    for (var i = 0; i < blocks.length; i++) {
      buf.write(i);
      buf.write('\t');
      buf.write(blocks[i].type.name);
      buf.write('\t');
      buf.write(_excerpt(blocks[i]));
      buf.write('\n');
    }
    return buf.toString();
  }

  static String _excerpt(ManuscriptBlock block) {
    final text = block.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final caption = (block.caption ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    final visible = text.isNotEmpty ? text : caption;
    if (visible.length <= 180) return visible;
    return visible.substring(0, 180);
  }

  static Future<Map<int, String>?> _ask(List<ManuscriptBlock> blocks) async {
    final lines = StringBuffer();
    final images = <GeminiInlinePart>[];
    var sent = 0;
    for (var i = 0; i < blocks.length && sent < 160; i++) {
      final block = blocks[i];
      final kind = switch (block.type) {
        ManuscriptBlockType.heading || ManuscriptBlockType.paragraph => 'text',
        ManuscriptBlockType.image => 'image',
        ManuscriptBlockType.table => 'table',
        ManuscriptBlockType.equation => 'equation',
      };
      final excerpt = _excerpt(block);
      if (kind == 'text' && excerpt.length < 2) continue;
      final imageName = _imageAttachment(block, i, images);
      final note = imageName == null ? excerpt : '$excerpt [see $imageName]';
      lines.writeln('$i\t$kind\t$note');
      sent++;
    }
    if (sent < 4) return null;

    final result = await GeminiAdvisorClient.instance.generateResult(
      preferPro: true,
      maxOutputTokens: 4096,
      attachments: images,
      systemPrompt: '''
You are reading one scientific manuscript immediately after a mechanical extract from Word. Bold and heading styles are often wrong. Pictures, chemical structures, chromatograms, and equations may be separate image or equation blocks.

Each input line is: index, tab, kind (text, image, table, or equation), tab, the author's original excerpt. Attached files are named image-N.png or image-N.jpg and belong to that index.

For TEXT lines only, choose one role:
- heading: the article title or a section/subsection that organizes the paper
- list_item: an instrument, chemical, reagent, strain, software package, or a model/manufacturer specification
- caption: the label of a nearby figure, table, scheme, or equation
- paragraph: body prose

Do not relabel image, table, or equation rows. Do not rewrite, translate, or add words.
Return only JSON: {"labels":[{"i":0,"role":"heading"}]}
Include only text indices you can judge.
''',
      userMessage: lines.toString(),
    );
    if (!result.isSuccess) return null;
    return _parseLabels(result.text!, blocks.length);
  }

  static String? _imageAttachment(
    ManuscriptBlock block,
    int index,
    List<GeminiInlinePart> images,
  ) {
    if (images.length >= 8) return null;
    if (block.type != ManuscriptBlockType.image &&
        block.type != ManuscriptBlockType.equation) {
      return null;
    }
    final url = (block.imageUrl ?? '').trim();
    if (!url.startsWith('data:image/')) return null;
    final semi = url.indexOf(';');
    final comma = url.indexOf(',');
    if (semi < 6 || comma < 0) return null;
    final mime = url.substring(5, semi);
    if (mime != 'image/png' && mime != 'image/jpeg' && mime != 'image/webp') {
      return null;
    }
    final payload = url.substring(comma + 1);
    if (payload.length < 80 || payload.length > 400000) return null;
    final ext = mime == 'image/png' ? 'png' : (mime == 'image/webp' ? 'webp' : 'jpg');
    final name = 'image-$index.$ext';
    images.add(GeminiInlinePart(
      mimeType: mime,
      base64Data: payload,
      fileName: name,
    ));
    return name;
  }

  static Map<int, String>? _parseLabels(String raw, int length) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    final decoded = jsonDecode(raw.substring(start, end + 1));
    if (decoded is! Map) return null;
    final list = decoded['labels'];
    if (list is! List || list.isEmpty) return null;
    const roles = {'heading', 'paragraph', 'list_item', 'caption'};
    final out = <int, String>{};
    for (final item in list) {
      if (item is! Map) continue;
      final n = item['i'] is int ? item['i'] as int : int.tryParse('${item['i']}');
      final role = item['role']?.toString();
      if (n == null || n < 0 || n >= length || role == null) continue;
      if (!roles.contains(role)) continue;
      out[n] = role;
    }
    return out.isEmpty ? null : out;
  }

  static bool _canBeHeading(String text) {
    final t = text.trim();
    if (t.isEmpty || t.length > 160 || isCatalogLine(t)) return false;
    final words = t.split(RegExp(r'\s+')).length;
    if (words > 18) return false;
    if (t.contains('. ') && words > 12) return false;
    return true;
  }

  static List<ManuscriptBlock> _apply(
    List<ManuscriptBlock> blocks,
    Map<int, String> labels,
  ) {
    final out = <ManuscriptBlock>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block.type != ManuscriptBlockType.heading &&
          block.type != ManuscriptBlockType.paragraph) {
        out.add(block);
        continue;
      }
      final text = block.text.trim();
      if (isCatalogLine(text)) {
        out.add(
          block.type == ManuscriptBlockType.paragraph
              ? block
              : block.copyWith(type: ManuscriptBlockType.paragraph),
        );
        continue;
      }
      final role = labels[i];
      if (role == 'heading' && _canBeHeading(text)) {
        out.add(
          block.type == ManuscriptBlockType.heading
              ? block
              : block.copyWith(type: ManuscriptBlockType.heading),
        );
        continue;
      }
      if (role == 'paragraph' || role == 'list_item' || role == 'caption') {
        if (block.type == ManuscriptBlockType.heading &&
            isStableSectionLabel(text) &&
            role != 'list_item') {
          out.add(block);
        } else {
          out.add(
            block.type == ManuscriptBlockType.paragraph
                ? block
                : block.copyWith(type: ManuscriptBlockType.paragraph),
          );
        }
        continue;
      }
      out.add(block);
    }
    return out;
  }
}
