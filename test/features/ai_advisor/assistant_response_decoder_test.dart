import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/ai_advisor/assistant/assistant_response_decoder.dart';

Stream<List<int>> chunks(String body, {int width = 1}) async* {
  final bytes = utf8.encode(body);
  for (var i = 0; i < bytes.length; i += width) {
    yield bytes.sublist(i, i + width > bytes.length ? bytes.length : i + width);
  }
}

void main() {
  test('Arabic and emoji survive split UTF-8, mixed-case type, CRLF', () async {
    final deltas = <String>[];
    final result = await readAssistantResponse(
      chunks(
        '\uFEFF:keepalive\r\nevent: message\r\ndata: {"message":{"t":"أهلا 😀"}}\r\n\r\ndata: {"result":{"text":"أهلا 😀"}}\r\n\r\n',
      ),
      contentType: 'Text/Event-Stream; Charset=UTF-8',
      onDelta: deltas.add,
    );
    expect(deltas, ['أهلا 😀']);
    expect(result['text'], 'أهلا 😀');
  });
  test('missing or wrong header still identifies SSE', () async {
    for (final type in ['', 'application/json']) {
      final result = await readAssistantResponse(
        chunks('data: {"result":{"text":"ok"}}\n\n'),
        contentType: type,
        onDelta: (_) {},
      );
      expect(result['text'], 'ok');
    }
  });
  test('multiline event data, comments, id and retry fields', () async {
    final result = await readAssistantResponse(
      chunks(
        ': hello\nid: a\nretry: 3000\ndata: {"result":\ndata: {"text":"ok"}}\n\n',
      ),
      onDelta: (_) {},
    );
    expect(result['text'], 'ok');
  });
  test('pretty JSON fallback including incorrect SSE header', () async {
    for (final type in ['application/json', 'text/event-stream']) {
      final result = await readAssistantResponse(
        chunks(' \n{\n "result": {"text":"ok"}\n}'),
        contentType: type,
        onDelta: (_) {},
      );
      expect(result['text'], 'ok');
    }
  });
  test('callable errors in JSON and SSE retain code and message', () async {
    for (final body in [
      '{"error":{"status":"RESOURCE_EXHAUSTED","message":"quota"}}',
      'data: {"error":{"status":"RESOURCE_EXHAUSTED","message":"quota"}}\n\n',
    ]) {
      await expectLater(
        readAssistantResponse(chunks(body), onDelta: (_) {}),
        throwsA(
          isA<AssistantWireException>()
              .having((e) => e.code, 'code', 'resource-exhausted')
              .having((e) => e.message, 'message', 'quota'),
        ),
      );
    }
  });
  test('deltas without result and unterminated result fail', () async {
    for (final body in [
      '',
      'data: {"message":{"t":"partial"}}\n\n',
      'data: {"result":{"text":"cut"}}\n',
      'data: [DONE]\n\n',
    ]) {
      await expectLater(
        readAssistantResponse(chunks(body), onDelta: (_) {}),
        throwsA(isA<AssistantWireException>()),
      );
    }
  });
  test(
    'malformed JSON, invalid envelope, HTML and UTF-8 fail clearly',
    () async {
      for (final body in [
        'data: bad\n\n',
        'data: []\n\n',
        '{"result":[]}',
        '<html>gateway error</html>',
      ]) {
        await expectLater(
          readAssistantResponse(chunks(body), onDelta: (_) {}),
          throwsA(isA<AssistantWireException>()),
        );
      }
      await expectLater(
        readAssistantResponse(Stream.value([0xc3, 0x28]), onDelta: (_) {}),
        throwsA(isA<AssistantWireException>()),
      );
    },
  );
  test('non-success status cannot produce a successful result', () async {
    await expectLater(
      readAssistantResponse(
        chunks('{"result":{"text":"bad"}}'),
        statusCode: 502,
        onDelta: (_) {},
      ),
      throwsA(
        isA<AssistantWireException>().having(
          (e) => e.code,
          'code',
          'unavailable',
        ),
      ),
    );
  });
  test(
    'terminal result cancels stream without waiting for EOF or duplicating text',
    () async {
      var cancelled = false;
      final controller = StreamController<List<int>>(
        onCancel: () {
          cancelled = true;
        },
      );
      final deltas = <String>[];
      final future = readAssistantResponse(
        controller.stream,
        onDelta: deltas.add,
      );
      controller.add(
        utf8.encode(
          'data: {"message":{"t":"once"}}\n\ndata: {"result":{"text":"once"}}\n\ndata: {"message":{"t":"twice"}}\n\n',
        ),
      );
      final result = await future.timeout(const Duration(seconds: 1));
      expect(result['text'], 'once');
      expect(deltas, ['once']);
      expect(cancelled, isTrue);
      await controller.close();
    },
  );
  test('idle timeout remains visible', () async {
    final controller = StreamController<List<int>>();
    await expectLater(
      readAssistantResponse(
        controller.stream,
        onDelta: (_) {},
        idleTimeout: const Duration(milliseconds: 5),
      ),
      throwsA(isA<TimeoutException>()),
    );
    await controller.close();
  });
  test('oversized single line is bounded before line splitting', () async {
    await expectLater(
      readAssistantResponse(
        Stream.value(List.filled(8 * 1024 * 1024 + 1, 65)),
        onDelta: (_) {},
      ),
      throwsA(isA<AssistantWireException>()),
    );
  });
}
