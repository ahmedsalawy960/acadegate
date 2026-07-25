import '../../core/locale/app_translate.dart';
import 'viva_committee.dart';
import 'viva_models.dart';
import 'viva_question_banks.dart';

class VivaLocalEngine {
  VivaLocalEngine._();

  static final VivaLocalEngine instance = VivaLocalEngine._();

  String introMessage({VivaAnswerMode mode = VivaAnswerMode.written}) {
    if (mode == VivaAnswerMode.oral) {
      return appTr(
        'مرحباً. نحن لجنة المناقشة الافتراضية — الجلسة شفهية. '
            'استمع للسؤال ثم أجب بصوتك كما في المناقشة الحقيقية.',
        'Welcome. We are the virtual defense committee — this session is oral. '
            'Listen to each question then answer aloud as in a real viva.',
      );
    }
    return appTr(
      'مرحباً. نحن لجنة المناقشة الافتراضية — الجلسة كتابية. '
          'اكتب إجاباتك بوضوح كما ستفعل أمام اللجنة الفعلية.',
      'Welcome. We are the virtual defense committee — this session is written. '
          'Type clear answers as you would before the actual committee.',
    );
  }

  String askQuestion({
    required VivaSessionConfig config,
    required VivaCommitteeMember member,
    required int questionIndex,
    required List<VivaMessage> history,
  }) {
    final grounded = _thesisGroundedQuestion(
      config: config,
      questionIndex: questionIndex,
    );
    if (grounded != null) return grounded;

    final bank = VivaQuestionBanks.forMember(
      memberId: member.id,
      facultyCategoryId: config.facultyCategoryId,
    );
    final pair = bank[questionIndex % bank.length];
    var text = appTr(pair[0], pair[1]);
    text = text
        .replaceAll('{title}', config.thesisTitle)
        .replaceAll('{methodology}', config.methodology)
        .replaceAll(
          '{specialization}',
          config.specialization.isNotEmpty
              ? config.specialization
              : appTr('تخصصك', 'your field'),
        );

    final asked =
        history.where((m) => m.role == VivaMessageRole.committee).length;
    if (asked > 1 && questionIndex.isOdd) {
      final snippet = _snippet(config, maxLen: 90);
      if (snippet != null) {
        return appTr(
          'بناءً على إجابتك السابقة، وكيف تربطها بما ورد في رسالتك: «$snippet»؟',
          'Based on your previous answer, how do you link it to what your thesis states: «$snippet»?',
        );
      }
      final followUps = [
        appTr(
          'بناءً على إجابتك السابقة: هل يمكنك التوسع بمثال من بياناتك؟',
          'Based on your previous answer: can you expand with an example from your data?',
        ),
        appTr(
          'وضح أكثر: ما الدليل الأقوى الذي تستند إليه في هذه النقطة؟',
          'Clarify further: what is the strongest evidence you rely on for this point?',
        ),
        appTr(
          'كيف ترد لو اعترض المناقش على هذا التفسير؟',
          'How would you respond if an examiner challenged this interpretation?',
        ),
      ];
      return followUps[questionIndex % followUps.length];
    }
    return text;
  }

  /// أسئلة مبنية على مقتطفات من الملخص / سياق المناقشة / مقتطف PDF.
  String? _thesisGroundedQuestion({
    required VivaSessionConfig config,
    required int questionIndex,
  }) {
    final snippets = _collectSnippets(config);
    if (snippets.isEmpty) return null;

    final snippet = snippets[questionIndex % snippets.length];
    final templates = <List<String>>[
      [
        'في رسالتك ورد: «$snippet». كيف تدافع عن هذه النقطة أمام اللجنة؟',
        'Your thesis states: «$snippet». How would you defend this point before the committee?',
      ],
      [
        'بناءً على ما ذكرتَه: «$snippet» — ما حدود هذا الادعاء أو التعميم؟',
        'Given what you wrote: «$snippet» — what are the limits of this claim or generalization?',
      ],
      [
        'كيف ترتبط عبارة «$snippet» بأسئلتك البحثية ومنهجية «${config.methodology}»؟',
        'How does «$snippet» connect to your research questions and «${config.methodology}» methodology?',
      ],
      [
        'لو اعترض المناقش على «$snippet»، ما الدليل الأقوى من بياناتك؟',
        'If an examiner challenged «$snippet», what is the strongest evidence from your data?',
      ],
      [
        'ما الذي يميز دراستك «${config.thesisTitle}» عن الدراسات السابقة في ضوء: «$snippet»؟',
        'What distinguishes your study «${config.thesisTitle}» from prior work in light of: «$snippet»?',
      ],
      [
        'وضّح للجنة كيف توصلت إلى: «$snippet»، وهل يمكن تفسيره ببديل آخر؟',
        'Explain to the committee how you arrived at: «$snippet», and whether an alternative interpretation is possible?',
      ],
    ];
    final pair = templates[questionIndex % templates.length];
    return appTr(pair[0], pair[1]);
  }

  List<String> _collectSnippets(VivaSessionConfig config) {
    final chunks = <String>[];
    void addFrom(String? source) {
      if (source == null || source.trim().isEmpty) return;
      final cleaned = source
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      // قسّم إلى جمل قصيرة قابلة للاقتباس في السؤال.
      final parts = cleaned.split(RegExp(r'[.!؟?\n•]+'));
      for (final part in parts) {
        final t = part.trim();
        if (t.length < 28) continue;
        chunks.add(t.length > 110 ? '${t.substring(0, 110)}…' : t);
        if (chunks.length >= 8) return;
      }
    }

    addFrom(config.defenseContext);
    addFrom(config.thesisExcerpt);
    addFrom(config.thesisSummary);
    return chunks;
  }

  String? _snippet(VivaSessionConfig config, {int maxLen = 80}) {
    final list = _collectSnippets(config);
    if (list.isEmpty) return null;
    final s = list.first;
    return s.length > maxLen ? '${s.substring(0, maxLen)}…' : s;
  }

  VivaReport buildReport({
    required VivaSessionConfig config,
    required List<VivaMessage> history,
  }) {
    final answers = history
        .where((m) => m.role == VivaMessageRole.student)
        .map((m) => m.content)
        .toList();
    final avgAnswerLen = answers.isEmpty
        ? 0
        : answers.map((a) => a.length).reduce((a, b) => a + b) ~/ answers.length;

    final weaknesses = <String>[
      if (avgAnswerLen < 80)
        appTr(
          'إجاباتك كانت مختصرة جداً — في المناقشة الحقيقية يتوقع المناقشون تفصيلاً وربطاً بالمراجع.',
          'Your answers were very brief — examiners expect detail and links to references in a real viva.',
        ),
      if (!config.thesisSummary.toLowerCase().contains('هدف') &&
          !config.thesisSummary.toLowerCase().contains('objective'))
        appTr(
          'ملخص الرسالة لا يبرز الأهداف بوضوح — جهّز صياغة دقيقة للأهداف والمساهمة.',
          'The thesis summary does not state objectives clearly — prepare a precise statement of aims and contribution.',
        ),
      appTr(
        'استعد لسؤال عن الفجوة البحثية: لماذا دراستك ضرورية الآن في «${config.specialization}»؟',
        'Prepare for the research-gap question: why your study matters now in «${config.specialization}».',
      ),
    ];

    final methodologyGaps = <String>[
      appTr(
        'وضّح لماذا اخترت منهجية «${config.methodology}» وما بدائلها التي استبعدتها.',
        'Clarify why you chose «${config.methodology}» methodology and which alternatives you ruled out.',
      ),
      appTr(
        'جهّز شرحاً لحجم العينة وآلية الوصول إليها ومعايير الإدراج والاستبعاد.',
        'Prepare an explanation of sample size, access, and inclusion/exclusion criteria.',
      ),
      if (config.methodology.contains('كمي') ||
          config.methodology.toLowerCase().contains('quant'))
        appTr(
          'توقّع أسئلة عن افتراضات التحليل الإحصائي واختبار المبادئ الأساسية.',
          'Expect questions on statistical assumptions and testing underlying principles.',
        ),
    ];

    final expectedQuestions = <String>[
      ...List.generate(
        3,
        (i) => _thesisGroundedQuestion(config: config, questionIndex: i),
      ).whereType<String>(),
      appTr(
        'ما الجديد في دراستك عن «${config.thesisTitle}» مقارنة بأحدث الأبحاث؟',
        'What is novel in your study on «${config.thesisTitle}» compared to recent research?',
      ),
      appTr(
        'كيف تساهم نتائجك في تطوير المعرفة في ${config.specialization}؟',
        'How do your findings advance knowledge in ${config.specialization}?',
      ),
      ...VivaQuestionBanks.forMember(
        memberId: 'external',
        facultyCategoryId: config.facultyCategoryId,
      ).take(2).map((pair) {
        return appTr(pair[0], pair[1])
            .replaceAll('{title}', config.thesisTitle)
            .replaceAll('{methodology}', config.methodology)
            .replaceAll('{specialization}', config.specialization);
      }),
    ];

    final tips = <String>[
      appTr(
        'راجع الفصل الأول والخاتمة — أغلب أسئلة اللجنة تنطلق منهما.',
        'Review chapter 1 and the conclusion — most committee questions start there.',
      ),
      appTr(
        'جهّز شريحة واحدة تلخص المنهجية والنتائج الرئيسية في دقيقتين.',
        'Prepare one slide summarizing methodology and key findings in two minutes.',
      ),
      if (config.isOralMode)
        appTr(
          'تدرّب شفهياً أمام مرآة أو زميل — المناقشة الحقيقية شفوية.',
          'Practice orally in front of a mirror or peer — the real viva is spoken.',
        )
      else
        appTr(
          'تدرّب على الإجابة دون قراءة — استخدم نقاطاً فقط.',
          'Practice answering without reading — use bullet prompts only.',
        ),
      if (config.defenseContext != null || config.thesisExcerpt != null)
        appTr(
          'أسئلة المحاكاة مبنية على مقتطفات من رسالتك — راجع تلك المقاطع قبل المناقشة الفعلية.',
          'Simulation questions are grounded in excerpts from your thesis — review those passages before the real viva.',
        ),
    ];

    final assessment = avgAnswerLen >= 120
        ? appTr(
            'أداء جيد في المحاكاة — واصل التدريب على الأسئلة المنهجية والحدود.',
            'Good performance in the simulation — keep practicing methodology and limitations questions.',
          )
        : appTr(
            'المحاكاة كشفت فجوات في التوسع والربط — خصص وقتاً إضافياً قبل المناقشة الفعلية.',
            'The simulation revealed gaps in depth and linkage — allocate extra prep time before the real viva.',
          );

    return VivaReport(
      weaknesses: weaknesses,
      methodologyGaps: methodologyGaps,
      expectedQuestions: expectedQuestions,
      preparationTips: tips,
      overallAssessment: assessment,
      fromCloudAi: false,
    );
  }
}
