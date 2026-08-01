import 'dart:convert';
import 'dart:io' show File;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../core/firebase/callable_http_client.dart';
import '../../core/locale/app_translate.dart';
import 'originality_check_models.dart';

class PickedOriginalityDocument {
  final List<int> bytes;
  final String name;
  final String? extractedTextPreview;

  const PickedOriginalityDocument({
    required this.bytes,
    required this.name,
    this.extractedTextPreview,
  });

  int get sizeBytes => bytes.length;

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class OriginalityCheckService {
  OriginalityCheckService._();

  static final OriginalityCheckService instance = OriginalityCheckService._();

  static const _allowedExtensions = ['pdf', 'doc', 'docx', 'txt', 'odt', 'rtf'];
  static const maxBytes = 24 * 1024 * 1024;
  static const maxSizeMb = 24;

  Future<PickedOriginalityDocument?> pickDocument() async {
    final readFromPath = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: !readFromPath,
      allowMultiple: false,
      lockParentWindow: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = await _readPlatformFileBytes(file);
    if (bytes == null || bytes.isEmpty) {
      throw Exception(appTr(
        'تعذر قراءة الملف — جرّب TXT/DOCX أصغر أو أعد المحاولة',
        'Could not read file — try a smaller TXT/DOCX or retry',
      ));
    }

    if (bytes.length > maxBytes) {
      throw Exception(appTr(
        'حجم الملف يجب ألا يتجاوز $maxSizeMb ميجابايت',
        'File size must not exceed $maxSizeMb MB',
      ));
    }

    final preview = _maybeExtractTxtPreview(file.name, bytes);

    return PickedOriginalityDocument(
      bytes: bytes,
      name: file.name,
      extractedTextPreview: preview,
    );
  }

  Future<List<int>?> _readPlatformFileBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes!;
    }

    final path = file.path;
    if (!kIsWeb && path != null && path.isNotEmpty) {
      final ioFile = File(path);
      if (await ioFile.exists()) {
        return ioFile.readAsBytes();
      }
    }

    return null;
  }

  String? _maybeExtractTxtPreview(String name, List<int> bytes) {
    final lower = name.toLowerCase();
    if (!lower.endsWith('.txt') && !lower.endsWith('.rtf')) return null;
    try {
      final text = utf8.decode(bytes, allowMalformed: true).trim();
      if (text.isEmpty) return null;
      return text.length > 8000 ? text.substring(0, 8000) : text;
    } catch (_) {
      return null;
    }
  }

  Future<OriginalityCheckReport> check({
    required OriginalityProvider provider,
    String? text,
    List<int>? fileBytes,
    String? fileName,
    String language = 'en',
  }) async {
    final trimmed = text?.trim() ?? '';
    final hasText = trimmed.isNotEmpty;
    final hasFile = fileBytes != null &&
        fileBytes.isNotEmpty &&
        fileName != null &&
        fileName.trim().isNotEmpty;

    if (!hasText && !hasFile) {
      throw Exception(appTr(
        'أدخل نصاً أو ارفع ملفاً',
        'Enter text or upload a file',
      ));
    }

    final payload = <String, dynamic>{
      'provider': _providerKey(provider),
      'language': language,
    };

    if (hasText) payload['text'] = trimmed;
    if (hasFile) {
      payload['base64'] = base64Encode(fileBytes);
      payload['filename'] = fileName.trim();
    }

    try {
      final data = await _invokeOriginalityCheck(payload);
      return OriginalityCheckReport.fromJson(data);
    } on CallableHttpException catch (e) {
      throw Exception(_mapCallableError(e.code, e.message));
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || e.code == 'unavailable') {
        throw Exception(appTr(
          'Cloud Function غير منشورة — انشر originalityCheck في Firebase',
          'Cloud Function not deployed — deploy originalityCheck to Firebase',
        ));
      }
      if (e.code == 'unauthenticated') {
        throw Exception(appTr(
          'يجب تسجيل الدخول لاستخدام فاحص التشابه',
          'Sign in to use the similarity checker',
        ));
      }
      if (e.code == 'failed-precondition') {
        throw Exception(e.message ??
            appTr(
              'مفاتيح Copyleaks أو PlagiarismCheck غير مضبوطة في Firebase',
              'Copyleaks or PlagiarismCheck keys not configured in Firebase',
            ));
      }
      throw Exception(e.message ?? e.code);
    } catch (e) {
      if (kDebugMode) debugPrint('originalityCheck error: $e');
      final msg = e.toString().replaceFirst('Exception: ', '');
      throw Exception(_mapProviderError(msg));
    }
  }

  bool get _useHttpCallable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Future<Map<String, dynamic>> _invokeOriginalityCheck(
    Map<String, dynamic> payload,
  ) async {
    if (_useHttpCallable) {
      return CallableHttpClient.call(
        name: 'originalityCheck',
        data: payload,
        timeout: const Duration(minutes: 5),
      );
    }

    final callable = FirebaseFunctions.instance.httpsCallable(
      'originalityCheck',
      options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
    );
    final response = await callable.call<Map<String, dynamic>>(payload);
    return Map<String, dynamic>.from(response.data);
  }

  String _mapCallableError(String code, String message) {
    switch (code) {
      case 'unauthenticated':
        return appTr(
          'يجب تسجيل الدخول لاستخدام فاحص التشابه',
          'Sign in to use the similarity checker',
        );
      case 'not-found':
      case 'unavailable':
        return appTr(
          'Cloud Function غير منشورة — انشر originalityCheck في Firebase',
          'Cloud Function not deployed — deploy originalityCheck to Firebase',
        );
      case 'failed-precondition':
        return _mapProviderError(
          message.isNotEmpty
              ? message
              : appTr(
                  'مفاتيح Copyleaks أو PlagiarismCheck غير مضبوطة في Firebase',
                  'Copyleaks or PlagiarismCheck keys not configured in Firebase',
                ),
        );
      case 'deadline-exceeded':
        return appTr(
          'انتهت مهلة الفحص — جرّب نصاً أقصر',
          'Scan timed out — try a shorter document',
        );
      default:
        return _mapProviderError(message.isNotEmpty ? message : code);
    }
  }

  String _mapProviderError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('not enough credits') ||
        lower.contains("don't have enough credits")) {
      return appTr(
        'رصيد Copyleaks غير كافٍ — أضف رصيداً في copyleaks.com',
        'Insufficient Copyleaks credits — add credits at copyleaks.com',
      );
    }
    if (lower.contains('not enough pages') ||
        lower.contains('balance')) {
      return appTr(
        'رصيد PlagiarismCheck غير كافٍ — اشحن حسابك في plagiarismcheck.org',
        'Insufficient PlagiarismCheck balance — top up your account at plagiarismcheck.org',
      );
    }
    if (lower.contains('file missed') || lower.contains('file not')) {
      return appTr(
        'PlagiarismCheck لا يقبل الملف مباشرة — جرّب Copyleaks للعربية أو أعد النشر',
        'PlagiarismCheck could not read the file — try Copyleaks for Arabic or redeploy functions',
      );
    }
    if (lower.contains('at least 80 characters')) {
      return appTr(
        'PlagiarismCheck يحتاج 80+ حرفاً مستخرجاً من الملف',
        'PlagiarismCheck needs 80+ extractable characters from the file',
      );
    }
    if (lower.contains('extract text')) {
      return appTr(
        'تعذر استخراج النص من الملف — جرّب DOCX أو PDF أو TXT',
        'Could not extract text from file — try DOCX, PDF, or TXT',
      );
    }
    return message;
  }

  String _providerKey(OriginalityProvider provider) {
    switch (provider) {
      case OriginalityProvider.auto:
        return 'auto';
      case OriginalityProvider.copyleaks:
        return 'copyleaks';
      case OriginalityProvider.plagiarismCheck:
        return 'plagiarismcheck';
    }
  }
}
