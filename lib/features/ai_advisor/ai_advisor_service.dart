import 'advisor_agent.dart';
import 'advisor_agent_registry.dart';
import 'advisor_branding.dart';
import 'advisor_message.dart';
import 'advisor_orchestrator.dart';
import 'gemini_advisor_client.dart';

class AiAdvisorService {
  AiAdvisorService._();

  static final AiAdvisorService instance = AiAdvisorService._();

  final _orchestrator = AdvisorOrchestrator.instance;

  int _messageCounter = 0;

  bool get isCloudAiEnabled => GeminiAdvisorClient.isConfigured;

  String _nextId() {
    _messageCounter++;
    return 'msg_$_messageCounter';
  }

  AdvisorMessage welcomeMessage() {
    return AdvisorMessage(
      id: _nextId(),
      role: AdvisorMessageRole.assistant,
      content: _welcomeContent(),
      createdAt: DateTime.now(),
    );
  }

  String _welcomeContent() {
    final agents = AdvisorAgentRegistry.agents
        .where((a) => a.id != AdvisorAgentId.general)
        .map((a) => '• ${a.shortLabel}')
        .join('\n');

    final mode = isCloudAiEnabled
        ? (GeminiAdvisorClient.runsOnWeb
            ? 'وضع ${AdvisorBranding.cloudBadge} — على المتصفح يُفضّل نشر Cloud Function أو التشغيل على Windows.'
            : 'وضع ${AdvisorBranding.cloudBadge} مفعّل — ردود Gemini الحقيقية.')
        : 'وضع ${AdvisorBranding.localBadge} — أضف مفتاح API حقيقي وشغّل على Windows.';

    return 'مرحباً! أنا **${AdvisorBranding.assistantTitle}** في ${AdvisorBranding.name}.\n\n'
        'محرك واحد يجمع وكلاء متخصصين:\n'
        '$agents\n\n'
        'اكتب أي طلب أكاديمي — سأوجّهه تلقائياً للوكيل المناسب '
        '(أو أكثر من وكيل إذا لزم).\n\n'
        '$mode';
  }

  Future<AdvisorMessage> ask({
    required String message,
    List<AdvisorMessage> history = const [],
  }) async {
    final trimmed = message.trim();
    final result = await _orchestrator.process(
      message: trimmed,
      history: history,
    );

    return AdvisorMessage(
      id: _nextId(),
      role: AdvisorMessageRole.assistant,
      content: result.content,
      createdAt: DateTime.now(),
      usedCloudAi: result.usedCloudAi,
      agentLabels: result.agentLabels,
    );
  }
}
