import 'dart:convert';

import 'package:http/http.dart' as http;

/// HTTP POST worker with no Firebase imports (safe for [Isolate.run] on Windows).
Future<Map<String, dynamic>> isolatedHttpPost({
  required String url,
  required String token,
  required String bodyJson,
  required Duration timeout,
}) async {
  final response = await http
      .post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
        body: bodyJson,
      )
      .timeout(timeout);

  Map<String, dynamic> decoded;
  try {
    final parsed = jsonDecode(response.body);
    if (parsed is! Map) {
      throw FormatException('Expected JSON object');
    }
    decoded = Map<String, dynamic>.from(parsed);
  } catch (_) {
    if (response.statusCode == 401) {
      return {
        'statusCode': 401,
        'decoded': {
          'error': {
            'status': 'UNAUTHENTICATED',
            'message': 'Unauthorized (401) — sign out and sign in again',
          },
        },
      };
    }
    return {
      'statusCode': response.statusCode,
      'decoded': {
        'error': {
          'status': 'INTERNAL',
          'message': 'Invalid response (${response.statusCode})',
        },
      },
    };
  }

  return {
    'statusCode': response.statusCode,
    'decoded': decoded,
  };
}
