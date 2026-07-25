import 'dart:convert';
import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../core/locale/app_translate.dart';
import '../ai_advisor/advisor_attachment.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import 'viva_models.dart';

class VivaPdfService {
  VivaPdfService._();

  static final VivaPdfService instance = VivaPdfService._();

  /// Gemini supports PDFs up to ~50MB; we allow 40MB and route large files
  /// via Storage so Cloud Function payloads stay small.
  static const maxBytes = 40 * 1024 * 1024;
  static const maxSizeMb = 40;
  static const inlineCloudMaxBytes = 8 * 1024 * 1024;

  Future<({List<int> bytes, String name})?> pickPdf() async {
    final readFromPath = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: !readFromPath,
      lockParentWindow: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = await _readPlatformFileBytes(file);
    if (bytes == null || bytes.isEmpty) {
      throw Exception(appTr(
        'تعذر قراءة ملف PDF — أعد المحاولة',
        'Could not read PDF file — please retry',
      ));
    }
    if (bytes.length > maxBytes) {
      throw Exception(appTr(
        'حجم ملف PDF يجب ألا يتجاوز $maxSizeMb ميجابايت',
        'PDF file size must not exceed $maxSizeMb MB',
      ));
    }
    return (bytes: bytes, name: file.name);
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

  Future<String> _uploadForCloudExtraction({
    required List<int> bytes,
    required String fileName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr(
        'سجّل الدخول لرفع ملفات PDF الكبيرة',
        'Sign in to upload large PDF files',
      ));
    }

    final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path =
        'uploads/${user.uid}/viva/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putData(
      Uint8List.fromList(bytes),
      SettableMetadata(contentType: 'application/pdf'),
    );
    return path;
  }

  Future<VivaPdfExtractionResult> extractFromPdf({
    required List<int> bytes,
    required String fileName,
  }) async {
    if (!GeminiAdvisorClient.isAvailable) {
      throw Exception(appTr(
        GeminiAdvisorClient.needsSignInForCloudAi
            ? 'استخراج بيانات الرسالة من PDF يتطلب تسجيل الدخول'
            : 'استخراج بيانات الرسالة من PDF غير متاح حالياً',
        GeminiAdvisorClient.needsSignInForCloudAi
            ? 'Extracting thesis data from PDF requires signing in'
            : 'Extracting thesis data from PDF is unavailable right now',
      ));
    }

    final useStorage = GeminiAdvisorClient.canUseCloudBackend &&
        (!GeminiAdvisorClient.hasLocalKey || bytes.length > inlineCloudMaxBytes);

    late final GeminiInlinePart attachment;
    if (useStorage && bytes.length > inlineCloudMaxBytes) {
      final storagePath = await _uploadForCloudExtraction(
        bytes: bytes,
        fileName: fileName,
      );
      attachment = GeminiInlinePart(
        mimeType: 'application/pdf',
        base64Data: '',
        fileName: fileName,
        storagePath: storagePath,
      );
    } else {
      attachment = GeminiInlinePart(
        mimeType: 'application/pdf',
        base64Data: base64Encode(bytes),
        fileName: fileName,
      );
    }

    final system = appTr(
      'أنت خبير في تحليل الرسائل العلمية واستخراج ما يلزم لمناقشة علمية واقعية. '
          'استخرج من ملف PDF المرفق فقط. أعد JSON صالحاً فقط بدون markdown بالمفاتيح: '
          'title, summary, methodology, specialization, '
          'researchQuestions (نص أو قائمة بالأسئلة/الأهداف البحثية كما في الرسالة), '
          'sampleDescription (العينة/المشاركون/البيانات إن وُجدت), '
          'mainFindings (أهم النتائج أو الاستنتاجات), '
          'limitations (الحدود إن وُجدت), '
          'excerpt (مقتطف طويل حتى 4500 حرف من المقدمة + المنهجية + أبرز النتائج — '
          'انسخ صياغة قريبة من النص الأصلي قدر الإمكان). '
          'اكتب الحقول بلغة المستند (عربي أو إنجليزي). لا تختلق محتوى غير موجود في PDF.',
      'You are an expert at extracting thesis content for a realistic viva. '
          'Extract from the attached PDF only. Return valid JSON only without markdown with keys: '
          'title, summary, methodology, specialization, '
          'researchQuestions (text or list of research questions/aims as in the thesis), '
          'sampleDescription (sample/participants/data if present), '
          'mainFindings (key findings or conclusions), '
          'limitations (if present), '
          'excerpt (long excerpt up to 4500 chars from intro + methods + key results — '
          'stay close to the original wording). '
          'Write fields in the document language. Do not invent content not in the PDF.',
    );

    final user = appTr(
      'حلّل ملف الرسالة المرفق واستخرج الحقول المطلوبة بدقة من النص الفعلي.',
      'Analyze the attached thesis PDF and extract the required fields accurately from the actual text.',
    );

    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: system,
      userMessage: user,
      attachments: [attachment],
      maxOutputTokens: 8192,
    );

    if (!result.isSuccess) {
      throw Exception(
        result.error ??
            appTr('تعذر تحليل PDF', 'Could not analyze PDF'),
      );
    }

    return _parseExtraction(result.text!, fileName);
  }

  VivaPdfExtractionResult _parseExtraction(String raw, String fileName) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      final fallback = text.length > 4500 ? text.substring(0, 4500) : text;
      return VivaPdfExtractionResult(
        fileName: fileName,
        title: fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), ''),
        summary: text.length > 2000 ? text.substring(0, 2000) : text,
        excerpt: fallback,
        defenseContext: fallback,
      );
    }

    String field(String key) {
      final raw = data[key];
      if (raw == null) return '';
      if (raw is List) {
        return raw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .join('\n• ');
      }
      return raw.toString().trim();
    }

    final title = field('title');
    final summary = field('summary');
    var excerpt = field('excerpt');
    if (excerpt.length > 4500) {
      excerpt = excerpt.substring(0, 4500);
    }

    if (title.isEmpty && summary.isEmpty) {
      throw Exception(appTr(
        'لم يُستخرج محتوى كافٍ من PDF — جرّب ملفاً أوضح أو ألصق الملخص يدوياً',
        'Could not extract enough content from PDF — try a clearer file or paste the summary manually',
      ));
    }

    final defenseParts = <String>[];
    void addPart(String labelAr, String labelEn, String value) {
      if (value.isEmpty) return;
      defenseParts.add('${appTr(labelAr, labelEn)}:\n$value');
    }

    addPart('الأسئلة/الأهداف البحثية', 'Research questions/aims',
        field('researchQuestions'));
    addPart('العينة/البيانات', 'Sample/data', field('sampleDescription'));
    addPart('النتائج الرئيسية', 'Main findings', field('mainFindings'));
    addPart('حدود الدراسة', 'Limitations', field('limitations'));
    final defenseContext =
        defenseParts.isEmpty ? null : defenseParts.join('\n\n');

    return VivaPdfExtractionResult(
      fileName: fileName,
      title: title.isNotEmpty
          ? title
          : fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), ''),
      summary: summary.isNotEmpty
          ? summary
          : (excerpt.isNotEmpty ? excerpt : title),
      methodology: field('methodology').isEmpty ? null : field('methodology'),
      specialization:
          field('specialization').isEmpty ? null : field('specialization'),
      excerpt: excerpt.isEmpty ? null : excerpt,
      defenseContext: defenseContext,
    );
  }
}
