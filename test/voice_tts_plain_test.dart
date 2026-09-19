import 'package:acadegate/core/voice/readable_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plainForSpeech strips markdown and keeps spoken words', () {
    const raw = '**مرحباً**\n\nانظر [جدول 3](https://example.com) و`code`.';
    final spoken = ReadableText.forSpeech(raw, arabic: true);
    expect(spoken, contains('مرحباً'));
    expect(spoken, contains('جدول 3'));
    expect(spoken, isNot(contains('**')));
    expect(spoken, isNot(contains('https://')));
    expect(spoken, isNot(contains('`')));
  });

  test('display and speech drop raw LaTeX for R squared', () {
    const raw =
        'فسّر قيمة معامل التحديد (\$\$R^2\$\$) لنموذج Dubinin-Radushkevich';
    final shown = ReadableText.forDisplay(raw);
    expect(shown, contains('R²'));
    expect(shown, isNot(contains('\$')));
    expect(shown, contains('فسّر'));
    expect(shown, contains('Dubinin'));

    final spoken = ReadableText.forSpeech(raw, arabic: true);
    expect(spoken, contains('آر تربيع'));
    expect(spoken, isNot(contains('\$')));
    expect(spoken, contains('فسّر'));
  });

  test('speech segments keep Arabic and English runs', () {
    const spoken = 'فسّر للجنة نموذج Dubinin في جدول 19';
    final parts = ReadableText.speechSegments(spoken);
    expect(parts.any((p) => p.arabic && p.text.contains('فسّر')), isTrue);
    expect(parts.any((p) => !p.arabic && p.text.contains('Dubinin')), isTrue);
  });

}
