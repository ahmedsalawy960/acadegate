import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';
import 'advisor_agent.dart';
import 'advisor_agent_registry.dart';
import 'advisor_attachment.dart';
import 'advisor_branding.dart';
import 'advisor_message.dart';
import 'advisor_orchestrator.dart';
import 'advisor_router.dart';
import 'assistant/academic_assistant_client.dart';
import 'catalog_hit.dart';
import 'gemini_advisor_client.dart';

class AiAdvisorService {
  AiAdvisorService._();

  static final AiAdvisorService instance = AiAdvisorService._();

  final _orchestrator = AdvisorOrchestrator.instance;

  int _messageCounter = 0;

  bool get isCloudAiEnabled => GeminiAdvisorClient.isAvailable;

  /// Unique across app restarts: conversations are reloaded from
  /// Firestore, so a per-session counter would overwrite old messages.
  String _nextId() {
    _messageCounter++;
    return newAdvisorMessageId(_messageCounter);
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
        .map((a) => '• ${a.displayShortLabel}')
        .join('\n');

    final mode = isCloudAiEnabled
        ? (GeminiAdvisorClient.canUseCloudBackend
            ? appTr(
                'وضع ${AdvisorBranding.cloudBadge}.',
                '${AdvisorBranding.cloudBadge} is on.',
              )
            : appTr(
                'وضع ${AdvisorBranding.cloudBadge} مفعّل.',
                '${AdvisorBranding.cloudBadge} is active.',
              ))
        : (GeminiAdvisorClient.needsSignInForCloudAi
            ? appTr(
                'الوضع الأساسي — **سجّل الدخول** لتفعيل المساعد الأكاديمي.',
                'Basic mode — **sign in** to turn on the Academic Assistant.',
              )
            : appTr(
                'وضع ${AdvisorBranding.localBadge} — سجّل الدخول لتفعيل المساعد الأكاديمي.',
                '${AdvisorBranding.localBadge} mode — sign in to turn on the Academic Assistant.',
              ));

    final persistence = FirebaseAuth.instance.currentUser != null
        ? appTr(
            'محادثتك تُحفظ تلقائياً في حسابك.',
            'Your conversation is saved automatically to your account.',
          )
        : appTr(
            'سجّل دخولك لحفظ المحادثة عند مغادرة الشاشة.',
            'Sign in to save the conversation when you leave this screen.',
          );

    return appTr(
      'مرحباً! أنا **${AdvisorBranding.assistantTitle}** في ${AdvisorBranding.name}.\n\n'
          'محرك واحد يجمع وكلاء متخصصين:\n'
          '$agents\n\n'
          'اكتب أي طلب أكاديمي أو **أرفق صورة/ملف** (📎) — سأوجّهه تلقائياً للوكيل المناسب '
          '(أو أكثر من وكيل إذا لزم).\n\n'
          '$mode\n'
          '$persistence',
      'Hello! I am **${AdvisorBranding.assistantTitle}** on ${AdvisorBranding.name}.\n\n'
          'One engine with specialist agents:\n'
          '$agents\n\n'
          'Type any academic request or **attach an image/file** (📎) — I will route it to the right agent '
          '(or more than one if needed).\n\n'
          '$mode\n'
          '$persistence',
    );
  }

  static const _deepAgents = {
    AdvisorAgentId.thesisPlanning,
    AdvisorAgentId.thesisWriter,
    AdvisorAgentId.literatureReview,
    AdvisorAgentId.dataAnalysis,
    AdvisorAgentId.researchSimulation,
    AdvisorAgentId.researchIdea,
  };

  /// Deep reasoning for substantial requests; the server only grants it to Pro/admin.
  static bool wantsDeepThinking(String message, {bool hasAttachments = false}) {
    if (hasAttachments) return true;
    final t = message.trim();
    if (t.length >= 160) return true;
    if (t.length < 25) return false;
    final plan = AdvisorRouter.instance.route(t);
    return plan.allAgents.any(_deepAgents.contains);
  }

  static List<Map<String, String>> historyForModel(List<AdvisorMessage> history) {
    return history
        .where(
          (m) =>
              (m.content.trim().isNotEmpty || m.attachments.isNotEmpty) &&
              !m.content.startsWith('⚠️'),
        )
        .map((m) {
          var text = m.content;
          if (m.attachments.isNotEmpty) {
            final names = m.attachments.map((a) => a.name).join(appTr('، ', ', '));
            final note = appTr('[مرفقات: $names]', '[Attachments: $names]');
            text = text.isEmpty ? note : '$text\n$note';
          }
          return {
            'role': m.role == AdvisorMessageRole.user ? 'user' : 'assistant',
            'text': text,
          };
        })
        .toList();
  }

  /// Streaming, tool-using assistant. Falls back to [ask] when the new
  /// backend is unreachable or the user is signed out.
  Future<AdvisorMessage> askStreaming({
    required String message,
    List<AdvisorMessage> history = const [],
    List<GeminiInlinePart> attachments = const [],
    void Function(String textSoFar)? onText,
    void Function(String? status)? onStatus,
  }) async {
    if (!AcademicAssistantClient.isAvailable) {
      return ask(message: message, history: history, attachments: attachments);
    }

    final result = await AcademicAssistantClient.instance.run(
      message: message,
      history: historyForModel(history),
      attachments: attachments,
      deep: wantsDeepThinking(message, hasAttachments: attachments.isNotEmpty),
      onText: onText,
      onStatus: onStatus,
    );

    if (result.backendUnavailable) {
      return ask(message: message, history: history, attachments: attachments);
    }

    final content = result.isSuccess
        ? result.text
        : [
            if (result.text.trim().isNotEmpty) result.text.trim(),
            '⚠️ ${AdvisorBranding.friendlyFailure(result.error)}',
          ].join('\n\n');

    final catalog = result.toolbox.catalog;
    return AdvisorMessage(
      id: _nextId(),
      role: AdvisorMessageRole.assistant,
      content: content,
      createdAt: DateTime.now(),
      usedCloudAi: true,
      agentLabels: [
        if (result.deep) appTr('تفكير عميق', 'Deep thinking'),
        ...result.toolLabels,
      ],
      catalog: catalog.isEmpty
          ? const CatalogSearchSnapshot(intent: CatalogIntentSummary.empty)
          : catalog,
    );
  }

  Future<AdvisorMessage> ask({
    required String message,
    List<AdvisorMessage> history = const [],
    List<GeminiInlinePart> attachments = const [],
  }) async {
    final trimmed = message.trim();
    final result = await _orchestrator.process(
      message: trimmed,
      history: history,
      attachments: attachments,
    );

    return AdvisorMessage(
      id: _nextId(),
      role: AdvisorMessageRole.assistant,
      content: result.content,
      createdAt: DateTime.now(),
      usedCloudAi: result.usedCloudAi,
      agentLabels: result.agentLabels,
      catalog: result.catalog,
    );
  }
}
