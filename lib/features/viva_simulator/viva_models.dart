enum VivaPhase { setup, session, report }

enum VivaMessageRole { system, committee, student }

/// كيف يجيب الطالب أثناء المحاكاة.
enum VivaAnswerMode { written, oral }

class VivaMessage {
  final String id;
  final VivaMessageRole role;
  final String? memberId;
  final String content;
  final DateTime createdAt;

  const VivaMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.memberId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role.name,
        'memberId': memberId,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };

  factory VivaMessage.fromMap(Map<String, dynamic> map) {
    return VivaMessage(
      id: map['id']?.toString() ?? '',
      role: VivaMessageRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => VivaMessageRole.system,
      ),
      memberId: map['memberId']?.toString(),
      content: map['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class VivaSessionConfig {
  final String thesisTitle;
  final String thesisSummary;
  final String degree;
  final String methodology;
  final String specialization;
  final String university;
  final String? pdfFileName;
  final String? thesisExcerpt;
  /// مقتطفات مركّزة من الرسالة لأسئلة المناقشة.
  final String? defenseContext;
  /// عدد أسئلة الجلسة (6–15).
  final int questionCount;
  /// كتابي أو شفهي.
  final VivaAnswerMode answerMode;
  /// معرّف كلية من faculty_categories (Engineering, Medicine, …).
  final String? facultyCategoryId;

  const VivaSessionConfig({
    required this.thesisTitle,
    required this.thesisSummary,
    required this.degree,
    required this.methodology,
    required this.specialization,
    required this.university,
    this.pdfFileName,
    this.thesisExcerpt,
    this.defenseContext,
    this.questionCount = 10,
    this.answerMode = VivaAnswerMode.written,
    this.facultyCategoryId,
  });

  static const questionCountOptions = [6, 8, 10, 12, 15];

  bool get isValid =>
      thesisTitle.trim().length >= 5 && thesisSummary.trim().length >= 40;

  bool get isOralMode => answerMode == VivaAnswerMode.oral;

  int get resolvedQuestionCount {
    if (questionCountOptions.contains(questionCount)) return questionCount;
    return questionCount.clamp(6, 15);
  }

  String get aiContextBlock {
    final buffer = StringBuffer()
      ..writeln('Title: $thesisTitle')
      ..writeln('Degree: $degree')
      ..writeln('Field: $specialization')
      ..writeln('Methodology: $methodology')
      ..writeln('University: $university')
      ..writeln('FacultyCategory: ${facultyCategoryId ?? 'general'}')
      ..writeln('AnswerMode: ${answerMode.name}')
      ..writeln('PlannedQuestions: $resolvedQuestionCount')
      ..writeln('Summary: $thesisSummary');
    if (defenseContext != null && defenseContext!.trim().isNotEmpty) {
      buffer.writeln('DefenseContextFromThesis:\n${defenseContext!.trim()}');
    }
    if (thesisExcerpt != null && thesisExcerpt!.trim().isNotEmpty) {
      buffer.writeln('ThesisExcerpt:\n${thesisExcerpt!.trim()}');
    }
    if (pdfFileName != null) {
      buffer.writeln('Source PDF: $pdfFileName');
    }
    return buffer.toString();
  }

  VivaSessionConfig copyWith({
    String? thesisTitle,
    String? thesisSummary,
    String? degree,
    String? methodology,
    String? specialization,
    String? university,
    String? pdfFileName,
    String? thesisExcerpt,
    String? defenseContext,
    int? questionCount,
    VivaAnswerMode? answerMode,
    String? facultyCategoryId,
    bool clearPdf = false,
    bool clearFaculty = false,
  }) {
    return VivaSessionConfig(
      thesisTitle: thesisTitle ?? this.thesisTitle,
      thesisSummary: thesisSummary ?? this.thesisSummary,
      degree: degree ?? this.degree,
      methodology: methodology ?? this.methodology,
      specialization: specialization ?? this.specialization,
      university: university ?? this.university,
      pdfFileName: clearPdf ? null : (pdfFileName ?? this.pdfFileName),
      thesisExcerpt: clearPdf ? null : (thesisExcerpt ?? this.thesisExcerpt),
      defenseContext: clearPdf ? null : (defenseContext ?? this.defenseContext),
      questionCount: questionCount ?? this.questionCount,
      answerMode: answerMode ?? this.answerMode,
      facultyCategoryId: clearFaculty
          ? null
          : (facultyCategoryId ?? this.facultyCategoryId),
    );
  }

  Map<String, dynamic> toMap() => {
        'thesisTitle': thesisTitle,
        'thesisSummary': thesisSummary,
        'degree': degree,
        'methodology': methodology,
        'specialization': specialization,
        'university': university,
        'pdfFileName': pdfFileName,
        'thesisExcerpt': thesisExcerpt,
        'defenseContext': defenseContext,
        'questionCount': questionCount,
        'answerMode': answerMode.name,
        'facultyCategoryId': facultyCategoryId,
      };

  factory VivaSessionConfig.fromMap(Map<String, dynamic> map) {
    final modeRaw = map['answerMode']?.toString() ?? 'written';
    final mode = VivaAnswerMode.values.firstWhere(
      (m) => m.name == modeRaw,
      orElse: () => VivaAnswerMode.written,
    );
    final count = (map['questionCount'] as num?)?.toInt() ?? 10;
    return VivaSessionConfig(
      thesisTitle: map['thesisTitle']?.toString() ?? '',
      thesisSummary: map['thesisSummary']?.toString() ?? '',
      degree: map['degree']?.toString() ?? 'ماجستير',
      methodology: map['methodology']?.toString() ?? 'كمي',
      specialization: map['specialization']?.toString() ?? '',
      university: map['university']?.toString() ?? '',
      pdfFileName: map['pdfFileName']?.toString(),
      thesisExcerpt: map['thesisExcerpt']?.toString(),
      defenseContext: map['defenseContext']?.toString(),
      questionCount: count,
      answerMode: mode,
      facultyCategoryId: map['facultyCategoryId']?.toString(),
    );
  }
}

class VivaReport {
  final List<String> weaknesses;
  final List<String> methodologyGaps;
  final List<String> expectedQuestions;
  final List<String> preparationTips;
  final String overallAssessment;
  final bool fromCloudAi;

  const VivaReport({
    required this.weaknesses,
    required this.methodologyGaps,
    required this.expectedQuestions,
    required this.preparationTips,
    required this.overallAssessment,
    this.fromCloudAi = false,
  });

  Map<String, dynamic> toMap() => {
        'weaknesses': weaknesses,
        'methodologyGaps': methodologyGaps,
        'expectedQuestions': expectedQuestions,
        'preparationTips': preparationTips,
        'overallAssessment': overallAssessment,
        'fromCloudAi': fromCloudAi,
      };

  factory VivaReport.fromMap(Map<String, dynamic> map) {
    List<String> listField(String key) =>
        (map[key] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        const [];

    return VivaReport(
      weaknesses: listField('weaknesses'),
      methodologyGaps: listField('methodologyGaps'),
      expectedQuestions: listField('expectedQuestions'),
      preparationTips: listField('preparationTips'),
      overallAssessment: map['overallAssessment']?.toString() ?? '',
      fromCloudAi: map['fromCloudAi'] == true,
    );
  }
}

class VivaSavedSession {
  final String id;
  final String title;
  final VivaSessionConfig config;
  final VivaPhase phase;
  final List<VivaMessage> messages;
  final VivaReport? report;
  final int questionIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VivaSavedSession({
    required this.id,
    required this.title,
    required this.config,
    required this.phase,
    required this.messages,
    required this.questionIndex,
    required this.createdAt,
    required this.updatedAt,
    this.report,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'config': config.toMap(),
        'phase': phase.name,
        'messages': messages.map((m) => m.toMap()).toList(),
        'report': report?.toMap(),
        'questionIndex': questionIndex,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory VivaSavedSession.fromMap(String id, Map<String, dynamic> map) {
    final rawMessages = map['messages'] as List<dynamic>? ?? [];
    return VivaSavedSession(
      id: id,
      title: map['title']?.toString() ?? '',
      config: VivaSessionConfig.fromMap(
        Map<String, dynamic>.from(map['config'] as Map? ?? {}),
      ),
      phase: VivaPhase.values.firstWhere(
        (p) => p.name == map['phase'],
        orElse: () => VivaPhase.setup,
      ),
      messages: rawMessages
          .map((m) => VivaMessage.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList(),
      report: map['report'] is Map
          ? VivaReport.fromMap(Map<String, dynamic>.from(map['report'] as Map))
          : null,
      questionIndex: (map['questionIndex'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class VivaPdfExtractionResult {
  final String fileName;
  final String title;
  final String summary;
  final String? methodology;
  final String? specialization;
  final String? excerpt;
  /// نص مركّز للمناقشة: أسئلة بحثية، عينة، نتائج، حدود…
  final String? defenseContext;

  const VivaPdfExtractionResult({
    required this.fileName,
    required this.title,
    required this.summary,
    this.methodology,
    this.specialization,
    this.excerpt,
    this.defenseContext,
  });
}
