import 'dart:async';
import 'dart:convert';

/// Parses Firebase callable JSON and SSE without depending on HTTP or Flutter.
/// Content-Type is only a hint: proxies may strip or rewrite it.
class AssistantWireException implements Exception {
  final String code;
  final String message;
  const AssistantWireException(this.code, this.message);
  @override
  String toString() => message;
}

Future<Map<String, dynamic>> readAssistantResponse(
  Stream<List<int>> bytes, {
  required void Function(String) onDelta,
  String contentType = '',
  int statusCode = 200,
  Duration idleTimeout = const Duration(seconds: 240),
}) async {
  const maxBody = 8 * 1024 * 1024;
  const maxEvent = 1024 * 1024;
  const incomplete = AssistantWireException(
    'invalid-response',
    'Incomplete assistant response.',
  );
  var size = 0;
  var frameSize = 0;
  var firstLine = true;
  bool? sse;
  final jsonBody = StringBuffer();
  final data = <String>[];

  Map<String, dynamic>? envelope(String raw) {
    final dynamic value;
    try {
      value = jsonDecode(raw);
    } on FormatException {
      throw const AssistantWireException(
        'invalid-response',
        'Invalid assistant response.',
      );
    }
    if (value is! Map<String, dynamic>) throw incomplete;
    if (value['error'] is Map) {
      final error = value['error'] as Map;
      final code = (error['status'] ?? 'internal')
          .toString()
          .toLowerCase()
          .replaceAll('_', '-');
      throw AssistantWireException(code, (error['message'] ?? code).toString());
    }
    if (value.containsKey('result')) {
      if (value['result'] is! Map<String, dynamic>) throw incomplete;
      if (statusCode < 200 || statusCode >= 300) {
        throw AssistantWireException(
          statusCode >= 500 ? 'unavailable' : 'internal',
          'HTTP $statusCode',
        );
      }
      return value['result'] as Map<String, dynamic>;
    }
    if (value['message'] is Map) {
      final delta = (value['message'] as Map)['t'];
      if (delta is String && delta.isNotEmpty) onDelta(delta);
    }
    return null;
  }

  try {
    final limited = bytes.map((chunk) {
      size += chunk.length;
      if (size > maxBody)
        throw const AssistantWireException(
          'invalid-response',
          'Assistant response is too large.',
        );
      return chunk;
    });
    await for (var line
        in limited
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .timeout(idleTimeout)) {
      if (firstLine) {
        firstLine = false;
        if (line.startsWith('\uFEFF')) line = line.substring(1);
      }
      if (sse == null) {
        if (line.trim().isEmpty) continue;
        final probe = line.trimLeft();
        if (probe.startsWith('{')) {
          sse = false;
        } else if (line.startsWith(':') ||
            RegExp(r'^(data|event|id|retry)(:|$)').hasMatch(line) ||
            contentType.toLowerCase().contains('text/event-stream')) {
          sse = true;
        } else {
          throw const AssistantWireException(
            'invalid-response',
            'Unrecognized assistant response.',
          );
        }
      }
      if (!sse) {
        jsonBody.writeln(line);
        continue;
      }
      if (line.isEmpty) {
        if (data.isNotEmpty) {
          final result = envelope(data.join('\n'));
          data.clear();
          frameSize = 0;
          // Stop at the terminal result. Do not wait for a proxy to close.
          if (result != null) return result;
        }
        frameSize = 0;
        continue;
      }
      frameSize += line.length;
      if (frameSize > maxEvent)
        throw const AssistantWireException(
          'invalid-response',
          'Assistant event is too large.',
        );
      if (line.startsWith(':')) continue;
      final colon = line.indexOf(':');
      final field = colon < 0 ? line : line.substring(0, colon);
      var value = colon < 0 ? '' : line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      if (field == 'data') data.add(value);
    }
  } on FormatException {
    throw const AssistantWireException(
      'invalid-response',
      'Invalid UTF-8 assistant response.',
    );
  }
  if (sse == false) {
    final result = envelope(jsonBody.toString());
    if (result != null) return result;
  }
  // SSE requires a blank-line event boundary and a terminal result envelope.
  // Deltas, [DONE], EOF or a cut-off result are not a successful round.
  throw incomplete;
}
