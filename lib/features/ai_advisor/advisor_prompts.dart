import '../../core/locale/app_translate.dart';
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
          label: agent.displayShortLabel,
          message: agent.samplePrompt,
        ),
      )
      .toList();
}

String get advisorGeneralHelp => appTr(
      '''
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
''',
      '''
I am the AcadeGate AI multi-agent engine. Try one of these requests:

• Suggest 10 thesis titles in solar energy
• Write a natural-style academic introduction about ...
• Simulate quantitative study results about ...
• Analyze a paper and suggest a research gap
• Format references in APA style
• Edit this text academically: ...
• Suggest statistical analysis with Python code
• Prepare a defense presentation outline
• Who is the best supervisor for my idea in ...?
''',
    );
