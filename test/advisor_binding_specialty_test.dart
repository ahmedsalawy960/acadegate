import 'package:acadegate/features/ai_advisor/advisor_agent.dart';
import 'package:acadegate/features/ai_advisor/advisor_agent_registry.dart';
import 'package:acadegate/features/ai_advisor/advisor_agent_tools.dart';
import 'package:acadegate/features/ai_advisor/assistant/academic_assistant_client.dart';
import 'package:acadegate/features/ai_advisor/assistant/assistant_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('binding specialty: tool gating', () {
    test('every selectable specialty has a tool mapping', () {
      final selectable = AdvisorAgentRegistry.agents
          .where((a) => a.id != AdvisorAgentId.general)
          .map((a) => a.id);
      for (final id in selectable) {
        expect(advisorAgentAllowedTools[id], isNotNull,
            reason: '$id needs a tool mapping');
        expect(advisorAgentAllowedTools[id]!, isNotEmpty,
            reason: '$id needs at least one tool');
      }
    });

    test('every mapped tool name is a real declared tool', () {
      final declared =
          AssistantToolbox.declarations.map((d) => d['name']).toSet();
      for (final entry in advisorAgentAllowedTools.entries) {
        for (final tool in entry.value) {
          expect(declared, contains(tool),
              reason: '${entry.key} maps unknown tool $tool');
        }
      }
    });

    test('editing specialty excludes the literature tool', () {
      final decls = AssistantToolbox.declarationsFor(
          advisorAgentAllowedTools[AdvisorAgentId.academicEditing]);
      final names = decls.map((d) => d['name']).toList();
      expect(names, contains('translate_academic_text'));
      expect(names, isNot(contains('search_scientific_literature')));
      expect(names, isNot(contains('check_research_evidence')));
      expect(names, isNot(contains('find_supervisors')));
    });

    test('auto mode (null) keeps every tool', () {
      expect(AssistantToolbox.declarationsFor(null).length,
          AssistantToolbox.declarations.length);
    });

    test('a gated tool is refused at execution and adds no chip label',
        () async {
      final box = AssistantToolbox(
        allowedTools: advisorAgentAllowedTools[AdvisorAgentId.academicEditing],
      );
      final result = await box.execute('find_supervisors', {'query': 'x'});
      expect(result['error'], contains('not available in this specialty'));
      expect(box.usedLabels, isEmpty);
    });

    test('an allowed tool executes normally under the gate', () async {
      final box = AssistantToolbox(
        allowedTools: advisorAgentAllowedTools[AdvisorAgentId.academicEditing],
        translate: (text, {required targetLang}) async => 'مترجم',
      );
      final result = await box.execute('translate_academic_text', {
        'text': 'Some academic text.',
        'target_language': 'ar',
      });
      expect(result['translation'], 'مترجم');
    });
  });

  group('binding specialty: persona block', () {
    test('selected specialty block is binding, not advisory', () {
      final block = AcademicAssistantClient.specialistFocusBlock(
        'حرر هذه الجملة',
        forcedAgentId: AdvisorAgentId.thesisPlanning,
      );
      final planning =
          AdvisorAgentRegistry.instance.byId(AdvisorAgentId.thesisPlanning);
      expect(block, contains(planning.systemPrompt.trim()));
      // Binding language present (AR or EN depending on test locale).
      final lower = block.toLowerCase();
      expect(
        lower.contains('ملزم') || lower.contains('binding'),
        isTrue,
      );
      expect(
        lower.contains('يتبع هذا التخصص') ||
            lower.contains('follows this specialty'),
        isTrue,
      );
    });

    test('auto mode block stays advisory with the active-specialty header',
        () {
      final block = AcademicAssistantClient.specialistFocusBlock(
        'اقترح لي عنوان رسالة في الطاقة الشمسية وخطة بحث',
      );
      if (block.isNotEmpty) {
        final lower = block.toLowerCase();
        expect(
          lower.contains('التخصص النشط') ||
              lower.contains('active specialty'),
          isTrue,
        );
        expect(lower.contains('ملزم') || lower.contains('binding'), isFalse);
      }
    });
  });
}
