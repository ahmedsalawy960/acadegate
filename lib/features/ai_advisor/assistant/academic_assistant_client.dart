import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/firebase/callable_http_client.dart';
import '../../../core/locale/app_translate.dart';
import '../advisor_attachment.dart';
import '../advisor_branding.dart';
import '../grounded_reference_service.dart';
import 'assistant_prompt.dart';
import 'assistant_reply_language.dart';
import 'assistant_tools.dart';

class AssistantRunResult {
  final String text;
  final String? error;
  final bool deep;
  final List<String> toolLabels;
  final AssistantToolbox toolbox;

  /// True when the backend could not be reached at all (caller may fall back).
  final bool backendUnavailable;

  const AssistantRunResult({
    required this.text,
    required this.toolbox,
    this.error,
    this.deep = false,
    this.toolLabels = const [],
    this.backendUnavailable = false,
  });

  bool get isSuccess => error == null && text.trim().isNotEmpty;
}

class _RoundResult {
  final List<Map<String, dynamic>> parts;
  final String text;
  final List<Map<String, dynamic>> calls;
  final bool deep;

  const _RoundResult({
    required this.parts,
    required this.text,
    required this.calls,
    required this.deep,
  });
}

class AssistantBackendException implements Exception {
  final String code;
  final String message;
  const AssistantBackendException(this.code, this.message);

  bool get isUnavailable => code == 'not-found' || code == 'unavailable' || code == 'network';

  @override
  String toString() => message;
}

/// Tool-using, streaming client for the `academicAssistant` Cloud Function.
class AcademicAssistantClient {
  AcademicAssistantClient._();

  static final AcademicAssistantClient instance = AcademicAssistantClient._();

  static const _functionName = 'academicAssistant';
  static const _maxRounds = 5;
  static const _maxHistoryMessages = 20;

  static bool get isAvailable => FirebaseAuth.instance.currentUser != null;

  String _newTurnId() {
    final r = Random.secure();
    return '${DateTime.now().millisecondsSinceEpoch}_${List.generate(10, (_) => r.nextInt(36).toRadixString(36)).join()}';
  }

  /// [onText] receives the full visible text so far; [onStatus] a short
  /// "searching…" label while tools run (null when writing).
  Future<AssistantRunResult> run({
    required String message,
    required List<Map<String, String>> history,
    List<GeminiInlinePart> attachments = const [],
    bool deep = false,
    void Function(String textSoFar)? onText,
    void Function(String? status)? onStatus,
  }) async {
    final toolbox = AssistantToolbox();
    final languageSample = message.trim().isNotEmpty
        ? message
        : history.reversed
            .firstWhere((h) => h['role'] == 'user', orElse: () => const {})['text'] ??
            appTr('عربي', 'English');
    final language = AssistantReplyLanguagePrefs.resolve(
      await AssistantReplyLanguagePrefs.load(),
      languageSample,
    );
    final systemPrompt = await AssistantPrompt.build(language: language);
    final turnId = _newTurnId();

    final contents = <Map<String, dynamic>>[
      for (final h in history.length > _maxHistoryMessages
          ? history.sublist(history.length - _maxHistoryMessages)
          : history)
        if ((h['text'] ?? '').trim().isNotEmpty)
          {
            'role': h['role'] == 'assistant' ? 'model' : 'user',
            'parts': [
              {'text': h['text']},
            ],
          },
      {
        'role': 'user',
        'parts': [
          {
            'text': message.trim().isNotEmpty
                ? message.trim()
                : appTr('حلّل الملفات المرفقة.', 'Analyze the attached files.'),
          },
        ],
      },
    ];

    final attachmentPayload = attachments
        .map(
          (a) => {
            'mimeType': a.mimeType,
            if (a.hasInlineData) 'base64Data': a.base64Data,
            if (a.hasStoragePath) 'storagePath': a.storagePath,
          },
        )
        .toList();

    final visible = StringBuffer();
    var usedDeep = false;

    for (var round = 0; round < _maxRounds; round++) {
      final lastRound = round == _maxRounds - 1;
      final prefix = visible.toString();
      onStatus?.call(null);

      _RoundResult res;
      try {
        res = await _callRound(
          payload: {
            'turnId': turnId,
            'systemPrompt': systemPrompt,
            'contents': contents,
            'functionDeclarations': AssistantToolbox.declarations,
            'toolMode': lastRound ? 'NONE' : 'AUTO',
            'mode': deep ? 'deep' : 'fast',
            if (attachmentPayload.isNotEmpty) 'attachments': attachmentPayload,
          },
          onDelta: (delta) {
            visible.write(delta);
            onText?.call(visible.toString());
          },
        );
      } on AssistantBackendException catch (e) {
        return AssistantRunResult(
          text: visible.toString(),
          error: e.message,
          deep: usedDeep,
          toolLabels: toolbox.usedLabels,
          toolbox: toolbox,
          backendUnavailable: round == 0 && visible.isEmpty && e.isUnavailable,
        );
      } catch (e) {
        debugPrint('academicAssistant failed: $e');
        return AssistantRunResult(
          text: visible.toString(),
          error: AdvisorBranding.friendlyFailure('$e'),
          deep: usedDeep,
          toolLabels: toolbox.usedLabels,
          toolbox: toolbox,
        );
      }

      usedDeep = usedDeep || res.deep;
      // Non-streaming transports (web) deliver the text only at the end.
      if (visible.length == prefix.length && res.text.isNotEmpty) {
        visible.write(res.text);
        onText?.call(visible.toString());
      }

      contents.add({'role': 'model', 'parts': res.parts});
      if (res.calls.isEmpty) break;

      if (visible.isNotEmpty && !visible.toString().endsWith('\n')) {
        visible.write('\n\n');
      }

      final responses = <Map<String, dynamic>>[];
      for (final call in res.calls) {
        final name = call['name']?.toString() ?? '';
        onStatus?.call(AssistantToolbox.statusLabel(name));
        final args = call['args'] is Map
            ? Map<String, dynamic>.from(call['args'] as Map)
            : <String, dynamic>{};
        final output = await toolbox.execute(name, args);
        responses.add({
          'functionResponse': {
            if (call['id'] != null) 'id': call['id'],
            'name': name,
            'response': output,
          },
        });
      }
      contents.add({'role': 'user', 'parts': responses});
    }
    onStatus?.call(null);

    var text = visible.toString().trim();
    if (text.isNotEmpty) {
      text = await GroundedReferenceService.instance.enforceVerifiedDois(
        text,
        known: toolbox.foundReferences,
      );
    }
    return AssistantRunResult(
      text: text,
      deep: usedDeep,
      toolLabels: toolbox.usedLabels,
      toolbox: toolbox,
      error: text.isEmpty
          ? appTr('لم يصل رد من المساعد — أعد المحاولة.', 'No reply from the assistant — try again.')
          : null,
    );
  }

  Future<_RoundResult> _callRound({
    required Map<String, dynamic> payload,
    required void Function(String delta) onDelta,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw AssistantBackendException(
        'unauthenticated',
        appTr('سجّل الدخول لاستخدام المساعد الأكاديمي.', 'Sign in to use the Academic Assistant.'),
      );
    }
    final token = await user.getIdToken();

    // Windows drops a quiet event-stream and the error is then hidden.
    final stream = kIsWeb || defaultTargetPlatform != TargetPlatform.windows;
    final request = http.Request('POST', Uri.parse(CallableHttpClient.functionUrl(_functionName)))
      ..headers.addAll({
        'Content-Type': 'application/json; charset=utf-8',
        if (stream) 'Accept': 'text/event-stream',
        'Authorization': 'Bearer $token',
      })
      ..body = jsonEncode({'data': payload});

    final client = http.Client();
    try {
      final http.StreamedResponse response;
      try {
        response = await client.send(request).timeout(
          Duration(seconds: stream ? 60 : 150),
        );
      } on TimeoutException {
        throw AssistantBackendException(
          'network',
          appTr('انتهت مهلة الاتصال بالمساعد.', 'Connection to the assistant timed out.'),
        );
      } catch (e) {
        throw AssistantBackendException('network', appTr('تعذر الاتصال: $e', 'Could not connect: $e'));
      }

      if (response.statusCode == 404) {
        throw AssistantBackendException(
          'not-found',
          appTr('خدمة المساعد الجديدة غير منشورة بعد.', 'The new assistant service is not deployed yet.'),
        );
      }

      final contentType = response.headers['content-type'] ?? '';
      Map<String, dynamic>? result;

      if (contentType.contains('text/event-stream')) {
        await for (final line in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .timeout(const Duration(seconds: 240))) {
          if (!line.startsWith('data:')) continue;
          final raw = line.substring(5).trim();
          if (raw.isEmpty) continue;
          final Map<String, dynamic> event;
          try {
            event = Map<String, dynamic>.from(jsonDecode(raw) as Map);
          } catch (_) {
            continue;
          }
          if (event['message'] is Map) {
            final t = (event['message'] as Map)['t'];
            if (t is String && t.isNotEmpty) onDelta(t);
          } else if (event['result'] is Map) {
            result = Map<String, dynamic>.from(event['result'] as Map);
          } else if (event['error'] is Map) {
            _throwCallableError(Map<String, dynamic>.from(event['error'] as Map));
          }
        }
      } else {
        final body = await response.stream.bytesToString();
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['error'] is Map) {
          _throwCallableError(Map<String, dynamic>.from(decoded['error'] as Map));
        }
        if (decoded is Map && decoded['result'] is Map) {
          result = Map<String, dynamic>.from(decoded['result'] as Map);
        }
      }

      if (result == null) {
        throw AssistantBackendException(
          'internal',
          appTr('رد غير مكتمل من الخادم.', 'Incomplete response from the server.'),
        );
      }
      if (result['error'] != null) {
        throw AssistantBackendException('internal', result['error'].toString());
      }

      final parts = (result['parts'] as List? ?? const [])
          .whereType<Map>()
          .map((p) => Map<String, dynamic>.from(p))
          .toList();
      final calls = (result['functionCalls'] as List? ?? const [])
          .whereType<Map>()
          .map((c) => Map<String, dynamic>.from(c))
          .where((c) => (c['name']?.toString() ?? '').isNotEmpty)
          .toList();
      return _RoundResult(
        parts: parts,
        text: result['text']?.toString() ?? '',
        calls: calls,
        deep: result['deep'] == true,
      );
    } on TimeoutException {
      throw AssistantBackendException(
        'network',
        appTr('توقف وصول الرد — أعد المحاولة.', 'The reply stalled — try again.'),
      );
    } finally {
      client.close();
    }
  }

  Never _throwCallableError(Map<String, dynamic> error) {
    final status = (error['status'] ?? 'internal').toString().toLowerCase().replaceAll('_', '-');
    final message = (error['message'] ?? status).toString();
    throw AssistantBackendException(status == 'not-found' ? 'not-found' : status, message);
  }
}
