import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/ai_advisor/advisor_personalization_policy.dart';

void main() {
  test('profile text is quoted data, including quotes and newlines', () {
    const raw = 'Interest: water\n"topic" {DATE}';
    final encoded = AdvisorPersonalizationPolicy.contextData(raw);
    expect(jsonDecode(encoded), raw);
    expect(encoded.contains('\n'), isFalse);
  });
  test(
    'Arabic and English policies cover current question, relevance and evidence',
    () {
      expect(AdvisorPersonalizationPolicy.ar, contains('طلب المستخدم الحالي'));
      expect(AdvisorPersonalizationPolicy.ar, contains('تجاهلها تماما'));
      expect(AdvisorPersonalizationPolicy.ar, contains('لا تستنتج علاقة'));
      expect(AdvisorPersonalizationPolicy.ar, contains('فرضية غير متحققة'));
      expect(
        AdvisorPersonalizationPolicy.en,
        contains('current request sets the topic'),
      );
      expect(
        AdvisorPersonalizationPolicy.en,
        contains('otherwise omit it completely'),
      );
      expect(
        AdvisorPersonalizationPolicy.en,
        contains('Never infer a scientific'),
      );
      expect(
        AdvisorPersonalizationPolicy.en,
        contains('label an exploratory idea as unverified'),
      );
    },
  );
}
