import 'package:flutter/foundation.dart';

import '../../core/locale/app_translate.dart';
import '../../core/voice/readable_text.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import '../profile/academic_profile_service.dart';
import 'viva_committee.dart';
import 'viva_local_engine.dart';
import 'viva_models.dart';
import 'viva_question_banks.dart';

class VivaService {
  VivaService._();

  static final VivaService instance = VivaService._();

  final _local = VivaLocalEngine.instance;

  bool get isCloudEnabled => GeminiAdvisorClient.isAvailable;

  /// Windows exits when this screen talks to Gemini while speech engines
  /// are loaded. Questions already extracted from the thesis are local.
  bool get _cloudQuestionsEnabled =>
      isCloudEnabled &&
      (kIsWeb || defaultTargetPlatform != TargetPlatform.windows);

  int _counter = 0;
  String _nextId() => 'viva_${++_counter}';

  Future<VivaSessionConfig?> configFromProfile() async {
    final profile = await AcademicProfileService.instance.loadProfile();
    if (profile == null) return null;
    return VivaSessionConfig(
      thesisTitle: profile.researchInterest,
      thesisSummary: appTr(
        'دراسة في ${profile.specialization} بمنهجية ${profile.methodology}. '
            'الاهتمام البحثي: ${profile.researchInterest}. '
            'الجامعة: ${profile.university}.',
        'A study in ${profile.specialization} using ${profile.methodology} methodology. '
            'Research interest: ${profile.researchInterest}. '
            'University: ${profile.university}.',
      ),
      degree: profile.degree,
      methodology: profile.methodology,
      specialization: profile.specialization,
      university: profile.university,
      facultyCategoryId: profile.resolvedFacultyCategory,
    );
  }

  VivaMessage systemMessage(String content) => VivaMessage(
        id: _nextId(),
        role: VivaMessageRole.system,
        content: content,
        createdAt: DateTime.now(),
      );

  VivaMessage committeeMessage({
    required VivaCommitteeMember member,
    required String content,
  }) =>
      VivaMessage(
        id: _nextId(),
        role: VivaMessageRole.committee,
        memberId: member.id,
        content: content,
        createdAt: DateTime.now(),
      );

  VivaMessage studentMessage(String content) => VivaMessage(
        id: _nextId(),
        role: VivaMessageRole.student,
        content: content,
        createdAt: DateTime.now(),
      );

  Future<String> generateQuestion({
    required VivaSessionConfig config,
    required VivaCommitteeMember member,
    required int questionIndex,
    required List<VivaMessage> history,
  }) async {
    if (_cloudQuestionsEnabled) {
      try {
        final cloud = await _cloudQuestion(
          config: config,
          member: member,
          questionIndex: questionIndex,
          history: history,
        );
        if (cloud != null && cloud.trim().isNotEmpty) {
          return ReadableText.forDisplay(cloud);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Viva cloud question failed, using local question: $e');
        }
      }
    }
    return ReadableText.forDisplay(
      _local.askQuestion(
        config: config,
        member: member,
        questionIndex: questionIndex,
        history: history,
      ),
    );
  }

  Future<VivaReport> generateReport({
    required VivaSessionConfig config,
    required List<VivaMessage> history,
  }) async {
    VivaReport report;
    if (_cloudQuestionsEnabled) {
      final cloud = await _cloudReport(config: config, history: history);
      report = cloud ?? _local.buildReport(config: config, history: history);
    } else {
      report = _local.buildReport(config: config, history: history);
    }
    if (config.issues.isEmpty) return report;
    final fromThesis = config.issues
        .take(8)
        .map(
          (i) => appTr(
            'من الرسالة [${i.kind}]: ${i.label}',
            'From the thesis [${i.kind}]: ${i.label}',
          ),
        )
        .where((line) => !report.weaknesses.contains(line))
        .toList();
    if (fromThesis.isEmpty) return report;
    return VivaReport(
      weaknesses: [...fromThesis, ...report.weaknesses],
      methodologyGaps: report.methodologyGaps,
      expectedQuestions: report.expectedQuestions,
      preparationTips: report.preparationTips,
      overallAssessment: report.overallAssessment,
      fromCloudAi: report.fromCloudAi,
    );
  }

  String introMessage(VivaSessionConfig? config) =>
      _local.introMessage(mode: config?.answerMode ?? VivaAnswerMode.written);

  Future<String?> _cloudQuestion({
    required VivaSessionConfig config,
    required VivaCommitteeMember member,
    required int questionIndex,
    required List<VivaMessage> history,
  }) async {
    final transcript = _formatHistory(
      history,
      supervisorFromThesis: config.supervisorFromThesis,
    );
    final maxQ = config.resolvedQuestionCount;
    final styleGuide = VivaQuestionBanks.cloudStyleGuide(
      facultyCategoryId: config.facultyCategoryId,
      specialization: config.specialization,
      questionIndex: questionIndex,
      maxQuestions: maxQ,
    );
    final system = appTr(
      'أنت ${member.displayName} (${member.displayRole}) في مناقشة رسالة ${config.degree}. '
          'اطرح سؤالاً واحداً فقط بالعربية الأكاديمية. '
          'إن وُجدت PreparedVivaQuestionsFromThesis فاستخدم السؤال رقم ${questionIndex + 1} (أو أقرب سؤال غير مكرر) مع الإبقاء على خصوصية الرسالة. '
          'وإلا فناقش إحدى IssuesAndCommentsFromThesis مع اقتباس. '
          'يجب أن يشير السؤال إلى نقطة من الرسالة. ممنوع الأسئلة العامة لأي رسالة. '
          'ممنوع اختلاق اسم مشرف أو مناقش — استخدم الدور فقط. '
          'اكتب الرموز بنص عادي مثل R² وليس LaTeX. لا تقدم إجابة — السؤال فقط.\n\n$styleGuide',
      'You are ${member.displayName} (${member.displayRole}) in a ${config.degree} thesis defense. '
          'Ask exactly ONE question in clear academic English. '
          'If PreparedVivaQuestionsFromThesis exists, use question ${questionIndex + 1} (or the nearest unused one) and keep the thesis-specific content. '
          'Otherwise interrogate one IssuesAndCommentsFromThesis item with a quote. '
          'The question MUST point to this thesis. Forbidden: generic questions. '
          'Do not invent a supervisor or examiner personal name — use the role only. '
          'Write symbols as plain text such as R², never LaTeX. Do not answer — question only.\n\n$styleGuide',
    );
    final user = '${config.aiContextBlock}\n\n'
        '${appTr(
          'اصنع السؤال من محتوى الرسالة أعلاه فقط — إن وُجدت أسئلة مُعدّة فاستخدم السؤال رقم ${questionIndex + 1}. '
              'وإلا فناقش ملاحظة/خطأ مقتبساً من IssuesAndCommentsFromThesis.',
          'Build the question from the thesis materials above only — if prepared questions exist, use question ${questionIndex + 1}. '
              'Otherwise interrogate a quoted issue from IssuesAndCommentsFromThesis.',
        )}\n\n'
        '${appTr('سجل المحاكاة', 'Simulation log')}:\n$transcript\n\n'
        '${appTr('رقم السؤال', 'Question number')}: ${questionIndex + 1} / $maxQ';

    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: system,
      userMessage: user,
      maxOutputTokens: 800,
    );
    final text = result.text?.trim();
    if (text == null || text.isEmpty) return null;
    return text.replaceAll(RegExp(r'^["\s]+|["\s]+$'), '');
  }

  Future<VivaReport?> _cloudReport({
    required VivaSessionConfig config,
    required List<VivaMessage> history,
  }) async {
    final transcript = _formatHistory(
      history,
      supervisorFromThesis: config.supervisorFromThesis,
    );
    final system = appTr(
      'أنت خبير في تقييم مناقشات الرسائل العلمية. '
          'أنتج تقريراً منظماً بالعربية بالأقسام التالية فقط (كل قسم بنقاط):\n'
          '1) نقاط الضعف\n'
          '2) فجوات منهجية\n'
          '3) أسئلة متوقعة في المناقشة الحقيقية\n'
          '4) نصائح التحضير\n'
          '5) التقييم العام (فقرة قصيرة)\n'
          '6) أخطاء وملاحظات من الرسالة (إن وُجدت IssuesAndCommentsFromThesis — اقتبس ولا تختلق)',
      'You are an expert in thesis defense assessment. '
          'Produce a structured report in English with only these sections (bullets each):\n'
          '1) Weaknesses\n'
          '2) Methodology gaps\n'
          '3) Likely questions in the real viva\n'
          '4) Preparation tips\n'
          '5) Overall assessment (short paragraph)\n'
          '6) Errors and comments from the thesis (if IssuesAndCommentsFromThesis exists — quote, do not invent)',
    );
    final user = '${config.aiContextBlock}\n\n'
        '${appTr('محادثة المحاكاة', 'Simulation dialogue')}:\n$transcript';

    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: system,
      userMessage: user,
      maxOutputTokens: 4096,
    );
    final text = result.text?.trim();
    if (text == null || text.isEmpty) return null;
    return _parseReportFromCloud(text);
  }

  String _formatHistory(
    List<VivaMessage> history, {
    String? supervisorFromThesis,
  }) {
    final buffer = StringBuffer();
    for (final msg in history) {
      if (msg.role == VivaMessageRole.system) continue;
      final label = switch (msg.role) {
        VivaMessageRole.committee => () {
            final m = msg.memberId != null
                ? VivaCommittee.byId(
                    msg.memberId!,
                    supervisorFromThesis: supervisorFromThesis,
                  ).displayName
                : appTr('لجنة', 'Committee');
            return m;
          }(),
        VivaMessageRole.student => appTr('الطالب', 'Student'),
        VivaMessageRole.system => '',
      };
      buffer.writeln('$label: ${msg.content}\n');
    }
    return buffer.toString();
  }

  VivaReport _parseReportFromCloud(String text) {
    List<String> section(String ar, String en) {
      final title = appTr(ar, en);
      final alt = appTr(en, ar);
      for (final key in [title, ar, en, alt]) {
        final idx = text.indexOf(key);
        if (idx >= 0) {
          final rest = text.substring(idx + key.length);
          final lines = rest
              .split('\n')
              .map((l) => l.replaceAll(RegExp(r'^[-•*\d.)\s]+'), '').trim())
              .where((l) => l.isNotEmpty && !l.startsWith('#'))
              .take(8)
              .toList();
          if (lines.isNotEmpty) return lines;
        }
      }
      return const [];
    }

    final weaknesses = section('نقاط الضعف', 'Weaknesses');
    final gaps = section('فجوات منهجية', 'Methodology gaps');
    final expected = section('أسئلة متوقعة', 'Likely questions');
    final tips = section('نصائح التحضير', 'Preparation tips');
    final extractedIssues = section('أخطاء وملاحظات', 'Errors and comments');

    return VivaReport(
      weaknesses: [
        ...extractedIssues,
        if (weaknesses.isNotEmpty)
          ...weaknesses
        else if (extractedIssues.isEmpty)
          text.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => text),
      ],
      methodologyGaps: gaps.isNotEmpty
          ? gaps
          : [
              appTr(
                'راجع الفصل المنهجي وربطه بأسئلة البحث.',
                'Review the methodology chapter and its link to research questions.',
              ),
            ],
      expectedQuestions: expected.isNotEmpty
          ? expected
          : [
              appTr(
                'ما المساهمة الأصلية لدراستك؟',
                'What is the original contribution of your study?',
              ),
            ],
      preparationTips: tips.isNotEmpty
          ? tips
          : [
              appTr(
                'تدرّب على إجابات مدتها دقيقتان لكل سؤال رئيسي.',
                'Practice two-minute answers for each main question.',
              ),
            ],
      overallAssessment: appTr(
        'تقرير مبني على محاكاة المناقشة.',
        'Cloud AI report based on the defense simulation.',
      ),
      fromCloudAi: true,
    );
  }

  VivaCommitteeMember memberForQuestionIndex(
    int index, {
    String? supervisorFromThesis,
  }) {
    final members = VivaCommittee.lineup(
      supervisorFromThesis: supervisorFromThesis,
    );
    return members[index % members.length];
  }
}
