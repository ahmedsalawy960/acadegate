import '../../core/locale/app_translate.dart';

/// Registry notice on a **confirmed** DOI (Crossref update / OpenAlex flag).
/// Never created from a model guess.
enum CitationNoticeKind {
  retraction,
  withdrawal,
  expressionOfConcern,
  correction,
  erratum,
  other,
}

class CitationNotice {
  final CitationNoticeKind kind;
  final String? noticeDoi;
  final String? label;
  final int? year;
  final String source;

  const CitationNotice({
    required this.kind,
    required this.source,
    this.noticeDoi,
    this.label,
    this.year,
  });

  String get kindLabel => switch (kind) {
        CitationNoticeKind.retraction => appTr('سحب', 'Retraction'),
        CitationNoticeKind.withdrawal => appTr('سحب/إلغاء', 'Withdrawal'),
        CitationNoticeKind.expressionOfConcern =>
          appTr('تعبير قلق', 'Expression of concern'),
        CitationNoticeKind.correction => appTr('تصحيح', 'Correction'),
        CitationNoticeKind.erratum => appTr('تصويب', 'Erratum'),
        CitationNoticeKind.other => appTr('تحديث', 'Update'),
      };

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'noticeDoi': noticeDoi,
        'label': label,
        'year': year,
        'source': source,
      };

  factory CitationNotice.fromMap(Map<String, dynamic> map) {
    return CitationNotice(
      kind: CitationNoticeKind.values.firstWhere(
        (k) => k.name == map['kind']?.toString(),
        orElse: () => CitationNoticeKind.other,
      ),
      source: map['source']?.toString() ?? 'Crossref',
      noticeDoi: map['noticeDoi']?.toString(),
      label: map['label']?.toString(),
      year: (map['year'] as num?)?.toInt(),
    );
  }
}

class CitationHealth {
  final List<CitationNotice> notices;

  const CitationHealth({this.notices = const []});

  static const empty = CitationHealth();

  bool get isRetracted => notices.any(
        (n) =>
            n.kind == CitationNoticeKind.retraction ||
            n.kind == CitationNoticeKind.withdrawal,
      );

  bool get hasExpressionOfConcern => notices.any(
        (n) => n.kind == CitationNoticeKind.expressionOfConcern,
      );

  bool get hasCorrection => notices.any(
        (n) =>
            n.kind == CitationNoticeKind.correction ||
            n.kind == CitationNoticeKind.erratum,
      );

  bool get hasSeriousNotice => isRetracted || hasExpressionOfConcern;

  bool get hasAnyNotice => notices.isNotEmpty;

  CitationNoticeKind? get worstKind {
    if (isRetracted) {
      return notices
          .firstWhere(
            (n) =>
                n.kind == CitationNoticeKind.retraction ||
                n.kind == CitationNoticeKind.withdrawal,
          )
          .kind;
    }
    if (hasExpressionOfConcern) {
      return CitationNoticeKind.expressionOfConcern;
    }
    if (hasCorrection) {
      return notices
          .firstWhere(
            (n) =>
                n.kind == CitationNoticeKind.correction ||
                n.kind == CitationNoticeKind.erratum,
          )
          .kind;
    }
    if (notices.isEmpty) return null;
    return CitationNoticeKind.other;
  }

  String get badgeLabel {
    final kind = worstKind;
    if (kind == null) return appTr('سليم في السجل', 'Clear in registry');
    return notices.firstWhere((n) => n.kind == kind).kindLabel;
  }

  String detailNote() {
    if (notices.isEmpty) return '';
    final parts = notices.map((n) {
      final year = n.year != null ? ' (${n.year})' : '';
      final doi = n.noticeDoi != null && n.noticeDoi!.isNotEmpty
          ? ' DOI ${n.noticeDoi}'
          : '';
      return '${n.kindLabel}$year — ${n.source}$doi';
    });
    return parts.join(' · ');
  }

  String examinerComment({required String title, String? doi}) {
    final work = title.trim().isEmpty
        ? (doi != null && doi.isNotEmpty ? 'DOI $doi' : appTr('مرجع', 'a reference'))
        : title.trim();
    if (isRetracted) {
      return appTr(
        'هذا العمل مسحوب أو ملغى في سجل Crossref/OpenAlex. اللجنة ستسأل لماذا استشهدتَ بـ «$work» وما الذي يبقى من نتيجتك بدونه.',
        'This work is retracted or withdrawn in Crossref/OpenAlex. The committee will ask why you cited “$work” and what remains of your claim without it.',
      );
    }
    if (hasExpressionOfConcern) {
      return appTr(
        'هناك تعبير قلق منشور على «$work». وضّح للجنة كيف راجعتَ موثوقية هذا المصدر.',
        'An expression of concern is registered for “$work”. Explain to the committee how you assessed this source.',
      );
    }
    return appTr(
      'وُجد تصحيح أو تصويب لاحق لـ «$work». هل نتيجتك تعتمد على الجزء المُصحَّح؟',
      'A later correction or erratum exists for “$work”. Does your claim rely on the corrected part?',
    );
  }

  String examinerQuestion({required String title, String? doi}) {
    final work = title.trim().isEmpty
        ? (doi != null && doi.isNotEmpty ? 'DOI $doi' : appTr('أحد مراجعك', 'one of your references'))
        : title.trim();
    if (isRetracted) {
      return appTr(
        'استشهدتَ بـ «$work» وهو مسحوب في السجل. أي فقرة في رسالتك تعتمد عليه، وما الذي يتغيّر لو حذفتَه؟',
        'You cited “$work”, which is retracted in the registry. Which passage depends on it, and what changes if you drop it?',
      );
    }
    if (hasExpressionOfConcern) {
      return appTr(
        '«$work» عليه تعبير قلق. كيف تبرر للجنة الإبقاء عليه في قائمة المراجع؟',
        '“$work” has an expression of concern. How do you justify keeping it in the reference list?',
      );
    }
    return appTr(
      '«$work» عليه تصحيح لاحق. هل راجعتَ التصحيح قبل أن تبني عليه نتيجة؟',
      '“$work” has a later correction. Did you read the correction before building a result on it?',
    );
  }

  CitationHealth merge(CitationHealth other) {
    if (other.notices.isEmpty) return this;
    if (notices.isEmpty) return other;
    final seen = <String>{};
    final merged = <CitationNotice>[];
    for (final notice in [...notices, ...other.notices]) {
      final key =
          '${notice.kind.name}|${notice.noticeDoi ?? ''}|${notice.source}';
      if (!seen.add(key)) continue;
      merged.add(notice);
    }
    return CitationHealth(notices: merged);
  }

  Map<String, dynamic> toMap() => {
        'notices': notices.map((n) => n.toMap()).toList(),
      };

  factory CitationHealth.fromMap(Map<String, dynamic> map) {
    final raw = map['notices'];
    if (raw is! List) return const CitationHealth();
    return CitationHealth(
      notices: raw
          .whereType<Map>()
          .map((e) => CitationNotice.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class CitationHealthClassifier {
  CitationHealthClassifier._();

  static String normalizeDoi(String doi) {
    return doi
        .trim()
        .replaceAll(RegExp(r'^https?://(dx\.)?doi\.org/', caseSensitive: false), '')
        .replaceAll(RegExp(r'[.,;)\]]+$'), '')
        .toLowerCase();
  }

  static CitationNoticeKind classify(String? typeOrLabel) {
    final raw = (typeOrLabel ?? '').toLowerCase().trim();
    if (raw.isEmpty) return CitationNoticeKind.other;
    if (raw.contains('retract') || raw.contains('سحب')) {
      return CitationNoticeKind.retraction;
    }
    if (raw.contains('withdraw') || raw.contains('إلغاء')) {
      return CitationNoticeKind.withdrawal;
    }
    if (raw.contains('concern') || raw.contains('قلق')) {
      return CitationNoticeKind.expressionOfConcern;
    }
    if (raw.contains('errat') || raw.contains('corrig') || raw.contains('تصويب')) {
      return CitationNoticeKind.erratum;
    }
    if (raw.contains('correct') || raw.contains('تصحيح')) {
      return CitationNoticeKind.correction;
    }
    return CitationNoticeKind.other;
  }

  static CitationHealth fromOpenAlexRetracted(bool isRetracted) {
    if (!isRetracted) return CitationHealth.empty;
    return const CitationHealth(
      notices: [
        CitationNotice(
          kind: CitationNoticeKind.retraction,
          source: 'OpenAlex',
          label: 'is_retracted',
        ),
      ],
    );
  }

  static CitationHealth fromCrossrefRelations({
    required bool retractedByRelation,
    List<CitationNotice> updates = const [],
  }) {
    var health = CitationHealth(notices: updates);
    if (retractedByRelation) {
      health = health.merge(
        const CitationHealth(
          notices: [
            CitationNotice(
              kind: CitationNoticeKind.retraction,
              source: 'Crossref',
              label: 'is-retracted-by',
            ),
          ],
        ),
      );
    }
    return health;
  }
}

/// Compact counts for viva / publish surfaces.
class CitationHealthSnapshot {
  final int checked;
  final int verified;
  final int retracted;
  final int concern;
  final int corrected;
  final int integrityScore;
  final List<String> seriousTitles;

  const CitationHealthSnapshot({
    required this.checked,
    required this.verified,
    required this.retracted,
    required this.concern,
    required this.corrected,
    required this.integrityScore,
    this.seriousTitles = const [],
  });

  bool get hasSerious => retracted > 0 || concern > 0;

  bool get hasAnyFlag => hasSerious || corrected > 0;

  String get headline {
    if (checked == 0) {
      return appTr('لم يُفحص سجل الاستشهاد بعد', 'Citation registry not checked yet');
    }
    if (retracted > 0) {
      return appTr(
        '$retracted مرجع مسحوب في السجل',
        '$retracted retracted reference(s) in the registry',
      );
    }
    if (concern > 0) {
      return appTr(
        '$concern مرجع عليه تعبير قلق',
        '$concern reference(s) with an expression of concern',
      );
    }
    if (corrected > 0) {
      return appTr(
        '$corrected مرجع عليه تصحيح لاحق',
        '$corrected reference(s) with a later correction',
      );
    }
    return appTr(
      'لا سحب ولا تعبير قلق في المراجع المفحوصة ($checked)',
      'No retraction or concern on checked references ($checked)',
    );
  }

  Map<String, dynamic> toMap() => {
        'checked': checked,
        'verified': verified,
        'retracted': retracted,
        'concern': concern,
        'corrected': corrected,
        'integrityScore': integrityScore,
        'seriousTitles': seriousTitles,
      };

  factory CitationHealthSnapshot.fromMap(Map<String, dynamic> map) {
    return CitationHealthSnapshot(
      checked: (map['checked'] as num?)?.toInt() ?? 0,
      verified: (map['verified'] as num?)?.toInt() ?? 0,
      retracted: (map['retracted'] as num?)?.toInt() ?? 0,
      concern: (map['concern'] as num?)?.toInt() ?? 0,
      corrected: (map['corrected'] as num?)?.toInt() ?? 0,
      integrityScore: (map['integrityScore'] as num?)?.toInt() ?? 0,
      seriousTitles: (map['seriousTitles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          const [],
    );
  }
}

class CitationHealthAlert {
  final String kind;
  final String quote;
  final String comment;
  final String question;

  const CitationHealthAlert({
    required this.kind,
    required this.quote,
    required this.comment,
    required this.question,
  });
}
