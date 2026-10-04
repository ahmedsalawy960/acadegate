import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/locale/app_translate.dart';
import '../../core/locale/locale_service.dart';
import '../ai_advisor/advisor_attachment.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import '../viva_simulator/viva_pdf_service.dart';
import 'methodology_integrity_models.dart';

class MethodologyPdfService {
  MethodologyPdfService._();

  static final MethodologyPdfService instance = MethodologyPdfService._();

  /// Max chars loaded into the editor from PDF extraction.
  /// If the chapter is longer, [truncated] is set and the full PDF is used at check time.
  static const maxMethodologyChars = 60000;
  static const _extractionOutputTokens = 8192;

  int get _maxMethodologyChars => maxMethodologyChars;

  Future<({List<int> bytes, String name})?> pickPdf() =>
      VivaPdfService.instance.pickPdf();

  /// Prefer Storage for large PDFs (same limit as Viva) to avoid callable payload failures.
  Future<GeminiInlinePart> pdfAttachmentForCloud({
    required List<int> bytes,
    required String fileName,
  }) async {
    final useStorage = GeminiAdvisorClient.canUseCloudBackend &&
        bytes.length > VivaPdfService.inlineCloudMaxBytes;
    if (useStorage) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception(appTr(
          'سجّل الدخول لرفع ملفات الرسالة الكبيرة',
          'Sign in to upload large thesis files',
        ));
      }
      final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
      final path =
          'uploads/${user.uid}/methodology/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final ref = FirebaseStorage.instance.ref().child(path);
      await ref.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(contentType: 'application/pdf'),
      );
      return GeminiInlinePart(
        mimeType: 'application/pdf',
        base64Data: '',
        fileName: fileName,
        storagePath: path,
      );
    }
    return GeminiInlinePart(
      mimeType: 'application/pdf',
      base64Data: base64Encode(bytes),
      fileName: fileName,
    );
  }

  Future<MethodologyPdfExtractionResult> extractMethodologyFromPdf({
    required List<int> bytes,
    required String fileName,
  }) async {
    if (!GeminiAdvisorClient.isAvailable) {
      throw Exception(appTr(
        'استخراج المنهجية من PDF يتطلب تسجيل الدخول',
        'Extracting methodology from a PDF requires sign-in',
      ));
    }

    final attachment = await pdfAttachmentForCloud(
      bytes: bytes,
      fileName: fileName,
    );

    final system = LocaleService.instance.isEnglish
        ? '''
You extract the FULL research methodology from an academic thesis PDF for integrity checking.
Rules:
- Read the entire PDF. Locate the methodology chapter/section (Methodology, Materials and Methods, Research Design, etc.).
- Copy the methodology content VERBATIM into methodologyText — do NOT summarize.
- Include all subsections: design, population/sample, instruments, procedures, analysis, ethics, validity.
- If methodology spans multiple sections, concatenate them in order into methodologyText.
- methodologyText may be up to $_maxMethodologyChars characters; if longer, include the most complete contiguous methodology text and set truncated=true (the full PDF will still be analyzed later).
- Also extract researchQuestion, populationSample, dataCollection, analysisApproach as separate concise fields when present.
- methodologyType: one of quantitative, qualitative, mixed, or unknown.

Return ONLY valid JSON (no markdown) with keys:
title, researchQuestion, methodologyType, methodologyText, populationSample, dataCollection, analysisApproach, truncated (boolean).
'''
        : '''
أنت تستخرج فصل/قسم المنهجية الكامل من رسالة علمية PDF لفحص السلامة المنهجية.
قواعد:
- اقرأ الملف كاملاً. حدّد فصل المنهجية (المنهجية، المنهج و procedures، Research Design، Materials and Methods…).
- انسخ نص المنهجية حرفياً في methodologyText — لا تلخّص.
- ضمّ كل الأقسام الفرعية: التصميم، المجتمع/العينة، الأدوات، الإجراءات، التحليل، الأخلاقيات، الصدق/الثبات.
- إن وُجدت أقسام متفرقة للمنهجية، ادمجها بالترتيب في methodologyText.
- methodologyText حتى $_maxMethodologyChars حرفاً؛ إن كان أطول فضمّ أكبر جزء متصل من المنهجية وضع truncated=true (سيُفحص PDF كاملاً لاحقاً).
- استخرج أيضاً researchQuestion وpopulationSample وdataCollection وanalysisApproach في حقول منفصلة عند وجودها.
- methodologyType: quantitative أو qualitative أو mixed أو unknown.

أعد JSON صالحاً فقط (بدون markdown) بالمفاتيح:
title, researchQuestion, methodologyType, methodologyText, populationSample, dataCollection, analysisApproach, truncated (boolean).
''';

    final user = appTr(
      'استخرج فصل المنهجية كاملاً من ملف PDF المرفق للفحص اللاحق.',
      'Extract the full methodology chapter from the attached PDF for later checking.',
    );

    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: system,
      userMessage: user,
      attachments: [attachment],
      maxOutputTokens: _extractionOutputTokens,
    );

    if (!result.isSuccess) {
      throw Exception(
        result.error ??
            appTr('تعذر استخراج المنهجية من PDF', 'Could not extract methodology from PDF'),
      );
    }

    return _parseExtraction(result.text!, fileName);
  }

  MethodologyPdfExtractionResult _parseExtraction(String raw, String fileName) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      final fallback = text.length > _maxMethodologyChars
          ? text.substring(0, _maxMethodologyChars)
          : text;
      if (fallback.trim().length < 80) {
        throw Exception(appTr(
          'لم يُستخرج نص منهجية كافٍ — تأكد أن PDF يحتوي فصل المنهجية',
          'Could not extract enough methodology text — ensure the PDF includes a methodology chapter',
        ));
      }
      return MethodologyPdfExtractionResult(
        fileName: fileName,
        title: fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), ''),
        researchQuestion: '',
        methodologyText: fallback,
        truncated: text.length > _maxMethodologyChars,
      );
    }

    var methodology = (data['methodologyText'] ?? '').toString().trim();
    final truncatedFlag = data['truncated'] == true;
    var truncated = truncatedFlag;
    if (methodology.length > _maxMethodologyChars) {
      methodology = methodology.substring(0, _maxMethodologyChars);
      truncated = true;
    }
    if (methodology.length < 80) {
      throw Exception(appTr(
        'لم يُستخرج نص منهجية كافٍ — تأكد أن PDF يحتوي فصل المنهجية',
        'Could not extract enough methodology text — ensure the PDF includes a methodology chapter',
      ));
    }

    return MethodologyPdfExtractionResult(
      fileName: fileName,
      title: (data['title'] ?? '').toString().trim(),
      researchQuestion: (data['researchQuestion'] ?? '').toString().trim(),
      methodologyText: methodology,
      methodologyType: (data['methodologyType'] ?? '').toString().trim(),
      populationSample: (data['populationSample'] ?? '').toString().trim(),
      dataCollection: (data['dataCollection'] ?? '').toString().trim(),
      analysisApproach: (data['analysisApproach'] ?? '').toString().trim(),
      truncated: truncated,
    );
  }
}
