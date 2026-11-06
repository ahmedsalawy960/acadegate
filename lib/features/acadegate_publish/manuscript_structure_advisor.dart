import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../ai_advisor/gemini_advisor_client.dart';
import 'citation_style_shapes.dart';
import 'publish_models.dart';

enum ManuscriptStructureLabelSource {
  model,
  cachedModel,
  localFallback,
  unavailable,
  tooShort,
}

/// Labels scholarly structure. Never rewrites the researcher's words.
class ManuscriptStructureAdvisor {
  ManuscriptStructureAdvisor._();

  static final _cache = <String, Map<int, String>>{};
  static final _inflight = <String, Future<List<ManuscriptBlock>>>{};
  static final Map<int, String> _parsedNumberRoles = {};
  static final Map<String, String> _numberRoles = {};

  static ManuscriptStructureLabelSource lastSource =
      ManuscriptStructureLabelSource.unavailable;

  static int lastLabelCount = 0;

  /// empty, timeout, or error. Shown only when Gemini does not finish.
  static String? lastDetailCode;

  static String statusMessage({required bool arabic}) {
    final count = lastLabelCount;
    final detail = _statusDetail(arabic);
    return switch (lastSource) {
      ManuscriptStructureLabelSource.model => arabic
          ? 'راجع AcadeGate الملف وصنّف $count سطراً. لم يُعد كتابة النص.'
          : 'AcadeGate reviewed the file and labeled $count lines. The text was not rewritten.',
      ManuscriptStructureLabelSource.cachedModel => arabic
          ? 'استُخدم تصنيف AcadeGate المحفوظ لـ $count سطراً. لم يُعد كتابة النص.'
          : 'A saved AcadeGate labeling for $count lines was reused. The text was not rewritten.',
      ManuscriptStructureLabelSource.localFallback => arabic
          ? 'لم يكتمل رد AcadeGate$detail. بقي النص كاملاً واستُخدم التصنيف المحلي.'
          : 'AcadeGate did not finish$detail. All text was kept and headings were labeled locally.',
      ManuscriptStructureLabelSource.unavailable => arabic
          ? 'AcadeGate غير متاح. بقي النص كاملاً واستُخدم التصنيف المحلي.'
          : 'AcadeGate is not available. All text was kept and headings were labeled locally.',
      ManuscriptStructureLabelSource.tooShort => arabic
          ? 'الملف قصير، فلم يُطلب من AcadeGate تصنيفه. حُفظ النص كما هو.'
          : 'The file is short, so AcadeGate was not asked to label it. The text was kept.',
    };
  }

  static String detailForGeminiError(String? error) {
    final msg = error ?? '';
    if (msg.contains('no longer available')) return 'retired';
    if (msg.contains('انتهى رصيد')) return 'quota';
    return 'error';
  }

  static String _statusDetail(bool arabic) {
    return switch (lastDetailCode) {
      'empty' => arabic
          ? ' (الرد لم يحتوِ تصنيفاً)'
          : ' (the reply had no labels)',
      'timeout' => arabic ? ' (انتهت المهلة)' : ' (timed out)',
      'error' => arabic ? ' (تعذر الاتصال)' : ' (the request failed)',
      'retired' => arabic
          ? ' (خدمة AcadeGate قيد التحديث)'
          : ' (AcadeGate service is updating)',
      'quota' => arabic
          ? ' (انتهى رصيد اليوم في AcadeGate)'
          : ' (today’s AcadeGate quota is used up)',
      _ => '',
    };
  }

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
    if (CitationStyleShapes.isSymbolDefinition(t) ||
        CitationStyleShapes.isNumericDataLine(t) ||
        CitationStyleShapes.isParameterLine(t)) {
      return false;
    }
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
    final out = <ManuscriptBlock>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block.type != ManuscriptBlockType.heading) {
        out.add(block);
        continue;
      }
      final next = _nextText(blocks, i + 1);
      if (isCatalogLine(block.text) ||
          CitationStyleShapes.isSymbolDefinition(block.text) ||
          CitationStyleShapes.isNumericDataLine(block.text) ||
          CitationStyleShapes.isParameterLine(block.text) ||
          _isSettingsLabel(block.text, next)) {
        out.add(block.copyWith(type: ManuscriptBlockType.paragraph));
      } else {
        out.add(block);
      }
    }
    return out;
  }

  static String? _nextText(List<ManuscriptBlock> blocks, int start) {
    for (var i = start; i < blocks.length; i++) {
      final text = blocks[i].text.trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  /// A short label sitting directly above readings or symbol definitions.
  static bool _isSettingsLabel(String raw, String? next) {
    if (next == null) return false;
    final t = raw.trim();
    if (t.isEmpty || t.length > 80 || RegExp(r'\.\s').hasMatch(t)) return false;
    if (t.split(RegExp(r'\s+')).length > 8) return false;
    final bare = t.replaceFirst(RegExp(r':+\s*$'), '').trim().toLowerCase();
    if (CitationStyleShapes.headingNames.contains(bare)) return false;
    if (RegExp(r'^\d+(?:\.\d+)*\.?\s+\S').hasMatch(t)) return false;
    return CitationStyleShapes.isSymbolDefinition(next) ||
        CitationStyleShapes.isNumericDataLine(next) ||
        CitationStyleShapes.isParameterLine(next);
  }

  /// One scientific-model pass over text, figures, tables, and equations.
  /// On failure, catalog lines are still paragraphs.
  static Future<List<ManuscriptBlock>> align(
    List<ManuscriptBlock> blocks,
  ) async {
    final local = demoteCatalogHeadings(blocks);
    if (local.length < 4) {
      lastSource = ManuscriptStructureLabelSource.tooShort;
      lastLabelCount = 0;
      lastDetailCode = null;
      return local;
    }
    if (!_modelAvailable) {
      lastSource = ManuscriptStructureLabelSource.unavailable;
      lastLabelCount = 0;
      lastDetailCode = null;
      return local;
    }
    final key = _signature(local);
    final cached = _cache[key];
    if (cached != null) {
      lastSource = ManuscriptStructureLabelSource.cachedModel;
      lastLabelCount = cached.length;
      lastDetailCode = null;
      return applyReviewedLabels(local, cached);
    }
    final pending = _inflight[key];
    if (pending != null) return pending;
    final run = _reviewWithModel(local, key);
    _inflight[key] = run;
    try {
      return await run;
    } finally {
      _inflight.remove(key);
    }
  }

  static Future<List<ManuscriptBlock>> _reviewWithModel(
    List<ManuscriptBlock> local,
    String key,
  ) async {
    try {
      final labels = await _ask(local).timeout(const Duration(seconds: 180));
      if (labels == null || labels.isEmpty) {
        lastSource = ManuscriptStructureLabelSource.localFallback;
        lastLabelCount = 0;
        lastDetailCode ??= 'empty';
        return local;
      }
      _cache[key] = labels;
      if (_cache.length > 6) {
        _cache.remove(_cache.keys.first);
      }
      lastSource = ManuscriptStructureLabelSource.model;
      lastLabelCount = labels.length;
      lastDetailCode = null;
      _rememberNumberRoles(local);
      return applyReviewedLabels(local, labels);
    } catch (e) {
      debugPrint('structure advisor: $e');
      lastSource = ManuscriptStructureLabelSource.localFallback;
      lastLabelCount = 0;
      lastDetailCode = e is TimeoutException ? 'timeout' : 'error';
      return local;
    }
  }

  /// Gemini's reading of a line's number: citation, equation_number, or float_number.
  static String? numberRoleFor(String text) {
    final key = _roleKey(text);
    if (key.isEmpty) return null;
    return _numberRoles[key];
  }

  static String _roleKey(String text) {
    final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return '';
    return t.length <= 180 ? t : t.substring(0, 180);
  }

  static void _rememberNumberRoles(List<ManuscriptBlock> blocks) {
    for (final entry in _parsedNumberRoles.entries) {
      if (entry.key < 0 || entry.key >= blocks.length) continue;
      final role = entry.value;
      if (role != 'equation_number' &&
          role != 'float_number' &&
          role != 'citation') {
        continue;
      }
      final key = _roleKey(blocks[entry.key].text);
      if (key.isEmpty) continue;
      _numberRoles[key] = role;
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
    final indexes = <int>[];
    for (var i = 0; i < blocks.length && indexes.length < 160; i++) {
      final block = blocks[i];
      final kind = switch (block.type) {
        ManuscriptBlockType.heading || ManuscriptBlockType.paragraph => 'text',
        ManuscriptBlockType.image => 'image',
        ManuscriptBlockType.table => 'table',
        ManuscriptBlockType.equation => 'equation',
      };
      final excerpt = _excerpt(block);
      if (kind == 'text' && excerpt.length < 2) continue;
      indexes.add(i);
    }
    if (indexes.length < 4) return null;
    _parsedNumberRoles.clear();

    // Small batches so one reply always finishes. A figure in the file is
    // described on its text line and cannot cancel the other batches.
    const batchSize = 32;
    final merged = <int, String>{};
    for (var start = 0; start < indexes.length; start += batchSize) {
      final end = start + batchSize > indexes.length
          ? indexes.length
          : start + batchSize;
      final part = await _askIndexes(blocks, indexes.sublist(start, end));
      if (part == null || part.isEmpty) continue;
      merged.addAll(part);
    }
    if (merged.isEmpty) return null;
    lastDetailCode = null;
    return merged;
  }

  /// Text only. Figure bytes are not attached: with images, Gemini 2.5 Pro
  /// spends the reply budget on thinking and the label JSON is cut off.
  static Future<Map<int, String>?> _askIndexes(
    List<ManuscriptBlock> blocks,
    List<int> indexes,
  ) async {
    final lines = StringBuffer();
    for (final i in indexes) {
      final block = blocks[i];
      final kind = switch (block.type) {
        ManuscriptBlockType.heading || ManuscriptBlockType.paragraph => 'text',
        ManuscriptBlockType.image => 'image',
        ManuscriptBlockType.table => 'table',
        ManuscriptBlockType.equation => 'equation',
      };
      final excerpt = _excerpt(block);
      final next = i + 1 < blocks.length ? _excerpt(blocks[i + 1]) : '';
      lines.writeln(
        next.isEmpty ? '$i\t$kind\t$excerpt' : '$i\t$kind\t$excerpt\tnext: $next',
      );
    }

    final result = await GeminiAdvisorClient.instance.generateResult(
      preferPro: true,
      maxOutputTokens: 8192,
      systemPrompt: '''
You are reading one scientific manuscript immediately after a mechanical extract from Word. Bold and heading styles are often wrong. Pictures, chemical structures, chromatograms, and equations may be separate image or equation blocks.

Each input line is: index, tab, kind (text, image, table, or equation), tab, the author's original excerpt.

This review happens before the manuscript is stored or exported. Word's heading style is not evidence. Judge every text index from the line and the following line.

For TEXT lines only, choose one role:
- heading: the article title or a section that organizes the paper, such as Introduction or a numbered subsection
- list_item: an instrument, chemical, reagent, strain, software package, or a model/manufacturer specification
- caption: the label of a nearby figure, table, scheme, or equation
- paragraph: body prose, a symbol definition (`W2 = final weight of the sample`), a setting (`Column temperature: 80`), a row of readings, or the short label directly above those settings

A heading does not contain an equals sign or a measured value.
An equation number is not a citation, even when the same digits exist in the bibliography. A line of dots then (12) or [12] after an equation is equation_number. Fig., Figure, Table, and Scheme numbers are float_number.

Do not relabel image, table, or equation rows. Do not rewrite, translate, or add words.
Return only compact JSON, with no markdown and no explanation: {"labels":[{"i":0,"role":"paragraph","num":"citation"}]}
num is citation, equation_number, float_number, or none.
Include every text index in this batch. Close the JSON array.
''',
      userMessage: lines.toString(),
    );
    if (!result.isSuccess) {
      debugPrint('structure advisor: ${result.error}');
      lastDetailCode = detailForGeminiError(result.error);
      return null;
    }
    final parsed = _parseLabels(result.text!, blocks.length);
    if (parsed == null) {
      lastDetailCode = 'empty';
      return null;
    }
    lastDetailCode = null;
    return parsed;
  }

  static Map<int, String>? parseModelLabels(String raw, int length) =>
      _parseLabels(raw, length);

  static Map<int, String>? _parseLabels(String raw, int length) {
    final fromJson = _labelsFromJson(raw, length);
    final fromPieces = _labelsFromPieces(raw, length);
    if (fromJson == null) return fromPieces;
    if (fromPieces == null) return fromJson;
    return fromPieces.length > fromJson.length ? fromPieces : fromJson;
  }

  static Map<int, String>? _labelsFromJson(String raw, int length) {
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      final decoded = jsonDecode(raw.substring(start, end + 1));
      if (decoded is! Map) return null;
      final list = decoded['labels'];
      if (list is! List || list.isEmpty) return null;
      return _collectLabels(list, length);
    } catch (_) {
      return null;
    }
  }

  static Map<int, String>? _labelsFromPieces(String raw, int length) {
    const roles = 'heading|paragraph|list_item|caption';
    final out = <int, String>{};
    void take(int? n, String? role) {
      if (n == null || role == null || n < 0 || n >= length) return;
      if (!{'heading', 'paragraph', 'list_item', 'caption'}.contains(role)) {
        return;
      }
      out[n] = role;
    }

    for (final match in RegExp(
      '\\{\\s*"i"\\s*:\\s*(\\d+)\\s*,\\s*"role"\\s*:\\s*"($roles)"[^}]*\\}',
    ).allMatches(raw)) {
      take(int.tryParse(match.group(1)!), match.group(2));
    }
    for (final match in RegExp(
      '\\{\\s*"role"\\s*:\\s*"($roles)"\\s*,\\s*"i"\\s*:\\s*(\\d+)[^}]*\\}',
    ).allMatches(raw)) {
      take(int.tryParse(match.group(2)!), match.group(1));
    }
    for (final match in RegExp(
      '"i"\\s*:\\s*(\\d+)[^}]{0,80}?"num"\\s*:\\s*"(citation|equation_number|float_number|none)"',
    ).allMatches(raw)) {
      final n = int.tryParse(match.group(1)!);
      if (n != null && n >= 0 && n < length) {
        _parsedNumberRoles[n] = match.group(2)!;
      }
    }
    return out.isEmpty ? null : out;
  }

  static Map<int, String>? _collectLabels(List<dynamic> list, int length) {
    const roles = {'heading', 'paragraph', 'list_item', 'caption'};
    final out = <int, String>{};
    for (final item in list) {
      if (item is! Map) continue;
      final n = item['i'] is int ? item['i'] as int : int.tryParse('${item['i']}');
      final role = item['role']?.toString();
      if (n == null || n < 0 || n >= length || role == null) continue;
      if (!roles.contains(role)) continue;
      out[n] = role;
      final numRole = item['num']?.toString();
      if (numRole == 'citation' ||
          numRole == 'equation_number' ||
          numRole == 'float_number' ||
          numRole == 'none') {
        _parsedNumberRoles[n] = numRole!;
      }
    }
    return out.isEmpty ? null : out;
  }

  /// The model's role wins. A local heading is not kept once the model
  /// calls the line a paragraph. Symbol definitions stay paragraphs.
  static List<ManuscriptBlock> applyReviewedLabels(
    List<ManuscriptBlock> blocks,
    Map<int, String> labels,
  ) {
    return demoteCatalogHeadings(_apply(blocks, labels));
  }

  static bool _canBeHeading(String text) {
    final t = text.trim();
    if (t.isEmpty || t.length > 160 || isCatalogLine(t)) return false;
    if (CitationStyleShapes.isSymbolDefinition(t) ||
        CitationStyleShapes.isNumericDataLine(t) ||
        CitationStyleShapes.isParameterLine(t)) {
      return false;
    }
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
        out.add(
          block.type == ManuscriptBlockType.paragraph
              ? block
              : block.copyWith(type: ManuscriptBlockType.paragraph),
        );
        continue;
      }
      out.add(block);
    }
    return out;
  }
}
