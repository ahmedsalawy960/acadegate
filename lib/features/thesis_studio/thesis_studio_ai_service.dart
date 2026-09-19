import 'dart:convert';

import '../../core/locale/app_translate.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import '../ai_advisor/grounded_reference_service.dart';
import '../ai_advisor/grounded_work.dart';
import '../profile/academic_profile.dart';
import '../research_supply_chain/research_goal.dart';
import 'thesis_studio_command.dart';
import 'thesis_studio_kind.dart';
import 'thesis_studio_length.dart';
import 'thesis_studio_literature_map.dart';
import 'thesis_studio_models.dart';
import 'thesis_studio_outline.dart';
import 'thesis_studio_prose.dart';

class ThesisStudioAiService {
  ThesisStudioAiService._();

  static final ThesisStudioAiService instance = ThesisStudioAiService._();

  /// Last write/grow diagnostic (quota, empty response, etc.) for the UI.
  String? lastFillDiagnostic;

  static bool isQuotaLikeError(String? message) {
    if (message == null || message.trim().isEmpty) return false;
    final lower = message.toLowerCase();
    return lower.contains('quota') ||
        lower.contains('resource-exhausted') ||
        lower.contains('resource_exhausted') ||
        lower.contains('daily') ||
        message.contains('الحد اليومي') ||
        message.contains('حصة');
  }

  Future<ThesisDraft> compose({
    required ThesisPlan plan,
    required GroundedReferenceBundle literature,
    required List<ThesisChapterTemplate> templates,
    AcademicProfile? profile,
    ThesisProgress? onProgress,
  }) async {
    final goal = plan.goal;
    final local = buildLocalDraft(
      goal: goal,
      literature: literature,
      templates: templates,
      profile: profile,
      plan: plan,
    );
    if (!GeminiAdvisorClient.isAvailable) {
      return local.copyWith(
        note: appTr(
          'سجّل الدخول لتفعيل AcadeGate AI — المسودة الحالية هيكل كامل بمراجع مؤكدة فقط.',
          'Sign in to enable AcadeGate AI — the current draft is a full outline with confirmed references only.',
        ),
      );
    }

    onProgress?.call(
      appTr('جارٍ صياغة العنوان والملخص...', 'Drafting title and abstract...'),
    );
    final front = await _frontMatter(plan, literature, profile);
    var draft = local.copyWith(
      proposedTitle: front.title.isNotEmpty ? front.title : local.proposedTitle,
      abstractText:
          front.abstractText.isNotEmpty ? front.abstractText : local.abstractText,
      researchQuestions: front.questions.isNotEmpty
          ? front.questions
          : local.researchQuestions,
      fromGemini: true,
      modelUsed: front.modelUsed,
      note: appTr(
        'مسودة مولَّدة للمراجعة على ${plan.targetPages} صفحة مستهدفة. تحقق من كل استشهاد مع النص الأصلي قبل التسليم. لا نختلق نتائج معملية.',
        'Generated draft for review at a ${plan.targetPages}-page target. Verify every citation against the original before submission. We do not invent lab results.',
      ),
    );

    final targets = ThesisLengthBudget.chapterWordTargets(plan, templates);
    final filled = <ThesisChapter>[];
    for (var i = 0; i < templates.length; i++) {
      final template = templates[i];
      final label = plan.arabic ? template.titleAr : template.titleEn;
      onProgress?.call(
        appTr(
          'جارٍ كتابة $label (${i + 1}/${templates.length})...',
          'Writing $label (${i + 1}/${templates.length})...',
        ),
      );
      final chapter = await fillChapter(
        plan: plan,
        literature: literature,
        template: template,
        priorChapters: filled,
        profile: profile,
        targetWords: targets[template.id],
      );
      filled.add(chapter);
    }

    return draft.copyWith(
      chapters: filled,
      fromGemini: filled.any((c) => c.fromGemini) || front.title.isNotEmpty,
    );
  }

  Future<ThesisChapter> fillChapter({
    required ThesisPlan plan,
    required GroundedReferenceBundle literature,
    required ThesisChapterTemplate template,
    List<ThesisChapter> priorChapters = const [],
    AcademicProfile? profile,
    int? targetWords,
  }) async {
    final local = _localChapter(plan, literature, template, profile);
    final words = targetWords ??
        ThesisLengthBudget.chapterWordTargets(
          plan,
          ThesisStudioOutline.forPlan(plan),
        )[template.id] ??
        800;
    if (template.depth == ThesisChapterDepth.scaffold ||
        !GeminiAdvisorClient.isAvailable) {
      return local;
    }

    final arabic = plan.arabic;
    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: _chapterSystem(arabic, template, plan, words),
      userMessage: _chapterUser(
        plan: plan,
        literature: literature,
        template: template,
        priorChapters: priorChapters,
        profile: profile,
        targetWords: words,
      ),
      maxOutputTokens: 8192,
      preferPro: true,
    );
    var body = local.body;
    var fromGemini = false;
    if (result.isSuccess && result.text != null) {
      final cleaned = await GroundedReferenceService.instance.enforceVerifiedDois(
        _stripInventedMarkers(
          result.text!,
          maxIndex: literature.works.length,
        ),
        known: literature,
      );
      if (_acceptableChapter(cleaned, template, priorChapters, targetWords: words)) {
        body = cleaned.trim();
        fromGemini = true;
      }
    }
    if (fromGemini || GeminiAdvisorClient.isAvailable) {
      body = await _growChapter(
        plan: plan,
        literature: literature,
        template: template,
        priorChapters: priorChapters,
        profile: profile,
        current: body,
        targetWords: words,
      );
      fromGemini = fromGemini || body != local.body;
    }
    return ThesisChapter(
      id: template.id,
      titleAr: template.titleAr,
      titleEn: template.titleEn,
      purposeAr: template.purposeAr,
      purposeEn: template.purposeEn,
      body: body,
      fromGemini: fromGemini,
      depth: template.depth,
    );
  }

  Future<ThesisParagraph> fillParagraph({
    required ThesisPlan plan,
    required GroundedReferenceBundle literature,
    required ThesisChapterTemplate template,
    required ThesisParagraph paragraph,
    required String command,
    List<ThesisParagraph> siblingParagraphs = const [],
    AcademicProfile? profile,
    ThesisProgress? onProgress,
    ThesisCommandSpec? spec,
    void Function(String body)? onBodyUpdate,
  }) async {
    final resolved = spec ??
        ThesisCommandSpec.parse(
          command,
          depth: template.depth,
          chapterId: template.id,
        );
    lastFillDiagnostic = null;
    final words = resolved.targetWords;
    final passWords = words.clamp(280, ThesisLengthBudget.wordsPerGrowPass);
    final slimLit = _slimLiterature(literature);
    final growLit = _slimLiterature(literature, maxWorks: 18, stripAbstracts: true);
    final local = _localParagraph(
      plan: plan,
      literature: slimLit,
      template: template,
      paragraph: paragraph,
      command: command,
    );
    if (template.depth == ThesisChapterDepth.scaffold ||
        !GeminiAdvisorClient.isAvailable) {
      if (!GeminiAdvisorClient.isAvailable) {
        lastFillDiagnostic = arabicUnavailableHint(plan.arabic);
      }
      return paragraph.copyWith(
        body: local,
        fromGemini: false,
        lastCommand: command,
      );
    }

    final arabic = plan.arabic;
    onProgress?.call(
      arabic
          ? 'جارٍ كتابة المبحث (هدف ≈ ${resolved.estimatedPages} صفحة · $words كلمة)...'
          : 'Writing this section (target ≈ ${resolved.estimatedPages} pages · $words words)...',
    );
    var body = local;
    var fromGemini = false;
    String? firstPassError;
    final existing = paragraph.body.trim();
    final alreadyLongEnough = ThesisLengthBudget.wordCount(existing) >=
        (words * 0.85).round();
    final continueLong = existing.length > 80 &&
        resolved.hasExplicitLength &&
        !alreadyLongEnough;
    if (continueLong) {
      body = existing;
      fromGemini = paragraph.fromGemini;
      onBodyUpdate?.call(body);
    } else {
      final result = await GeminiAdvisorClient.instance.generateResult(
        systemPrompt: _paragraphSystem(arabic, template, plan, passWords),
        userMessage: _paragraphUser(
          plan: plan,
          literature: slimLit,
          template: template,
          paragraph: paragraph,
          command: command,
          siblingParagraphs: siblingParagraphs,
          profile: profile,
          targetWords: passWords,
        ),
        maxOutputTokens: 8192,
        // Pro is slow/fragile for long thesis slices — prefer Flash for length growth.
        preferPro: false,
      );
      if (result.isSuccess && result.text != null) {
        final cleaned =
            await GroundedReferenceService.instance.enforceVerifiedDois(
          _stripInventedMarkers(
            result.text!,
            maxIndex: slimLit.works.length,
          ),
          known: slimLit,
        );
        if (_acceptableParagraph(
          cleaned,
          template,
          siblingParagraphs,
          current: paragraph,
        )) {
          body = cleaned.trim();
          fromGemini = true;
          onBodyUpdate?.call(body);
        } else {
          firstPassError = arabic
              ? 'رُفضت الدفعة الأولى (تشابه/قصر). نتابع بالتكملة إن أمكن.'
              : 'First pass rejected (similarity/too short). Continuing growth if possible.';
          onProgress?.call(firstPassError);
        }
      } else if ((result.error ?? '').trim().isNotEmpty) {
        firstPassError = result.error!.trim();
        onProgress?.call(
          arabic
              ? 'تعذّرت الدفعة الأولى: $firstPassError'
              : 'First pass failed: $firstPassError',
        );
        if (isQuotaLikeError(firstPassError)) {
          lastFillDiagnostic = arabic
              ? 'خطأ: $firstPassError — جلب المراجع يستهلك حصة AI؛ لم تبقَ طلبات كافية لكتابة ${resolved.estimatedPages} صفحة.'
              : 'Error: $firstPassError — literature harvest used AI quota; not enough left for ${resolved.estimatedPages} pages.';
          onProgress?.call(lastFillDiagnostic!);
          return paragraph.copyWith(
            body: body,
            fromGemini: fromGemini,
            lastCommand: command,
          );
        }
      }
    }

    final needsGrow =
        ThesisLengthBudget.wordCount(body) < (words * 0.85).round() &&
            words > ThesisLengthBudget.paragraphWords(template.depth);
    if (needsGrow && GeminiAdvisorClient.isAvailable) {
      body = await _growSection(
        plan: plan,
        literature: growLit,
        template: template,
        paragraph: paragraph,
        command: command,
        siblingParagraphs: siblingParagraphs,
        profile: profile,
        current: body,
        targetWords: words,
        onProgress: onProgress,
        onBodyUpdate: onBodyUpdate,
      );
      fromGemini = fromGemini || body != local;
    }

    final finalWords = ThesisLengthBudget.wordCount(body);
    if (resolved.hasExplicitLength &&
        finalWords < (words * 0.55).round()) {
      final prior = lastFillDiagnostic;
      final diag = arabic
          ? 'اكتمل جزئياً: $finalWords/$words كلمة (≈ ${ThesisLengthBudget.estimatedPagesOf(body)}/${resolved.estimatedPages} صفحة)${prior == null ? '' : ' · السبب: $prior'}${firstPassError == null || prior != null ? '' : ' · $firstPassError'}. ارفع حصة AI أو أعد التوليد غداً.'
          : 'Partial: $finalWords/$words words (≈ ${ThesisLengthBudget.estimatedPagesOf(body)}/${resolved.estimatedPages} pp)${prior == null ? '' : ' · cause: $prior'}${firstPassError == null || prior != null ? '' : ' · $firstPassError'}. Raise AI quota or regenerate tomorrow.';
      lastFillDiagnostic = diag;
      onProgress?.call(diag);
    }

    return paragraph.copyWith(
      body: body,
      fromGemini: fromGemini,
      lastCommand: command,
    );
  }

  static String arabicUnavailableHint(bool arabic) => arabic
      ? 'الذكاء الاصطناعي غير متاح (تسجيل الدخول مطلوب للسحابة).'
      : 'AI unavailable (sign-in required for cloud).';

  /// Keep prompts small so each grow pass can emit a full slice.
  static GroundedReferenceBundle _slimLiterature(
    GroundedReferenceBundle literature, {
    int maxWorks = 28,
    bool stripAbstracts = false,
  }) {
    final sliced = literature.works.length <= maxWorks
        ? literature.works
        : literature.works.take(maxWorks).toList();
    if (!stripAbstracts && sliced.length == literature.works.length) {
      return literature;
    }
    return GroundedReferenceBundle(
      topic: literature.topic,
      works: stripAbstracts
          ? [
              for (final w in sliced)
                GroundedWork(
                  title: w.title,
                  authors: w.authors,
                  year: w.year,
                  journal: w.journal,
                  doi: w.doi,
                  externalUrl: w.externalUrl,
                  abstractText: '',
                  source: w.source,
                ),
            ]
          : sliced,
    );
  }

  Future<String> _growSection({
    required ThesisPlan plan,
    required GroundedReferenceBundle literature,
    required ThesisChapterTemplate template,
    required ThesisParagraph paragraph,
    required String command,
    required List<ThesisParagraph> siblingParagraphs,
    AcademicProfile? profile,
    required String current,
    required int targetWords,
    ThesisProgress? onProgress,
    void Function(String body)? onBodyUpdate,
  }) async {
    if (template.depth == ThesisChapterDepth.scaffold) return current;
    var body = current;
    final arabic = plan.arabic;
    final neededPasses = (targetWords / ThesisLengthBudget.wordsPerGrowPass)
        .ceil()
        .clamp(1, ThesisLengthBudget.maxGrowPasses);
    final sectionTitle = paragraph.heading(arabic);
    final topic = ThesisCommandSpec.parse(
      command,
      depth: template.depth,
      chapterId: template.id,
    ).topicText;
    final headings = <String>[
      for (var i = 1; i <= neededPasses; i++)
        arabic
            ? (topic.length >= 8
                ? '$topic — محور $i'
                : '$sectionTitle — تكملة $i')
            : (topic.length >= 8
                ? '$topic — facet $i'
                : '$sectionTitle — continuation $i'),
    ];

    var successPasses = 0;
    var consecutiveFails = 0;
    var attempts = 0;
    final maxAttempts = ThesisLengthBudget.maxGrowPasses * 2;
    String? lastError;

    while (successPasses < neededPasses && attempts < maxAttempts) {
      attempts++;
      final have = ThesisLengthBudget.wordCount(body);
      if (have >= (targetWords * 0.85).round()) break;
      if (consecutiveFails >= 5) {
        final stopMsg = arabic
            ? 'توقفت التكملة بعد عدة محاولات فاشلة عند ≈ $have كلمة${lastError == null ? '' : ': $lastError'}. اضغط «توليد» مجدداً للمتابعة.'
            : 'Stopped after several failed continuations at ≈ $have words${lastError == null ? '' : ': $lastError'}. Press Generate again to continue.';
        lastFillDiagnostic = stopMsg;
        onProgress?.call(stopMsg);
        break;
      }

      final facet = headings[successPasses % headings.length];
      final remaining =
          (targetWords - have).clamp(280, ThesisLengthBudget.wordsPerGrowPass);
      final pagesHave = ThesisLengthBudget.estimatedPagesOf(body);
      final pagesWant =
          (targetWords / ThesisLengthBudget.wordsPerPage).ceil();
      onProgress?.call(
        arabic
            ? 'تكملة ${successPasses + 1}/$neededPasses · $have كلمة (≈ $pagesHave/$pagesWant صفحة)...'
            : 'Continuing ${successPasses + 1}/$neededPasses · $have words (≈ $pagesHave/$pagesWant pages)...',
      );
      final result = await GeminiAdvisorClient.instance.generateResult(
        systemPrompt: _paragraphSystem(arabic, template, plan, remaining),
        userMessage: _growUserMessage(
          plan: plan,
          literature: literature,
          template: template,
          paragraph: paragraph,
          command: command,
          facet: facet,
          remaining: remaining,
          bodyTail: _tail(body, 700),
        ),
        maxOutputTokens: 8192,
        preferPro: false,
      );
      if (!result.isSuccess || result.text == null) {
        consecutiveFails++;
        lastError = (result.error ?? 'empty response').trim();
        if (lastError.length > 140) {
          lastError = '${lastError.substring(0, 140)}…';
        }
        lastFillDiagnostic = lastError;
        onProgress?.call(
          arabic
              ? 'تعذّرت تكملة ${successPasses + 1}: $lastError'
              : 'Continuation ${successPasses + 1} failed: $lastError',
        );
        // Quota will never recover mid-loop — stop immediately.
        if (isQuotaLikeError(lastError)) {
          onProgress?.call(
            arabic
                ? 'توقفت التكملة: $lastError (عند ≈ $have كلمة من أصل $targetWords). ارفع الحد اليومي من لوحة الإدارة أو حاول غداً.'
                : 'Growth stopped: $lastError (at ≈ $have of $targetWords words). Raise the daily limit in admin or try tomorrow.',
          );
          lastFillDiagnostic = arabic
              ? 'خطأ الحصة: $lastError'
              : 'Quota error: $lastError';
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 600));
        continue;
      }
      var cleaned = await GroundedReferenceService.instance.enforceVerifiedDois(
        _stripInventedMarkers(
          result.text!,
          maxIndex: literature.works.length,
        ),
        known: literature,
      );
      cleaned = cleaned.trim();
      if (cleaned.length < 80) {
        consecutiveFails++;
        lastError = arabic ? 'رد قصير جداً' : 'response too short';
        continue;
      }
      final headingLine = ThesisStudioProse.sanitize(facet).trim();
      final skipHeading = headingLine.isEmpty ||
          ThesisStudioProse.isFallbackPartHeading(headingLine) ||
          body.contains(headingLine);
      body = skipHeading
          ? '$body\n\n$cleaned'
          : '$body\n\n$headingLine\n$cleaned';
      consecutiveFails = 0;
      lastError = null;
      successPasses++;
      onBodyUpdate?.call(body);
    }
    return body;
  }

  Future<List<String>> _headingsFromCommand({
    required ThesisPlan plan,
    required String command,
    required String heading,
    required int targetWords,
  }) async {
    final count = (targetWords / ThesisLengthBudget.wordsPerGrowPass)
        .ceil()
        .clamp(4, ThesisLengthBudget.maxGrowPasses)
        .toInt();
    final fallback = <String>[
      for (var i = 1; i <= count; i++)
        plan.arabic ? '$heading - $i' : '$heading - part $i',
    ];
    if (!GeminiAdvisorClient.isAvailable) return fallback;
    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: plan.arabic
          ? '''
قسّم أمر الباحث إلى عناوين فرعية تغطي الأمر داخل هدف الرسالة فقط. أي تخصص. لا تفترض موضوعاً غير مذكور في الهدف أو الأمر.
أعد JSON فقط: {"headings":["عنوان1","عنوان2"]}
$count عناوين بالعربية، كل عنوان 3-12 كلمة، مستخرج من الأمر والهدف لا من خيالك.
'''
          : '''
Split the user's command into subsection headings that cover THAT command inside the thesis goal only. Any academic field. Never invent a topic absent from the goal or command.
Return JSON only: {"headings":["h1","h2"]}
$count headings in the draft language, 3-12 words each, taken from the command and goal, not invented.
''',
      userMessage: '''
Draft language: ${plan.arabic ? 'Arabic' : 'English'}
Section: $heading
Thesis goal (parent frame):
${ResearchGoalParser.contextForAi(plan.goal.raw)}
User command (must stay inside the goal):
${command.trim().isEmpty ? heading : command.trim()}
''',
      maxOutputTokens: 1200,
      preferPro: true,
    );
    if (!result.isSuccess || result.text == null) return fallback;
    final map = _parseJsonMap(result.text!);
    final raw = map?['headings'];
    if (raw is! List) return fallback;
    final headings = <String>[];
    for (final item in raw) {
      final t = ThesisStudioProse.sanitize(item.toString()).trim();
      if (t.length >= 3) headings.add(t);
    }
    return headings.length >= 3 ? headings.take(count).toList() : fallback;
  }

  static String _tail(String text, int maxChars) {
    final t = text.trim();
    if (t.length <= maxChars) return t;
    return t.substring(t.length - maxChars);
  }

  Future<String> fillAbstract({
    required ThesisPlan plan,
    required GroundedReferenceBundle literature,
    required String command,
    AcademicProfile? profile,
  }) async {
    final local = _localAbstractSlot(plan, literature, command);
    if (!GeminiAdvisorClient.isAvailable) return local;
    final arabic = plan.arabic;
    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: arabic
          ? '''
أنت تكتب ملخص رسالة علمية بالعربية الفصحى المبسطة (180-250 كلمة).
لا تختلق DOI أو مؤلفاً أو نتيجة. لا تزعم أن البحث أُنجز.
استشهد فقط بـ [n] من القائمة إن وُجدت دراسات. هذه فقرة واحدة للمراجعة.
نص عادي بلا Markdown أو # أو * أو صيغ \$ .
التزم بهدف الرسالة؛ أمر الملخص عدسة على الهدف لا موضوعاً جديداً.
'''
          : '''
You write a thesis abstract in clear academic English (180-250 words).
Never invent a DOI, author, or result. Do not claim the research is finished.
Cite only [n] from the list if studies exist. This is one paragraph to review.
Plain prose only — no Markdown, #, *, or \$ math.
Stay strictly inside the thesis goal; the abstract command is only a lens on that goal.
''',
      userMessage: [
        _contextBlock(plan, literature, profile),
        GroundedReferenceService.instance.promptBlock(literature),
        arabic
            ? '\nهدف الرسالة الملزم:\n${ResearchGoalParser.contextForAi(plan.goal.raw)}\nأمر هذه الفقرة (داخل الهدف فقط): ${command.trim().isEmpty ? 'ملخص العمل حسب الهدف أعلاه' : command.trim()}'
            : '\nBinding thesis goal:\n${ResearchGoalParser.contextForAi(plan.goal.raw)}\nParagraph command (inside the goal only): ${command.trim().isEmpty ? 'Abstract for the goal above' : command.trim()}',
      ].join('\n'),
      maxOutputTokens: 2500,
      preferPro: true,
    );
    if (!result.isSuccess || result.text == null) return local;
    final cleaned = await GroundedReferenceService.instance.enforceVerifiedDois(
      _stripInventedMarkers(
        result.text!,
        maxIndex: literature.works.length,
      ),
      known: literature,
    );
    return cleaned.trim().length >= 80 ? cleaned.trim() : local;
  }

  Future<String> _growChapter({
    required ThesisPlan plan,
    required GroundedReferenceBundle literature,
    required ThesisChapterTemplate template,
    required List<ThesisChapter> priorChapters,
    AcademicProfile? profile,
    required String current,
    required int targetWords,
  }) async {
    if (template.depth == ThesisChapterDepth.scaffold) return current;
    var body = current;
    final arabic = plan.arabic;
    final sections = _subsections(template, arabic);
    for (var i = 0; i < sections.length; i++) {
      if (_wordCount(body) >= (targetWords * 0.72).round()) break;
      final remaining = (targetWords - _wordCount(body)).clamp(250, 1800);
      final result = await GeminiAdvisorClient.instance.generateResult(
        systemPrompt: _chapterSystem(arabic, template, plan, remaining),
        userMessage: [
          _chapterUser(
            plan: plan,
            literature: literature,
            template: template,
            priorChapters: priorChapters,
            profile: profile,
            targetWords: remaining,
          ),
          arabic
              ? '\nأكمل فقط المبحث: ${sections[i]}. لا تعد كتابة ما سبق. الهدف حوالي $remaining كلمة. الاستشهاد بـ [n] فقط.'
              : '\nContinue only this subsection: ${sections[i]}. Do not rewrite earlier text. Target about $remaining words. Cite [n] only.',
        ].join(),
        maxOutputTokens: 8192,
        preferPro: true,
      );
      if (!result.isSuccess || result.text == null) continue;
      final cleaned = await GroundedReferenceService.instance.enforceVerifiedDois(
        _stripInventedMarkers(
          result.text!,
          maxIndex: literature.works.length,
        ),
        known: literature,
      );
      if (cleaned.trim().length < 80) continue;
      if (_tooSimilar(cleaned, body)) continue;
      body = '$body\n\n${cleaned.trim()}';
    }
    return body;
  }

  static int _wordCount(String text) =>
      text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  static List<({String ar, String en})> subsectionPairs(
    ThesisChapterTemplate template,
  ) {
    switch (template.id) {
      case 'intro':
        return const [
          (ar: '1.1 السياق', en: '1.1 Context'),
          (ar: '1.2 مشكلة الدراسة', en: '1.2 Research problem'),
          (ar: '1.3 الأهداف', en: '1.3 Aims'),
          (ar: '1.4 الأسئلة', en: '1.4 Questions'),
          (ar: '1.5 الأهمية والحدود', en: '1.5 Significance and scope'),
        ];
      case 'literature':
        return const [
          (
            ar: '2.1 مدخل مراجعة الأدبيات ونطاقها',
            en: '2.1 Scope and approach of the review',
          ),
          (
            ar: '2.2 الإطار المفاهيمي / النظري من الدراسات',
            en: '2.2 Conceptual / theoretical threads in the literature',
          ),
          (
            ar: '2.3 المحاور الموضوعية: تركيب نقدي للدراسات',
            en: '2.3 Thematic synthesis of prior studies',
          ),
          (
            ar: '2.4 مقارنة المناهج والعينات والنتائج',
            en: '2.4 Comparison of methods, samples, and findings',
          ),
          (
            ar: '2.5 الفجوة البحثية وخلاصة الفصل',
            en: '2.5 Research gap and chapter synthesis',
          ),
        ];
      case 'experimental':
      case 'methods':
        return const [
          (ar: 'المواد', en: 'Materials'),
          (ar: 'الأجهزة والمعايرة', en: 'Instruments and calibration'),
          (ar: 'خطوات الإجراء', en: 'Procedure'),
          (ar: 'ضبط الجودة', en: 'Quality control'),
        ];
      case 'theory':
      case 'theme_a':
      case 'theme_b':
        return const [
          (ar: 'تطوير الحجة', en: 'Develop the argument'),
          (ar: 'حدود الشاهد', en: 'Limits of the evidence'),
        ];
      case 'results':
      case 'results_discussion':
        return const [
          (ar: 'إطار الجداول (فارغ)', en: 'Table frames (empty)'),
          (ar: 'ما ينتظر القياس', en: 'What awaits measurement'),
        ];
      case 'discussion':
        return const [
          (ar: 'مناقشة بانتظار النتائج', en: 'Discussion awaiting results'),
        ];
      default:
        return const [
          (ar: 'الحدود', en: 'Limits'),
          (ar: 'الخطوات التالية', en: 'Next steps'),
        ];
    }
  }

  static List<String> _subsections(ThesisChapterTemplate template, bool arabic) {
    return [
      for (final pair in subsectionPairs(template)) arabic ? pair.ar : pair.en,
    ];
  }

  static List<ThesisParagraph> emptyParagraphs(ThesisChapterTemplate template) {
    final pairs = subsectionPairs(template);
    return [
      for (var i = 0; i < pairs.length; i++)
        ThesisParagraph(
          id: '${template.id}_p$i',
          headingAr: pairs[i].ar,
          headingEn: pairs[i].en,
        ),
    ];
  }

  static ThesisDraft buildSkeletonDraft({
    required ThesisPlan plan,
  }) {
    final outline = ThesisStudioOutline.forPlan(plan);
    final field = _fieldLabel(plan.goal, arabic: plan.arabic);
    final degree = plan.goal.degreeLabelFor(plan.arabic);
    final title = plan.arabic
        ? (plan.kind == ThesisKind.literary
            ? '$degree في $field: قراءة تحليلية'
            : '$degree في $field: دراسة ${plan.kind == ThesisKind.experimental ? 'معملية' : 'ميدانية'}')
        : (plan.kind == ThesisKind.literary
            ? '$degree in $field: an analytical reading'
            : '$degree in $field: a ${plan.kind == ThesisKind.experimental ? 'laboratory' : 'field'} study');
    return ThesisDraft(
      goal: plan.goal,
      plan: plan,
      literature: GroundedReferenceBundle(topic: field),
      proposedTitle: title,
      abstractText: '',
      researchQuestions: const [],
      chapters: [
        for (final template in outline)
          ThesisChapter(
            id: template.id,
            titleAr: template.titleAr,
            titleEn: template.titleEn,
            purposeAr: template.purposeAr,
            purposeEn: template.purposeEn,
            depth: template.depth,
            paragraphs: emptyParagraphs(template),
          ),
      ],
      note: appTr(
        'الهيكل فارغ عمداً. الذكاء الاصطناعي يقرأ هدفك كاملاً للعنوان والأسئلة. كل فقرة تُولَّد وحدها مع مراجع ذلك الأمر، بما فيها الرسائل الجامعية ذات DOI.',
        'The outline is empty on purpose. AI reads your full goal for the title and questions. Each paragraph is generated with sources for that command, including DOI-confirmed dissertations.',
      ),
    );
  }

  Future<ThesisDraft> enrichSkeleton({
    required ThesisDraft draft,
    AcademicProfile? profile,
  }) async {
    if (!GeminiAdvisorClient.isAvailable) {
      return draft.copyWith(
        note: appTr(
          'سجّل الدخول حتى يقرأ Gemini 2.5 Pro هدفك كاملاً ويضع العنوان بلغة المسودة. بدون تسجيل يبقى العنوان قالباً محلياً.',
          'Sign in so Gemini 2.5 Pro can read your full goal and write the title in the draft language. Without sign-in the title stays a local template.',
        ),
      );
    }
    final arabic = draft.arabic;
    final lang = arabic ? 'Arabic' : 'English';
    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: arabic
          ? '''
أنت مستشار رسائل في AcadeGate. اقرأ هدف الباحث كاملاً (كل الجمل).
أعد JSON فقط:
{"title":"عنوان رسالة بالعربية يطابق التخصص والمشكلة والمنهج إن ذُكرا","questions":["سؤال1","سؤال2","سؤال3"],"field_ar":"موضوع قصير","field_en":"English topic 4-16 words"}
قواعد: العنوان بالعربية فقط. لا تختلق نتائج أو DOI. لا تترجم إلى الإنجليزية.
'''
          : '''
You are an AcadeGate thesis advisor. Read the student's FULL goal (every sentence).
Return JSON only:
{"title":"precise English thesis title naming field, problem, and method if given","questions":["q1","q2","q3"],"field_en":"4-16 word English topic","field_ar":"short Arabic topic"}
Rules: the title and questions MUST be in English only. Never answer in Arabic. Do not invent results or DOIs. Do not ignore later sentences.
''',
      userMessage: '''
Draft language (mandatory): $lang
Degree: ${draft.goal.degreeLabelFor(arabic)}
Thesis type: ${draft.plan.kindLabel}
Structure: ${draft.plan.shapeLabel}
${profile != null ? 'Researcher: ${profile.fullName} · ${profile.university} · ${profile.specialization}' : ''}
${draft.plan.discipline.promptBlock(arabic)}
User goal:
${ResearchGoalParser.contextForAi(draft.goal.raw)}
''',
      maxOutputTokens: 2000,
      preferPro: true,
    );
    if (!result.isSuccess || result.text == null) return draft;
    final map = _parseJsonMap(result.text!);
    if (map == null) return draft;
    final title = map['title']?.toString().trim() ?? '';
    final questions = <String>[];
    final rawQ = map['questions'];
    if (rawQ is List) {
      for (final item in rawQ) {
        final q = item.toString().trim();
        if (q.isNotEmpty) questions.add(q);
      }
    }
    final fieldEn = map['field_en']?.toString().trim() ?? '';
    final fieldAr = map['field_ar']?.toString().trim() ?? '';
    var goal = draft.goal;
    if (fieldEn.length >= 4 || fieldAr.length >= 3) {
      goal = goal.copyWith(
        field: fieldAr.length >= 3 ? fieldAr : goal.field,
        fieldEn: fieldEn.length >= 4 ? fieldEn : goal.fieldEn,
      );
    }
    final useAiTitle = title.length >= 8 && _titleMatchesDraftLanguage(title, arabic);
    return draft.copyWith(
      goal: goal,
      plan: draft.plan.copyWith(goal: goal),
      proposedTitle: useAiTitle ? title : draft.proposedTitle,
      researchQuestions: questions.isNotEmpty ? questions.take(5).toList() : draft.researchQuestions,
      fromGemini: true,
      modelUsed: result.modelUsed,
      note: appTr(
        'العنوان والأسئلة من ${result.modelUsed ?? 'Gemini'} بلغة المسودة ($lang). الفقرات ما زالت فارغة حتى تكتب أمر كل فقرة.',
        'Title and questions are from ${result.modelUsed ?? 'Gemini'} in the draft language ($lang). Paragraphs stay empty until you command each one.',
      ),
    );
  }

  static bool _titleMatchesDraftLanguage(String title, bool arabic) {
    final ar = RegExp(r'[\u0600-\u06FF]').allMatches(title).length;
    final en = RegExp(r'[A-Za-z]').allMatches(title).length;
    if (arabic) return ar >= en;
    return en > ar;
  }

  static ThesisDraft buildLocalDraft({
    required ResearchGoal goal,
    required GroundedReferenceBundle literature,
    List<ThesisChapterTemplate>? templates,
    AcademicProfile? profile,
    ThesisPlan? plan,
  }) {
    final guess = ThesisKindDetector.detect(raw: goal.raw, profile: profile);
    final resolved = plan ??
        ThesisPlan(
          goal: goal,
          kind: guess.kind,
          shape: guess.shape,
          arabic: guess.arabic,
        );
    final outline = templates ?? ThesisStudioOutline.forPlan(resolved);
    final field = _fieldLabel(goal);
    final methods = DegreePlanEngine.methodHint(goal);
    final questions = _localQuestions(resolved, methods);
    final map = ThesisLiteratureMapper.fromBundle(literature);
    return ThesisDraft(
      goal: goal,
      plan: resolved,
      literature: literature,
      literatureMap: map,
      proposedTitle: resolved.arabic
          ? (resolved.kind == ThesisKind.literary
              ? '${goal.degreeLabel} في $field: قراءة تحليلية'
              : '${goal.degreeLabel} في $field: دراسة ${resolved.kind == ThesisKind.experimental ? 'معملية' : 'ميدانية'}')
          : (resolved.kind == ThesisKind.literary
              ? '${goal.degreeLabel} in $field: an analytical reading'
              : '${goal.degreeLabel} in $field: a ${resolved.kind == ThesisKind.experimental ? 'laboratory' : 'field'} study'),
      abstractText: _localAbstract(resolved, literature, methods, profile),
      researchQuestions: questions,
      chapters: [
        for (final t in outline) _localChapter(resolved, literature, t, profile),
      ],
      fromGemini: false,
    );
  }

  Future<({String title, String abstractText, List<String> questions, String? modelUsed})>
      _frontMatter(
    ThesisPlan plan,
    GroundedReferenceBundle literature,
    AcademicProfile? profile,
  ) async {
    final arabic = plan.arabic;
    final kindHint = plan.kindLabel;
    final shapeHint = plan.shapeLabel;
    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: arabic
          ? '''
أنت مستشار رسائل علمية في AcadeGate. نوع الرسالة: $kindHint. الهيكل: $shapeHint.
أعد JSON فقط بلا Markdown:
{"title":"عنوان رسالة دقيق يذكر التخصص","abstract":"ملخص 180-250 كلمة","questions":["سؤال1","سؤال2","سؤال3"]}
قواعد: لا تختلق DOI أو مؤلفاً أو مجلة. لا تزعم أن البحث أُنجز أو أن النتائج وُجدت. الملخص مسودة عمل. إن كانت الدراسات قليلة صرّح بذلك. للأدبي: نبرة نقدية. للمعملي: لا أرقام نتائج.
'''
          : '''
You are an AcadeGate thesis advisor. Thesis type: $kindHint. Structure: $shapeHint.
Return JSON only, no markdown:
{"title":"precise thesis title naming the field","abstract":"180-250 word abstract","questions":["q1","q2","q3"]}
Rules: never invent a DOI, author, or journal. Do not claim the research is finished or that results exist. The abstract is a working draft. If few studies exist, say so. Literary: critical tone. Experimental: no result numbers.
''',
      userMessage: _contextBlock(plan, literature, profile),
      maxOutputTokens: 2500,
      preferPro: true,
    );
    if (!result.isSuccess || result.text == null) {
      return (title: '', abstractText: '', questions: const <String>[], modelUsed: null);
    }
    final map = _parseJsonMap(result.text!);
    if (map == null) {
      return (
        title: '',
        abstractText: result.text!.trim(),
        questions: const <String>[],
        modelUsed: result.modelUsed,
      );
    }
    final questions = <String>[];
    final rawQ = map['questions'];
    if (rawQ is List) {
      for (final item in rawQ) {
        final q = item.toString().trim();
        if (q.isNotEmpty) questions.add(q);
      }
    }
    return (
      title: map['title']?.toString().trim() ?? '',
      abstractText: map['abstract']?.toString().trim() ?? '',
      questions: questions.take(5).toList(),
      modelUsed: result.modelUsed,
    );
  }

  String _chapterSystem(
    bool arabic,
    ThesisChapterTemplate template,
    ThesisPlan plan,
    int targetWords,
  ) {
    final goal = plan.goal;
    final citeRule = arabic
        ? 'استشهد فقط بالأعمال المرقّمة في قائمة المراجع بصيغة [n]. ممنوع DOI أو مؤلف أو سنة غير موجودة في القائمة. إن لم تكفِ الدراسات اكتب فصلاً أقصر وصرّح بالفجوة. RAG: ابنِ الجملة على الملخص/العنوان المؤكد لا على التخمين.'
        : 'Cite only the numbered works as [n]. Never add a DOI, author, or year that is not on the list. If studies are few, write a shorter chapter and name the gap. RAG: ground every claim in the confirmed title/abstract, never in guesswork.';
    final depthRule = switch (template.depth) {
      ThesisChapterDepth.scaffold => arabic
          ? 'هذا الفصل هيكل فقط بعد جمع البيانات. ممنوع اختلاق أرقام أو إحصاء أو منحنيات حتى لو طُلبت $targetWords كلمة.'
          : 'This chapter is a frame only until data exist. Invent no numbers, statistics, or curves even if $targetWords words were requested.',
      ThesisChapterDepth.protocol => arabic
          ? 'اكتب بروتوكولاً إجرائياً مفصلاً (حوالي $targetWords كلمة): مواد، أجهزة، خطوات، ضبط جودة. ممنوع ادعاء أن التجربة أُنجزت وممنوع أي نتيجة.'
          : 'Write a detailed procedural protocol (about $targetWords words): materials, instruments, steps, quality control. Do not claim the experiment is done and include no results.',
      ThesisChapterDepth.full => arabic
          ? 'اكتب نثراً أكاديمياً متصلاً لا قائمة نقاط قصيرة: حوالي $targetWords كلمة، مع عناوين فرعية. طول المستند المستهدف ${plan.targetPages} صفحة.'
          : 'Write continuous academic prose, not a short bullet list: about $targetWords words with subsections. Document target ${plan.targetPages} pages.',
    };
    final kindRule = switch (plan.kind) {
      ThesisKind.literary => arabic
          ? 'رسالة أدبية/إنسانية: حجة وتحليل نصي أو تاريخي، لا منهج تجريبي قسري.'
          : 'Literary/humanities thesis: argument and textual or historical analysis, not a forced lab method.',
      ThesisKind.experimental => arabic
          ? 'رسالة معملية: مقدمة ودراسات سابقة غنية؛ الجزء العملي بروتوكول؛ النتائج تُترك فارغة.'
          : 'Lab thesis: rich introduction and literature; experimental section is a protocol; results stay empty.',
      ThesisKind.empirical => arabic
          ? 'رسالة ميدانية/إحصائية: وضّح الأداة والعينة المقترحة دون اختلاق استجابات.'
          : 'Empirical/statistical thesis: name the proposed instrument and sample, invent no responses.',
    };
    if (arabic) {
      return '''
أنت تكتب مسودة فصل رسالة علمية بالعربية الفصحى المبسطة.
الفصل: ${template.titleAr}
الغرض: ${template.purposeAr}
الهيكل: ${plan.shapeLabel}
$kindRule
${_chapterJob(template, true)}
$citeRule
$depthRule
لا تكتب قائمة مراجع في نهاية الفصل. لا تنسخ متن فصل آخر. لا تلتف على كاشفات الذكاء الاصطناعي. هذه مسودة للمراجعة لا نسخة تسليم ولا رسالة من 150 صفحة. اكتب هذا الفصل لغرضه فقط.
''';
    }
    return '''
You write a thesis-chapter draft in clear academic English.
Chapter: ${template.titleEn}
Purpose: ${template.purposeEn}
Structure: ${plan.shapeLabel}
$kindRule
${_chapterJob(template, false)}
$citeRule
$depthRule
Do not append a reference list. Do not copy another chapter's body. Do not evade AI detectors. This is a draft to verify, not a 150-page submission. Write this chapter for its own purpose only.
Methods hint if relevant: ${DegreePlanEngine.methodHint(goal)}.
''';
  }

  String _chapterUser({
    required ThesisPlan plan,
    required GroundedReferenceBundle literature,
    required ThesisChapterTemplate template,
    required List<ThesisChapter> priorChapters,
    AcademicProfile? profile,
    int targetWords = 800,
  }) {
    final buffer = StringBuffer(_contextBlock(plan, literature, profile));
    buffer.writeln();
    buffer.writeln(
      GroundedReferenceService.instance.promptBlock(literature),
    );
    if (template.id == 'literature') {
      buffer.writeln();
      buffer.writeln(
        ThesisLiteratureMapper.comparisonTable(
          ThesisLiteratureMapper.fromBundle(literature),
          arabic: plan.arabic,
        ),
      );
    }
    if (priorChapters.isNotEmpty) {
      buffer.writeln(
        plan.arabic
            ? '\nفصول سابقة (عناوين فقط — لا تنسخ متنها):'
            : '\nEarlier chapters (titles only — do not copy their body):',
      );
      for (final ch in priorChapters) {
        buffer.writeln('- ${ch.title(plan.arabic)} [${ch.id}]');
      }
    }
    buffer.writeln(
      plan.arabic
          ? '\nاكتب الآن متن: ${template.titleAr} (حوالي $targetWords كلمة)\n${_chapterJob(template, true)}'
          : '\nNow write the body of: ${template.titleEn} (about $targetWords words)\n${_chapterJob(template, false)}',
    );
    return buffer.toString();
  }

  String _paragraphSystem(
    bool arabic,
    ThesisChapterTemplate template,
    ThesisPlan plan,
    int targetWords,
  ) {
    final citeRule = arabic
        ? 'استشهد فقط بالأعمال المرقّمة في القائمة بصيغة [n]. ممنوع اختلاق مؤلف أو سنة أو DOI. بعد الكتابة يُحوَّل [n] إلى أسلوب التوثيق المختار (APA = مؤلف، سنة؛ IEEE = [n]).'
        : 'Cite only numbered works as [n]. Never invent an author, year, or DOI. After writing, [n] is converted to the selected style (APA = Author, Year; IEEE = [n]).';
    final plainRule = arabic
        ? 'نص عادي فقط. ممنوع Markdown أو رموز # و * و ** و ### وعلامات \$ للرياضيات. الأسماء العلمية بدون نجوم. العناوين الفرعية سطر مستقل بلا #.'
        : 'Plain prose only. No Markdown, no # * ** ###, and no \$ math. Scientific names without asterisks. Subheadings are a plain line without #.';
    final depthRule = switch (template.depth) {
      ThesisChapterDepth.scaffold => arabic
          ? 'هيكل فقط: جداول فارغة بانتظار البيانات. ممنوع أرقام ملفّقة حتى لو طُلب طول كبير.'
          : 'Frame only: empty tables awaiting data. Invent no numbers even if a long text was requested.',
      ThesisChapterDepth.protocol => arabic
          ? 'فقرة إجرائية بلا ادعاء أن التجربة أُنجزت وبلا نتائج. طول الهدف حوالي $targetWords كلمة.'
          : 'A procedural section. Do not claim the experiment is done and include no results. Target about $targetWords words.',
      ThesisChapterDepth.full => arabic
          ? 'نفّذ أمر المستخدم حرفياً من حيث الموضوع والطول داخل هدف الرسالة فقط. نثر أكاديمي بعناوين فرعية، حوالي $targetWords كلمة في هذه الدفعة. لا تختصر إلى فقرة واحدة إن طُلبت صفحات.'
          : 'Carry out the user command for topic AND length, strictly inside the thesis goal. Continuous academic prose with subheadings, about $targetWords words in this pass. Do not shrink a multi-page request into one short paragraph.',
    };
    final goalRule = arabic
        ? 'هدف الرسالة في أعلى الشاشة هو الإطار الأب. أمر الفقرة تفصيل داخل هذا الهدف فقط. ممنوع الخروج إلى موضوع أو محصول أو منهج أو تخصص غير مذكور في الهدف حتى لو ورد في الأمر بشكل عام أو فضفاض. إن تعارض الأمر مع الهدف، التزم بالهدف وأعد تفسير الأمر كمبحث منه.'
        : 'The thesis goal at the top of the screen is the parent frame. The paragraph command is only a sub-task inside that goal. Never drift to a topic, crop, method, or field not present in the goal, even if the command is vague. If the command conflicts with the goal, stay with the goal and reinterpret the command as a subsection of it.';
    if (arabic) {
      return '''
أنت تكتب قسماً من رسالة علمية بالعربية الفصحى المبسطة حسب أمر المستخدم (قد يكون عدة صفحات على دفعات).
نوع الرسالة: ${plan.kindLabel}. الفصل: ${template.titleAr}
$citeRule
$plainRule
$goalRule
$depthRule
${plan.discipline.promptBlock(true)}
${_chapterJob(template, true)}
لا تكتب قائمة مراجع. لا تنسخ فقرات أخرى. لا تلتف على كاشفات الذكاء الاصطناعي.
''';
    }
    return '''
You write a thesis section in clear academic English, following the user command (this may be several pages across passes).
Thesis type: ${plan.kindLabel}. Chapter: ${template.titleEn}
$citeRule
$plainRule
$goalRule
$depthRule
${plan.discipline.promptBlock(false)}
${_chapterJob(template, false)}
Do not append a reference list. Do not copy other paragraphs. Do not evade AI detectors.
''';
  }

  String _paragraphUser({
    required ThesisPlan plan,
    required GroundedReferenceBundle literature,
    required ThesisChapterTemplate template,
    required ThesisParagraph paragraph,
    required String command,
    required List<ThesisParagraph> siblingParagraphs,
    AcademicProfile? profile,
    int targetWords = 320,
  }) {
    final buffer = StringBuffer(_contextBlock(plan, literature, profile));
    buffer.writeln();
    buffer.writeln(GroundedReferenceService.instance.promptBlock(literature));
    if (template.id == 'literature') {
      buffer.writeln();
      buffer.writeln(
        ThesisLiteratureMapper.comparisonTable(
          ThesisLiteratureMapper.fromBundle(literature),
          arabic: plan.arabic,
        ),
      );
      buffer.writeln(_literatureSlotBrief(paragraph, plan.arabic));
    }
    final preferred = _preferredIndexes(literature, paragraph.references);
    if (preferred.isNotEmpty) {
      buffer.writeln(
        plan.arabic
            ? '\nالمراجع المفضّلة لهذه الفقرة: ${preferred.map((n) => '[$n]').join(' ')}'
            : '\nPreferred sources for this paragraph: ${preferred.map((n) => '[$n]').join(' ')}',
      );
    }
    final siblings = siblingParagraphs
        .where((p) => p.id != paragraph.id && p.body.trim().isNotEmpty)
        .toList();
    if (siblings.isNotEmpty) {
      buffer.writeln(
        plan.arabic
            ? '\nفقرات أُنجزت في هذا الفصل (لا تكررها):'
            : '\nParagraphs already written in this chapter (do not repeat):',
      );
      for (final sibling in siblings) {
        final cut = sibling.body.trim();
        buffer.writeln(
          '- ${sibling.heading(plan.arabic)}: ${cut.length > 180 ? '${cut.substring(0, 180)}…' : cut}',
        );
      }
    }
    final order = command.trim().isEmpty
        ? paragraph.heading(plan.arabic)
        : command.trim();
    final goalText = ResearchGoalParser.contextForAi(plan.goal.raw);
    buffer.writeln(
      plan.arabic
          ? '\n── هدف الرسالة (إطار ملزم لكل الفقرات) ──\n$goalText'
          : '\n── Thesis goal (binding frame for every paragraph) ──\n$goalText',
    );
    buffer.writeln(
      plan.arabic
          ? '\n── أمر هذه الفقرة (مبحث داخل الهدف أعلاه فقط) ──\n'
              'العنوان: «${paragraph.heading(true)}»\n'
              'الأمر: $order\n'
              'الفصل: ${template.titleAr}\n'
              'هدف هذه الدفعة حوالي $targetWords كلمة'
              '${template.id == 'literature' ? ' (مراجعة أدبيات رسالة: تركيب نقدي متعدد الفقرات، لا ملخص قصير)' : ''}. '
              'اربط كل جملة بالهدف الأب. ممنوع موضوع خارج الهدف حتى لو وسّع الأمر.'
          : '\n── Paragraph command (sub-task inside the thesis goal only) ──\n'
              'Heading: «${paragraph.heading(false)}»\n'
              'Command: $order\n'
              'Chapter: ${template.titleEn}\n'
              'This pass: about $targetWords words'
              '${template.id == 'literature' ? ' (thesis literature review: critical multi-paragraph synthesis, not a short survey)' : ''}. '
              'Tie every sentence to the parent goal. Do not leave the goal even if the command is broad.',
    );
    return buffer.toString();
  }

  /// Compact grow prompt — large full-context prompts often yield empty/short replies.
  String _growUserMessage({
    required ThesisPlan plan,
    required GroundedReferenceBundle literature,
    required ThesisChapterTemplate template,
    required ThesisParagraph paragraph,
    required String command,
    required String facet,
    required int remaining,
    required String bodyTail,
  }) {
    final arabic = plan.arabic;
    final buffer = StringBuffer();
    final goalText = ResearchGoalParser.contextForAi(plan.goal.raw, maxChars: 500);
    buffer.writeln(
      arabic
          ? 'هدف الرسالة: $goalText'
          : 'Thesis goal: $goalText',
    );
    buffer.writeln(
      arabic
          ? 'الفصل: ${template.titleAr} · الفقرة: ${paragraph.heading(true)}'
          : 'Chapter: ${template.titleEn} · section: ${paragraph.heading(false)}',
    );
    buffer.writeln(
      arabic ? 'أمر الفقرة: ${command.trim()}' : 'Command: ${command.trim()}',
    );
    buffer.writeln(
      arabic
          ? 'محور هذه الدفعة فقط: $facet'
          : 'This pass facet only: $facet',
    );
    buffer.writeln(
      arabic
          ? 'اكتب ≈ $remaining كلمة نثر أكاديمي متصل بعناوين فرعية قصيرة. ممنوع إعادة صياغة الذيل. استشهد بـ [n] فقط.'
          : 'Write ≈ $remaining words of continuous academic prose with short subheadings. Do not rewrite the tail. Cite [n] only.',
    );
    buffer.writeln();
    if (literature.works.isEmpty) {
      buffer.writeln(
        arabic
            ? 'لا مراجع مرقّمة — اكتب بدون استشهادات ملفّقة.'
            : 'No numbered sources — write without invented citations.',
      );
    } else {
      buffer.writeln(
        arabic ? 'مراجع مسموحة (عنوان فقط):' : 'Allowed sources (titles only):',
      );
      final n = literature.works.length.clamp(0, 18);
      for (var i = 0; i < n; i++) {
        final w = literature.works[i];
        final year = w.year == null ? '' : ' (${w.year})';
        buffer.writeln('${i + 1}. ${w.title}$year');
      }
    }
    buffer.writeln();
    buffer.writeln(
      arabic
          ? 'ذيل النص السابق (سياق فقط — لا تكرره):\n$bodyTail'
          : 'Previous tail (context only — do not repeat):\n$bodyTail',
    );
    return buffer.toString();
  }

  static String _literatureSlotBrief(ThesisParagraph paragraph, bool arabic) {
    final id = paragraph.id;
    if (arabic) {
      if (id.endsWith('_p0')) {
        return 'مهمة هذا المبحث: مدخل يوضح نطاق المراجعة ومعايير الإدراج من قائمة [n] فقط، وكيف ستُرتَّب المحاور. بلا سرد لكل دراسة هنا.';
      }
      if (id.endsWith('_p1')) {
        return 'مهمة هذا المبحث: استخرج من الدراسات المرقّمة الخيوط المفاهيمية/النظرية ذات الصلة بالهدف، مع استشهاد [n].';
      }
      if (id.endsWith('_p2')) {
        return 'مهمة هذا المبحث: تركيب موضوعي نقدي — اجمع الدراسات في محاور، وقارن بينها داخل كل محور. ممنوع قائمة «دراسة ثم دراسة» بلا ربط.';
      }
      if (id.endsWith('_p3')) {
        return 'مهمة هذا المبحث: مقارنة منهجية صريحة (تصميم، عينة، أدوات، نتائج رئيسة) بين الدراسات المرقّمة، مع إبراز القيود الظاهرة في الملخصات.';
      }
      return 'مهمة هذا المبحث: صِغ الفجوة البحثية صراحةً واربطها بهدف الرسالة، ثم لخّص ما أثبته الفصل وما يبقى مفتوحاً.';
    }
    if (id.endsWith('_p0')) {
      return 'Slot job: state the review scope and inclusion logic from the numbered list only, and preview the thematic organization. Do not dump every study here.';
    }
    if (id.endsWith('_p1')) {
      return 'Slot job: draw conceptual/theoretical threads from the numbered studies that serve the thesis goal; cite [n].';
    }
    if (id.endsWith('_p2')) {
      return 'Slot job: thematic critical synthesis — cluster studies into themes and compare within each theme. No unlinked study-by-study list.';
    }
    if (id.endsWith('_p3')) {
      return 'Slot job: explicit methodological comparison (design, sample, tools, main findings) across numbered studies; note limits visible in abstracts.';
    }
    return 'Slot job: state the research gap explicitly, tie it to the thesis goal, and close with what this chapter established and what remains open.';
  }

  static List<int> _preferredIndexes(
    GroundedReferenceBundle literature,
    List<GroundedWork> preferred,
  ) {
    final indexes = <int>[];
    for (final work in preferred) {
      final i = literature.works.indexWhere(
        (item) => item.doi.toLowerCase() == work.doi.toLowerCase(),
      );
      if (i >= 0) indexes.add(i + 1);
    }
    return indexes;
  }

  String _localParagraph({
    required ThesisPlan plan,
    required GroundedReferenceBundle literature,
    required ThesisChapterTemplate template,
    required ThesisParagraph paragraph,
    required String command,
  }) {
    final arabic = plan.arabic;
    if (template.depth == ThesisChapterDepth.scaffold) {
      return arabic
          ? '${paragraph.headingAr}\nجدول بانتظار البيانات (متغير | وحدة | ملاحظة). لا أرقام ملفّقة.'
          : '${paragraph.headingEn}\nTable awaiting data (variable | unit | note). No invented numbers.';
    }
    if (literature.works.isEmpty) {
      return arabic
          ? 'فقرة فارغة: لا توجد دراسات DOI مؤكدة لهذا الأمر بعد. استخدم أداة جلب المراجع أسفل الفقرة ثم ولّدها.'
          : 'Empty paragraph: no DOI-confirmed studies for this command yet. Use the literature tool under the paragraph, then generate it.';
    }
    final focus = paragraph.references.isNotEmpty
        ? paragraph.references
        : literature.works;
    final take = focus.take(4).toList();
    final lines = <String>[];
    if (command.trim().isNotEmpty) {
      lines.add(
        arabic
            ? 'هذه الفقرة تجيب عن الأمر: ${command.trim()}.'
            : 'This paragraph addresses the command: ${command.trim()}.',
      );
    }
    for (final work in take) {
      final n = literature.works.indexWhere(
            (item) => item.doi.toLowerCase() == work.doi.toLowerCase(),
          ) +
          1;
      if (n <= 0) continue;
      lines.add(
        arabic
            ? 'تشير الدراسة [$n] (${work.title}) إلى محور مرتبط بهذا المبحث.'
            : 'Study [$n] (${work.title}) addresses a theme related to this subsection.',
      );
    }
    return lines.join(' ');
  }

  String _localAbstractSlot(
    ThesisPlan plan,
    GroundedReferenceBundle literature,
    String command,
  ) {
    final arabic = plan.arabic;
    if (literature.works.isEmpty) {
      return arabic
          ? 'ملخص فارغ حتى تُجلب مراجع مؤكدة لأمر هذه الفقرة.'
          : 'Empty abstract until DOI-confirmed studies are fetched for this paragraph command.';
    }
    final n = literature.works.length;
    final cue = command.trim().isEmpty
        ? (arabic ? plan.goal.field : plan.goal.fieldEn)
        : command.trim();
    return arabic
        ? 'مسودة ملخص حول «$cue» استناداً إلى $n دراسة مؤكدة بـ DOI. تُراجع مع المشرف؛ لا نتائج ملفّقة.'
        : 'Working abstract on “$cue” from $n DOI-confirmed studies. Review with your supervisor; no fabricated results.';
  }

  bool _acceptableParagraph(
    String text,
    ThesisChapterTemplate template,
    List<ThesisParagraph> siblings, {
    required ThesisParagraph current,
  }) {
    final body = text.trim();
    if (body.isEmpty) return false;
    if (RegExp(r'^n the\b', caseSensitive: false).hasMatch(body)) return false;
    final words = body.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final floor = switch (template.depth) {
      ThesisChapterDepth.full => 70,
      ThesisChapterDepth.protocol => 40,
      ThesisChapterDepth.scaffold => 12,
    };
    if (words < floor) return false;
    for (final sibling in siblings) {
      if (sibling.id == current.id) continue;
      if (_tooSimilar(body, sibling.body)) return false;
    }
    return true;
  }

  String _contextBlock(
    ThesisPlan plan,
    GroundedReferenceBundle literature,
    AcademicProfile? profile,
  ) {
    final goal = plan.goal;
    final methods = DegreePlanEngine.methodHint(goal);
    final buffer = StringBuffer();
    final topic = ThesisStudioOutline.displayTopic(
      goal.fieldEn.isNotEmpty ? goal.fieldEn : goal.field,
      fallback: goal.raw,
    );
    buffer.writeln(_topicStatement(goal, plan.arabic));
    if (plan.arabic) {
      buffer.writeln('الدرجة: ${goal.degreeLabel} · الموضوع: $topic');
      buffer.writeln('نوع الرسالة: ${plan.kindLabel}');
      buffer.writeln('الهيكل: ${plan.shapeLabel}');
      buffer.writeln('لغة المسودة: العربية');
      buffer.writeln('المنهج/الأدوات: $methods');
      buffer.writeln('المستفيد: ${goal.institutionLabel}');
      if (plan.discipline.isPresent) {
        buffer.writeln(plan.discipline.promptBlock(true));
      }
    } else {
      buffer.writeln('Degree: ${goal.degreeLabel} · topic: $topic');
      buffer.writeln('Thesis type: ${plan.kindLabel}');
      buffer.writeln('Structure: ${plan.shapeLabel}');
      buffer.writeln('Draft language: English');
      buffer.writeln('Methods/tools: $methods');
      buffer.writeln('Beneficiary: ${goal.institutionLabel}');
      if (plan.discipline.isPresent) {
        buffer.writeln(plan.discipline.promptBlock(false));
      }
    }
    if (profile != null) {
      buffer.writeln(
        plan.arabic
            ? 'الباحث: ${profile.fullName} · ${profile.university} · ${profile.specialization}'
            : 'Researcher: ${profile.fullName} · ${profile.university} · ${profile.specialization}',
      );
    }
    buffer.writeln(
      plan.arabic
          ? 'عدد الدراسات المؤكدة: ${literature.works.length}'
          : 'Confirmed studies: ${literature.works.length}',
    );
    return buffer.toString();
  }

  String _chapterJob(ThesisChapterTemplate template, bool arabic) {
    switch (template.id) {
      case 'intro':
        return arabic
            ? 'مهمة هذا الفصل حصرياً: المقدمة (سياق، مشكلة، أهداف، أسئلة، أهمية، حدود). ممنوع نسخ مراجعة الأدبيات أو بروتوكول التجربة أو النتائج.'
            : 'Exclusive job: Introduction (context, problem, aims, questions, significance, scope). Do not copy the literature review, experimental protocol, or results.';
      case 'literature':
        return arabic
            ? '''
مهمة هذا الفصل حصرياً: مراجعة أدبيات رسالة جامعية (حجماً ومضموناً)، وليست قائمة ملخصات قصيرة.
الشكل المطلوب كما في الرسائل العلمية/الأدبية:
(1) مدخل يوضح نطاق المراجعة وكيف تُرتَّب الدراسات.
(2) تنظيم موضوعي (محاور) لا سرد دراسةً بعد دراسة بلا ربط.
(3) تركيب نقدي: قارن الأهداف والمنهج والعينة والنتائج بين الدراسات المرقّمة [n] فقط.
(4) أبرز الاتفاق والاختلاف والقيود مما يظهر في العناوين/الملخصات المؤكدة — ممنوع اختلاق تفاصيل غير موجودة في القائمة.
(5) اختم بفجوة بحثية واضحة تربط هدف الرسالة.
ممنوع إعادة كتابة المقدمة أو وصف تجربتك أو اختلاق DOI/مؤلف/سنة/إحصاء.
'''
            : '''
Exclusive job: a thesis-length literature review in substance and size — not a short annotated list.
Required shape (as in scientific and literary theses):
(1) Open with the review's scope and how studies are organized.
(2) Organize thematically (themes), not as an unlinked study-by-study dump.
(3) Critically synthesize: compare aims, methods, samples, and findings across numbered studies [n] only.
(4) State agreements, disagreements, and limits visible from confirmed titles/abstracts — invent no missing details.
(5) End with an explicit research gap tied to the thesis goal.
Do not rewrite the introduction, describe your experiment, or invent DOI/author/year/statistics.
''';
      case 'experimental':
      case 'methods':
        return arabic
            ? 'مهمة هذا الفصل حصرياً: بروتوكول مواد/أجهزة/خطوات/ضبط جودة. ممنوع النتائج وممنوع إعادة المقدمة.'
            : 'Exclusive job: protocol of materials, instruments, steps, and quality control. No results. Do not rewrite the introduction.';
      case 'results':
        return arabic
            ? 'مهمة هذا الفصل حصرياً: هيكل جداول فارغة بانتظار البيانات. ممنوع أرقام ملفّقة وممنوع نسخ فصول أخرى.'
            : 'Exclusive job: empty table frames awaiting data. Invent no numbers. Do not copy other chapters.';
      case 'results_discussion':
        return arabic
            ? 'مهمة هذا الفصل حصرياً: هيكل نتائج ومناقشة فارغ بانتظار القياسات. ممنوع اختلاق أرقام أو نسخ الأدبيات.'
            : 'Exclusive job: empty results-and-discussion frame awaiting measurements. Invent no numbers. Do not copy the literature chapter.';
      case 'discussion':
        return arabic
            ? 'مهمة هذا الفصل حصرياً: هيكل مناقشة يُملأ بعد النتائج الحقيقية مقابل الدراسات المؤكدة فقط.'
            : 'Exclusive job: discussion frame to be filled after real results, against confirmed studies only.';
      case 'theory':
        return arabic
            ? 'مهمة هذا الفصل حصرياً: الإطار النظري للمفاهيم. ليس مقدمة عامة ولا نتائج.'
            : 'Exclusive job: theoretical frame for concepts. Not a general introduction and not results.';
      case 'theme_a':
      case 'theme_b':
        return arabic
            ? 'مهمة هذا الفصل حصرياً: مبحث تحليلي مستقل بحجة مختلفة عن الفصول الأخرى.'
            : 'Exclusive job: an independent analytical chapter with an argument distinct from other chapters.';
      default:
        return arabic
            ? 'مهمة هذا الفصل حصرياً: خاتمة وحدود وخطوات تالية — بلا نتائج ملفّقة.'
            : 'Exclusive job: conclusion, limits, and next steps — no fabricated findings.';
    }
  }

  String _topicStatement(ResearchGoal goal, bool arabic) {
    final raw = ResearchGoalParser.contextForAi(goal.raw);
    final paste = ResearchGoalParser.looksLikePastedManuscript(goal.raw);
    if (arabic) {
      return paste
          ? 'موضوع مستخرج من نص طويل ألصقه المستخدم (اقرأ كل الجمل ولا تنسخ النص): $raw'
          : 'هدف العمل كاملاً (قد يكون عدة جمل؛ لا تنسخ حرفياً): $raw';
    }
    return paste
        ? 'Topic extracted from a long paste (read every sentence; do not copy the paste): $raw'
        : 'Full working goal (may be several sentences; do not copy verbatim): $raw';
  }

  bool _acceptableChapter(
    String text,
    ThesisChapterTemplate template,
    List<ThesisChapter> prior, {
    int? targetWords,
  }) {
    final body = text.trim();
    if (body.isEmpty) return false;
    if (RegExp(r'^n the\b', caseSensitive: false).hasMatch(body)) return false;
    final words =
        body.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final floor = switch (template.depth) {
      ThesisChapterDepth.full => 280,
      ThesisChapterDepth.protocol => 160,
      ThesisChapterDepth.scaffold => 40,
    };
    final minWords = targetWords == null
        ? floor
        : (targetWords * 0.28).round().clamp(floor, 900);
    if (words < minWords) return false;
    final bulletLines = body.split('\n').where((line) {
      final t = line.trim();
      return t.startsWith('•') ||
          t.startsWith('- ') ||
          t.startsWith('* ') ||
          RegExp(r'^\d+(\.\d+)*[.)]\s').hasMatch(t);
    }).length;
    if (template.depth == ThesisChapterDepth.full &&
        bulletLines >= 6 &&
        words < 500) {
      return false;
    }
    for (final chapter in prior) {
      if (_tooSimilar(body, chapter.body)) return false;
    }
    return true;
  }

  static bool _tooSimilar(String a, String b, {double threshold = 0.52}) {
    final sa = _tokenSet(a);
    final sb = _tokenSet(b);
    if (sa.isEmpty || sb.isEmpty) return false;
    final inter = sa.intersection(sb).length;
    final union = sa.union(sb).length;
    if (union == 0) return false;
    return inter / union >= threshold;
  }

  static Set<String> _tokenSet(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[^a-zA-Z\u0600-\u06FF0-9]+'))
        .where((t) => t.length >= 4)
        .toSet();
  }

  static ThesisChapter _localChapter(
    ThesisPlan plan,
    GroundedReferenceBundle literature,
    ThesisChapterTemplate template,
    AcademicProfile? profile,
  ) {
    return ThesisChapter(
      id: template.id,
      titleAr: template.titleAr,
      titleEn: template.titleEn,
      purposeAr: template.purposeAr,
      purposeEn: template.purposeEn,
      body: _localBody(plan, literature, template, profile),
      depth: template.depth,
    );
  }

  static String _localBody(
    ThesisPlan plan,
    GroundedReferenceBundle literature,
    ThesisChapterTemplate template,
    AcademicProfile? profile,
  ) {
    switch (template.id) {
      case 'intro':
        return _localIntro(plan, literature);
      case 'theory':
        return _localTheory(plan, literature);
      case 'literature':
        return _literatureBody(plan, literature);
      case 'theme_a':
      case 'theme_b':
        return _localTheme(plan, literature, template.id);
      case 'methods':
      case 'experimental':
        return _localExperimental(plan, literature, template, profile);
      case 'results':
      case 'results_discussion':
        return _localResultsFrame(plan, literature, template);
      case 'discussion':
        return _localDiscussionFrame(plan, literature);
      default:
        return _localConclusion(plan, literature);
    }
  }

  static String _localIntro(
    ThesisPlan plan,
    GroundedReferenceBundle literature,
  ) {
    final field = _fieldLabel(plan.goal);
    final methods = DegreePlanEngine.methodHint(plan.goal);
    final cites = _citationHints(literature);
    final questions = _localQuestions(plan, methods).map((q) => '• $q').join('\n');
    final sourceLine = cites.isEmpty
        ? (plan.arabic
            ? 'لم تُؤكَّد دراسات DOI بعد؛ يبقى الإطار قصيراً حتى تُراجع المصادر، ولا تُختلق مراجع.'
            : 'No DOI-confirmed studies yet; the frame stays short until sources are reviewed, and none are invented.')
        : (plan.arabic
            ? 'تُبنى الأسئلة على الدراسات المؤكدة $cites دون تلخيص نتائج غير موجودة.'
            : 'Questions rest on confirmed studies $cites without summarising findings that do not exist.');
    if (plan.kind == ThesisKind.literary) {
      if (plan.arabic) {
        return '''
هذا الفصل هو مقدمة الرسالة في $field، وليس مراجعة أدبيات ولا تحليلاً نصياً مكتملًا.

1.1 السياق
تُقرأ $field بوصفها إشكالية قرائية/تحليلية لا تجربة معملية. يحدد الفصل المدونة، والمنهج (نقدي أو تحليلي أو تاريخي أو مقارن)، وحدود ما يمكن ادّعاؤه قبل قراءة الأصول.

1.2 المشكلة
المشكلة هي فجوة في الدراسات المؤكدة حول $field داخل السياق المحدد، لا نقص في «نتائج معملية».

1.3 الأهداف
صياغة سؤال بحث قابل للنقاش، وربط الحجة بالمصادر المؤكدة فقط، وتأجيل الشواهد غير المقروءة.

1.4 الأسئلة
$questions

1.5 الأهمية والحدود
الأهمية معرفية/نقدية. الحدود: لا شواهد مخترعة ولا أرشيف غير مُراجع.

1.6 ما لا يدخل هنا
مراجعة الدراسات نقطة بنقطة تُترك لفصل الأدبيات. التحليل التفصيلي للمباحث اللاحقة.

$sourceLine
''';
      }
      return '''
This chapter is the introduction to a thesis on $field. It is not a literature review and not a finished textual analysis.

1.1 Context
The work treats $field as a reading/analytical problem, not a laboratory experiment. It names the corpus, the method (critical, analytic, historical, or comparative), and the limit of what can be claimed before the sources are read.

1.2 Problem
The problem is a gap in the confirmed scholarship on $field in the chosen setting, not a missing set of lab results.

1.3 Aims
State a discussable research question, keep claims inside DOI-confirmed sources, and postpone unread evidence.

1.4 Questions
$questions

1.5 Significance and scope
Significance is critical/intellectual. Scope excludes invented quotations and unreviewed archives.

1.6 What this chapter excludes
Study-by-study review belongs in the literature chapter. Close analysis belongs in later thematic chapters.

$sourceLine
''';
    }
    if (plan.arabic) {
      return '''
هذا الفصل هو مقدمة رسالة ${plan.goal.degreeLabel} في $field وفق الهيكل المختار (${plan.shapeLabel}). ليس مراجعة أدبيات، وليس بروتوكول تجربة، وليس نتائج.

1.1 السياق
يقع موضوع $field عند تقاطع القياس والجودة في السياق المستهدف (${plan.goal.institutionLabel}). الدراسات المؤكدة ترسم الخريطة الخارجية فقط.

1.2 مشكلة الدراسة
المشكلة عملية: غياب بروتوكول محدد بضوابط جودة لـ $field في هذا السياق. المسودة تعامل الفجوة كمسألة تصميم لا كنتيجة.

1.3 الأهداف
(1) صياغة هدف قابل للقياس لـ $field.
(2) ربط الهدف بأدوات $methods بوصفها مقترحة لا منفَّذة.
(3) إبقاء الادعاءات داخل الأدبيات ذات DOI المؤكد.

1.4 الأسئلة / الفروض المقترحة
$questions

1.5 الأهمية والحدود والتعريفات
الأهمية تطبيقية/أكاديمية بعد تجربة حقيقية. الحدود: لا أحجام عينات ولا أرقام. التعريفات الإجرائية تُثبَّت مع المشرف قبل التشغيل.

1.6 ما يُستبعد من هذا الفصل
ممنوع بروتوكول المواد والأجهزة (فصل عملي مستقل) وممنوع جداول النتائج وممنوع نسخ فقرات من نص طويل ألصقه المستخدم.

$sourceLine
''';
    }
    return '''
This chapter is the introduction to a ${plan.goal.degreeLabel} thesis on $field, following the selected spine (${plan.shapeLabel}). It is not a literature review, not an experimental protocol, and not a results chapter.

1.1 Context
Work on $field sits at the meeting point of measurement and quality in the intended setting (${plan.goal.institutionLabel}). Confirmed studies map the outer field only.

1.2 Research problem
The practical problem is the absence of a locally specified, quality-controlled protocol for $field. This draft treats the gap as a design problem, not as a finding.

1.3 Aims
(1) State a measurable aim for $field.
(2) Align that aim with $methods as proposed tools, not completed runs.
(3) Keep every claim inside the DOI-confirmed bibliography.

1.4 Questions / working hypotheses
$questions

1.5 Significance, scope, and definitions
Significance is industrial/academic utility after a real experiment. Scope invents neither sample sizes nor numbers. Operational definitions are fixed with the supervisor before any run.

1.6 What this chapter excludes
Materials and instrument sequences belong in Experimental. Tables belong in Results. Long pasted manuscript text must not be copied here.

$sourceLine
''';
  }

  static String _localTheory(
    ThesisPlan plan,
    GroundedReferenceBundle literature,
  ) {
    final field = _fieldLabel(plan.goal);
    final cites = _citationHints(literature);
    if (plan.arabic) {
      return '''
هذا الفصل إطار نظري لـ $field فقط، وليس مقدمة عامة ولا نتائج.

يُختار من المفاهيم ما يفسّر الإشكالية (حدود المصطلح، المقاربة، وحدة التحليل).
${cites.isEmpty ? 'بسبب قلة المصادر المؤكدة يُؤجَّل التوسيع ولا تُختلق نظريات.' : 'الانطلاق من $cites لصياغة المفاهيم بعد قراءة النص الكامل.'}

ما يُستبعد: بروتوكول معملي، جداول، وإعادة كتابة أسئلة الفصل الأول.
''';
    }
    return '''
This chapter is a theoretical frame for $field only. It is not a general introduction and not results.

Concepts are limited to what explains the problem (term boundaries, approach, unit of analysis).
${cites.isEmpty ? 'With few confirmed sources, expansion waits and no theory is invented.' : 'Start from $cites to draft concepts after the full texts are read.'}

Excluded: laboratory protocol, tables, and a rewrite of Chapter 1 questions.
''';
  }

  static String _localTheme(
    ThesisPlan plan,
    GroundedReferenceBundle literature,
    String id,
  ) {
    final field = _fieldLabel(plan.goal);
    final cites = _citationHints(literature);
    final axis = id == 'theme_b'
        ? (plan.arabic ? 'محور ثانٍ مستقل' : 'a second independent axis')
        : (plan.arabic ? 'محور أول' : 'a first axis');
    if (plan.arabic) {
      return '''
هذا المبحث يطوّر $axis في $field. الحجة تعتمد على المصادر المؤكدة $cites فقط.

مسار العمل: قراءة الأصل عبر DOI، استخراج الشاهد، ثم التفسير داخل حدود المدونة. لا تُختلق اقتباسات أو وثائق.

بعد القراءة تُستبدل هذه المسودة بتحليل أدق. هذا الفصل ليس مقدمة ولا خاتمة.
''';
    }
    return '''
This chapter develops $axis in $field. The argument uses only confirmed sources $cites.

Workflow: read the original via DOI, extract evidence, then interpret inside the corpus limits. Quotations and archives are not invented.

After that reading, replace this draft with closer analysis. This chapter is neither the introduction nor the conclusion.
''';
  }

  static String _localExperimental(
    ThesisPlan plan,
    GroundedReferenceBundle literature,
    ThesisChapterTemplate template,
    AcademicProfile? profile,
  ) {
    final field = _fieldLabel(plan.goal);
    final methods = DegreePlanEngine.methodHint(plan.goal);
    final cites = _citationHints(literature);
    final heading = template.id == 'experimental'
        ? (plan.arabic ? 'الجزء العملي' : 'Experimental')
        : (plan.arabic ? 'المنهجية' : 'Methodology');
    final profileNote = profile?.methodology.trim().isNotEmpty == true
        ? (plan.arabic
            ? '\nتوجه الملف الأكاديمي: ${profile!.methodology.trim()}.'
            : '\nAcademic-profile note: ${profile!.methodology.trim()}.')
        : '';
    final sourceLine = cites.isEmpty
        ? (plan.arabic
            ? 'لا تُنسَخ بروتوكولات من دراسات غير مؤكدة.'
            : 'Do not copy protocols from unverified studies.')
        : (plan.arabic
            ? 'راجع إجراءات $cites ثم عدّلها لسياقك مع المشرف؛ لا تنسخها حرفياً.'
            : 'Review procedures in $cites and adapt them with the supervisor; do not copy them verbatim.');
    if (plan.arabic) {
      return '''
هذا فصل $heading لـ $field. هو بروتوكول مقترح بأدوات $methods، وليس مقدمة، وليس نتائج.

3.1 المواد
عيّنات العمل (تُرمَّز بعد الاستلام)، مذيبات ومعايير، وأي مواد مساعدة يوافق عليها المشرف. لا تُختلق أرقام تشغيل أو تواريخ تحليل.

3.2 الأجهزة
الأدوات المقترحة: $methods. المعايرة والبلانك إلزاميان قبل أي تشغيل. لا تُختلق موديلات أجهزة.

3.3 الإجراءات
(1) استلام العيّنة وترميزها.
(2) التحضير والتجانس حسب طبيعة المصفوفة.
(3) القياس وفق $methods مع تكرار مخطط.
(4) توثيق الظروف دون تسجيل قراءات غير موجودة.
لم تُنفَّذ التجربة بعد.

3.4 ضبط الجودة
تكرارات، بلانك، وتحقق استرجاعي — مخطط لا منفَّذ. أي تركيز أو مردود أو كروماتوغرام في هذه المسودة اختلاق ويُحذف.

3.5 ما لا يُكتب هنا
إعادة مقدمة الرسالة، جدول الأدبيات، وتفسير نتائج.

$sourceLine$profileNote
''';
    }
    return '''
This is the $heading chapter for $field. It is a proposed $methods protocol, not an introduction and not a results section.

3.1 Materials
Working samples (coded on receipt), solvents and standards, and any adjuncts the supervisor approves. Batch numbers and analysis dates are not fabricated.

3.2 Instruments
Proposed tools: $methods. Calibration and blanks are mandatory before any run. Instrument models are not invented.

3.3 Procedure
(1) Sample receipt and coding.
(2) Preparation and homogenisation according to the matrix.
(3) Measurement with $methods and planned replicates.
(4) Record conditions only — do not record peak areas or titres that do not exist.
The experiment has not been run.

3.4 Quality control
Replicates, blanks, and recovery checks are planned, not executed. Any concentration, yield, or chromatogram written now would be fabricated and is omitted.

3.5 What this chapter excludes
A rewrite of the introduction, the literature comparison table, and interpretation of results.

$sourceLine$profileNote
''';
  }

  static String _localResultsFrame(
    ThesisPlan plan,
    GroundedReferenceBundle literature,
    ThesisChapterTemplate template,
  ) {
    final field = _fieldLabel(plan.goal);
    final methods = DegreePlanEngine.methodHint(plan.goal);
    final merged = template.id == 'results_discussion';
    final title = merged
        ? (plan.arabic ? 'النتائج والمناقشة' : 'Results and discussion')
        : (plan.arabic ? 'النتائج' : 'Results');
    if (plan.arabic) {
      return '''
هذا هيكل $title لـ $field. يُملأ بعد جمع البيانات فقط. أي رقم يُكتب الآن اختلاق ولن يُدرج.

جدول 1. توصيف العيّنة (بعد الجمع)
| الرمز | المصفوفة | التاريخ | ملاحظات |
| — | — | — | — |

جدول 2. مؤشرات $methods (بعد القياس)
| الرمز | المؤشر | القيمة | وحدة | ملاحظة ضبط الجودة |
| — | — | — | — | — |

شكل 1. يُضاف بعد وجود قيم حقيقية في الجدول 2.

${merged ? 'المناقشة تُكتب بعد الجدول 2 مقابل الدراسات المؤكدة فقط، لا بنسخ فصل الأدبيات.' : 'التفسير يُترك لفصل المناقشة بعد وجود قيم حقيقية.'}
''';
    }
    return '''
This is the $title frame for $field. It is filled only after data exist. Any number written now would be fabricated and is omitted.

Table 1. Sample description (after collection)
| Code | Matrix | Date | Notes |
| — | — | — | — |

Table 2. $methods indicators (after measurement)
| Code | Indicator | Value | Unit | QC note |
| — | — | — | — | — |

Figure 1. Added only after Table 2 holds real values.

${merged ? 'Discussion is written after Table 2, against confirmed studies only — not by copying the literature chapter.' : 'Interpretation is left to the Discussion chapter after real values exist.'}
''';
  }

  static String _localDiscussionFrame(
    ThesisPlan plan,
    GroundedReferenceBundle literature,
  ) {
    final field = _fieldLabel(plan.goal);
    final cites = _citationHints(literature);
    if (plan.arabic) {
      return '''
هذا هيكل مناقشة $field. يُكتب بعد النتائج الحقيقية فقط.

محاور لاحقة (فارغة حتى توجد أرقام): الاتفاق/الاختلاف مع $cites، حدود القياس، وما لا يمكن تعميمه.

ممنوع تفسير أرقام غير موجودة، وممنوع إعادة سرد المقدمة أو بروتوكول التجربة.
''';
    }
    return '''
This is the discussion frame for $field. It is written only after real results exist.

Later headings (empty until numbers exist): agreement/disagreement with $cites, measurement limits, and what cannot be generalised.

Do not interpret numbers that do not exist, and do not retell the introduction or the experimental protocol.
''';
  }

  static String _localConclusion(
    ThesisPlan plan,
    GroundedReferenceBundle literature,
  ) {
    final field = _fieldLabel(plan.goal);
    final cites = _citationHints(literature);
    if (plan.arabic) {
      return '''
خاتمة مسودة $field. المساهمة الحالية هي الإطار والأدبيات المؤكدة${plan.kind == ThesisKind.literary ? ' ومسار المباحث التحليلية' : ' وبروتوكول العمل'} — لا نتائج ملفّقة.

الحدود: المسودة ليست رسالة جاهزة للتسليم ولا بديلاً عن ${plan.kind == ThesisKind.literary ? 'قراءة الأصول' : 'تنفيذ التجربة'}.
${cites.isEmpty ? 'أولوية المراجع: DOI أدق قبل التوسيع.' : 'أعد قراءة $cites مع المشرف قبل أي ادعاء نهائي.'}

الخطوات التالية: تثبيت الأسئلة، قراءة النصوص الكاملة، ثم ${plan.kind == ThesisKind.literary ? 'التحليل' : 'التشغيل وجمع البيانات'}.
''';
    }
    return '''
Conclusion of the $field draft. The present contribution is the frame and confirmed literature${plan.kind == ThesisKind.literary ? ' plus the analytic chapter path' : ' plus a working protocol'} — not fabricated findings.

Limits: this is not a submission copy and not a substitute for ${plan.kind == ThesisKind.literary ? 'reading the originals' : 'running the experiment'}.
${cites.isEmpty ? 'Reference priority: a more precise DOI before expansion.' : 'Re-read $cites with the supervisor before any final claim.'}

Next steps: lock the questions, read the full texts, then ${plan.kind == ThesisKind.literary ? 'analyse' : 'run the work and collect data'}.
''';
  }

  static String _literatureBody(
    ThesisPlan plan,
    GroundedReferenceBundle literature,
  ) {
    final goal = plan.goal;
    final field = _fieldLabel(goal);
    if (literature.works.isEmpty) {
      return plan.arabic
          ? 'فصل مراجعة الأدبيات في $field. لم يُعثر على أعمال بـ DOI مؤكد في OpenAlex أو Crossref أو Semantic Scholar. لم تُختلق أي دراسة. هذا الفصل ليس مقدمة ولا بروتوكول تجربة.'
          : 'Literature-review chapter on $field. No DOI-confirmed works were found in OpenAlex, Crossref, or Semantic Scholar. No study was invented. This chapter is neither the introduction nor an experimental protocol.';
    }
    final table = ThesisLiteratureMapper.comparisonTable(
      ThesisLiteratureMapper.fromBundle(literature),
      arabic: plan.arabic,
    );
    if (plan.arabic) {
      return '''
هذا فصل مراجعة الأدبيات في $field بصيغة رسالة جامعية: نطاق المراجعة، محاور موضوعية، مقارنة نقدية للمناهج والعينات والنتائج، ثم فجوة بحثية. ليس مقدمة الرسالة ولا وصف تجربتك.

تُراجع الدراسات المؤكدة فقط. الفرض التفصيلي والإحصاء يُستخرجان من النص الكامل لاحقاً — لا تُختلق من العنوان.

$table

لكل محور: ركّب الدراسات [n] معاً، قارن ماذا قاست وبأي أداة، وما الذي يبقى غير محسوم لـ $field. ممنوع قائمة ملخصات قصيرة بلا ربط، وممنوع نسخ المقدمة أو بروتوكول المواد.
''';
    }
    return '''
This is the literature-review chapter on $field in thesis form: review scope, thematic synthesis, critical comparison of methods/samples/findings, then a research gap. It is not the introduction and not a description of your experiment.

Only confirmed studies are reviewed. Detailed hypotheses and statistics come later from full texts — never invent them from titles.

$table

For each theme: synthesize numbered studies [n], compare what they measured and with which tools, and state what remains unresolved for $field. No short unlinked summaries. Do not copy the introduction or materials protocol.
''';
  }

  static String _localAbstract(
    ThesisPlan plan,
    GroundedReferenceBundle literature,
    String methods,
    AcademicProfile? profile,
  ) {
    final goal = plan.goal;
    final field = _fieldLabel(goal);
    final uni = profile != null && profile.university.trim().isNotEmpty
        ? profile.university.trim()
        : '';
    if (plan.arabic) {
      return 'مسودة ${goal.degreeLabel} في $field (${plan.kindLabel}). '
          'جمعت المنصة ${literature.works.length} دراسة DOI مؤكدة دون اختلاق مصادر. '
          'الهيكل المختار: ${plan.shapeLabel}. '
          '${plan.kind == ThesisKind.experimental ? 'المقدمة ومراجعة الأدبيات مسودتان طويلتان لكل فصل غرضه؛ الجزء العملي بروتوكول $methods؛ النتائج جداول فارغة حتى تُجمع البيانات. ' : ''}'
          '${uni.isNotEmpty ? 'السياق: $uni. ' : ''}'
          'ليست رسالة جاهزة من عشرات الصفحات ولا نسخة تسليم.';
    }
    return 'A ${goal.degreeLabel} draft in $field (${plan.kindLabel}). '
        'The platform collected ${literature.works.length} DOI-confirmed studies and invented none. '
        'Selected structure: ${plan.shapeLabel}. '
        '${plan.kind == ThesisKind.experimental ? 'Introduction and literature are separate chapter drafts; experimental work is a $methods protocol; results remain empty tables until data exist. ' : ''}'
        '${uni.isNotEmpty ? 'Context: $uni. ' : ''}'
        'Not a finished multi-chapter submission and not a 150-page thesis.';
  }

  static List<String> _localQuestions(ThesisPlan plan, String methods) {
    final field = _fieldLabel(plan.goal);
    if (plan.kind == ThesisKind.literary) {
      if (plan.arabic) {
        return [
          'كيف يُقرأ $field في المدونة المحددة وما الإشكالية النقدية؟',
          'ما الفجوة في الدراسات المؤكدة بـ DOI حول $field؟',
          'أي منهج تحليلي يناسب $field دون إسقاط أدوات تجريبية عليه؟',
        ];
      }
      return [
        'How is $field to be read in the chosen corpus, and what is the critical problem?',
        'What gap remains in the DOI-confirmed scholarship on $field?',
        'Which analytic method fits $field without imposing lab tools on it?',
      ];
    }
    if (plan.arabic) {
      return [
        'كيف يُقاس أو يُختبر $field باستخدام $methods؟',
        'ما الفجوة المتبقية في الدراسات المؤكدة بـ DOI حول $field؟',
        'أي ضبط جودة أو تصميم يلزم قبل تفسير أي نتيجة؟',
      ];
    }
    return [
      'How can $field be measured or tested with $methods?',
      'What gap remains in the DOI-confirmed studies on $field?',
      'Which quality control or design is required before any result is interpreted?',
    ];
  }

  static String _citationHints(GroundedReferenceBundle literature) {
    if (literature.works.isEmpty) return '';
    final n = literature.works.length;
    if (n == 1) return '[1]';
    if (n == 2) return '[1], [2]';
    return '[1]–[$n]';
  }

  static String _fieldLabel(ResearchGoal goal, {bool arabic = true}) {
    final primary = arabic
        ? (goal.field.trim().isNotEmpty ? goal.field : goal.fieldEn)
        : (goal.fieldEn.trim().isNotEmpty ? goal.fieldEn : goal.field);
    return ThesisStudioOutline.displayTopic(
      primary,
      fallback: goal.raw,
    );
  }

  /// Keep only `[n]` that exist in the citing list. Invented markers stay as
  /// bare text otherwise and break APA rendering + the verification report.
  static String _stripInventedMarkers(String text, {required int maxIndex}) {
    var cleaned = ThesisStudioProse.sanitize(
      text.replaceAll(RegExp(r'```json|```', caseSensitive: false), ''),
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\[(\d{1,3}(?:\s*[,;]\s*\d{1,3})*(?:\s*[–-]\s*\d{1,3})?)\]'),
      (m) {
        final raw = m.group(1)!;
        if (raw.contains(RegExp(r'[–-]'))) {
          final parts = raw.split(RegExp(r'\s*[–-]\s*'));
          if (parts.length != 2) return '';
          final a = int.tryParse(parts[0].trim());
          final b = int.tryParse(parts[1].trim());
          if (a == null || b == null) return '';
          if (maxIndex <= 0 || a < 1 || b > maxIndex || b < a) return '';
          return m.group(0)!;
        }
        final nums = [
          for (final p in raw.split(RegExp(r'\s*[,;]\s*')))
            int.tryParse(p.trim()),
        ].whereType<int>().toList();
        if (nums.isEmpty) return '';
        if (maxIndex <= 0) return '';
        final kept = [for (final n in nums) if (n >= 1 && n <= maxIndex) n];
        if (kept.isEmpty) return '';
        if (kept.length == nums.length) return m.group(0)!;
        return '[${kept.join(', ')}]';
      },
    );
    return cleaned.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();
  }

  static Map<String, dynamic>? _parseJsonMap(String raw) {
    var text = raw.trim();
    text = text.replaceAll(RegExp(r'^```json|```$', multiLine: true), '').trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }
}
