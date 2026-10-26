import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../ai_advisor/gemini_advisor_client.dart';
import 'citation_formatter.dart';
import 'publish_models.dart';

/// Restyles a bibliography to one journal system. Does not invent missing fields.
class BibliographyStyleAdvisor {
  BibliographyStyleAdvisor._();

  static final _cache = <String, List<String>>{};

  static Future<List<String>?> restyle({
    required List<PublishReference> references,
    required PublishCitationStyle style,
    String? referenceExample,
    String? inTextExample,
    bool plainNumbers = false,
  }) async {
    if (references.isEmpty) return const [];
    if (!_modelAvailable) return null;
    final local = [
      for (var i = 0; i < references.length; i++)
        CitationFormatter.buildBibliographyEntry(
          reference: references[i],
          style: style,
          index: CitationFormatter.bibliographyIndex(references[i], i + 1),
          plainNumberList: plainNumbers,
        ).plain.trim(),
    ];
    final key = '${style.name}|$plainNumbers|${referenceExample ?? ''}|'
        '${local.join('\n')}';
    final cached = _cache[key];
    if (cached != null) return cached;

    final numbered = CitationFormatter.isNumberedStyle(style);
    final marker = !numbered
        ? 'Do not add numbers. Keep author–date form.'
        : (plainNumbers
            ? 'Every line starts with the same marker: 1. 2. 3.'
            : 'Every line starts with the same marker: [1] [2] [3].');
    final sample = (referenceExample ?? '').trim();
    final inText = (inTextExample ?? '').trim();

    final out = List<String>.from(local);
    var anyModel = false;
    const batch = 8;
    for (var start = 0; start < references.length; start += batch) {
      final end = (start + batch) < references.length
          ? start + batch
          : references.length;
      try {
        final lines = await _ask(
          references: references.sublist(start, end),
          local: local.sublist(start, end),
          style: style,
          marker: marker,
          sample: sample,
          inText: inText,
          indexBase: start,
        ).timeout(const Duration(seconds: 40));
        if (lines == null || lines.length != end - start) continue;
        for (var i = 0; i < lines.length; i++) {
          final source = _sourceLine(references[start + i], local[start + i]);
          if (_keepsFacts(
            source,
            lines[i],
            numbered: sample.isEmpty ? numbered : _sampleIsNumbered(sample),
          )) {
            out[start + i] = _alignToSample(
              local: local[start + i],
              model: lines[i],
              sample: sample,
            );
            anyModel = true;
          }
        }
      } catch (e) {
        debugPrint('bibliography advisor: $e');
      }
    }
    if (!anyModel) return null;
    _cache[key] = out;
    if (_cache.length > 4) _cache.remove(_cache.keys.first);
    return out;
  }

  static bool get _modelAvailable {
    try {
      return GeminiAdvisorClient.isAvailable;
    } catch (_) {
      return false;
    }
  }

  static String _sourceLine(PublishReference reference, String local) {
    final raw = reference.rawText.trim();
    return raw.length >= 20 ? raw : local;
  }

  static Future<List<String>?> _ask({
    required List<PublishReference> references,
    required List<String> local,
    required PublishCitationStyle style,
    required String marker,
    required String sample,
    required String inText,
    required int indexBase,
  }) async {
    final input = StringBuffer();
    for (var i = 0; i < references.length; i++) {
      input.writeln('${indexBase + i + 1}\t${_sourceLine(references[i], local[i])}');
    }
    final result = await GeminiAdvisorClient.instance.generateResult(
      preferPro: true,
      maxOutputTokens: 8192,
      systemPrompt: '''
You are the references editor of a scientific journal. Restyle each source line into one consistent reference list.

Target style: ${style.name}.
$marker
${sample.isEmpty ? 'No journal sample was supplied. Follow the named style only.' : 'Match this journal sample: $sample'}
${inText.isEmpty ? '' : 'In-text sample from the guide: $inText'}

Rules:
- Return the same number of lines, in the same order.
- Keep every surname, year, title, journal, volume, issue, pages, and DOI that the source line already contains.
- Copy a DOI exactly, including the 10. prefix. If the source has no DOI, do not invent one.
- Do not invent volume, pages, or authors.
- Do not reduce a surname to a single initial.
- Do not split a title in the middle.
- Return only JSON: {"lines":["..."]}
''',
      userMessage: input.toString(),
    );
    if (!result.isSuccess) return null;
    return _parseLines(result.text!, references.length);
  }

  static List<String>? _parseLines(String raw, int count) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    final decoded = jsonDecode(raw.substring(start, end + 1));
    if (decoded is! Map) return null;
    final list = decoded['lines'];
    if (list is! List || list.length != count) return null;
    final out = <String>[];
    for (final item in list) {
      final line = '$item'.trim();
      if (line.length < 8) return null;
      out.add(line);
    }
    return out;
  }

  static bool _keepsFacts(
    String source,
    String line, {
    required bool numbered,
  }) {
    if (line.trim().length < 8) return false;
    final year = RegExp(r'(?:19|20)\d{2}').firstMatch(source)?.group(0);
    if (year != null && !line.contains(year)) return false;
    final doi = RegExp(r'10\.\d{4,}/[^\s,;]+').firstMatch(source)?.group(0);
    if (doi != null && !line.contains(doi.split('/').first)) return false;
    if (RegExp(r'doi:\s*(?!10\.)', caseSensitive: false).hasMatch(line)) {
      return false;
    }
    final token = RegExp(r'[A-Za-z]{6,}').firstMatch(source)?.group(0);
    if (token != null && !line.toLowerCase().contains(token.toLowerCase())) {
      return false;
    }
    if (numbered) {
      final bracket = RegExp(r'^\[\d+\]').hasMatch(line.trim());
      final plain = RegExp(r'^\d+\.\s').hasMatch(line.trim());
      if (!bracket && !plain) return false;
    }
    return true;
  }

  static bool _sampleIsNumbered(String sample) {
    final t = sample.trim();
    return RegExp(r'^\[\d+\]').hasMatch(t) || RegExp(r'^\d+\.').hasMatch(t);
  }

  static String _alignToSample({
    required String local,
    required String model,
    required String sample,
  }) {
    if (sample.trim().isEmpty) return _withLocalPrefix(local, model);
    final body = model.trim().replaceFirst(
          RegExp(r'^(?:\[\d+\]|\d+\.)\s*'),
          '',
        );
    if (!_sampleIsNumbered(sample)) return body;
    final plain = RegExp(r'^\d+\.').hasMatch(sample.trim());
    final prefix =
        RegExp(r'^(?:\[\d+\]|\d+\.)\s*').firstMatch(local.trim())?.group(0);
    if (prefix == null) return model.trim();
    final wantedPlain = RegExp(r'^\d+\.').hasMatch(prefix);
    if (wantedPlain == plain) return '$prefix$body';
    final number = RegExp(r'\d+').firstMatch(prefix)?.group(0) ?? '1';
    return plain ? '$number. $body' : '[$number] $body';
  }

  static String _withLocalPrefix(String local, String model) {
    final prefix =
        RegExp(r'^(?:\[\d+\]|\d+\.)\s*').firstMatch(local.trim())?.group(0);
    final body = model.trim().replaceFirst(
          RegExp(r'^(?:\[\d+\]|\d+\.)\s*'),
          '',
        );
    if (prefix == null) return body;
    return '$prefix$body';
  }
}
