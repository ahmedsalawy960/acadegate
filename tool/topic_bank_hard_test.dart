/// اختبار مسار 5 — تشابه عناوين + حزمة اعتماد (بدون شبكة إن أمكن).
/// تشغيل: dart run tool/topic_bank_hard_test.dart
import 'package:acadegate/features/topic_bank/topic_similarity.dart';

void main() {
  var failed = 0;
  failed += _sec('تطبيع عربي', () {
    _expect(
      TopicSimilarity.normalize('دراسةُ أثرِ التعلُّم') ==
          TopicSimilarity.normalize('دراسه اثر التعلم'),
      'normalize',
    );
  });
  failed += _sec('تشابه مرتفع لنفس العنوان', () {
    final s = TopicSimilarity.score(
      'أثر التعلم النشط على التحصيل الدراسي لدى تلاميذ المرحلة الابتدائية',
      'أثر التعلم النشط على التحصيل الدراسي لدى تلاميذ المرحلة الابتدائية بمصر',
    );
    _expect(s >= 0.55, 'expected medium+ got $s');
  });
  failed += _sec('تشابه منخفض لموضوع مختلف', () {
    final s = TopicSimilarity.score(
      'أثر التعلم النشط على التحصيل',
      'حوكمة الذكاء الاصطناعي في القرارات الإدارية',
    );
    _expect(s < 0.35, 'expected distant got $s');
  });
  failed += _sec('تسميات المخاطر', () {
    _expect(TopicSimilarity.riskLabelAr(0.8).contains('مرتفع'), 'high');
    _expect(TopicSimilarity.riskLabelEn(0.4).contains('Low'), 'low');
  });

  print(failed == 0
      ? '\nالنتيجة: نجاح اختبارات بنك الموضوعات (تشابه).'
      : '\nالنتيجة: فشل $failed.');
}

int _sec(String n, void Function() fn) {
  try {
    fn();
    print('صح — $n');
    return 0;
  } catch (e) {
    print('خطأ — $n\n  $e');
    return 1;
  }
}

void _expect(bool c, String m) {
  if (!c) throw StateError(m);
}
