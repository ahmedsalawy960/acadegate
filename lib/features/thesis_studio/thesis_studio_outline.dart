import '../research_supply_chain/research_goal.dart';
import 'thesis_studio_kind.dart';
import 'thesis_studio_models.dart';

class ThesisStudioOutline {
  ThesisStudioOutline._();

  static List<ThesisChapterTemplate> forGoal(ResearchGoal goal) {
    final guess = ThesisKindDetector.detect(raw: goal.raw);
    return forPlan(
      ThesisPlan(
        goal: goal,
        kind: guess.kind,
        shape: guess.shape,
        arabic: guess.arabic,
      ),
    );
  }

  static List<ThesisChapterTemplate> forPlan(ThesisPlan plan) {
    final goal = plan.goal;
    final fieldAr = fieldArOf(goal);
    final fieldEn = fieldEnOf(goal);
    final phd = goal.track == ResearchDegreeTrack.phd;
    final diploma = goal.track == ResearchDegreeTrack.diploma;

    final chapters = switch (plan.shape) {
      ThesisShape.arabicLiterary || ThesisShape.englishHumanities => _literary(
          fieldAr: fieldAr,
          fieldEn: fieldEn,
          phd: phd,
          diploma: diploma,
          arabicShape: plan.shape == ThesisShape.arabicLiterary,
        ),
      ThesisShape.arabicEmpirical => _arabicEmpirical(
          goal: goal,
          fieldAr: fieldAr,
          fieldEn: fieldEn,
          phd: phd,
          diploma: diploma,
          lab: plan.kind == ThesisKind.experimental,
        ),
      ThesisShape.englishExperimentalMerged => _englishExperimental(
          goal: goal,
          diploma: diploma,
          mergeResults: true,
        ),
      ThesisShape.englishExperimentalSplit => _englishExperimental(
          goal: goal,
          diploma: diploma,
          mergeResults: false,
        ),
    };
    return _number(chapters);
  }

  static List<ThesisChapterTemplate> _literary({
    required String fieldAr,
    required String fieldEn,
    required bool phd,
    required bool diploma,
    required bool arabicShape,
  }) {
    final list = <ThesisChapterTemplate>[
      ThesisChapterTemplate(
        id: 'intro',
        titleAr: 'الفصل الأول: الإطار العام لـ $fieldAr',
        titleEn: 'Chapter 1: Introduction to $fieldEn',
        purposeAr:
            'الموضوع، الإشكالية، المنهج النقدي/التحليلي، الحدود — بلا نتائج مختلقة.',
        purposeEn:
            'Topic, problem, analytic method, and scope — no fabricated findings.',
        depth: ThesisChapterDepth.full,
      ),
    ];
    if (phd) {
      list.add(
        ThesisChapterTemplate(
          id: 'theory',
          titleAr: 'الفصل الثاني: الإطار النظري لـ $fieldAr',
          titleEn: 'Chapter 2: Theoretical framework for $fieldEn',
          purposeAr: 'المفاهيم والنظريات التي تفسّر $fieldAr فقط.',
          purposeEn: 'Concepts and theories that explain $fieldEn only.',
          depth: ThesisChapterDepth.full,
        ),
      );
    }
    list.add(
      ThesisChapterTemplate(
        id: 'literature',
        titleAr: arabicShape
            ? 'دراسات سابقة وإطار مرجعي في $fieldAr'
            : 'مراجعة الأدبيات في $fieldAr',
        titleEn: 'Literature and prior scholarship on $fieldEn',
        purposeAr:
            'فصل الدراسات السابقة: فقرة لكل مرجع معتمد (مؤلف، سنة، موضوع، نتائج من الملخص) من DOI مؤكد — مع إمكانية الاستيراد باللصق.',
        purposeEn:
            'Prior-studies chapter: one paragraph per relied-on work (author, year, topic, findings from abstract) from confirmed DOIs — paste-import supported.',
        depth: ThesisChapterDepth.full,
      ),
    );
    list.add(
      ThesisChapterTemplate(
        id: 'theme_a',
        titleAr: 'مبحث تحليلي أول في $fieldAr',
        titleEn: 'First analytical chapter on $fieldEn',
        purposeAr:
            'تحليل موضوعي/نصي مبني على المصادر المؤكدة فقط.',
        purposeEn:
            'Thematic or textual analysis grounded only in confirmed sources.',
        depth: ThesisChapterDepth.full,
      ),
    );
    if (!diploma) {
      list.add(
        ThesisChapterTemplate(
          id: 'theme_b',
          titleAr: 'مبحث تحليلي ثانٍ في $fieldAr',
          titleEn: 'Second analytical chapter on $fieldEn',
          purposeAr: 'مبحث مكمل يطوّر الحجة دون اختلاق شواهد.',
          purposeEn:
              'A second thread that develops the argument without invented evidence.',
          depth: ThesisChapterDepth.full,
        ),
      );
    }
    list.add(
      ThesisChapterTemplate(
        id: 'conclusion',
        titleAr: 'الخاتمة والتوصيات في $fieldAr',
        titleEn: 'Conclusion and recommendations on $fieldEn',
        purposeAr: 'مساهمة القراءة، الحدود، وما يبقى للمشرف.',
        purposeEn: 'Contribution, limits, and what the supervisor still decides.',
        depth: ThesisChapterDepth.full,
      ),
    );
    return list;
  }

  static List<ThesisChapterTemplate> _arabicEmpirical({
    required ResearchGoal goal,
    required String fieldAr,
    required String fieldEn,
    required bool phd,
    required bool diploma,
    required bool lab,
  }) {
    final methods = DegreePlanEngine.methodHint(goal);
    final list = <ThesisChapterTemplate>[
      ThesisChapterTemplate(
        id: 'intro',
        titleAr: 'الفصل الأول: الإطار العام لـ $fieldAr',
        titleEn: 'Chapter 1: General framework of $fieldEn',
        purposeAr:
            'مقدمة، مشكلة، أهداف، أسئلة/فروض، أهمية، حدود — بلا نتائج رقمية.',
        purposeEn:
            'Introduction, problem, aims, questions, significance, limits — no numeric results.',
        depth: ThesisChapterDepth.full,
      ),
    ];
    if (phd) {
      list.add(
        ThesisChapterTemplate(
          id: 'theory',
          titleAr: 'الإطار النظري لـ $fieldAr',
          titleEn: 'Theoretical framework for $fieldEn',
          purposeAr: 'المفاهيم المرتبطة بـ $fieldAr فقط.',
          purposeEn: 'Concepts tied to $fieldEn only.',
          depth: ThesisChapterDepth.full,
        ),
      );
    }
    list.add(
      ThesisChapterTemplate(
        id: 'literature',
        titleAr: 'الدراسات السابقة في $fieldAr',
        titleEn: 'Previous studies on $fieldEn',
        purposeAr:
            'فصل الدراسات السابقة: فقرة لكل مرجع معتمد من الملخص (مؤلف، سنة، موضوع، نتائج) عبر استيراد DOI.',
        purposeEn:
            'Prior-studies chapter: one abstract-based paragraph per relied-on work via DOI import.',
        depth: ThesisChapterDepth.full,
      ),
    );
    if (!diploma || lab) {
      list.add(
        ThesisChapterTemplate(
          id: lab ? 'experimental' : 'methods',
          titleAr: lab
              ? 'المواد والطرق / الجزء العملي لـ $fieldAr'
              : 'منهجية دراسة $fieldAr',
          titleEn: lab
              ? 'Materials and methods / experimental work on $fieldEn'
              : 'Methodology for $fieldEn',
          purposeAr:
              'تصميم، عينة، و$methods — بروتوكول بلا بيانات مختلقة.',
          purposeEn:
              'Design, sample, and $methods — a protocol with no invented data.',
          depth: ThesisChapterDepth.protocol,
        ),
      );
    }
    if (!diploma) {
      if (phd) {
        list.add(
          ThesisChapterTemplate(
            id: 'results',
            titleAr: 'النتائج في $fieldAr',
            titleEn: 'Results for $fieldEn',
            purposeAr: 'هيكل جداول بعد جمع البيانات — ممنوع اختلاق أرقام.',
            purposeEn: 'Table frames after data collection — invent no numbers.',
            depth: ThesisChapterDepth.scaffold,
          ),
        );
        list.add(
          ThesisChapterTemplate(
            id: 'discussion',
            titleAr: 'مناقشة $fieldAr',
            titleEn: 'Discussion of $fieldEn',
            purposeAr: 'يُكتب بعد النتائج الحقيقية مقابل الدراسات المؤكدة.',
            purposeEn: 'Written after real results against confirmed studies.',
            depth: ThesisChapterDepth.scaffold,
          ),
        );
      } else {
        list.add(
          ThesisChapterTemplate(
            id: 'results_discussion',
            titleAr: 'النتائج والمناقشة في $fieldAr',
            titleEn: 'Results and discussion of $fieldEn',
            purposeAr:
                'هيكل الفصل بعد التجربة — بلا إحصاء أو منحنيات مختلقة.',
            purposeEn:
                'Chapter frame after the experiment — no invented statistics or curves.',
            depth: ThesisChapterDepth.scaffold,
          ),
        );
      }
    }
    list.add(
      ThesisChapterTemplate(
        id: 'conclusion',
        titleAr: 'الاستنتاجات والتوصيات في $fieldAr',
        titleEn: 'Conclusions and recommendations on $fieldEn',
        purposeAr: 'ما يمكن التوصية به قبل جمع البيانات، والحدود.',
        purposeEn: 'What can be recommended before data exist, plus limits.',
        depth: ThesisChapterDepth.protocol,
      ),
    );
    return list;
  }

  static List<ThesisChapterTemplate> _englishExperimental({
    required ResearchGoal goal,
    required bool diploma,
    required bool mergeResults,
  }) {
    final methods = DegreePlanEngine.methodHint(goal);
    final list = <ThesisChapterTemplate>[
      ThesisChapterTemplate(
        id: 'intro',
        titleAr: 'المقدمة',
        titleEn: 'Introduction',
        purposeAr: 'السياق، الفجوة، الأهداف، الأسئلة — بلا نتائج ملفّقة.',
        purposeEn:
            'Context, gap, aims, and questions — no fabricated findings.',
        depth: ThesisChapterDepth.full,
      ),
      ThesisChapterTemplate(
        id: 'literature',
        titleAr: 'مراجعة الأدبيات',
        titleEn: 'Literature review',
        purposeAr:
            'فصل الدراسات السابقة: فقرة لكل مرجع معتمد من الملخص عبر استيراد DOI.',
        purposeEn:
            'Prior-studies chapter: one abstract-based paragraph per relied-on work via DOI import.',
        depth: ThesisChapterDepth.full,
      ),
      ThesisChapterTemplate(
        id: 'experimental',
        titleAr: 'الجزء العملي (Experimental)',
        titleEn: 'Experimental',
        purposeAr: 'مواد، أجهزة، إجراءات $methods — بلا نتائج.',
        purposeEn: 'Materials, instruments, $methods procedures — no results.',
        depth: ThesisChapterDepth.protocol,
      ),
    ];
    if (!diploma) {
      if (mergeResults) {
        list.add(
          ThesisChapterTemplate(
            id: 'results_discussion',
            titleAr: 'النتائج والمناقشة',
            titleEn: 'Results and discussion',
            purposeAr:
                'يُملأ بعد القياسات — هيكل جداول فقط الآن.',
            purposeEn: 'Filled after measurements — table frames only for now.',
            depth: ThesisChapterDepth.scaffold,
          ),
        );
      } else {
        list.add(
          ThesisChapterTemplate(
            id: 'results',
            titleAr: 'النتائج',
            titleEn: 'Results',
            purposeAr: 'عرض موضوعي بعد جمع البيانات — بلا أرقام الآن.',
            purposeEn: 'Objective presentation after data — no numbers now.',
            depth: ThesisChapterDepth.scaffold,
          ),
        );
        list.add(
          ThesisChapterTemplate(
            id: 'discussion',
            titleAr: 'المناقشة',
            titleEn: 'Discussion',
            purposeAr: 'تفسير مقابل الأدبيات المؤكدة بعد النتائج الحقيقية.',
            purposeEn:
                'Interpretation against confirmed literature after real results.',
            depth: ThesisChapterDepth.scaffold,
          ),
        );
      }
    }
    list.add(
      ThesisChapterTemplate(
        id: 'conclusion',
        titleAr: 'الخاتمة',
        titleEn: 'Conclusion',
        purposeAr: 'حدود العمل الحالي وخطوات ما بعد التجربة.',
        purposeEn: 'Limits of this draft and next steps after the experiment.',
        depth: ThesisChapterDepth.protocol,
      ),
    );
    return list;
  }

  static List<ThesisChapterTemplate> _number(
    List<ThesisChapterTemplate> raw,
  ) {
    return [
      for (var i = 0; i < raw.length; i++)
        ThesisChapterTemplate(
          id: raw[i].id,
          titleAr: _ensureChapterNo(raw[i].titleAr, i + 1, arabic: true),
          titleEn: _ensureChapterNo(raw[i].titleEn, i + 1, arabic: false),
          purposeAr: raw[i].purposeAr,
          purposeEn: raw[i].purposeEn,
          depth: raw[i].depth,
        ),
    ];
  }

  static String _ensureChapterNo(String title, int n, {required bool arabic}) {
    if (RegExp(r'(الفصل|Chapter)\s', caseSensitive: false).hasMatch(title)) {
      return title;
    }
    return arabic ? 'الفصل $n: $title' : 'Chapter $n: $title';
  }

  static String fieldArOf(ResearchGoal goal) {
    return displayTopic(
      goal.field.trim().isNotEmpty ? goal.field : goal.fieldEn,
      fallback: goal.raw,
    );
  }

  static String fieldEnOf(ResearchGoal goal) {
    return displayTopic(
      goal.fieldEn.trim().isNotEmpty ? goal.fieldEn : goal.field,
      fallback: goal.raw,
    );
  }

  /// Short topic for titles — never dump a pasted manuscript.
  static String displayTopic(String value, {String fallback = '', int max = 64}) {
    var t = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.length < 3) {
      t = fallback.trim().replaceAll(RegExp(r'\s+'), ' ');
    }
    t = t.replaceFirst(RegExp(r'^[a-z]{1,2}\s+'), '');
    if (t.length > 400) {
      t = t.substring(0, 120);
    }
    if (t.length > max) {
      final cut = t.substring(0, max);
      final sp = cut.lastIndexOf(' ');
      t = '${sp > 24 ? cut.substring(0, sp) : cut}…';
    }
    return t;
  }
}
