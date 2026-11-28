import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/community/starter_text.dart';

void main() {
  test('picks the Arabic or English part of a starter title', () {
    const raw = 'أهلاً بك | Welcome';
    expect(
      pickStarterLanguage(raw, separator: kStarterTitleSeparator, english: false),
      'أهلاً بك',
    );
    expect(
      pickStarterLanguage(raw, separator: kStarterTitleSeparator, english: true),
      'Welcome',
    );
  });

  test('room title keeps the Arabic prefix only in Arabic', () {
    const raw = 'غرفة: ابدأ | Start your research';
    expect(
      pickStarterLanguage(raw, separator: kStarterTitleSeparator, english: true),
      'Start your research',
    );
  });

  test('splits a starter body on the divider line', () {
    const raw = 'نص عربي\nسطر\n\n———\n\nEnglish text\nline';
    expect(
      pickStarterLanguage(raw, separator: kStarterBodySeparator, english: true),
      'English text\nline',
    );
    expect(
      pickStarterLanguage(raw, separator: kStarterBodySeparator, english: false),
      'نص عربي\nسطر',
    );
  });

  test('falls back to the full text when the separator is missing or a side is empty', () {
    expect(
      pickStarterLanguage('No separator', separator: kStarterTitleSeparator, english: true),
      'No separator',
    );
    expect(
      pickStarterLanguage(' | English only', separator: kStarterTitleSeparator, english: true),
      ' | English only',
    );
  });
}
