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
  "titleFontSizePt": number or null,
  "headingFontSizePt": number or null,
  "bodyFontSizePt": number or null,
  "lineSpacing": number or null,
  "lineSpacingLabel": "single" | "double" | "1.5" | null,
  "marginCm": number or null,
  "justifyText": boolean or null,
  "columns": 1 | 2 | null,
  "paperSize": "a4" | "letter" | null,
  "firstLineIndentCm": number or null,
  "headingNumbered": boolean or null,
  "headingUppercase": boolean or null,
  "titleUppercase": boolean or null,
  "titleAlign": "center" | "left" | null,
  "pageNumbers": boolean or null,
  "runningHeader": boolean or null,
  "runningTitleMaxChars": number or null,
  "maxReferences": number or null,
  "maxFiguresAndTables": number or null,
  "figureMaxWidthCm": number or null,
  "keywordsMin": number or null,
  "keywordsMax": number or null,
  "noEtAlInReferences": boolean or null,
  "referencesHeading": string or null,
  "referenceListPlainNumber": boolean or null,
  "referenceExample": string or null,
  "inTextExample": string or null,
  "abstractMaxWords": number or null,
  "sectionOrder": string[],
  "acceptedFileFormats": string[],
  "articleProcessingCharge": string or null,
  "keyRequirements": string[],
  "excerpt": string,
  "notes": string
}
Rules: found=false if no formatting instructions. Extract EVERY layout rule stated: columns, paper size, first-line indent, heading numbering/case, title alignment, page numbers, running header, title/heading/body font sizes, section order. citationStyle must be THIS journal's style (acs/ieee/apa/vancouver/harvard/chicago). ACS chemistry journals typically use superscript numbers. excerpt must quote the actual instruction. Do not invent Times New Roman, double spacing, or APA. single-spaced => lineSpacing=1. referenceListPlainNumber=true when the guide lists references as 1., 2., 3. without square brackets. Copy the guide's SAMPLE reference line into referenceExample and the SAMPLE in-text citation into inTextExample exactly as printed. Also extract: titleUppercase, maxReferences, maxFiguresAndTables, figureMaxWidthCm, keywordsMin, keywordsMax, runningTitleMaxChars, noEtAlInReferences, headingNumbered=false when the guide forbids numbering sections.
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

    // Pasted / uploaded guide text is the source of truth for ANY journal.
    // Never fall through to URL search — that made «Apply pasted text» appear
    // to do nothing while a 3-minute cloud fetch ran.
    if (text.length >= 15) {
      return _extractFromProvidedText(
        journalName: journalName,
        publisher: publisher,
        text: text,
        sourceUrl: url.isNotEmpty ? url : 'pasted_by_user',
        fallback: fallback,
      );
    }

    final payload = {
      'journalName': journalName,
      'publisher': publisher,
      'issn': issn,
      if (url.isNotEmpty) 'guidelinesUrl': url,
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
        heuristic: null,
      );
      if (parsed.success) return parsed;
      return parsed;
    }

    return JournalGuidelinesExtractionResult(
      success: false,
      reason: 'cloud_unavailable',
      message: cloudError ??
          appTr(
            'تعذّر البحث التلقائي. الصق نص دليل المؤلفين من موقع المجلة ثم اضغط تطبيق.',
            'Automatic search failed. Paste the author guide from the journal site, then apply.',
          ),
    );
  }

  Future<JournalGuidelinesExtractionResult> _extractFromProvidedText({
    required String journalName,
    required String publisher,
    required String text,
    required String sourceUrl,
    JournalFormatRules? fallback,
  }) async {
    final heuristic = JournalGuidelinesHeuristic.extract(
      text,
      requireDistinctive: false,
    );

    if (heuristic != null) {
      return _resultFromExtracted(
        extracted: heuristic,
        journalName: journalName,
        publisher: publisher,
        sourceUrl: sourceUrl,
        sourceType: 'pasted_text_heuristic',
        fallback: fallback,
      );
    }

    return JournalGuidelinesExtractionResult(
      success: false,
      reason: 'paste_unparsed',
      message: appTr(
        'لم يُستخرج من النص الملصوق تعليمات تنسيق واضحة. الصق فقرات الدليل (المراجع، الملخص، العنوان، الأشكال) ثم أعد التطبيق.',
        'No clear formatting instructions were found in the pasted text. Paste the guide sections on references, abstract, title, and figures, then apply again.',
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
    Map<String, dynamic>? heuristic,
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

    final extracted = JournalGuidelinesHeuristic.merge(
      heuristic,
      Map<String, dynamic>.from(rulesMap),
    );
    return _resultFromExtracted(
      extracted: extracted,
      journalName: journalName,
      publisher: publisher,
      sourceUrl: data['sourceUrl']?.toString() ?? '',
      sourceType: data['sourceType']?.toString() ?? 'cloud',
      fallback: fallback,
      attemptedUrls: _stringList(data['attemptedUrls']),
      fetchLog: fetchLog,
    );
  }

  JournalGuidelinesExtractionResult _resultFromExtracted({
    required Map<String, dynamic> extracted,
    required String journalName,
    required String publisher,
    required String sourceUrl,
    required String sourceType,
    JournalFormatRules? fallback,
    List<String> attemptedUrls = const [],
    List<String> fetchLog = const [],
  }) {
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
      sourceType: sourceType,
      rules: rules,
      attemptedUrls: attemptedUrls,
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
    Map<String, dynamic>? heuristic,
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

    final parsed = _parseJsonFromModel(result.text!);
    final extracted = JournalGuidelinesHeuristic.merge(heuristic, parsed);
    if (extracted['found'] != true) return null;

    return _resultFromExtracted(
      extracted: extracted,
      journalName: journalName,
      publisher: publisher,
      sourceUrl: sourceUrl,
      sourceType: 'gemini_client',
      fallback: fallback,
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
    final refExample = extracted['referenceExample']?.toString().trim();
    final inTextExample = extracted['inTextExample']?.toString().trim();

    final columns = extracted['columns'];
    final paper = extracted['paperSize']?.toString();
    return [
      ...reqs,
      if (refExample != null && refExample.isNotEmpty)
        'شكل المرجع: $refExample',
      if (inTextExample != null && inTextExample.isNotEmpty)
        'الاقتباس في النص: $inTextExample',
      if (sections.isNotEmpty) 'ترتيب الأقسام: ${sections.join(' → ')}',
      if (apc != null && apc.isNotEmpty) 'رسوم النشر: $apc',
      if (abstractMax != null) 'حد أقصى للملخص: $abstractMax كلمة',
      if (formats.isNotEmpty) 'صيغ الملفات: ${formats.join(', ')}',
      if (columns != null) 'أعمدة: $columns',
      if (paper != null && paper.isNotEmpty) 'حجم الورق: $paper',
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
