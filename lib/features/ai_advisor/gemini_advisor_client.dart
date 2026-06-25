import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'advisor_attachment.dart';

class GeminiGenerateResult {
  final String? text;
  final String? error;
  final String? modelUsed;

  const GeminiGenerateResult({this.text, this.error, this.modelUsed});

  bool get isSuccess => text != null && text!.isNotEmpty;
}

class GeminiAdvisorClient {
  GeminiAdvisorClient._();

  static final GeminiAdvisorClient instance = GeminiAdvisorClient._();

  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _preferredModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: '',
  );

  static const _modelFallbacks = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-2.5-pro',
    'gemini-2.0-flash-lite',
    'gemini-1.5-flash',
    'gemini-flash-latest',
  ];

  static bool get isConfigured =>
      _apiKey.isNotEmpty && !_looksLikePlaceholder(_apiKey);

  static bool get runsOnWeb => kIsWeb;

  static bool _looksLikePlaceholder(String key) {
    final trimmed = key.trim();
    if (trimmed.length < 35) return true;
    final upper = trimmed.toUpperCase();
    if (upper.contains('XXXX') || upper.contains('...')) return true;
    if (RegExp(r'^[\?\*\.xX]+$', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }
    return false;
  }

  List<String> get _modelsToTry {
    if (_preferredModel.isNotEmpty) {
      return [_preferredModel, ..._modelFallbacks.where((m) => m != _preferredModel)];
    }
    return _modelFallbacks;
  }

  Future<GeminiGenerateResult> generateResult({
    required String systemPrompt,
    required String userMessage,
    List<Map<String, String>> history = const [],
    List<GeminiInlinePart> attachments = const [],
    int maxOutputTokens = 8192,
  }) async {
    if (!isConfigured) {
      return const GeminiGenerateResult(
        error:
            'مفتاح API غير صالح. استخدم مفتاحاً حقيقياً من Google AI Studio (ليس AIzaSyXXXXXXXX).',
      );
    }

    if (kIsWeb) {
      final viaFunction = await _generateViaCloudFunction(
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        history: history,
        maxOutputTokens: maxOutputTokens,
      );
      if (viaFunction.isSuccess) return viaFunction;
    }

    GeminiGenerateResult? lastError;
    for (final model in _modelsToTry) {
      var result = await _generateViaHttp(
        model: model,
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        history: history,
        attachments: attachments,
        maxOutputTokens: maxOutputTokens,
      );
      if (result.isSuccess) return result;

      if (history.isNotEmpty && _isHistorySignatureError(result.error)) {
        result = await _generateViaHttp(
          model: model,
          systemPrompt: systemPrompt,
          userMessage: userMessage,
          history: const [],
          attachments: attachments,
          maxOutputTokens: maxOutputTokens,
        );
        if (result.isSuccess) return result;
      }

      lastError = result;
    }

    if (kIsWeb && lastError != null) {
      return GeminiGenerateResult(
        error: '${lastError.error}\n\n'
            'على المتصفح (Chrome): شغّل التطبيق على Windows بدلاً من Chrome، '
            'أو انشر Cloud Function من مجلد functions في المشروع.',
      );
    }

    return lastError ??
        const GeminiGenerateResult(error: 'تعذر الحصول على رد من Gemini');
  }

  Future<GeminiGenerateResult> _generateViaCloudFunction({
    required String systemPrompt,
    required String userMessage,
    required List<Map<String, String>> history,
    required int maxOutputTokens,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'geminiAdvisor',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
      );

      final response = await callable.call<Map<String, dynamic>>({
        'systemPrompt': systemPrompt,
        'userMessage': userMessage,
        'history': history,
        'maxOutputTokens': maxOutputTokens,
      });

      final data = response.data;
      final text = data['text']?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return GeminiGenerateResult(
          text: text,
          modelUsed: data['model']?.toString(),
        );
      }

      return GeminiGenerateResult(
        error: data['error']?.toString() ?? 'رد فارغ من Cloud Function',
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || e.code == 'unavailable') {
        return const GeminiGenerateResult(
          error: 'Cloud Function غير منشورة بعد (geminiAdvisor)',
        );
      }
      return GeminiGenerateResult(error: 'Cloud Function: ${e.message}');
    } catch (e) {
      return GeminiGenerateResult(error: 'Cloud Function: $e');
    }
  }

  Future<GeminiGenerateResult> _generateViaHttp({
    required String model,
    required String systemPrompt,
    required String userMessage,
    required List<Map<String, String>> history,
    required List<GeminiInlinePart> attachments,
    required int maxOutputTokens,
  }) async {
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey',
      );

      final contents = <Map<String, dynamic>>[];
      for (final item in history) {
        final role = item['role'];
        final text = item['text'];
        if (role == null || text == null || text.isEmpty) continue;
        contents.add({
          'role': role == 'assistant' ? 'model' : 'user',
          'parts': [
            {'text': text},
          ],
        });
      }

      contents.add({
        'role': 'user',
        'parts': _buildUserParts(userMessage, attachments),
      });

      final response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'system_instruction': {
                'parts': [
                  {'text': systemPrompt},
                ],
              },
              'contents': contents,
              'generationConfig': {
                'temperature': 0.85,
                'maxOutputTokens': maxOutputTokens,
                'thinkingConfig': {'thinkingBudget': 0},
              },
            }),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final apiError = _parseApiError(response.body);
        return GeminiGenerateResult(
          error: 'Gemini ($model): $apiError',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final extracted = _extractResponseText(data);
      if (extracted != null && extracted.isNotEmpty) {
        return GeminiGenerateResult(text: extracted, modelUsed: model);
      }

      final blockReason = data['promptFeedback']?['blockReason']?.toString();
      if (blockReason != null && blockReason.isNotEmpty) {
        return GeminiGenerateResult(
          error: 'Gemini ($model): المحتوى محظور ($blockReason)',
        );
      }

      return GeminiGenerateResult(
        error: 'Gemini ($model): رد فارغ — جرّب صياغة أخرى أو نموذجاً مختلفاً',
      );
    } catch (e) {
      final hint = kIsWeb ? ' (غالباً CORS على المتصفح)' : '';
      return GeminiGenerateResult(error: 'اتصال Gemini$hint: $e');
    }
  }

  static List<Map<String, dynamic>> _buildUserParts(
    String userMessage,
    List<GeminiInlinePart> attachments,
  ) {
    final parts = <Map<String, dynamic>>[];
    final trimmed = userMessage.trim();
    if (trimmed.isNotEmpty) {
      parts.add({'text': trimmed});
    }

    for (final attachment in attachments) {
      parts.add({
        'inline_data': {
          'mime_type': attachment.mimeType,
          'data': attachment.base64Data,
        },
      });
    }

    if (parts.isEmpty) {
      parts.add({'text': 'حلّل المرفقات المرفقة وأجب بالعربية.'});
    } else if (attachments.isNotEmpty && trimmed.isEmpty) {
      parts.insert(0, {
        'text': 'حلّل الملفات المرفقة وأجب بالعربية.',
      });
    }

    return parts;
  }

  static String? _extractResponseText(Map<String, dynamic> data) {
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return null;

    final candidate = candidates.first as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) return null;

    final chunks = <String>[];
    for (final raw in parts) {
      if (raw is! Map<String, dynamic>) continue;
      final text = raw['text']?.toString().trim();
      if (text != null && text.isNotEmpty) {
        chunks.add(text);
      }
    }
    if (chunks.isEmpty) return null;
    return chunks.join('\n');
  }

  static bool _isHistorySignatureError(String? error) {
    if (error == null) return false;
    final lower = error.toLowerCase();
    return lower.contains('thought_signature') ||
        lower.contains('thought signature');
  }

  String _parseApiError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>?;
      final message = error?['message']?.toString();
      if (message != null && message.isNotEmpty) return message;
    } catch (_) {}
    return 'خطأ API (${body.length > 120 ? '${body.substring(0, 120)}...' : body})';
  }

  Future<String?> generate({
    required String systemPrompt,
    required String userMessage,
    List<Map<String, String>> history = const [],
    List<GeminiInlinePart> attachments = const [],
    int maxOutputTokens = 8192,
  }) async {
    final result = await generateResult(
      systemPrompt: systemPrompt,
      userMessage: userMessage,
      history: history,
      attachments: attachments,
      maxOutputTokens: maxOutputTokens,
    );
    return result.text;
  }
}
