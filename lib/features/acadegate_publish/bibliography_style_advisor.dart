import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../ai_advisor/gemini_advisor_client.dart';
import 'citation_formatter.dart';
import 'publish_models.dart';

/// Restyles a bibliography to one journal system. Does not invent missing fields.
class BibliographyStyleAdvisor {
  BibliographyStyleAdvisor._();

  /// Offline request seam; bypasses model availability and cache in tests.
  @visibleForTesting
  static Future<List<String>?> Function(List<String> sources)?
  requestLinesForTesting;

  static final _cache = <String, List<String>>{};

  static Future<List<String>?> restyle({
    required List<PublishReference> references,
    required PublishCitationStyle style,
    String? referenceExample,
    String? inTextExample,
    bool plainNumbers = false,
  }) async {
    if (references.isEmpty) return const [];
    // ACS punctuation and bold/italic runs are built at construction; the
    // text restyle path would flatten them.
    if (style == PublishCitationStyle.acs) return null;
    if (requestLinesForTesting == null && !_modelAvailable) return null;
    final local = [
      for (var i = 0; i < references.length; i++)
        CitationFormatter.buildBibliographyEntry(
          reference: references[i],
          style: style,
          index: CitationFormatter.bibliographyIndex(references[i], i + 1),
          plainNumberList: plainNumbers,
        ).plain.trim(),
    ];
    final key =
        '${style.name}|$plainNumbers|${referenceExample ?? ''}|'
        '${local.join('\n')}';
    final cached = _cache[key];
    if (requestLinesForTesting == null && cached != null) return cached;

    final numbered = CitationFormatter.isNumberedStyle(style);
    final marker = !numbered
        ? 'Do not add numbers. Keep author–date form.'
        : (plainNumbers || style == PublishCitationStyle.acs
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
          if (_keepsFacts(source, lines[i])) {
            out[start + i] = CitationFormatter.applyListNumberPolicy(
              BibliographyEntry([BibliographySpan(lines[i])]),
              style: style,
              index: CitationFormatter.bibliographyIndex(
                references[start + i],
                start + i + 1,
              ),
              plainNumberList: plainNumbers,
            ).plain;
            anyModel = true;
          }
        }
      } catch (e) {
        debugPrint('bibliography advisor: $e');
      }
    }
    if (!anyModel) return null;
    if (requestLinesForTesting == null) _cache[key] = out;
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
    final request = requestLinesForTesting;
    if (request != null) {
      return request([
        for (var i = 0; i < references.length; i++)
          _sourceLine(references[i], local[i]),
      ]);
    }
    final input = StringBuffer();
    for (var i = 0; i < references.length; i++) {
      input.writeln(
        '${indexBase + i + 1}\t${_sourceLine(references[i], local[i])}',
      );
    }
    final result = await GeminiAdvisorClient.instance.generateResult(
      preferPro: true,
      maxOutputTokens: 8192,
      systemPrompt:
          '''
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

  static bool _keepsFacts(String source, String line) {
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
    return true;
  }
}
