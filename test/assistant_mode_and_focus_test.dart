import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/ai_advisor/ai_advisor_service.dart';
import 'package:acadegate/features/ai_advisor/assistant/academic_assistant_client.dart';

void main() {
  group('wantsDeepThinking', () {
    test('substantive editing, citation, and presentation requests go deep', () {
      expect(
        AiAdvisorService.wantsDeepThinking('أريد تحرير هذا النص وتحسين صياغته الأكاديمية'),
        isTrue,
      );
      expect(
        AiAdvisorService.wantsDeepThinking('رتب هذه المراجع بأسلوب APA لو سمحت'),
        isTrue,
      );
      expect(
        AiAdvisorService.wantsDeepThinking('جهز هيكل عرض تقديمي للمناقشة من فضلك'),
        isTrue,
      );
    });

    test('short messages stay fast and long ones go deep', () {
      expect(AiAdvisorService.wantsDeepThinking('شكرا لك'), isFalse);
      final long = 'أ' * 170;
      expect(AiAdvisorService.wantsDeepThinking(long), isTrue);
    });

    test('attachments always request deep', () {
      expect(AiAdvisorService.wantsDeepThinking('حلل', hasAttachments: true), isTrue);
    });
  });

  group('specialistFocusBlock', () {
    test('injects the routed specialist persona', () {
      final focus = AcademicAssistantClient.specialistFocusBlock(
        'أريد تحرير هذا النص وتحسين صياغته الأكاديمية',
      );
      expect(focus, contains('التخصص النشط'));
      expect(focus, contains('التحرير الأكاديمي'));
    });

    test('stays empty for general chat and catalog requests', () {
      expect(AcademicAssistantClient.specialistFocusBlock('شكرا لك'), isEmpty);
      expect(
        AcademicAssistantClient.specialistFocusBlock('أريد HPLC في الشرقية'),
        isEmpty,
      );
    });

    test('never leaks a model or vendor name into the prompt block', () {
      for (final m in [
        'أريد تحرير هذا النص وتحسين صياغته الأكاديمية',
        'رتب هذه المراجع بأسلوب APA لو سمحت',
        'اقترح لي عناوين رسالة في الطاقة الشمسية',
      ]) {
        final focus = AcademicAssistantClient.specialistFocusBlock(m).toLowerCase();
        expect(focus.contains('gemini'), isFalse);
        expect(focus.contains('openai'), isFalse);
      }
    });
  });

  group('wantsCodeExecution', () {
    test('statistics and simulation turns enable it', () {
      expect(
        AcademicAssistantClient.wantsCodeExecution(
          'حلل هذه البيانات إحصائياً واذكر الاختبار المناسب',
        ),
        isTrue,
      );
      expect(
        AcademicAssistantClient.wantsCodeExecution(
          'محاكاة نتائج دراسة كمية عن رضا الطلاب',
        ),
        isTrue,
      );
    });

    test('ordinary questions do not enable it', () {
      expect(AcademicAssistantClient.wantsCodeExecution('شكرا لك'), isFalse);
      expect(
        AcademicAssistantClient.wantsCodeExecution(
          'رتب هذه المراجع بأسلوب APA لو سمحت',
        ),
        isFalse,
      );
    });
  });
}
