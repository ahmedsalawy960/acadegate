import '../../core/locale/app_translate.dart';
import 'import_models.dart';

class OpenAlexAuthorQuality {
  final int score;
  final String tierLabel;
  final List<String> warnings;
  final List<String> strengths;

  const OpenAlexAuthorQuality({
    required this.score,
    required this.tierLabel,
    this.warnings = const [],
    this.strengths = const [],
  });

  bool get isWeak => score < 45;

  static OpenAlexAuthorQuality evaluate(OpenAlexAuthor author) {
    var score = 0;
    final warnings = <String>[];
    final strengths = <String>[];

    if (author.worksCount >= 30) {
      score += 25;
      strengths.add(
        appTr('منشورات كثيرة', 'Many publications'),
      );
    } else if (author.worksCount >= 10) {
      score += 18;
    } else if (author.worksCount >= 3) {
      score += 10;
    } else {
      warnings.add(
        appTr('عدد منشورات قليل جداً', 'Very few publications'),
      );
    }

    if (author.citedByCount >= 500) {
      score += 25;
      strengths.add(appTr('استشهادات عالية', 'High citations'));
    } else if (author.citedByCount >= 100) {
      score += 18;
    } else if (author.citedByCount >= 20) {
      score += 10;
    } else {
      warnings.add(
        appTr('استشهادات منخفضة', 'Low citations'),
      );
    }

    if (author.hIndex >= 10) {
      score += 20;
      strengths.add(appTr('h-index جيد', 'Solid h-index'));
    } else if (author.hIndex >= 3) {
      score += 12;
    } else if (author.hIndex > 0) {
      score += 6;
    } else {
      warnings.add(appTr('بدون h-index واضح', 'No clear h-index'));
    }

    if (author.orcid != null && author.orcid!.isNotEmpty) {
      score += 12;
      strengths.add('ORCID');
    } else {
      warnings.add(appTr('بدون ORCID للتحقق', 'No ORCID for verification'));
    }

    if (author.institutionName.trim().isNotEmpty) {
      score += 8;
    } else {
      warnings.add(
        appTr('الجامعة غير واضحة في OpenAlex', 'University unclear in OpenAlex'),
      );
    }

    if (author.tags.length >= 3) {
      score += 5;
    }

    if (author.lastPublicationYear != null &&
        author.lastPublicationYear! >= DateTime.now().year - 5) {
      score += 5;
      strengths.add(appTr('نشاط حديث', 'Recent activity'));
    } else if (author.lastPublicationYear != null &&
        author.lastPublicationYear! < DateTime.now().year - 10) {
      warnings.add(
        appTr('آخر نشاط قديم', 'Last activity is old'),
      );
    }

    final clamped = score.clamp(0, 100);
    final tierLabel = _tierLabel(clamped);

    return OpenAlexAuthorQuality(
      score: clamped,
      tierLabel: tierLabel,
      warnings: warnings.take(3).toList(),
      strengths: strengths.take(3).toList(),
    );
  }

  static String _tierLabel(int score) {
    if (score >= 70) {
      return appTr('ملف قوي', 'Strong profile');
    }
    if (score >= 45) {
      return appTr('ملف متوسط — راجع يدوياً', 'Moderate — review manually');
    }
    return appTr('ملف ضعيف — تحقق قبل الاستيراد', 'Weak — verify before import');
  }
}
