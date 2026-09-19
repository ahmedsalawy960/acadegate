import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../core/locale/app_translate.dart';
import '../academic_integrity/bibliography_harvest.dart';
import '../acadegate_publish/manuscript_document_parser.dart';
import '../ai_advisor/advisor_attachment.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import 'local_path_bytes.dart';
import 'viva_models.dart';

class VivaPdfService {
  VivaPdfService._();

  static final VivaPdfService instance = VivaPdfService._();

  /// Gemini supports PDFs up to ~50MB; we allow 40MB and route large files
  /// via Storage so Cloud Function payloads stay small.
  static const maxBytes = 40 * 1024 * 1024;
  static const maxSizeMb = 40;
  static const inlineCloudMaxBytes = 8 * 1024 * 1024;

  Future<({List<int> bytes, String name})?> pickThesisFile() {
    return _pickFiles(const ['pdf', 'docx']);
  }

  /// PDF-only picker used by methodology integrity and other PDF tools.
  Future<({List<int> bytes, String name})?> pickPdf() {
    return _pickFiles(const ['pdf']);
  }

  Future<({List<int> bytes, String name})?> _pickFiles(
    List<String> allowedExtensions,
  ) async {
    final readFromPath = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: !readFromPath,
      lockParentWindow: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = await _readPlatformFileBytes(file);
    if (bytes == null || bytes.isEmpty) {
      throw Exception(appTr(
        'تعذر قراءة الملف — أعد المحاولة',
        'Could not read the file — please retry',
      ));
    }
    if (bytes.length > maxBytes) {
      throw Exception(appTr(
        'حجم الملف يجب ألا يتجاوز $maxSizeMb ميجابايت',
        'File size must not exceed $maxSizeMb MB',
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
      return readLocalPathBytes(path);
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
        'سجّل الدخول لرفع ملفات الرسالة الكبيرة',
        'Sign in to upload large thesis files',
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

  Future<VivaPdfExtractionResult> extractFromThesis({
    required List<int> bytes,
    required String fileName,
  }) async {
    if (fileName.toLowerCase().endsWith('.docx')) {
      final parsed = await ManuscriptDocumentParser.parseFile(
        bytes: Uint8List.fromList(bytes),
        filename: fileName,
        allowCloud: false,
      );
      final text = parsed.fullText.trim().isNotEmpty
          ? parsed.fullText
          : parsed.bodyText;
      if (text.trim().length < 80) {
        throw Exception(appTr(
          'لم يُستخرج نص كافٍ من ملف Word — ارفع PDF أو ملفاً أوضح',
          'Not enough text from the Word file — upload a PDF or a clearer file',
        ));
      }
      final cover = text.length > 14000 ? text.substring(0, 14000) : text;
      final bibliography = BibliographyHarvest.combine(
        BibliographyHarvest.fromLines(
          parsed.references.map((r) {
            if (r.rawText.trim().length >= 12) return r.rawText;
            final n = r.importedNumber;
            final doi = r.doi.trim();
            return [
              if (n != null) '[$n]',
              r.title,
              if (doi.isNotEmpty) doi,
            ].join(' ');
          }),
        ),
        BibliographyHarvest.fromThesisText(text),
      );
      final extracted = await extractStructured(
        fileName: fileName,
        sourceText: prioritizeThesisText(text),
        coverText: cover,
      );
      return _withBibliography(extracted, bibliography);
    }
    return extractFromPdf(bytes: bytes, fileName: fileName);
  }

  Future<VivaPdfExtractionResult> extractFromPdf({
    required List<int> bytes,
    required String fileName,
  }) async {
    _ensureCloud();

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

    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: _extractionSystemPrompt,
      userMessage: appTr(
        'حلّل ملف الرسالة المرفق. ابدأ بمصفوفة issues ثم الأسئلة الصعبة. '
        'ممنوع أسئلة عامة مثل «كيف تبرر هذه النقطة». JSON فقط.',
        'Analyze the attached thesis. Start with the issues array then hard questions. '
        'Forbidden: generic questions like “how do you justify this point”. JSON only.',
      ),
      attachments: [attachment],
      maxOutputTokens: 8192,
    );

    if (!result.isSuccess) {
      throw Exception(
        result.error ?? appTr('تعذر تحليل الملف', 'Could not analyze the file'),
      );
    }

    return _enrichIfNeeded(
      initial: parseExtraction(result.text!, fileName),
      fileName: fileName,
      attachments: [attachment],
    );
  }

  Future<VivaPdfExtractionResult> extractStructured({
    required String fileName,
    required String sourceText,
    String? coverText,
  }) async {
    _ensureCloud();
    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: _extractionSystemPrompt,
      userMessage: appTr(
        'هذا نص من فصول الرسالة (مقدمة + منهج/نتائج + خاتمة). '
        'استخرج العنوان كما هو على الغلاف، وأسماء المشرفين المطبوعة تحت إشراف/المشرف، '
        'ثم issues ثم أسئلة مناقشة صعبة:\n\n$sourceText',
        'This is thesis text (intro + methods/results + conclusion). '
        'Extract the cover title and printed supervisor names, then issues, then hard viva questions:\n\n$sourceText',
      ),
      maxOutputTokens: 8192,
    );
    if (!result.isSuccess) {
      throw Exception(
        result.error ?? appTr('تعذر تحليل الملف', 'Could not analyze the file'),
      );
    }
    return _enrichIfNeeded(
      initial: parseExtraction(
        result.text!,
        fileName,
        coverText: coverText ?? sourceText,
      ),
      fileName: fileName,
      sourceText: sourceText,
      coverText: coverText ?? sourceText,
    );
  }

  Future<VivaPdfExtractionResult> _enrichIfNeeded({
    required VivaPdfExtractionResult initial,
    required String fileName,
    String? sourceText,
    String? coverText,
    List<GeminiInlinePart> attachments = const [],
  }) async {
    var current = applyCoverFallbacks(
      initial,
      fileName: fileName,
      coverText: coverText ?? sourceText,
    );
    if (current.issues.length >= 8) return current;

    final critique = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: _critiqueSystemPrompt,
      userMessage: sourceText != null
          ? appTr(
              'استخرج أكبر عدد ممكن من الأخطاء والثغرات والتناقضات من هذا النص. JSON فقط.\n\n$sourceText',
              'Extract as many errors, gaps, and contradictions as you can from this text. JSON only.\n\n$sourceText',
            )
          : appTr(
              'من ملف الرسالة المرفق: استخرج أكبر عدد ممكن من الأخطاء والثغرات والتناقضات مع اقتباس. JSON فقط.',
              'From the attached thesis: extract as many errors, gaps, and contradictions as you can, with quotes. JSON only.',
            ),
      attachments: attachments,
      maxOutputTokens: 8192,
    );
    if (!critique.isSuccess || critique.text == null) return current;
    return applyCoverFallbacks(
      mergeExtractions(
        current,
        parseExtraction(critique.text!, fileName, coverText: coverText),
      ),
      fileName: fileName,
      coverText: coverText ?? sourceText,
    );
  }

  void _ensureCloud() {
    if (GeminiAdvisorClient.isAvailable) return;
    throw Exception(appTr(
      GeminiAdvisorClient.needsSignInForCloudAi
          ? 'استخراج الرسالة يتطلب تسجيل الدخول'
          : 'استخراج الرسالة غير متاح حالياً',
      GeminiAdvisorClient.needsSignInForCloudAi
          ? 'Extracting the thesis requires signing in'
          : 'Thesis extraction is unavailable right now',
    ));
  }

  String get _extractionSystemPrompt => appTr(
        'أنت ممتحن لجنة مناقشة صارم. استخرج من المستند فقط — ممنوع اختلاق أسماء مشرفين أو أرقام أو جداول. '
        'أعد JSON صالحاً فقط (بدون markdown) بهذا الترتيب:\n'
        'issues (مفتاح إلزامي أولاً: 10 إلى 16 كائناً {kind, quote, comment} — '
        'kind=error|gap|inconsistency|comment. ابحث عن: تناقض ملخص/نتائج، عينة بلا تبرير، '
        'اختبار إحصائي غير مناسب، ادعاء بلا دليل، حدود غير مذكورة، أدوات بلا صدق/ثبات، '
        'تعميم أوسع من البيانات، مراجع ناقصة، صياغة تُظهر النتيجة قبل المنهج),\n'
        'vivaQuestions (8 إلى 12 سؤالاً صعباً بأسلوب مناقش: يعترض على رقم أو جدول أو اختيار منهجي. '
        'ممنوع الأسئلة السهلة مثل «كيف تبرر هذه النقطة» أو إعادة جملة الملخص),\n'
        'title (عنوان الغلاف كما هو مطبوع),\n'
        'supervisorNames (قائمة أسماء المشرفين كما طُبعت تحت إشراف/المشرف الرئيسي/المساعد),\n'
        'supervisorName (المشرف الرئيسي فقط إن وُجد),\n'
        'summary, methodology, specialization,\n'
        'researchQuestions, sampleDescription, mainFindings, limitations,\n'
        'excerpt (حتى 1600 حرف من المنهج والنتائج فقط).\n'
        'لا تترك issues فارغة إن وُجد فصل منهج أو نتائج. لا تخترع مشرفاً.',
        'You are a strict viva examiner. Extract from the document only — never invent supervisor names, numbers, or tables. '
        'Return valid JSON only (no markdown) in this order:\n'
        'issues (REQUIRED first: 10 to 16 objects {kind, quote, comment} — '
        'kind=error|gap|inconsistency|comment. Look for: abstract/results mismatch, unjustified sample, '
        'wrong statistical test, unsupported claim, missing limits, unvalidated instrument, '
        'over-generalization, thin references, results stated before methods),\n'
        'vivaQuestions (8 to 12 HARD examiner questions that challenge a number, table, or method choice. '
        'Forbidden: easy prompts like “how do you justify this point” or restating the abstract),\n'
        'title (cover title as printed),\n'
        'supervisorNames (list of supervisor names as printed under Supervision / main / co-supervisor),\n'
        'supervisorName (main supervisor only if printed),\n'
        'summary, methodology, specialization,\n'
        'researchQuestions, sampleDescription, mainFindings, limitations,\n'
        'excerpt (up to 1600 chars from methods and results only).\n'
        'Do not leave issues empty if methods or results exist. Do not invent a supervisor.',
      );

  String get _critiqueSystemPrompt => appTr(
        'أنت مراجع لغة ومنهجية لرسالة علمية. مهمتك الوحيدة: استخراج أخطاء وثغرات وتناقضات من النص. '
        'أعد JSON فقط بالمفتاح issues (12 إلى 18 عنصراً). كل عنصر {kind, quote, comment}: '
        'kind=error|gap|inconsistency|comment، quote اقتباس قصير من النص، comment اعتراض المناقش. '
        'لا تختلق أرقاماً أو جداول غير موجودة. لا تُرجع أسئلة.',
        'You are a methods and language reviewer. Your only task: extract errors, gaps, and contradictions. '
        'Return JSON only with key issues (12 to 18 items). Each item {kind, quote, comment}: '
        'kind=error|gap|inconsistency|comment, quote a short passage, comment is the examiner objection. '
        'Do not invent numbers or tables. Do not return questions.',
      );

  VivaPdfExtractionResult parseExtraction(
    String raw,
    String fileName, {
    String? coverText,
  }) {
    var data = decodeExtractionJson(raw);
    data ??= recoverPartialExtraction(raw);
    if (data == null) {
      final fallback = raw.trim();
      final cut = fallback.length > 4500 ? fallback.substring(0, 4500) : fallback;
      final recoveredIssues = _parseIssues(
        extractJsonArray(raw, const ['issues', 'errors', 'comments', 'weaknesses']),
      );
      return applyCoverFallbacks(
        VivaPdfExtractionResult(
          fileName: fileName,
          title: fileName.replaceAll(RegExp(r'\.(pdf|docx)$', caseSensitive: false), ''),
          summary: fallback.length > 2000 ? fallback.substring(0, 2000) : fallback,
          excerpt: cut,
          defenseContext: cut,
          extractedQuestions: recoveredIssues.isNotEmpty
              ? recoveredIssues.take(10).map(_questionFromIssue).toList()
              : examinerQuestionsFromPassage(cut),
          issues: recoveredIssues,
        ),
        fileName: fileName,
        coverText: coverText,
      );
    }

    final map = data;
    String field(String key) {
      final value = map[key];
      if (value == null) return '';
      if (value is List) {
        return value
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .join('\n• ');
      }
      return value.toString().trim();
    }

    List<String> stringList(String key) {
      final value = map[key];
      if (value is List) {
        return value
            .map((e) => e.toString().trim())
            .where((e) => e.length >= 12)
            .toList();
      }
      if (value is String && value.trim().isNotEmpty) {
        return value
            .split(RegExp(r'\n+|•|;'))
            .map((e) => e.replaceFirst(RegExp(r'^\s*\d+[.)]\s*'), '').trim())
            .where((e) => e.length >= 12)
            .toList();
      }
      return const [];
    }

    final title = field('title');
    final summary = field('summary');
    var excerpt = field('excerpt');
    if (excerpt.length > 2200) excerpt = excerpt.substring(0, 2200);

    final researchQs = stringList('researchQuestions');
    var vivaQs = stringList('vivaQuestions');
    if (vivaQs.isEmpty) vivaQs = stringList('questions');

    final issues = _parseIssues(
      map['issues'] ??
          map['errors'] ??
          map['comments'] ??
          map['weaknesses'] ??
          map['ملاحظات'] ??
          map['أخطاء'],
    );

    vivaQs = vivaQs.where(_looksLikeExaminerQuestion).toList();
    if (vivaQs.length < 6 && issues.isNotEmpty) {
      vivaQs = [
        ...vivaQs,
        ...issues.map(_questionFromIssue),
      ];
    }
    if (vivaQs.isEmpty) {
      vivaQs = [
        ...researchQs.map(
          (q) => appTr(
            'سؤالك البحثي: «$q». أي نتيجة تجيب عنه تحديداً، وما الذي يبقى بلا دليل؟',
            'Your research question: «$q». Which result answers it, and what remains unproven?',
          ),
        ),
        ...issues.map(_questionFromIssue),
      ];
    }
    if (vivaQs.isEmpty) {
      vivaQs = examinerQuestionsFromPassage(excerpt.isNotEmpty ? excerpt : summary);
    }

    if (title.isEmpty &&
        summary.isEmpty &&
        excerpt.isEmpty &&
        vivaQs.isEmpty &&
        issues.isEmpty) {
      throw Exception(appTr(
        'لم يُستخرج محتوى كافٍ من الملف — جرّب PDF أوضح أو ألصق الملخص يدوياً',
        'Could not extract enough content — try a clearer PDF or paste the summary manually',
      ));
    }

    final defenseParts = <String>[];
    void addPart(String labelAr, String labelEn, String value) {
      if (value.isEmpty) return;
      defenseParts.add('${appTr(labelAr, labelEn)}:\n$value');
    }

    addPart('الأسئلة/الأهداف البحثية', 'Research questions/aims',
        researchQs.isEmpty ? field('researchQuestions') : researchQs.map((q) => '• $q').join('\n'));
    addPart('العينة/البيانات', 'Sample/data', field('sampleDescription'));
    addPart('النتائج الرئيسية', 'Main findings', field('mainFindings'));
    addPart('حدود الدراسة', 'Limitations', field('limitations'));
    if (issues.isNotEmpty) {
      addPart(
        'ملاحظات وأخطاء للمناقشة',
        'Issues and comments for the viva',
        issues.map((i) => '• [${i.kind}] ${i.label}').join('\n'),
      );
    }
    final defenseContext =
        defenseParts.isEmpty ? null : defenseParts.join('\n\n');

    final supervisors = _collectSupervisorNames(map);

    return applyCoverFallbacks(
      VivaPdfExtractionResult(
        fileName: fileName,
        title: title,
        summary: summary.isNotEmpty
            ? summary
            : (excerpt.isNotEmpty ? excerpt : title),
        methodology: field('methodology').isEmpty ? null : field('methodology'),
        specialization:
            field('specialization').isEmpty ? null : field('specialization'),
        excerpt: excerpt.isEmpty ? null : excerpt,
        defenseContext: defenseContext,
        extractedQuestions: vivaQs.take(15).toList(),
        issues: issues.take(24).toList(),
        supervisorFromThesis:
            supervisors.isNotEmpty ? supervisors.first : null,
        supervisorsFromThesis: supervisors,
      ),
      fileName: fileName,
      coverText: coverText,
    );
  }

  static List<String> questionsFromPassage(String passage) =>
      examinerQuestionsFromPassage(passage);

  static List<String> examinerQuestionsFromPassage(String passage) {
    final parts = passage.split(RegExp(r'[.!؟?\n•]+'));
    final qs = <String>[];
    final probes = <List<String>>[
      [
        'ادعيتَ: «{s}». ما حجم العينة والاختبار الذي يثبت هذا، وما قوة الأثر؟',
        'You claimed: «{s}». What sample size and test support this, and what is the effect size?',
      ],
      [
        '«{s}» — هل يناقض هذا الملخص أو جدولاً لاحقاً؟ أين الرقم الأدق؟',
        '«{s}» — does this contradict the abstract or a later table? Which number is exact?',
      ],
      [
        'إذا اعترض المناقش أن «{s}» تعميم أوسع من بياناتك، ما حدود العبارة؟',
        'If an examiner says «{s}» over-generalizes your data, what is the precise limit?',
      ],
    ];
    var i = 0;
    for (final part in parts) {
      final t = part.trim();
      if (t.length < 48) continue;
      final snippet = t.length > 140 ? '${t.substring(0, 140)}…' : t;
      final pair = probes[i % probes.length];
      qs.add(appTr(pair[0], pair[1]).replaceAll('{s}', snippet));
      i++;
      if (qs.length >= 10) break;
    }
    return qs;
  }

  static bool _looksLikeExaminerQuestion(String q) {
    final t = q.trim();
    if (t.length < 24) return false;
    final weak = RegExp(
      r'كيف تبرر هذه النقطة|how do you justify this (point|before)',
      caseSensitive: false,
    );
    return !weak.hasMatch(t);
  }

  static String _questionFromIssue(VivaThesisIssue issue) {
    return appTr(
      'المناقش يعترض [${issue.kind}]: ${issue.label} ما دليلك، وما الذي تغيّر لو صحّ الاعتراض؟',
      'The examiner objects [${issue.kind}]: ${issue.label} What is your evidence, and what changes if the objection is right?',
    );
  }

  static VivaPdfExtractionResult mergeExtractions(
    VivaPdfExtractionResult primary,
    VivaPdfExtractionResult extra,
  ) {
    final seenIssues = <String>{};
    final issues = <VivaThesisIssue>[];
    for (final issue in [...primary.issues, ...extra.issues]) {
      final key = issue.label.toLowerCase();
      if (key.isEmpty || !seenIssues.add(key)) continue;
      issues.add(issue);
    }

    final seenQs = <String>{};
    final questions = <String>[];
    for (final q in [
      ...primary.extractedQuestions,
      ...extra.extractedQuestions,
      ...issues.map(_questionFromIssue),
    ]) {
      final key = q.trim().toLowerCase();
      if (key.length < 24 || !seenQs.add(key)) continue;
      if (!_looksLikeExaminerQuestion(q)) continue;
      questions.add(q.trim());
    }

    return VivaPdfExtractionResult(
      fileName: primary.fileName,
      title: primary.title.isNotEmpty ? primary.title : extra.title,
      summary: primary.summary.length >= extra.summary.length
          ? primary.summary
          : extra.summary,
      methodology: primary.methodology ?? extra.methodology,
      specialization: primary.specialization ?? extra.specialization,
      excerpt: primary.excerpt ?? extra.excerpt,
      defenseContext: primary.defenseContext ?? extra.defenseContext,
      extractedQuestions: questions.take(15).toList(),
      issues: issues.take(24).toList(),
      supervisorFromThesis:
          primary.supervisorFromThesis ?? extra.supervisorFromThesis,
      supervisorsFromThesis: {
        ...primary.supervisorsFromThesis,
        ...extra.supervisorsFromThesis,
      }.where((e) => e.trim().length >= 4).toList(),
      bibliographyText: (primary.bibliographyText != null &&
              primary.bibliographyText!.trim().isNotEmpty)
          ? primary.bibliographyText
          : extra.bibliographyText,
    );
  }

  static VivaPdfExtractionResult _withBibliography(
    VivaPdfExtractionResult result,
    String bibliography,
  ) {
    final trimmed = bibliography.trim();
    if (trimmed.isEmpty) return result;
    return VivaPdfExtractionResult(
      fileName: result.fileName,
      title: result.title,
      summary: result.summary,
      methodology: result.methodology,
      specialization: result.specialization,
      excerpt: result.excerpt,
      defenseContext: result.defenseContext,
      extractedQuestions: result.extractedQuestions,
      issues: result.issues,
      supervisorFromThesis: result.supervisorFromThesis,
      supervisorsFromThesis: result.supervisorsFromThesis,
      bibliographyText: trimmed,
    );
  }

  static VivaPdfExtractionResult applyCoverFallbacks(
    VivaPdfExtractionResult result, {
    required String fileName,
    String? coverText,
  }) {
    final stem = fileName.replaceAll(
      RegExp(r'\.(pdf|docx)$', caseSensitive: false),
      '',
    );
    var title = result.title.trim();
    if (title.isEmpty ||
        title.toLowerCase() == stem.toLowerCase() ||
        _looksLikeCoverNoise(title)) {
      final guessed = guessTitleFromText(coverText ?? result.excerpt ?? '');
      if (guessed != null) title = guessed;
    }
    if (title.isEmpty) title = stem;

    var summary = result.summary.trim();
    if (summary.length < 40) {
      final fallback = (result.excerpt ?? result.defenseContext ?? '').trim();
      if (fallback.length >= 40) summary = fallback;
    }

    var supervisors = result.supervisorsFromThesis
        .map(cleanSupervisorName)
        .where((e) => e != null)
        .cast<String>()
        .toList();
    if (supervisors.isEmpty && result.supervisorFromThesis != null) {
      final one = cleanSupervisorName(result.supervisorFromThesis!);
      if (one != null) supervisors = [one];
    }
    if (supervisors.isEmpty && (coverText != null && coverText.trim().isNotEmpty)) {
      supervisors = guessSupervisorsFromText(coverText);
    }

    return VivaPdfExtractionResult(
      fileName: result.fileName,
      title: title,
      summary: summary,
      methodology: result.methodology,
      specialization: result.specialization,
      excerpt: result.excerpt,
      defenseContext: result.defenseContext,
      extractedQuestions: result.extractedQuestions,
      issues: result.issues,
      supervisorFromThesis: supervisors.isNotEmpty ? supervisors.first : null,
      supervisorsFromThesis: supervisors,
      bibliographyText: result.bibliographyText,
    );
  }

  static String? guessTitleFromText(String text) {
    if (text.trim().isEmpty) return null;
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((e) => e.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((e) => e.length >= 8)
        .toList();
    for (var i = 0; i < lines.length && i < 50; i++) {
      final line = lines[i];
      if (RegExp(
        r'عنوان(?:\s+الرسالة|\s+البحث)?|thesis title|title of the',
        caseSensitive: false,
      ).hasMatch(line)) {
        final rest = line
            .replaceFirst(
              RegExp(
                r'^.*?(?:عنوان(?:\s+الرسالة|\s+البحث)?|thesis title|title)\s*[:：\-]?\s*',
                caseSensitive: false,
              ),
              '',
            )
            .trim();
        if (_looksLikeTitle(rest)) return rest;
        if (i + 1 < lines.length && _looksLikeTitle(lines[i + 1])) {
          return lines[i + 1];
        }
      }
    }
    for (final line in lines.take(30)) {
      if (_looksLikeTitle(line) && !_looksLikeCoverNoise(line)) return line;
    }
    return null;
  }

  static List<String> guessSupervisorsFromText(String text) {
    if (text.trim().isEmpty) return const [];
    final names = <String>[];
    final seen = <String>{};
    void add(String? raw) {
      final cleaned = cleanSupervisorName(raw ?? '');
      if (cleaned == null) return;
      final key = cleaned.toLowerCase();
      if (seen.add(key)) names.add(cleaned);
    }

    final labeled = RegExp(
      r'(?:المشرف(?:\s+(?:الرئيسي|الأول|المساعد|المشارك))?|إشراف|تحت إشراف|'
      r'supervised by|supervisor|co-?supervisor)\s*[:：\-]?\s*([^\n]{4,80})',
      caseSensitive: false,
    );
    for (final match in labeled.allMatches(text)) {
      add(match.group(1));
    }

    final lines = text.split(RegExp(r'\r?\n'));
    var capture = false;
    var captured = 0;
    for (final raw in lines.take(90)) {
      final line = raw.trim();
      if (RegExp(
        r'^(إشراف|تحت إشراف|المشرفون|هيئة الإشراف|supervision|supervisors?)\s*[:：]?$',
        caseSensitive: false,
      ).hasMatch(line)) {
        capture = true;
        continue;
      }
      if (capture) {
        if (line.isEmpty || _looksLikeCoverNoise(line)) {
          if (captured >= 1) break;
          continue;
        }
        add(line);
        captured++;
        if (captured >= 4) break;
      }
    }
    return names.take(4).toList();
  }

  static String? cleanSupervisorName(String raw) {
    var name = raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceFirst(
          RegExp(
            r'^(?:المشرف(?:\s+(?:الرئيسي|الأول|المساعد|المشارك))?|إشراف|تحت إشراف|'
            r'supervised by|supervisor|co-?supervisor)\s*[:：\-]?\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    name = name.replaceAll(RegExp(r'[|،,;]+$'), '').trim();
    if (name.length < 4 || name.length > 80) return null;
    if (isInventedSupervisor(name) || _looksLikeCoverNoise(name)) return null;
    return name;
  }

  static bool isInventedSupervisor(String name) {
    return RegExp(
      r'نادية حسن|كريم منصور|ليلى عمر|Nadia Hassan|Karim Mansour|Layla Omar|'
      r'غير مذكور|غير محدد|لا يوجد|unknown|not specified|n/?a|'
      r'^(أ\.?\s*د\.?|د\.|prof\.?|dr\.?|المشرف|supervisor)\s*$',
      caseSensitive: false,
    ).hasMatch(name.trim());
  }

  static bool _looksLikeTitle(String line) {
    final t = line.trim();
    if (t.length < 12 || t.length > 220) return false;
    if (_looksLikeCoverNoise(t)) return false;
    return !RegExp(r'^\d+$').hasMatch(t);
  }

  static bool _looksLikeCoverNoise(String line) {
    final t = line.trim();
    if (RegExp(r'^بسم الله').hasMatch(t)) return true;
    if (t.length < 70 &&
        RegExp(
          r'^(جامعة|كلية|قسم |faculty of|university of|department of)\b',
          caseSensitive: false,
        ).hasMatch(t)) {
      return true;
    }
    if (RegExp(
      r'^(رسالة مقدمة|للحصول على|submitted in|in partial fulfillment)',
      caseSensitive: false,
    ).hasMatch(t)) {
      return true;
    }
    return RegExp(
      r'^(إشراف|المشرف|title|abstract|ماجستير|دكتوراه|master|doctorate)\s*$',
      caseSensitive: false,
    ).hasMatch(t);
  }

  static List<String> _collectSupervisorNames(Map<String, dynamic> map) {
    final out = <String>[];
    void addAll(dynamic raw) {
      if (raw == null) return;
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            addAll(item['name'] ?? item['اسم'] ?? item['supervisor']);
          } else {
            final cleaned = cleanSupervisorName(item.toString());
            if (cleaned != null) out.add(cleaned);
          }
        }
        return;
      }
      final cleaned = cleanSupervisorName(raw.toString());
      if (cleaned != null) out.add(cleaned);
    }

    addAll(map['supervisorNames']);
    addAll(map['supervisors']);
    addAll(map['supervisorName']);
    addAll(map['coSupervisor']);
    addAll(map['المشرف']);
    addAll(map['المشرفون']);
    return {
      for (final name in out) name.toLowerCase(): name,
    }.values.toList();
  }

  /// مقدمة + منهج/نتائج + خاتمة بدل أول 28 ألف حرف فقط.
  static String prioritizeThesisText(String text, {int maxChars = 48000}) {
    final cleaned = text.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
    if (cleaned.length <= maxChars) return cleaned;

    final headLen = (maxChars * 0.22).round().clamp(2000, 10000);
    final tailLen = (maxChars * 0.30).round().clamp(3000, 14000);
    final head = cleaned.substring(0, headLen);
    final tail = cleaned.substring(cleaned.length - tailLen);

    final lower = cleaned.toLowerCase();
    final markers = [
      'منهج',
      'methodology',
      'methods',
      'نتائج',
      'results',
      'مناقشة',
      'discussion',
      'تحليل',
      'analysis',
      'عينة',
      'sample',
      'حدود',
      'limitation',
    ];
    var midStart = cleaned.length ~/ 3;
    for (final marker in markers) {
      final i = lower.indexOf(marker, 8000);
      if (i >= 8000 && i < cleaned.length - tailLen - 2000) {
        midStart = i;
        break;
      }
    }
    final midBudget = maxChars - headLen - tailLen - 40;
    final midEnd =
        (midStart + midBudget).clamp(midStart, cleaned.length - tailLen).toInt();
    final mid = cleaned.substring(midStart, midEnd);
    return '$head\n\n[...]\n\n$mid\n\n[...]\n\n$tail';
  }

  static Map<String, dynamic>? decodeExtractionJson(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }
    final start = text.indexOf('{');
    if (start < 0) return null;
    var end = text.lastIndexOf('}');
    if (end <= start) {
      text = _closeTruncatedJson(text.substring(start));
    } else {
      text = text.substring(start, end + 1);
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      try {
        final repaired = jsonDecode(_closeTruncatedJson(text));
        if (repaired is Map<String, dynamic>) return repaired;
        if (repaired is Map) return Map<String, dynamic>.from(repaired);
      } catch (_) {}
    }
    return null;
  }

  static Map<String, dynamic>? recoverPartialExtraction(String raw) {
    final issues = extractJsonArray(
      raw,
      const ['issues', 'errors', 'comments', 'weaknesses'],
    );
    final questions = extractJsonArray(
      raw,
      const ['vivaQuestions', 'questions'],
    );
    if (issues == null && questions == null) return null;
    return {
      if (questions != null) 'vivaQuestions': questions,
      if (issues != null) 'issues': issues,
    };
  }

  static List<dynamic>? extractJsonArray(String raw, List<String> keys) {
    for (final key in keys) {
      final match = RegExp(
        '"$key"\\s*:\\s*\\[',
        caseSensitive: false,
      ).firstMatch(raw);
      if (match == null) continue;
      final start = match.end - 1;
      final slice = _sliceBalanced(raw, start, '[', ']');
      if (slice == null) continue;
      try {
        final decoded = jsonDecode(slice);
        if (decoded is List) return decoded;
      } catch (_) {
        try {
          final decoded = jsonDecode('$slice]');
          if (decoded is List) return decoded;
        } catch (_) {}
      }
    }
    return null;
  }

  static String _closeTruncatedJson(String text) {
    var out = text.trim();
    final openCurly = '{'.allMatches(out).length - '}'.allMatches(out).length;
    final openSquare = '['.allMatches(out).length - ']'.allMatches(out).length;
    if (out.endsWith(',')) out = out.substring(0, out.length - 1);
    out += ']' * (openSquare > 0 ? openSquare : 0);
    out += '}' * (openCurly > 0 ? openCurly : 0);
    return out;
  }

  static String? _sliceBalanced(
    String text,
    int start,
    String open,
    String close,
  ) {
    if (start < 0 || start >= text.length || text[start] != open) return null;
    var depth = 0;
    for (var i = start; i < text.length; i++) {
      final ch = text[i];
      if (ch == open) depth++;
      if (ch == close) {
        depth--;
        if (depth == 0) return text.substring(start, i + 1);
      }
    }
    return text.substring(start);
  }

  List<VivaThesisIssue> _parseIssues(dynamic raw) {
    if (raw == null) return const [];
    if (raw is String && raw.trim().length >= 12) {
      return raw
          .split(RegExp(r'\n+|•|;'))
          .map((e) => e.replaceFirst(RegExp(r'^\s*\d+[.)]\s*'), '').trim())
          .where((e) => e.length >= 12)
          .map((e) => VivaThesisIssue(kind: 'comment', comment: e))
          .toList();
    }
    if (raw is Map) {
      return _parseIssues(raw.values.toList());
    }
    if (raw is! List) return const [];
    final out = <VivaThesisIssue>[];
    for (final item in raw) {
      if (item is String && item.trim().length >= 12) {
        out.add(VivaThesisIssue(kind: 'comment', comment: item.trim()));
        continue;
      }
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final issue = VivaThesisIssue.fromMap(map);
        if (issue.quote.trim().isNotEmpty || issue.comment.trim().isNotEmpty) {
          out.add(issue);
        }
      }
    }
    return out;
  }
}
