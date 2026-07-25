import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/firebase/callable_http_client.dart';
import '../../core/locale/app_translate.dart';
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

  static bool get hasLocalKey =>
      _apiKey.isNotEmpty && !_looksLikePlaceholder(_apiKey);

  /// يعتمد على مفتاح dart-define (Windows/Android/iOS).
  static bool get isConfigured => hasLocalKey;

  static bool get runsOnWeb => kIsWeb;

  /// Cloud Function متاحة على كل المنصات بعد تسجيل الدخول (لا حاجة لمفتاح محلي).
  static bool get canUseCloudBackend =>
      FirebaseAuth.instance.currentUser != null;

  /// نص أو مرفقات — مفتاح محلي أو Cloud Function بعد تسجيل الدخول.
  static bool get isAvailable => hasLocalKey || canUseCloudBackend;

  static bool get canAnalyzeAttachments => isAvailable;

  static bool get needsSignInForCloudAi =>
      !hasLocalKey && FirebaseAuth.instance.currentUser == null;

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
    final needsStorageBackend =
        attachments.any((a) => a.hasStoragePath) && canUseCloudBackend;

    if (canUseCloudBackend) {
      final viaFunction = await _generateViaCloudFunction(
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        history: history,
        attachments: attachments,
        maxOutputTokens: maxOutputTokens,
      );
      if (viaFunction.isSuccess) return viaFunction;
      if (!hasLocalKey || needsStorageBackend) return viaFunction;
    }

    if (!hasLocalKey) {
      if (needsSignInForCloudAi) {
        return GeminiGenerateResult(
          error: appTr(
            'سجّل الدخول لاستخدام AcadeGate AI.',
            'Sign in to use AcadeGate AI.',
          ),
        );
      }
      return GeminiGenerateResult(
        error: appTr(
          'سجّل الدخول لاستخدام AcadeGate AI، أو أضف مفتاح Gemini في dart_defines.json '
              'وشغّل إعداد: AcadeGate (Windows + AI).',
          'Sign in to use AcadeGate AI, or add a Gemini key in dart_defines.json '
              'and launch: AcadeGate (Windows + AI).',
        ),
      );
    }

    final inlineOnly = attachments.where((a) => a.hasInlineData).toList();
    if (attachments.isNotEmpty && inlineOnly.isEmpty) {
      return GeminiGenerateResult(
        error: appTr(
          'الملف الكبير يتطلب تسجيل الدخول لتحليله عبر السحابة.',
          'Large files require sign-in for cloud analysis.',
        ),
      );
    }

    GeminiGenerateResult? lastError;
    for (final model in _modelsToTry) {
      var result = await _generateViaHttp(
        model: model,
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        history: history,
        attachments: inlineOnly,
        maxOutputTokens: maxOutputTokens,
      );
      if (result.isSuccess) return result;

      if (history.isNotEmpty && _isHistorySignatureError(result.error)) {
        result = await _generateViaHttp(
          model: model,
          systemPrompt: systemPrompt,
          userMessage: userMessage,
          history: const [],
          attachments: inlineOnly,
          maxOutputTokens: maxOutputTokens,
        );
        if (result.isSuccess) return result;
      }

      lastError = result;
    }

    if (kIsWeb && lastError != null) {
      return GeminiGenerateResult(
        error: '${lastError.error}\n\n'
            '${appTr(
              'على المتصفح (Chrome): شغّل التطبيق على Windows بدلاً من Chrome، '
                  'أو انشر Cloud Function من مجلد functions في المشروع.',
              'In the browser (Chrome): run the app on Windows instead of Chrome, '
                  'or deploy the Cloud Function from the functions folder in the project.',
            )}',
      );
    }

    return lastError ??
        GeminiGenerateResult(
          error: appTr(
            'تعذر الحصول على رد من Gemini',
            'Could not get a response from Gemini',
          ),
        );
  }

  Future<GeminiGenerateResult> _generateViaCloudFunction({
    required String systemPrompt,
    required String userMessage,
    required List<Map<String, String>> history,
    required List<GeminiInlinePart> attachments,
    required int maxOutputTokens,
  }) async {
    final payload = <String, dynamic>{
      'systemPrompt': systemPrompt,
      'userMessage': userMessage,
      'history': history,
      'attachments': attachments
          .map(
            (a) => {
              'mimeType': a.mimeType,
              if (a.hasInlineData) 'base64Data': a.base64Data,
              if (a.hasStoragePath) 'storagePath': a.storagePath,
              'fileName': a.fileName,
            },
          )
          .toList(),
      'maxOutputTokens': maxOutputTokens,
    };

    // Windows cloud_functions pigeon channel often fails; use HTTP like other callables.
    if (_preferHttpCallable) {
      return _generateViaCallableHttp(payload);
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'geminiAdvisor',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 180)),
      );

      final response = await callable.call<Map<String, dynamic>>(payload);

      final data = response.data;
      final text = data['text']?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return GeminiGenerateResult(
          text: text,
          modelUsed: data['model']?.toString(),
        );
      }

      return GeminiGenerateResult(
        error: data['error']?.toString() ??
            appTr('رد فارغ من Cloud Function', 'Empty response from Cloud Function'),
      );
    } on FirebaseFunctionsException catch (e) {
      if (_isPluginChannelError(e.message)) {
        return _generateViaCallableHttp(payload);
      }
      if (e.code == 'not-found' || e.code == 'unavailable') {
        return GeminiGenerateResult(
          error: appTr(
            'Cloud Function غير منشورة بعد (geminiAdvisor)',
            'Cloud Function not deployed yet (geminiAdvisor)',
          ),
        );
      }
      return GeminiGenerateResult(error: 'Cloud Function: ${e.message}');
    } catch (e) {
      if (_isPluginChannelError(e.toString())) {
        return _generateViaCallableHttp(payload);
      }
      return GeminiGenerateResult(error: 'Cloud Function: $e');
    }
  }

  static bool get _preferHttpCallable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static bool _isPluginChannelError(String? message) {
    if (message == null) return false;
    final lower = message.toLowerCase();
    return lower.contains('unable to establish connection on channel') ||
        lower.contains('cloudfunctionshostapi') ||
        lower.contains('pigeon');
  }

  Future<GeminiGenerateResult> _generateViaCallableHttp(
    Map<String, dynamic> payload,
  ) async {
    try {
      final data = await CallableHttpClient.call(
        name: 'geminiAdvisor',
        data: payload,
        timeout: const Duration(seconds: 180),
        callableProtocol: true,
      );
      final text = data['text']?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return GeminiGenerateResult(
          text: text,
          modelUsed: data['model']?.toString(),
        );
      }
      return GeminiGenerateResult(
        error: data['error']?.toString() ??
            appTr('رد فارغ من Cloud Function', 'Empty response from Cloud Function'),
      );
    } on CallableHttpException catch (e) {
      if (e.code == 'not-found' || e.code == 'unavailable') {
        return GeminiGenerateResult(
          error: appTr(
            'Cloud Function غير منشورة بعد (geminiAdvisor)',
            'Cloud Function not deployed yet (geminiAdvisor)',
          ),
        );
      }
      if (e.code == 'unauthenticated') {
        return GeminiGenerateResult(
          error: appTr(
            'سجّل الدخول مجدداً لاستخدام AcadeGate AI.',
            'Sign in again to use AcadeGate AI.',
          ),
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
          error: appTr(
            'Gemini ($model): المحتوى محظور ($blockReason)',
            'Gemini ($model): content blocked ($blockReason)',
          ),
        );
      }

      return GeminiGenerateResult(
        error: appTr(
          'Gemini ($model): رد فارغ — جرّب صياغة أخرى أو نموذجاً مختلفاً',
          'Gemini ($model): empty response — try different wording or another model',
        ),
      );
    } catch (e) {
      final hint = kIsWeb
          ? appTr(' (غالباً CORS على المتصفح)', ' (likely CORS in the browser)')
          : '';
      return GeminiGenerateResult(
        error: appTr('اتصال Gemini$hint: $e', 'Gemini connection$hint: $e'),
      );
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
      if (!attachment.hasInlineData) continue;
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
    return appTr(
      'خطأ API (${body.length > 120 ? '${body.substring(0, 120)}...' : body})',
      'API error (${body.length > 120 ? '${body.substring(0, 120)}...' : body})',
    );
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
