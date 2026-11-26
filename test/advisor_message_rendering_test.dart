import 'package:acadegate/features/ai_advisor/advisor_branding.dart';
import 'package:acadegate/features/ai_advisor/advisor_message_format.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatAdvisorMessageContent markdown normalization', () {
    test('drops horizontal-rule lines of -, * and _', () {
      const reply = 'فقرة أولى\n---\nفقرة ثانية\n***\nفقرة ثالثة\n___\nالرابع';
      final out = formatAdvisorMessageContent(reply);
      expect(out, isNot(contains('---')));
      expect(out, isNot(contains('***')));
      expect(out, isNot(contains('___')));
      expect(out.split('\n'), hasLength(4));
    });

    test('keeps a dash-prefixed line that is a bullet, not a rule', () {
      final out = formatAdvisorMessageContent('- نقطة أولى\n- نقطة ثانية');
      expect(out, contains('- نقطة أولى'));
      expect(out, contains('- نقطة ثانية'));
    });

    test('converts pipe tables to plain lines and drops separator rows', () {
      const reply =
          '| Original | Correction |\n| --- | ---: |\n| yiel` | yield |';
      final out = formatAdvisorMessageContent(reply);
      expect(out, isNot(contains('|')));
      expect(out, contains('Original — Correction'));
      expect(out, contains('yiel — yield'));
    });

    test('strips single-asterisk italics but keeps 2*3 multiplication', () {
      final out =
          formatAdvisorMessageContent('*Scientific Reports* and 2*3=6');
      expect(out, contains('Scientific Reports'));
      expect(out, isNot(contains('*Scientific Reports*')));
      expect(out, contains('2*3=6'));
    });

    test('strips inline backticks', () {
      expect(formatAdvisorMessageContent('القيمة `yield` هنا'), 'القيمة yield هنا');
    });

    test('strips \$...\$ math delimiters, keeps currency dollars', () {
      expect(formatAdvisorMessageContent(r'where $p < 0.05$ holds'),
          'where p < 0.05 holds');
      expect(formatAdvisorMessageContent(r'unit is $WP$ here'), 'unit is WP here');
      expect(formatAdvisorMessageContent(r'costs $50 and $60 total'),
          r'costs $50 and $60 total');
    });

    test('converts "* " bullets to real bullets', () {
      final out = formatAdvisorMessageContent('* أولاً\n* ثانياً');
      expect(out, contains('• أولاً'));
      expect(out, contains('• ثانياً'));
    });

    test('still strips headings, bold, fences and the plan marker', () {
      final out = formatAdvisorMessageContent(
        '### عنوان\n**مهم**\n```\ncode\n```\n${AdvisorBranding.planMarker}',
      );
      expect(out, isNot(contains('###')));
      expect(out, isNot(contains('**')));
      expect(out, isNot(contains('```')));
      expect(out, isNot(contains(AdvisorBranding.planMarker)));
      expect(out, contains('عنوان'));
      expect(out, contains('مهم'));
    });
  });

  group('advisorTextDirectionFor', () {
    test('Arabic-dominant text is RTL', () {
      expect(advisorTextDirectionFor('هذه فقرة عربية كاملة عن الدراسة'),
          TextDirection.rtl);
    });

    test('English-dominant text is LTR', () {
      expect(
        advisorTextDirectionFor(
            'This study evaluated the effectiveness of drip irrigation.'),
        TextDirection.ltr,
      );
    });

    test('mixed text with few English terms stays RTL', () {
      expect(
        advisorTextDirectionFor(
            'أظهرت النتائج تحسناً في wheat yield بنسبة 18%'),
        TextDirection.rtl,
      );
    });

    test('mixed text that is mostly English with Arabic terms is LTR', () {
      expect(
        advisorTextDirectionFor(
            'The results showed improvement in wheat yield بنسبة كبيرة overall across seasons.'),
        TextDirection.ltr,
      );
    });

    test('empty and digit-only text defaults to RTL (app direction)', () {
      expect(advisorTextDirectionFor(''), TextDirection.rtl);
      expect(advisorTextDirectionFor('18% (2026)'), TextDirection.rtl);
    });
  });
}
