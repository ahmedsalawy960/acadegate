import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../core/firebase/callable_http_client.dart';
import '../../core/locale/app_translate.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import 'journal_format_rules.dart';
import 'journal_guidelines_heuristic.dart';

class JournalGuidelinesExtractionResult {
  final bool success;
  final String? reason;
  final String? message;
  final String? sourceUrl;
  final String? sourceType;
  final JournalFormatRules? rules;
  final List<String> attemptedUrls;
  final List<String> keyRequirements;
  final List<String> fetchLog;
  final String? excerpt;
  final String? notes;

  const JournalGuidelinesExtractionResult({
    required this.success,
    this.reason,
    this.message,
    this.sourceUrl,
    this.sourceType,
    this.rules,
    this.attemptedUrls = const [],
    this.keyRequirements = const [],
    this.fetchLog = const [],
    this.excerpt,
    this.notes,
  });
}

class JournalGuidelinesExtractService {
  JournalGuidelinesExtractService._();

  static final JournalGuidelinesExtractService instance =
      JournalGuidelinesExtractService._();

  static const _extractSystemPrompt = '''
You extract journal author formatting rules from official guidelines text.
Return ONLY valid JSON (no markdown fences):
{
  "found": boolean,
  "confidence": "high" | "medium" | "low",
  "citationStyle": "ieee" | "apa" | "vancouver" | "acs" | "chicago" | "harvard" | "other",
  "fontFamily": string or null,
  "bodyFontSizePt": number or null,
  "lineSpacing": number or null,
  "lineSpacingLabel": "single" | "double" | "1.5" | null,
  "marginCm": number or null,
  "justifyText": boolean or null,
  "referencesHeading": string or null,
  "referenceListPlainNumber": boolean or null,
  "abstractMaxWords": number or null,
  "sectionOrder": string[],
  "acceptedFileFormats": string[],
  "articleProcessingCharge": string or null,
  "keyRequirements": string[],
  "excerpt": string,
  "notes": string
}
Rules: found=false if no formatting instructions. single-spaced => lineSpacing=1. referenceListPlainNumber=true when the guide says references are listed as 1., 2., 3. without square brackets while in-text uses [1]. Do not invent rules.
''';

  Future<JournalGuidelinesExtractionResult> extract({
    required String journalName,
    String publisher = '',
    String issn = '',
    String guidelinesUrl = '',
    String guidelinesText = '',
    String submissionUrl = '',
    List<String> candidateUrls = const [],
    JournalFormatRules? fallback,
  }) async {
    final url = guidelinesUrl.trim();
    final text = guidelinesText.trim();

    if (journalName.trim().isEmpty) {
      return JournalGuidelinesExtractionResult(
        success: false,
        reason: 'missing_journal',
        message: appTr('اسم المجلة مطلوب', 'Journal name is required'),
      );
    }

    if (text.length >= 15) {
      final heuristic = JournalGuidelinesHeuristic.extract(text);
      if (heuristic != null) {
        final rules = JournalFormatRules.fromExtracted(
          journalName: journalName,
          publisher: publisher,
          sourceUrl: url.isNotEmpty ? url : 'pasted_by_user',
          extracted: heuristic,
          fallback: fallback,
        );
        return JournalGuidelinesExtractionResult(
          success: true,
          sourceUrl: url.isNotEmpty ? url : 'pasted_by_user',
          sourceType: 'pasted_text_heuristic',
          rules: rules,
          keyRequirements: _requirementsFromExtracted(heuristic),
          excerpt: heuristic['excerpt']?.toString(),
        );
      }
    }

    final payload = {
      'journalName': journalName,
      'publisher': publisher,
      'issn': issn,
      if (url.isNotEmpty) 'guidelinesUrl': url,
      if (text.isNotEmpty) 'guidelinesText': text,
      if (submissionUrl.trim().isNotEmpty) 'submissionUrl': submissionUrl.trim(),
      if (candidateUrls.isNotEmpty) 'candidateUrls': candidateUrls,
    };

    Map<String, dynamic>? data;
    String? cloudError;

    try {
      data = await _callCloud(payload);
    } catch (e) {
      cloudError = '$e';
    }

    if (data != null) {
      final parsed = _parseCloudResult(
        data: data,
        journalName: journalName,
        publisher: publisher,
        fallback: fallback,
      );
      if (parsed.success) return parsed;

      if (text.length >= 80) {
        final local = await _extractWithGeminiClient(
          journalName: journalName,
          publisher: publisher,
          sourceUrl: url.isNotEmpty ? url : 'pasted_by_user',
          pageText: text,
          fallback: fallback,
        );
        if (local != null) return local;
      }
      return parsed;
    }

    if (text.length >= 80) {
      final local = await _extractWithGeminiClient(
        journalName: journalName,
        publisher: publisher,
        sourceUrl: url.isNotEmpty ? url : 'pasted_by_user',
        pageText: text,
        fallback: fallback,
      );
      if (local != null) return local;
    }

    return JournalGuidelinesExtractionResult(
      success: false,
      reason: 'cloud_unavailable',
      message: cloudError ??
          appTr(
            'تعذّر الاتصال بخدمة القراءة. انسخ نص الدليل من الصفحة والصقه في الحقل النصي.',
            'Could not reach the reader service. Copy the guide text from the page and paste it.',
          ),
    );
  }

  Future<Map<String, dynamic>> _callCloud(Map<String, dynamic> payload) async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return CallableHttpClient.call(
        name: 'journalGuidelinesExtractHttp',
        data: payload,
        timeout: const Duration(minutes: 3),
      );
    }

    final callable = FirebaseFunctions.instance.httpsCallable(
      'journalGuidelinesExtract',
      options: HttpsCallableOptions(timeout: const Duration(minutes: 2)),
    );
    final response = await callable.call<Map<String, dynamic>>(payload);
    return Map<String, dynamic>.from(response.data);
  }

  JournalGuidelinesExtractionResult _parseCloudResult({
    required Map<String, dynamic> data,
    required String journalName,
    required String publisher,
    JournalFormatRules? fallback,
  }) {
    final success = data['success'] == true;
    final fetchLog = _fetchLogLines(data['fetchLog']);

    if (!success) {
      return JournalGuidelinesExtractionResult(
        success: false,
        reason: data['reason']?.toString(),
        message: data['message']?.toString(),
        attemptedUrls: _stringList(data['attemptedUrls']),
        fetchLog: fetchLog,
      );
    }

    final rulesMap = data['rules'];
    if (rulesMap is! Map) {
      return JournalGuidelinesExtractionResult(
        success: false,
        reason: 'invalid_response',
        message: appTr('استجابة غير صالحة من الخادم', 'Invalid server response'),
        fetchLog: fetchLog,
      );
    }

    final extracted = Map<String, dynamic>.from(rulesMap);
    final rules = JournalFormatRules.fromExtracted(
      journalName: journalName,
      publisher: publisher,
      sourceUrl: data['sourceUrl']?.toString() ?? '',
      extracted: extracted,
      fallback: fallback,
    );

    return JournalGuidelinesExtractionResult(
      success: true,
      sourceUrl: data['sourceUrl']?.toString(),
      sourceType: data['sourceType']?.toString(),
      rules: rules,
      attemptedUrls: _stringList(data['attemptedUrls']),
      keyRequirements: _requirementsFromExtracted(extracted),
      fetchLog: fetchLog,
      excerpt: extracted['excerpt']?.toString(),
      notes: extracted['notes']?.toString(),
    );
  }

  Future<JournalGuidelinesExtractionResult?> _extractWithGeminiClient({
    required String journalName,
    required String publisher,
    required String sourceUrl,
    required String pageText,
    JournalFormatRules? fallback,
  }) async {
    if (!GeminiAdvisorClient.isAvailable) return null;

    final clipped = pageText.length > 60000
        ? pageText.substring(0, 60000)
        : pageText;

    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: _extractSystemPrompt,
      userMessage:
          'Journal: $journalName\nPublisher: $publisher\nSource: $sourceUrl\n\nTEXT:\n$clipped',
      maxOutputTokens: 4096,
    );

    if (!result.isSuccess || result.text == null) return null;

    final extracted = _parseJsonFromModel(result.text!);
    if (extracted == null || extracted['found'] != true) return null;

    final rules = JournalFormatRules.fromExtracted(
      journalName: journalName,
      publisher: publisher,
      sourceUrl: sourceUrl,
      extracted: extracted,
      fallback: fallback,
    );

    return JournalGuidelinesExtractionResult(
      success: true,
      sourceUrl: sourceUrl,
      sourceType: 'gemini_client',
      rules: rules,
      keyRequirements: _requirementsFromExtracted(extracted),
      excerpt: extracted['excerpt']?.toString(),
      notes: extracted['notes']?.toString(),
    );
  }

  static Map<String, dynamic>? _parseJsonFromModel(String raw) {
    final trimmed = raw.trim();
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false)
        .firstMatch(trimmed);
    final candidate = fenced?.group(1)?.trim() ?? trimmed;
    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    final start = candidate.indexOf('{');
    final end = candidate.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final decoded = jsonDecode(candidate.substring(start, end + 1));
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return null;
  }

  static List<String> _requirementsFromExtracted(Map<String, dynamic> extracted) {
    final reqs = _stringList(extracted['keyRequirements']);
    final sections = _stringList(extracted['sectionOrder']);
    final apc = extracted['articleProcessingCharge']?.toString().trim();
    final abstractMax = extracted['abstractMaxWords'];
    final formats = _stringList(extracted['acceptedFileFormats']);

    return [
      ...reqs,
      if (sections.isNotEmpty) 'ترتيب الأقسام: ${sections.join(' → ')}',
      if (apc != null && apc.isNotEmpty) 'رسوم النشر: $apc',
      if (abstractMax != null) 'حد أقصى للملخص: $abstractMax كلمة',
      if (formats.isNotEmpty) 'صيغ الملفات: ${formats.join(', ')}',
    ];
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  static List<String> _fetchLogLines(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((entry) {
      if (entry is! Map) return entry.toString();
      final url = entry['url'] ?? '';
      final source = entry['source'] ?? '';
      if (source == 'google_search_grounding') {
        final err = entry['error']?.toString() ?? '';
        return err.isEmpty
            ? 'Google Search (AI) → بحث تلقائي عن الدليل'
            : 'Google Search (AI) → فشل: $err';
      }
      final fetched = entry['fetched'] == true;
      final len = entry['textLength'] ?? 0;
      final status = entry['status'] ?? '';
      return '$url → ${fetched ? "OK ($len chars)" : "FAILED ($status)"}';
    }).toList();
  }
}
