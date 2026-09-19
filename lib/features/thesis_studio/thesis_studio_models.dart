import '../ai_advisor/grounded_work.dart';
import '../research_supply_chain/research_goal.dart';
import 'thesis_studio_kind.dart';

typedef ThesisProgress = void Function(String label);

class ThesisChapterTemplate {
  final String id;
  final String titleAr;
  final String titleEn;
  final String purposeAr;
  final String purposeEn;
  final ThesisChapterDepth depth;

  const ThesisChapterTemplate({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.purposeAr,
    required this.purposeEn,
    this.depth = ThesisChapterDepth.full,
  });
}

class ThesisParagraph {
  final String id;
  final String headingAr;
  final String headingEn;
  final String body;
  final List<GroundedWork> references;
  final bool fromGemini;
  final String lastCommand;

  const ThesisParagraph({
    required this.id,
    required this.headingAr,
    required this.headingEn,
    this.body = '',
    this.references = const [],
    this.fromGemini = false,
    this.lastCommand = '',
  });

  String heading(bool arabic) => arabic ? headingAr : headingEn;

  bool get isEmpty => body.trim().isEmpty;

  ThesisParagraph copyWith({
    String? body,
    List<GroundedWork>? references,
    bool? fromGemini,
    String? lastCommand,
    String? headingAr,
    String? headingEn,
  }) {
    return ThesisParagraph(
      id: id,
      headingAr: headingAr ?? this.headingAr,
      headingEn: headingEn ?? this.headingEn,
      body: body ?? this.body,
      references: references ?? this.references,
      fromGemini: fromGemini ?? this.fromGemini,
      lastCommand: lastCommand ?? this.lastCommand,
    );
  }
}

class ThesisChapter {
  final String id;
  final String titleAr;
  final String titleEn;
  final String purposeAr;
  final String purposeEn;
  final String body;
  final bool fromGemini;
  final ThesisChapterDepth depth;
  final List<ThesisParagraph> paragraphs;

  const ThesisChapter({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    this.purposeAr = '',
    this.purposeEn = '',
    this.body = '',
    this.fromGemini = false,
    this.depth = ThesisChapterDepth.full,
    this.paragraphs = const [],
  });

  String title(bool arabic) => arabic ? titleAr : titleEn;

  String purpose(bool arabic) => arabic ? purposeAr : purposeEn;

  static String assembleBody(List<ThesisParagraph> paragraphs, bool arabic) {
    final parts = <String>[];
    for (final paragraph in paragraphs) {
      if (paragraph.body.trim().isEmpty) continue;
      parts.add('${paragraph.heading(arabic)}\n${paragraph.body.trim()}');
    }
    return parts.join('\n\n');
  }

  ThesisChapter replacingParagraph(ThesisParagraph updated, {required bool arabic}) {
    final next = [
      for (final paragraph in paragraphs)
        paragraph.id == updated.id ? updated : paragraph,
    ];
    return copyWith(
      paragraphs: next,
      body: assembleBody(next, arabic),
      fromGemini: fromGemini || updated.fromGemini,
    );
  }

  ThesisChapter copyWith({
    String? body,
    bool? fromGemini,
    List<ThesisParagraph>? paragraphs,
  }) {
    return ThesisChapter(
      id: id,
      titleAr: titleAr,
      titleEn: titleEn,
      purposeAr: purposeAr,
      purposeEn: purposeEn,
      body: body ?? this.body,
      fromGemini: fromGemini ?? this.fromGemini,
      depth: depth,
      paragraphs: paragraphs ?? this.paragraphs,
    );
  }
}

class ThesisDraft {
  final ResearchGoal goal;
  final ThesisPlan plan;
  final GroundedReferenceBundle literature;
  final List<LiteratureMapRow> literatureMap;
  final String proposedTitle;
  final String abstractText;
  final List<String> researchQuestions;
  final List<ThesisChapter> chapters;
  final bool fromGemini;
  final String? modelUsed;
  final String? note;
  final List<GroundedWork> abstractReferences;

  const ThesisDraft({
    required this.goal,
    required this.plan,
    required this.literature,
    this.literatureMap = const [],
    this.proposedTitle = '',
    this.abstractText = '',
    this.researchQuestions = const [],
    this.chapters = const [],
    this.fromGemini = false,
    this.modelUsed,
    this.note,
    this.abstractReferences = const [],
  });

  ThesisKind get kind => plan.kind;
  ThesisShape get shape => plan.shape;
  bool get arabic => plan.arabic;

  bool get hasGeneratedProse {
    if (abstractText.trim().isNotEmpty) return true;
    for (final chapter in chapters) {
      if (chapter.body.trim().isNotEmpty) return true;
      for (final paragraph in chapter.paragraphs) {
        if (paragraph.body.trim().isNotEmpty) return true;
      }
    }
    return false;
  }

  ThesisDraft replacingChapter(ThesisChapter chapter) {
    return copyWith(
      chapters: [
        for (final item in chapters) item.id == chapter.id ? chapter : item,
      ],
    );
  }

  ThesisDraft copyWith({
    ResearchGoal? goal,
    ThesisPlan? plan,
    String? proposedTitle,
    String? abstractText,
    List<String>? researchQuestions,
    List<ThesisChapter>? chapters,
    bool? fromGemini,
    String? modelUsed,
    String? note,
    GroundedReferenceBundle? literature,
    List<LiteratureMapRow>? literatureMap,
    List<GroundedWork>? abstractReferences,
  }) {
    return ThesisDraft(
      goal: goal ?? this.goal,
      plan: plan ?? this.plan,
      literature: literature ?? this.literature,
      literatureMap: literatureMap ?? this.literatureMap,
      proposedTitle: proposedTitle ?? this.proposedTitle,
      abstractText: abstractText ?? this.abstractText,
      researchQuestions: researchQuestions ?? this.researchQuestions,
      chapters: chapters ?? this.chapters,
      fromGemini: fromGemini ?? this.fromGemini,
      modelUsed: modelUsed ?? this.modelUsed,
      note: note ?? this.note,
      abstractReferences: abstractReferences ?? this.abstractReferences,
    );
  }
}

class LiteratureMapRow {
  final int index;
  final GroundedWork work;
  final String focus;
  final String notes;

  const LiteratureMapRow({
    required this.index,
    required this.work,
    this.focus = '',
    this.notes = '',
  });
}
