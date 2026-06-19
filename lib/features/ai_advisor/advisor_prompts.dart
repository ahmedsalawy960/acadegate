import 'advisor_agent.dart';
import 'advisor_agent_registry.dart';

class AdvisorQuickPrompt {
  final String label;
  final String message;

  const AdvisorQuickPrompt({
    required this.label,
    required this.message,
  });
}

List<AdvisorQuickPrompt> get advisorQuickPrompts {
  return AdvisorAgentRegistry.agents
      .where((agent) => agent.id != AdvisorAgentId.general)
      .map(
        (agent) => AdvisorQuickPrompt(
          label: agent.shortLabel,
          message: agent.samplePrompt,
        ),
      )
      .toList();
}

const advisorGeneralHelp = '''
أنا محرك AcadeGate AI متعدد الوكلاء. جرّب أحد هذه الطلبات:

• اقترح لي 10 عناوين رسالة في الطاقة الشمسية
• اكتب مقدمة أكاديمية بأسلوب طبيعي عن ...
• حاكِ نتائج دراسة كمية عن ...
• حلّل ورقة علمية واقترح فجوة بحثية
• رتّب المراجع بأسلوب APA
• حرّر هذا النص أكاديمياً: ...
• اقترح تحليلاً إحصائياً مع كود Python
• جهّز هيكل عرض تقديمي للمناقشة
• ما المشرف الأنسب لفكرتي في ...؟
''';
