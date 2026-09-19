import '../ai_advisor/gemini_advisor_client.dart';
import '../profile/academic_profile.dart';

/// ترتيب خفيف بـ Gemini لاختيار أفضل مرشح ضمن قائمة مُصفّاة مسبقاً بالتخصص.
class HomeForYouAi {
  HomeForYouAi._();

  /// يعيد فهرس المرشح الأفضل (0-based)، أو null عند الفشل/التعذر.
  static Future<int?> pickBestIndex({
    required AcademicProfile profile,
    required String kindAr,
    required String kindEn,
    required List<String> candidates,
  }) async {
    if (candidates.length <= 1) {
      return candidates.isEmpty ? null : 0;
    }

    final client = GeminiAdvisorClient.instance;
    if (!GeminiAdvisorClient.canUseCloudBackend &&
        !GeminiAdvisorClient.hasLocalKey) {
      return null;
    }

    final faculty = profile.resolvedFacultyCategory ?? '';
    final lines = [
      for (var i = 0; i < candidates.length; i++) '${i + 1}. ${candidates[i]}',
    ].join('\n');

    final system = '''
You rank academic recommendations for a postgraduate researcher.
Pick ONLY the single best match for their faculty and specialization.
Reply with ONE integer only: the candidate number (1-${candidates.length}).
No words, no markdown.
''';

    final user = '''
Faculty/category: $faculty
Specialization: ${profile.specialization}
Research interest: ${profile.researchInterest}
Degree: ${profile.degree}

Kind: $kindEn ($kindAr)
Candidates:
$lines
''';

    try {
      final result = await client
          .generateResult(
            systemPrompt: system,
            userMessage: user,
            maxOutputTokens: 16,
          )
          .timeout(const Duration(seconds: 8));
      if (!result.isSuccess) return null;
      final match = RegExp(r'\d+').firstMatch(result.text!.trim());
      if (match == null) return null;
      final n = int.tryParse(match.group(0)!);
      if (n == null || n < 1 || n > candidates.length) return null;
      return n - 1;
    } catch (_) {
      return null;
    }
  }
}
