import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/ai_advisor/assistant/assistant_attachment_payload.dart';

void main() {
  test('inline payload preserves filename for every allowed extension', () {
    for (final ext in [
      'png',
      'jpg',
      'jpeg',
      'webp',
      'pdf',
      'doc',
      'docx',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
      'txt',
      'md',
      'csv',
      'tsv',
    ]) {
      final name = 'اختبار.$ext';
      final payload = buildAssistantAttachmentPayload(
        fileName: name,
        mimeType: 'application/octet-stream',
        base64Data: 'YWJj',
      );
      expect(payload, {
        'fileName': name,
        'mimeType': 'application/octet-stream',
        'base64Data': 'YWJj',
      }, reason: ext);
    }
  });

  test('storage payload preserves filename and omits empty inline data', () {
    expect(
      buildAssistantAttachmentPayload(
        fileName: 'sample.pdf',
        mimeType: 'application/pdf',
        base64Data: '  ',
        storagePath: 'uploads/test/advisor/chat/sample.pdf',
      ),
      {
        'fileName': 'sample.pdf',
        'mimeType': 'application/pdf',
        'storagePath': 'uploads/test/advisor/chat/sample.pdf',
      },
    );
  });

  test('empty storage path is omitted, inline data is not rewritten', () {
    expect(
      buildAssistantAttachmentPayload(
        fileName: 'sample.jpg',
        mimeType: 'image/jpeg',
        base64Data: ' YWJj ',
        storagePath: '  ',
      ),
      {
        'fileName': 'sample.jpg',
        'mimeType': 'image/jpeg',
        'base64Data': ' YWJj ',
      },
    );
  });

  test('both populated transport fields retain existing behavior', () {
    final payload = buildAssistantAttachmentPayload(
      fileName: 'sample.csv',
      mimeType: 'text/csv',
      base64Data: 'YWJj',
      storagePath: 'uploads/test/advisor/chat/sample.csv',
    );
    expect(payload.keys.toSet(), {
      'fileName',
      'mimeType',
      'base64Data',
      'storagePath',
    });
  });
}
