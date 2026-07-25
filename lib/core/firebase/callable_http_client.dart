import 'dart:convert';
import 'dart:isolate';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'callable_http_worker.dart';

/// Calls Firebase backend from desktop when [cloud_functions] has no plugin.
class CallableHttpClient {
  CallableHttpClient._();

  static const _region = 'us-central1';
  static const _projectId = 'acadegate-new';
  static const _isolateDecodeThreshold = 32768;

  static String functionUrl(String name) {
    if (name == 'originalityCheck') {
      return 'https://$_region-$_projectId.cloudfunctions.net/originalityCheckHttp';
    }
    if (name == 'publishExtractReferencesHttp') {
      return 'https://$_region-$_projectId.cloudfunctions.net/publishExtractReferencesHttp';
    }
    if (name == 'journalGuidelinesExtractHttp') {
      return 'https://$_region-$_projectId.cloudfunctions.net/journalGuidelinesExtractHttp';
    }
    return 'https://$_region-$_projectId.cloudfunctions.net/$name';
  }

  static Future<Map<String, dynamic>> call({
    required String name,
    required Map<String, dynamic> data,
    Duration timeout = const Duration(minutes: 5),
    /// When true, body is `{"data": ...}` for Firebase [onCall] HTTP protocol.
    bool callableProtocol = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw CallableHttpException(
        'unauthenticated',
        'No Firebase user — sign in again',
      );
    }

    String? token;
    try {
      token = await user.getIdToken(false);
    } catch (e) {
      if (kDebugMode) debugPrint('getIdToken failed: $e');
      throw CallableHttpException(
        'unauthenticated',
        'Could not get auth token — sign out and sign in again',
      );
    }

    if (token == null || token.isEmpty) {
      throw CallableHttpException(
        'unauthenticated',
        'Empty auth token — sign out and sign in again',
      );
    }

    if (kDebugMode) {
      debugPrint(
        'CallableHttp ${functionUrl(name)} uid=${user.uid} tokenLen=${token.length}'
        '${callableProtocol ? ' protocol=callable' : ''}',
      );
    }

    final url = functionUrl(name);
    final bodyJson = jsonEncode(callableProtocol ? {'data': data} : data);
    final useWorkerIsolate = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        name == 'publishExtractReferencesHttp';

    if (useWorkerIsolate) {
      if (kDebugMode) {
        debugPrint('CallableHttp isolate worker for $name');
      }
      return _callInWorkerIsolate(
        url: url,
        token: token,
        bodyJson: bodyJson,
        timeout: timeout,
      );
    }

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

    if (response.body.length > _isolateDecodeThreshold) {
      return _parseResponse(
        response.statusCode,
        await compute(_decodeJsonString, response.body),
      );
    }
    return _parseResponse(response.statusCode, response.body);
  }

  static Future<Map<String, dynamic>> _callInWorkerIsolate({
    required String url,
    required String token,
    required String bodyJson,
    required Duration timeout,
  }) async {
    final envelope = await Isolate.run(
      () => isolatedHttpPost(
        url: url,
        token: token,
        bodyJson: bodyJson,
        timeout: timeout,
      ),
    );
    final statusCode = envelope['statusCode'] as int? ?? 500;
    final decoded = envelope['decoded'];
    return _parseResponse(statusCode, decoded);
  }

  static dynamic _decodeJsonString(String body) => jsonDecode(body);

  static Map<String, dynamic> _parseResponse(int statusCode, dynamic rawBody) {
    Map<String, dynamic>? decoded;
    try {
      if (rawBody is Map) {
        decoded = Map<String, dynamic>.from(rawBody);
      } else if (rawBody is String) {
        final parsed = jsonDecode(rawBody);
        if (parsed is Map) {
          decoded = Map<String, dynamic>.from(parsed);
        }
      }
    } catch (_) {
      if (statusCode == 401) {
        throw CallableHttpException(
          'unauthenticated',
          'Unauthorized (401) — sign out and sign in again',
        );
      }
      throw CallableHttpException(
        'internal',
        'Invalid response ($statusCode)',
      );
    }

    if (decoded == null) {
      throw CallableHttpException(
        'internal',
        'Invalid response ($statusCode)',
      );
    }

    final error = decoded['error'];
    if (error is Map) {
      final status = error['status']?.toString().toLowerCase() ?? 'unknown';
      final message = error['message']?.toString() ?? status;
      throw CallableHttpException(status, message);
    }

    if (statusCode >= 400) {
      throw CallableHttpException(
        'internal',
        'HTTP $statusCode',
      );
    }

    final result = decoded['result'];
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    if (decoded.containsKey('similarityPercent') || decoded.containsKey('scanId')) {
      return decoded;
    }

    throw CallableHttpException(
      'internal',
      'Empty response ($statusCode)',
    );
  }
}

class CallableHttpException implements Exception {
  final String code;
  final String message;

  CallableHttpException(this.code, this.message);

  @override
  String toString() => message;
}
