import 'package:acadegate/features/academic_integrity/academic_translation_service.dart';
import 'package:acadegate/features/ai_advisor/assistant/assistant_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AcademicTranslationResult', () {
    test('fromMap parses the function response', () {
      final r = AcademicTranslationResult.fromMap(const {
        'translation': 'النص المترجم',
        'model': 'gemini-3.6-flash',
        'chunks': 2,
      });
      expect(r.translation, 'النص المترجم');
      expect(r.model, 'gemini-3.6-flash');
      expect(r.chunks, 2);
    });

    test('fromMap tolerates missing fields', () {
      final r = AcademicTranslationResult.fromMap(const {});
      expect(r.translation, '');
      expect(r.chunks, 0);
    });
  });

  group('AcademicTranslationService seam', () {
    tearDown(() => AcademicTranslationService.debugTranslate = null);

    test('debugTranslate short-circuits the live call', () async {
      AcademicTranslationService.debugTranslate =
          ({required text, required targetLang}) async =>
              AcademicTranslationResult(
                  translation: 'stub:$targetLang:$text', model: 'm', chunks: 1);
      final r = await AcademicTranslationService.instance
          .translate(text: 'hello', targetLang: 'ar');
      expect(r.translation, 'stub:ar:hello');
    });
  });

  group('assistant translate_academic_text tool', () {
    test('declares the tool with text and target_language params', () {
      final decl = AssistantToolbox.declarations
          .firstWhere((d) => d['name'] == 'translate_academic_text');
      final props = decl['parameters']['properties'] as Map<String, dynamic>;
      expect(props.keys, containsAll(<String>['text', 'target_language']));
      expect(decl['parameters']['required'],
          containsAll(<String>['text', 'target_language']));
    });

    test('executes through the injected translator and normalizes language',
        () async {
      String? gotText;
      String? gotLang;
      final box = AssistantToolbox(
        translate: (text, {required targetLang}) async {
          gotText = text;
          gotLang = targetLang;
          return 'الترجمة';
        },
      );
      final result = await box.execute('translate_academic_text', {
        'text': 'An abstract about irrigation.',
        'target_language': 'Arabic',
      });
      expect(result['translation'], 'الترجمة');
      expect(gotText, 'An abstract about irrigation.');
      expect(gotLang, 'ar');
    });

    test('rejects bad target language and overlong text', () async {
      final box = AssistantToolbox(
        translate: (text, {required targetLang}) async => 'x',
      );
      final badLang = await box.execute('translate_academic_text', {
        'text': 'hello there',
        'target_language': 'fr',
      });
      expect(badLang['error'], contains('target_language'));

      final tooLong = await box.execute('translate_academic_text', {
        'text': 'a' * 40001,
        'target_language': 'en',
      });
      expect(tooLong['error'], contains('too long'));

      final tooShort = await box.execute('translate_academic_text', {
        'text': 'hi',
        'target_language': 'en',
      });
      expect(tooShort['error'], contains('too short'));
    });

    test('has a brand-neutral chip label', () {
      expect(AssistantToolbox.statusLabel('translate_academic_text'),
          isNot(equals('translate_academic_text')));
    });
  });
}
