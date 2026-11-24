import 'package:acadegate/features/ai_advisor/advisor_attachment.dart';
import 'package:acadegate/features/ai_advisor/advisor_chat_store.dart';
import 'package:acadegate/features/ai_advisor/advisor_message.dart';
import 'package:flutter_test/flutter_test.dart';

AdvisorMessage _msg(String content, {List<AdvisorAttachment> attachments = const []}) =>
    AdvisorMessage(
      id: 'm1',
      role: AdvisorMessageRole.user,
      content: content,
      createdAt: DateTime(2026, 11, 24),
      attachments: attachments,
    );

const _file = AdvisorAttachment(
  name: 'data.pdf',
  mimeType: 'application/pdf',
  url: '',
  isImage: false,
);

void main() {
  group('isReloadableMessage', () {
    test('drops true placeholders but keeps attachment-only turns', () {
      expect(AdvisorChatStore.isReloadableMessage(_msg('')), isFalse);
      expect(AdvisorChatStore.isReloadableMessage(_msg('   ')), isFalse);
      expect(AdvisorChatStore.isReloadableMessage(_msg('', attachments: [_file])), isTrue);
      expect(AdvisorChatStore.isReloadableMessage(_msg('سؤال')), isTrue);
      expect(AdvisorChatStore.isReloadableMessage(_msg('سؤال', attachments: [_file])), isTrue);
    });
  });

  group('newAdvisorMessageId', () {
    test('sequential ids never repeat within a session', () {
      final ids = {for (var i = 1; i <= 50; i++) newAdvisorMessageId(i)};
      expect(ids.length, 50);
    });

    test('the same sequence number after a restart gets a fresh id', () async {
      final before = newAdvisorMessageId(1);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final afterRestart = newAdvisorMessageId(1);
      expect(before, isNot(afterRestart));
    });

    test('ids never collapse to the old per-session counter shape', () {
      expect(newAdvisorMessageId(1), isNot('msg_1'));
    });
  });
}
