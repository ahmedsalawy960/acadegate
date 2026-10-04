import '../../core/locale/app_translate.dart';
import '../acadegate_publish/manuscript_draft_chat_service.dart';
import '../acadegate_publish/publish_services.dart';
import '../profile/academic_profile_service.dart';
import 'advisor_agent.dart';
import 'advisor_agent_registry.dart';
import 'advisor_attachment.dart';
import 'advisor_branding.dart';
import 'advisor_message.dart';
import 'advisor_router.dart';
import 'catalog_hit.dart';
import 'catalog_search_service.dart';
import 'gemini_advisor_client.dart';
import 'grounded_reference_service.dart';
import 'grounded_work.dart';
import 'local_advisor_engine.dart';

class AdvisorOrchestratorResult {
  final String content;
  final List<String> agentLabels;
  final bool usedCloudAi;
  final String? cloudError;
  final CatalogSearchSnapshot catalog;

  const AdvisorOrchestratorResult({
    required this.content,
    required this.agentLabels,
    this.usedCloudAi = false,
    this.cloudError,
    this.catalog = const CatalogSearchSnapshot(
      intent: CatalogIntentSummary.empty,
    ),
  });
}

class AdvisorOrchestrator {
  AdvisorOrchestrator._();

  static final AdvisorOrchestrator instance = AdvisorOrchestrator._();

  Future<AdvisorOrchestratorResult> process({
    required String message,
    List<AdvisorMessage> history = const [],
    List<GeminiInlinePart> attachments = const [],
  }) async {
    final routeText = message.trim().isNotEmpty
        ? message
        : attachments.isNotEmpty
            ? appTr(
                'حلل الملف: ${attachments.first.fileName}',
                'Analyze file: ${attachments.first.fileName}',
              )
            : message;
    final plan = AdvisorRouter.instance.route(routeText);
    final labels = plan.allAgents
        .map((id) => AdvisorAgentRegistry.instance.byId(id).displayShortLabel)
        .toList();

    final catalog = plan.primary == AdvisorAgentId.catalogExecute
        ? await CatalogSearchService.instance.search(routeText)
        : const CatalogSearchSnapshot(intent: CatalogIntentSummary.empty);

    if (plan.primary == AdvisorAgentId.catalogExecute) {
      return AdvisorOrchestratorResult(
        content: CatalogSearchService.instance.localReply(catalog),
        agentLabels: labels,
        catalog: catalog,
      );
    }

    if (attachments.isEmpty &&
        ManuscriptDraftChatService.looksLikeDraftQuestion(routeText)) {
      final draft = await ManuscriptService.instance.latestWithContent();
      if (draft != null) {
        final reply = await ManuscriptDraftChatService.instance.ask(
          manuscript: draft,
          question: routeText,
        );
        return AdvisorOrchestratorResult(
          content: reply.text,
          agentLabels: [
            appTr('اسأل المسودة', 'Ask draft'),
            ...labels,
          ],
        );
      }
      return AdvisorOrchestratorResult(
        content: appTr(
          'هذا السؤال عن مسودتك. ارفع PDF أو Word من **نشر → المسودة** ثم اسأل '
          '«هل الملخص يطابق النتائج؟» أو «أين جدول 3؟» — الإجابة تكون من ملفك أنت.',
          'That question is about your draft. Upload a PDF or Word file from **Publish → Draft**, then ask '
          '"Does the abstract match the results?" or "Where is Table 3?" — answers come from your file.',
        ),
        agentLabels: [appTr('اسأل المسودة', 'Ask draft')],
      );
    }

    if (plan.primary == AdvisorAgentId.citations) {
      final grounded = GroundedReferenceService.instance;
      if (GroundedReferenceService.looksLikeBibliographyPaste(routeText)) {
        return AdvisorOrchestratorResult(
          content: await grounded.verifyPastedBibliography(routeText),
          agentLabels: labels,
        );
      }
      final refs = await grounded.searchTopic(routeText);
      return AdvisorOrchestratorResult(
        content: grounded.replyForCitations(refs, message: routeText),
        agentLabels: labels,
      );
    }

    if (attachments.isNotEmpty && !GeminiAdvisorClient.canAnalyzeAttachments) {
      final content = GeminiAdvisorClient.needsSignInForCloudAi
          ? appTr(
              '⚠️ **تحليل الصور والملفات يتطلب تسجيل الدخول**\n\n'
                  'سجّل دخولك ثم أعد إرسال المرفقات.',
              '⚠️ **Analyzing images and files requires signing in**\n\n'
                  'Sign in and resend the attachments.',
            )
          : appTr(
              '⚠️ **تحليل الصور والملفات يتطلب ${AdvisorBranding.cloudBadge}**\n\n'
                  'سجّل الدخول ثم أعد إرسال المرفقات (لا حاجة لمفتاح محلي بعد تسجيل الدخول).',
              '⚠️ **Analyzing images and files requires ${AdvisorBranding.cloudBadge}**\n\n'
                  'Sign in and resend the attachments (no local API key needed after sign-in).',
            );
      return AdvisorOrchestratorResult(
        content: content,
        agentLabels: labels,
      );
    }

    if (GeminiAdvisorClient.isAvailable) {
      GroundedReferenceBundle? literatureRefs;
      final wantsGroundedRefs =
          plan.allAgents.contains(AdvisorAgentId.literatureReview) ||
              plan.allAgents.contains(AdvisorAgentId.citations);
      if (wantsGroundedRefs) {
        literatureRefs =
            await GroundedReferenceService.instance.searchTopic(message);
      }
      final cloud = await _askCloud(
        message: message,
        plan: plan,
        history: history,
        attachments: attachments,
        literatureRefs: literatureRefs,
      );
      if (cloud.isSuccess) {
        var content = await GroundedReferenceService.instance.enforceVerifiedDois(
          cloud.text!,
          known: literatureRefs,
        );
        if (literatureRefs != null) {
          content =
              '$content\n\n${GroundedReferenceService.instance.bibliographySection(literatureRefs)}';
        }
        return AdvisorOrchestratorResult(
          content: content,
          agentLabels: labels,
          usedCloudAi: true,
        );
      }

      // فشل السحابة: نعطي رداً محلياً كاملاً + توضيح الخطأ (لا نترك المستخدم بلا نتيجة)
      final local = await LocalAdvisorEngine.instance.respondToAgents(
        message: message,
        plan: plan,
      );
      return AdvisorOrchestratorResult(
        content: appTr(
          '⚠️ **تعذر الاتصال بـ ${AdvisorBranding.cloudBadge}**\n'
              '${cloud.error}\n\n'
              '---\n'
              '**رد احتياطي (محرك محلي):**\n\n'
              '$local\n\n'
              '---\n'
              'لتفعيل المساعد الأكاديمي:\n'
              '1. سجّل الدخول على Chrome/Web\n'
              '2. أو شغّل على Windows مع `dart_defines.json`',
          '⚠️ **Could not connect to ${AdvisorBranding.cloudBadge}**\n'
              '${cloud.error}\n\n'
              '---\n'
              '**Fallback response (local engine):**\n\n'
              '$local\n\n'
              '---\n'
              'To turn on the Academic Assistant:\n'
              '1. Sign in on Chrome/Web\n'
              '2. Or run on Windows with `dart_defines.json`',
        ),
        agentLabels: labels,
        cloudError: cloud.error,
      );
    }

    final local = await LocalAdvisorEngine.instance.respondToAgents(
      message: message,
      plan: plan,
    );

    return AdvisorOrchestratorResult(
      content: appTr(
        '$local\n\n'
            '---\n'
            '⚠️ أنت على **الوضع الأساسي** (قوالب محلية). '
            'لتفعيل المساعد الأكاديمي:\n'
            '1. سجّل الدخول على Chrome/Web\n'
            '2. أو انسخ `dart_defines.example.json` إلى `dart_defines.json` على Windows',
        '$local\n\n'
            '---\n'
            '⚠️ You are on **${AdvisorBranding.localBadge} mode** (local templates). '
            'To turn on the Academic Assistant:\n'
            '1. Sign in on Chrome/Web\n'
            '2. Or copy `dart_defines.example.json` to `dart_defines.json` on Windows',
      ),
      agentLabels: labels,
    );
  }

  Future<GeminiGenerateResult> _askCloud({
    required String message,
    required AdvisorRoutePlan plan,
    required List<AdvisorMessage> history,
    required List<GeminiInlinePart> attachments,
    GroundedReferenceBundle? literatureRefs,
  }) async {
    final profile = await AcademicProfileService.instance.loadProfile();
    final profileSummary = profile == null
        ? ''
        : appTr(
            'الاسم: ${profile.fullName}، الجامعة: ${profile.university}، '
                'التخصص: ${profile.specialization}، الاهتمام: ${profile.researchInterest}، '
                'المنهجية: ${profile.methodology}',
            'Name: ${profile.fullName}, University: ${profile.university}, '
                'Specialization: ${profile.specialization}, Interest: ${profile.researchInterest}, '
                'Methodology: ${profile.methodology}',
          );

    final primaryAgent = AdvisorAgentRegistry.instance.byId(plan.primary);
    var extraContext = '';

    if (plan.primary == AdvisorAgentId.supervisorMatch) {
      extraContext = await LocalAdvisorEngine.instance.supervisorHint(message);
    }
    if (literatureRefs != null) {
      extraContext = [
        extraContext,
        GroundedReferenceService.instance.promptBlock(literatureRefs),
      ].where((s) => s.trim().isNotEmpty).join('\n\n');
    }

    final systemPrompt = AdvisorAgentRegistry.instance.cloudSystemPrompt(
      agentName: primaryAgent.displayName,
      agentFocus: primaryAgent.systemPrompt,
      profileSummary: profileSummary,
      extraContext: extraContext,
      isMultiAgent: plan.isMultiAgent,
      supportingAgents: plan.supporting
          .map((id) => AdvisorAgentRegistry.instance.byId(id).displayName)
          .toList(),
    );

    final recentHistory = history
        .where(
          (m) =>
              (m.content.trim().isNotEmpty || m.attachments.isNotEmpty) &&
              !m.content.startsWith('⚠️'),
        )
        .toList()
        .reversed
        .take(12)
        .toList()
        .reversed
        .map((m) {
          var text = m.content;
          if (m.attachments.isNotEmpty) {
            final sep = appTr('، ', ', ');
            final names = m.attachments.map((a) => a.name).join(sep);
            text = text.isEmpty
                ? appTr('[مرفقات: $names]', '[Attachments: $names]')
                : '$text\n${appTr('[مرفقات: $names]', '[Attachments: $names]')}';
          }
          return {
            'role': m.role == AdvisorMessageRole.user ? 'user' : 'assistant',
            'text': text,
          };
        })
        .toList();

    return GeminiAdvisorClient.instance.generateResult(
      systemPrompt: systemPrompt,
      userMessage: message,
      history: recentHistory,
      attachments: attachments,
      maxOutputTokens: 8192,
    );
  }
}
