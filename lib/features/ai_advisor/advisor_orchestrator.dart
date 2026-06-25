import '../profile/academic_profile_service.dart';
import 'advisor_agent.dart';
import 'advisor_agent_registry.dart';
import 'advisor_attachment.dart';
import 'advisor_branding.dart';
import 'advisor_message.dart';
import 'advisor_router.dart';
import 'gemini_advisor_client.dart';
import 'local_advisor_engine.dart';

class AdvisorOrchestratorResult {
  final String content;
  final List<String> agentLabels;
  final bool usedCloudAi;
  final String? cloudError;

  const AdvisorOrchestratorResult({
    required this.content,
    required this.agentLabels,
    this.usedCloudAi = false,
    this.cloudError,
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
            ? 'حلل الملف: ${attachments.first.fileName}'
            : message;
    final plan = AdvisorRouter.instance.route(routeText);
    final labels = plan.allAgents
        .map((id) => AdvisorAgentRegistry.instance.byId(id).shortLabel)
        .toList();

    if (attachments.isNotEmpty && !GeminiAdvisorClient.isConfigured) {
      return AdvisorOrchestratorResult(
        content: '⚠️ **تحليل الصور والملفات يتطلب ${AdvisorBranding.cloudBadge}**\n\n'
            'فعّل مفتاح Gemini ثم أعد إرسال المرفقات.\n'
            '`flutter run -d windows --dart-define-from-file=dart_defines.json`',
        agentLabels: labels,
      );
    }

    if (GeminiAdvisorClient.isConfigured) {
      final cloud = await _askCloud(
        message: message,
        plan: plan,
        history: history,
        attachments: attachments,
      );
      if (cloud.isSuccess) {
        return AdvisorOrchestratorResult(
          content: cloud.text!,
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
        content: '⚠️ **تعذر الاتصال بـ ${AdvisorBranding.cloudBadge}**\n'
            '${cloud.error}\n\n'
            '---\n'
            '**رد احتياطي (محرك محلي):**\n\n'
            '$local\n\n'
            '---\n'
            'للحصول على ردود مثل Gemini:\n'
            '1. مفتاح API حقيقي من Google AI Studio\n'
            '2. `flutter run -d windows --dart-define-from-file=dart_defines.json`\n'
            '   أو `--dart-define=GEMINI_API_KEY=مفتاحك`',
        agentLabels: labels,
        cloudError: cloud.error,
      );
    }

    final local = await LocalAdvisorEngine.instance.respondToAgents(
      message: message,
      plan: plan,
    );

    return AdvisorOrchestratorResult(
      content: '$local\n\n'
          '---\n'
          '⚠️ أنت على **الوضع الأساسي** (قوالب محلية). '
          'للحصول على إجابات مثل Gemini مباشرة:\n'
          '1. مفتاح API حقيقي من Google AI Studio\n'
          '2. انسخ `dart_defines.example.json` إلى `dart_defines.json` وضع المفتاح\n'
          '3. شغّل: `flutter run -d windows --dart-define-from-file=dart_defines.json`',
      agentLabels: labels,
    );
  }

  Future<GeminiGenerateResult> _askCloud({
    required String message,
    required AdvisorRoutePlan plan,
    required List<AdvisorMessage> history,
    required List<GeminiInlinePart> attachments,
  }) async {
    final profile = await AcademicProfileService.instance.loadProfile();
    final profileSummary = profile == null
        ? ''
        : 'الاسم: ${profile.fullName}، الجامعة: ${profile.university}، '
            'التخصص: ${profile.specialization}، الاهتمام: ${profile.researchInterest}، '
            'المنهجية: ${profile.methodology}';

    final primaryAgent = AdvisorAgentRegistry.instance.byId(plan.primary);
    var extraContext = '';

    if (plan.primary == AdvisorAgentId.supervisorMatch) {
      extraContext = await LocalAdvisorEngine.instance.supervisorHint(message);
    }

    final systemPrompt = AdvisorAgentRegistry.instance.cloudSystemPrompt(
      agentName: primaryAgent.nameAr,
      agentFocus: primaryAgent.systemPrompt,
      profileSummary: profileSummary,
      extraContext: extraContext,
      isMultiAgent: plan.isMultiAgent,
      supportingAgents: plan.supporting
          .map((id) => AdvisorAgentRegistry.instance.byId(id).nameAr)
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
            final names = m.attachments.map((a) => a.name).join('، ');
            text = text.isEmpty ? '[مرفقات: $names]' : '$text\n[مرفقات: $names]';
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
