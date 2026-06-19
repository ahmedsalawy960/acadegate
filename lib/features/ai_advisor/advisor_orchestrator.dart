import '../profile/academic_profile_service.dart';
import 'advisor_agent.dart';
import 'advisor_agent_registry.dart';
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
  }) async {
    final plan = AdvisorRouter.instance.route(message);
    final labels = plan.allAgents
        .map((id) => AdvisorAgentRegistry.instance.byId(id).shortLabel)
        .toList();

    if (GeminiAdvisorClient.isConfigured) {
      final cloud = await _askCloud(
        message: message,
        plan: plan,
        history: history,
      );
      if (cloud.isSuccess) {
        return AdvisorOrchestratorResult(
          content: cloud.text!,
          agentLabels: labels,
          usedCloudAi: true,
        );
      }

      // لا نخدع المستخدم بردود قوالب — نوضح فشل الاتصال الحقيقي
      final localHint = await _localHintForPlan(message, plan);
      return AdvisorOrchestratorResult(
        content: '⚠️ **تعذر الاتصال بـ ${AdvisorBranding.cloudBadge}**\n\n'
            '${cloud.error}\n\n'
            '---\n'
            '**تلميح سريع (ليس بديل Gemini):**\n$localHint',
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
          '2. التشغيل على **Windows** وليس Chrome\n'
          '   `flutter run -d windows --dart-define=GEMINI_API_KEY=مفتاحك`',
      agentLabels: labels,
    );
  }

  Future<String> _localHintForPlan(String message, AdvisorRoutePlan plan) async {
    if (plan.primary == AdvisorAgentId.supervisorMatch) {
      return LocalAdvisorEngine.instance.supervisorHint(message);
    }
    return 'تحقق من المفتاح والمنصة ثم أعد المحاولة.';
  }

  Future<GeminiGenerateResult> _askCloud({
    required String message,
    required AdvisorRoutePlan plan,
    required List<AdvisorMessage> history,
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
        .where((m) => m.content.trim().isNotEmpty && !m.content.startsWith('⚠️'))
        .toList()
        .reversed
        .take(12)
        .toList()
        .reversed
        .map(
          (m) => {
            'role': m.role == AdvisorMessageRole.user ? 'user' : 'assistant',
            'text': m.content,
          },
        )
        .toList();

    return GeminiAdvisorClient.instance.generateResult(
      systemPrompt: systemPrompt,
      userMessage: message,
      history: recentHistory,
      maxOutputTokens: 8192,
    );
  }
}
