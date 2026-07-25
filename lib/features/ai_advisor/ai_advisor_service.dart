import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';
import 'advisor_agent.dart';
import 'advisor_agent_registry.dart';
import 'advisor_attachment.dart';
import 'advisor_branding.dart';
import 'advisor_message.dart';
import 'advisor_orchestrator.dart';
import 'gemini_advisor_client.dart';

class AiAdvisorService {
  AiAdvisorService._();

  static final AiAdvisorService instance = AiAdvisorService._();

  final _orchestrator = AdvisorOrchestrator.instance;

  int _messageCounter = 0;

  bool get isCloudAiEnabled => GeminiAdvisorClient.isAvailable;

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
        .map((a) => '• ${a.displayShortLabel}')
        .join('\n');

    final mode = isCloudAiEnabled
        ? (GeminiAdvisorClient.canUseCloudBackend
            ? appTr(
                'وضع ${AdvisorBranding.cloudBadge} — ردود ذكية عبر السحابة.',
                '${AdvisorBranding.cloudBadge} mode — smart responses via cloud.',
              )
            : appTr(
                'وضع ${AdvisorBranding.cloudBadge} مفعّل — ردود ذكية حقيقية.',
                '${AdvisorBranding.cloudBadge} mode is active — real smart responses.',
              ))
        : (GeminiAdvisorClient.needsSignInForCloudAi
            ? appTr(
                'الوضع الأساسي — **سجّل الدخول** لتفعيل الذكاء السحابي (بدون مفتاح محلي).',
                'Basic mode — **sign in** to enable cloud AI (no local API key needed).',
              )
            : appTr(
                'وضع ${AdvisorBranding.localBadge} — انسخ dart_defines.example.json إلى dart_defines.json '
                    'وشغّل من Cursor: AcadeGate (Windows + AI)، أو سجّل الدخول للذكاء السحابي.',
                '${AdvisorBranding.localBadge} mode — copy dart_defines.example.json to dart_defines.json '
                    'and run from Cursor: AcadeGate (Windows + AI), or sign in for cloud AI.',
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
    );
  }
}
