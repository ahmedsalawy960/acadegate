import 'package:acadegate/features/ai_advisor/assistant/assistant_reply_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AssistantReplyLanguage auto(String m) =>
      AssistantReplyLanguagePrefs.resolve(AssistantReplyLanguage.auto, m);

  test('auto follows the dominant language of the question', () {
    expect(auto('اقترح لي عناوين رسالة'), AssistantReplyLanguage.arabic);
    expect(auto('Suggest thesis titles on solar energy'), AssistantReplyLanguage.english);
  });

  test('English terms inside an Arabic question stay Arabic', () {
    expect(auto('أريد جهاز HPLC لتحليل عينات Paracetamol'), AssistantReplyLanguage.arabic);
  });

  test('one Arabic word inside an English question stays English', () {
    expect(auto('Find an HPLC lab in الشرقية for my samples please'), AssistantReplyLanguage.english);
  });

  test('manual choice overrides the question language', () {
    expect(
      AssistantReplyLanguagePrefs.resolve(AssistantReplyLanguage.english, 'سؤال بالعربية'),
      AssistantReplyLanguage.english,
    );
    expect(
      AssistantReplyLanguagePrefs.resolve(AssistantReplyLanguage.arabic, 'English question'),
      AssistantReplyLanguage.arabic,
    );
  });
}
