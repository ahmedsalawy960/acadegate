import 'package:acadegate/features/ai_advisor/advisor_agent.dart';
import 'package:acadegate/features/ai_advisor/advisor_agent_registry.dart';
import 'package:acadegate/features/ai_advisor/advisor_branding.dart';
import 'package:acadegate/features/ai_advisor/advisor_message_format.dart';
import 'package:acadegate/features/ai_advisor/assistant/academic_assistant_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('specialist selection (chip tap selects, never auto-sends)', () {
    test('forced agent persona is used regardless of message text', () {
      final focus = AcademicAssistantClient.specialistFocusBlock(
        'ما المشرف الأنسب لفكرتي؟',
        forcedAgentId: AdvisorAgentId.academicEditing,
      );
      final editing = AdvisorAgentRegistry.instance
          .byId(AdvisorAgentId.academicEditing);
      expect(focus, contains(editing.systemPrompt.trim()));
      expect(focus, contains(editing.displayShortLabel));
    });

    test('without a forced agent, routing still follows the message text',
        () {
      final routed = AcademicAssistantClient.specialistFocusBlock(
        'حرر هذا النص أكاديمياً من فضلك وحسّن الصياغة',
      );
      final forcedOther = AcademicAssistantClient.specialistFocusBlock(
        'حرر هذا النص أكاديمياً من فضلك وحسّن الصياغة',
        forcedAgentId: AdvisorAgentId.supervisorMatch,
      );
      // Forcing a different agent changes the persona, proving the override
      // wins over text routing.
      expect(routed == forcedOther, isFalse);
    });

    test('forcing the general agent yields no specialist framing', () {
      expect(
        AcademicAssistantClient.specialistFocusBlock(
          'أي سؤال',
          forcedAgentId: AdvisorAgentId.general,
        ),
        isEmpty,
      );
    });

    test('forced data-analysis agent enables code execution for short text',
        () {
      expect(
        AcademicAssistantClient.wantsCodeExecution(
          'احسب المتوسط',
          forcedAgentId: AdvisorAgentId.dataAnalysis,
        ),
        isTrue,
      );
    });
  });

  group('formatAdvisorMessageContent', () {
    test('strips heading hashes so ### never shows literally', () {
      const reply = 'مقدمة\n\n### المشرفون المتاحون على المنصة:\n\n1. د. أحمد';
      final out = formatAdvisorMessageContent(reply);
      expect(out, isNot(contains('###')));
      expect(out, contains('المشرفون المتاحون على المنصة:'));
    });

    test('strips all heading levels but keeps list text and hashes mid-line',
        () {
      const reply = '## عنوان\n#### فرعي\nسطر فيه رقم #5 عادي';
      final out = formatAdvisorMessageContent(reply);
      expect(out, isNot(contains('##')));
      expect(out, contains('عنوان'));
      expect(out, contains('فرعي'));
      expect(out, contains('رقم #5 عادي'));
    });

    test('still strips bold markers, code fences and the plan marker', () {
      final out = formatAdvisorMessageContent(
        '**مهم**\n```\ncode\n```\n${AdvisorBranding.planMarker}',
      );
      expect(out, isNot(contains('**')));
      expect(out, isNot(contains('```')));
      expect(out, isNot(contains(AdvisorBranding.planMarker)));
      expect(out, contains('مهم'));
    });
  });
}
