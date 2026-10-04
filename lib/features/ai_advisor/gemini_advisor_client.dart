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

class GeminiImageResult {
  final List<int>? bytes;
  final String mimeType;
  final String? error;
  final String? modelUsed;

  const GeminiImageResult({
    this.bytes,
    this.mimeType = 'image/png',
    this.error,
    this.modelUsed,
  });

  bool get isSuccess => bytes != null && bytes!.isNotEmpty;
}

class GeminiAdvisorClient {
  GeminiAdvisorClient._();

  static final GeminiAdvisorClient instance = GeminiAdvisorClient._();

  /// Local keys are debug-only. Release/web builds must not pass
  /// `--dart-define-from-file=dart_defines.json` (keys would embed in the binary).
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _preferredModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: '',
  );

  /// نماذج حالية — 1.5/2.0 أُوقفت؛ 2.5 Flash قوي وسريع للصور والنص
  static const _modelFallbacks = [
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-2.5-flash-lite',
    'gemini-flash-latest',
  ];

  static const _imageModels = [
    'gemini-2.5-flash-image',
    'gemini-2.5-flash-preview-image-generation',
    'gemini-2.0-flash-preview-image-generation',
    'gemini-2.0-flash-exp-image-generation',
  ];

  static const _thinkingModels = {
    'gemini-2.5-flash',
    'gemini-2.5-pro',
  };

  static bool get hasLocalKey =>
      kDebugMode && _apiKey.isNotEmpty && !_looksLikePlaceholder(_apiKey);

  /// مفتاح dart-define محلي — Debug فقط؛ الإنتاج عبر Cloud Functions.
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

  List<String> _modelsToTryFor({required bool preferPro}) {
    final base = _modelsToTry;
    if (!preferPro) return base;
    return [
      'gemini-2.5-pro',
      ...base.where((m) => m != 'gemini-2.5-pro'),
    ];
  }

  Future<GeminiGenerateResult> generateResult({
    required String systemPrompt,
    required String userMessage,
    List<Map<String, String>> history = const [],
    List<GeminiInlinePart> attachments = const [],
    int maxOutputTokens = 8192,
    bool preferPro = false,
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
        preferPro: preferPro,
      );
      if (viaFunction.isSuccess) return viaFunction;
      if (!hasLocalKey || needsStorageBackend) return viaFunction;
      // Signed-in users stay on cloud quotas (no local API-key bypass).
      if (FirebaseAuth.instance.currentUser != null) return viaFunction;
    }

    if (!hasLocalKey) {
      if (needsSignInForCloudAi) {
        return GeminiGenerateResult(
          error: appTr(
            'سجّل الدخول لاستخدام المساعد الأكاديمي.',
            'Sign in to use the Academic Assistant.',
          ),
        );
      }
      return GeminiGenerateResult(
        error: appTr(
          'سجّل الدخول لاستخدام المساعد الأكاديمي.',
          'Sign in to use the Academic Assistant.',
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

    final errors = <GeminiGenerateResult>[];
    for (final model in _modelsToTryFor(preferPro: preferPro)) {
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

      errors.add(result);
    }

    final chosen = _pickUsefulError(errors);
    if (kIsWeb && chosen != null) {
      return GeminiGenerateResult(
        error: '${chosen.error}\n\n'
            '${appTr(
              'على المتصفح (Chrome): شغّل التطبيق على Windows بدلاً من Chrome، '
                  'أو انشر Cloud Function من مجلد functions في المشروع.',
              'In the browser (Chrome): run the app on Windows instead of Chrome, '
                  'or deploy the Cloud Function from the functions folder in the project.',
            )}',
      );
    }

    return chosen ??
        GeminiGenerateResult(
          error: appTr(
            'تعذر الحصول على رد من Gemini',
            'Could not get a response from Gemini',
          ),
        );
  }

  static GeminiGenerateResult? _pickUsefulError(List<GeminiGenerateResult> errors) {
    if (errors.isEmpty) return null;
    final notFound = RegExp(
      r'is not found|not supported for generateContent',
      caseSensitive: false,
    );
    for (final e in errors) {
      final msg = e.error ?? '';
      if (msg.isNotEmpty && !notFound.hasMatch(msg)) return e;
    }
    return errors.last;
  }

  Future<GeminiGenerateResult> _generateViaCloudFunction({
    required String systemPrompt,
    required String userMessage,
    required List<Map<String, String>> history,
    required List<GeminiInlinePart> attachments,
    required int maxOutputTokens,
    bool preferPro = false,
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
      'preferPro': preferPro,
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
      if (e.code == 'resource-exhausted' || e.code == 'resource_exhausted') {
        return GeminiGenerateResult(
          error: e.message?.trim().isNotEmpty == true
              ? e.message!.trim()
              : appTr(
                  'وصلت للحد اليومي للمساعد الأكاديمي.',
                  'Daily Academic Assistant limit reached.',
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
            'سجّل الدخول مجدداً لاستخدام المساعد الأكاديمي.',
            'Sign in again to use the Academic Assistant.',
          ),
        );
      }
      if (e.code == 'resource-exhausted' || e.code == 'resource_exhausted') {
        return GeminiGenerateResult(
          error: e.message.trim().isNotEmpty
              ? e.message.trim()
              : appTr(
                  'وصلت للحد اليومي للمساعد الأكاديمي.',
                  'Daily Academic Assistant limit reached.',
                ),
        );
      }
      final msg = e.message.trim();
      if (msg.isEmpty || msg.toUpperCase() == 'INTERNAL') {
        return GeminiGenerateResult(
          error: appTr(
            'خطأ داخلي في خادم AI (Firestore/الحصة). أعد المحاولة بعد لحظات.',
            'Internal AI server error (Firestore/quota). Try again in a moment.',
          ),
        );
      }
      return GeminiGenerateResult(error: 'Cloud Function: $msg');
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
              'systemInstruction': {
                'parts': [
                  {'text': systemPrompt},
                ],
              },
              'contents': contents,
              'generationConfig': _generationConfig(
                model: model,
                maxOutputTokens: maxOutputTokens,
                hasAttachments: attachments.any((a) => a.hasInlineData),
              ),
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

  static Map<String, dynamic> _generationConfig({
    required String model,
    required int maxOutputTokens,
    required bool hasAttachments,
  }) {
    final config = <String, dynamic>{
      'temperature': hasAttachments ? 0.4 : 0.85,
      'maxOutputTokens': maxOutputTokens,
    };
    // thinkingConfig يكسر طلبات الصور وكثيراً من النماذج غير 2.5
    if (!hasAttachments && _thinkingModels.contains(model)) {
      config['thinkingConfig'] = {'thinkingBudget': 0};
    }
    return config;
  }

  static String _cleanBase64(String raw) {
    var s = raw.replaceAll(RegExp(r'\s'), '');
    final m = RegExp(r'^data:[^;]+;base64,(.+)$', caseSensitive: false)
        .firstMatch(s);
    if (m != null) s = m.group(1) ?? s;
    return s;
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
      final data = _cleanBase64(attachment.base64Data);
      if (data.isEmpty) continue;
      parts.add({
        'inlineData': {
          'mimeType': attachment.mimeType,
          'data': data,
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

  /// يولّد صورة أنيميشن/مشهد من وصف نصي (+ صورة منتج اختيارية كمرجع).
  Future<GeminiImageResult> generateImage({
    required String prompt,
    List<GeminiInlinePart> referenceImages = const [],
  }) async {
    if (canUseCloudBackend) {
      final viaFunction = await _generateImageViaCloud(prompt, referenceImages);
      if (viaFunction.isSuccess) return viaFunction;
      if (!hasLocalKey) return viaFunction;
    }

    if (!hasLocalKey) {
      return GeminiImageResult(
        error: appTr(
          'سجّل الدخول لتوليد فيديو الأنيميشن، أو أضف مفتاح Gemini.',
          'Sign in to generate the animation video, or add a Gemini key.',
        ),
      );
    }

    final inlineOnly = referenceImages.where((a) => a.hasInlineData).toList();
    GeminiImageResult? last;
    for (final model in _imageModels) {
      last = await _generateImageViaHttp(
        model: model,
        prompt: prompt,
        references: inlineOnly,
      );
      if (last.isSuccess) return last;
    }
    return last ??
        GeminiImageResult(
          error: appTr(
            'تعذر توليد صورة الأنيميشن',
            'Could not generate animation frame',
          ),
        );
  }

  Future<GeminiImageResult> _generateImageViaCloud(
    String prompt,
    List<GeminiInlinePart> references,
  ) async {
    final payload = <String, dynamic>{
      'generateImage': true,
      'userMessage': prompt,
      'attachments': references
          .where((a) => a.hasInlineData || a.hasStoragePath)
          .map(
            (a) => {
              'mimeType': a.mimeType,
              if (a.hasInlineData) 'base64Data': a.base64Data,
              if (a.hasStoragePath) 'storagePath': a.storagePath,
              'fileName': a.fileName,
            },
          )
          .toList(),
    };
    try {
      late final Map<String, dynamic> data;
      if (_preferHttpCallable) {
        data = await CallableHttpClient.call(
          name: 'geminiAdvisor',
          data: payload,
          timeout: const Duration(seconds: 180),
          callableProtocol: true,
        );
      } else {
        try {
          final callable = FirebaseFunctions.instance.httpsCallable(
            'geminiAdvisor',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 180)),
          );
          final response = await callable.call<Map<String, dynamic>>(payload);
          data = Map<String, dynamic>.from(response.data);
        } on FirebaseFunctionsException catch (e) {
          if (_isPluginChannelError(e.message)) {
            data = await CallableHttpClient.call(
              name: 'geminiAdvisor',
              data: payload,
              timeout: const Duration(seconds: 180),
              callableProtocol: true,
            );
          } else {
            return GeminiImageResult(error: 'Cloud Function: ${e.message}');
          }
        }
      }
      return _imageResultFromMap(data);
    } catch (e) {
      return GeminiImageResult(error: 'Cloud Function: $e');
    }
  }

  Future<GeminiImageResult> _generateImageViaHttp({
    required String model,
    required String prompt,
    required List<GeminiInlinePart> references,
  }) async {
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey',
      );
      final parts = _buildUserParts(prompt, references);
      final response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {'role': 'user', 'parts': parts},
              ],
              'generationConfig': {
                'responseModalities': ['TEXT', 'IMAGE'],
                'temperature': 0.7,
              },
            }),
          )
          .timeout(const Duration(seconds: 90));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return GeminiImageResult(
          error: 'Gemini ($model): ${_parseApiError(response.body)}',
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _imageResultFromMap(data, modelHint: model);
    } catch (e) {
      return GeminiImageResult(error: 'Gemini image: $e');
    }
  }

  static GeminiImageResult _imageResultFromMap(
    Map<String, dynamic> data, {
    String? modelHint,
  }) {
    final err = data['error']?.toString();
    if (err != null && err.isNotEmpty && data['imageBase64'] == null) {
      return GeminiImageResult(error: err, modelUsed: modelHint);
    }
    final b64 = data['imageBase64']?.toString() ??
        _extractInlineImageBase64(data);
    if (b64 == null || b64.isEmpty) {
      return GeminiImageResult(
        error: appTr(
          'النموذج لم يُرجع صورة. جرّب مرة أخرى.',
          'The model did not return an image. Please retry.',
        ),
        modelUsed: data['model']?.toString() ?? modelHint,
      );
    }
    try {
      final bytes = base64Decode(_cleanBase64(b64));
      return GeminiImageResult(
        bytes: bytes,
        mimeType: data['mimeType']?.toString() ?? 'image/png',
        modelUsed: data['model']?.toString() ?? modelHint,
      );
    } catch (e) {
      return GeminiImageResult(error: 'Image decode: $e');
    }
  }

  static String? _extractInlineImageBase64(Map<String, dynamic> data) {
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return null;
    final content = (candidates.first as Map)['content'];
    if (content is! Map) return null;
    final parts = content['parts'];
    if (parts is! List) return null;
    for (final raw in parts) {
      if (raw is! Map) continue;
      final inline = raw['inlineData'] ?? raw['inline_data'];
      if (inline is! Map) continue;
      final b64 = inline['data']?.toString();
      if (b64 != null && b64.isNotEmpty) return b64;
    }
    return null;
  }
}
