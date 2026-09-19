import '../../core/locale/app_translate.dart';
import '../academic/academic_degrees.dart';

enum ResearchDegreeTrack { masters, phd, diploma, unspecified }

enum InstitutionTarget { factory, ministry, development, university, unspecified }

class ResearchGoal {
  final String raw;
  final String field;
  final String fieldEn;
  final ResearchDegreeTrack track;
  final InstitutionTarget institution;
  final String searchQuery;
  final int years;
  final List<String> searchQueries;
  final List<String> matchKeywords;
  final List<String> methods;

  const ResearchGoal({
    required this.raw,
    required this.field,
    this.fieldEn = '',
    this.track = ResearchDegreeTrack.unspecified,
    this.institution = InstitutionTarget.unspecified,
    this.searchQuery = '',
    this.years = 2,
    this.searchQueries = const [],
    this.matchKeywords = const [],
    this.methods = const [],
  });

  ResearchGoal copyWith({
    String? field,
    String? fieldEn,
    ResearchDegreeTrack? track,
    InstitutionTarget? institution,
    String? searchQuery,
    int? years,
    List<String>? searchQueries,
    List<String>? matchKeywords,
    List<String>? methods,
  }) {
    return ResearchGoal(
      raw: raw,
      field: field ?? this.field,
      fieldEn: fieldEn ?? this.fieldEn,
      track: track ?? this.track,
      institution: institution ?? this.institution,
      searchQuery: searchQuery ?? this.searchQuery,
      years: years ?? this.years,
      searchQueries: searchQueries ?? this.searchQueries,
      matchKeywords: matchKeywords ?? this.matchKeywords,
      methods: methods ?? this.methods,
    );
  }

  String degreeLabelFor(bool arabic) {
    return switch (track) {
      ResearchDegreeTrack.phd => arabic ? 'دكتوراه' : 'PhD',
      ResearchDegreeTrack.diploma =>
        arabic ? 'دبلوم دراسات عليا' : 'Postgraduate diploma',
      ResearchDegreeTrack.masters => arabic ? 'ماجستير' : "Master's",
      ResearchDegreeTrack.unspecified =>
        arabic ? 'دراسات عليا' : 'Graduate study',
    };
  }

  String get degreeLabel {
    return switch (track) {
      ResearchDegreeTrack.phd => appTr('دكتوراه', 'PhD'),
      ResearchDegreeTrack.diploma => appTr('دبلوم دراسات عليا', 'Postgraduate diploma'),
      ResearchDegreeTrack.masters => appTr('ماجستير', "Master's"),
      ResearchDegreeTrack.unspecified => appTr('دراسات عليا', 'Graduate study'),
    };
  }

  String get institutionLabel {
    return switch (institution) {
      InstitutionTarget.factory => appTr('مصنع / صناعة', 'Factory / industry'),
      InstitutionTarget.ministry => appTr('وزارة / جهة عامة', 'Ministry / public body'),
      InstitutionTarget.development => appTr('تنمية مؤسسية', 'Institutional development'),
      InstitutionTarget.university => appTr('جامعة / بحث أكاديمي', 'University / academic'),
      InstitutionTarget.unspecified => appTr('تطبيق مؤسسي عام', 'General institutional use'),
    };
  }

  String profileDegreeValue() {
    return switch (track) {
      ResearchDegreeTrack.phd => 'دكتوراه',
      ResearchDegreeTrack.diploma => 'دبلوم دراسات عليا',
      ResearchDegreeTrack.masters => 'ماجستير',
      ResearchDegreeTrack.unspecified => 'ماجستير',
    };
  }
}

class DegreePlanStage {
  final String period;
  final String title;
  final List<String> outcomes;
  final List<String> platformActions;

  const DegreePlanStage({
    required this.period,
    required this.title,
    this.outcomes = const [],
    this.platformActions = const [],
  });
}

class FundingFit {
  final String title;
  final String kind;
  final String why;
  final String? challengeId;
  final double budget;
  final String currency;

  const FundingFit({
    required this.title,
    required this.kind,
    required this.why,
    this.challengeId,
    this.budget = 0,
    this.currency = '',
  });
}

class ResearchGoalParser {
  ResearchGoalParser._();

  static const _stop = {
    'the', 'and', 'for', 'with', 'from', 'into', 'that', 'this', 'using',
    'study', 'based', 'among', 'between', 'after', 'before', 'their',
    'want', 'like', 'your', 'same', 'near', 'work', 'make',
    'master', 'masters', 'phd', 'diploma', 'degree',
    'factory', 'ministry', 'university', 'college', 'faculty', 'industry',
    'development', 'public', 'body',
    'عمل', 'أريد', 'اريد', 'ماجستير', 'دكتوراه', 'دبلوم', 'في', 'عن', 'من',
    'كلية', 'جامعة', 'مصنع', 'وزارة', 'تنمية', 'نفس', 'قريب',
  };

  static const _aliases = <String, String>{
    'كيمياء تحليلية': 'analytical chemistry',
    'الكيمياء التحليلية': 'analytical chemistry',
    'تحليلية': 'analytical chemistry',
    'نانو': 'nanomaterials',
    'نانوماتيريل': 'nanomaterials',
    'امتصاص': 'adsorption',
    'امتزاز': 'adsorption',
    'كرومات': 'chromatography',
    'زيت': 'edible oil',
    'زيوت': 'edible oil',
    'تكرير': 'oil refining',
    'مياه': 'water treatment',
    'معادن ثقيلة': 'heavy metals',
    'حفاز': 'catalysis',
    'طاقة متجددة': 'renewable energy',
    'زراعة': 'agriculture',
    'ذكاء اصطناعي': 'artificial intelligence',
  };

  /// Pull any Latin scholarly phrases already present in mixed Arabic/English text.
  /// Topic translation itself is done by the AI search planner — not a fixed glossary.
  static List<String> englishQueriesFromText(String text) {
    if (text.trim().isEmpty) return const [];
    final out = <String>[];
    final seen = <String>{};
    for (final m in RegExp(
      r'[A-Za-z][A-Za-z0-9\-/]*(?:\s+[A-Za-z][A-Za-z0-9\-/]*){0,6}',
    ).allMatches(text)) {
      final phrase = (m.group(0) ?? '').trim();
      if (phrase.length < 4) continue;
      if (seen.add(phrase.toLowerCase())) out.add(phrase);
    }
    return out.take(6).toList();
  }

  static bool containsArabic(String text) =>
      RegExp(r'[\u0600-\u06FF]').hasMatch(text);

  /// Too generic to prove relevance by themselves in any discipline.
  static const _weakTokens = {
    'products', 'product', 'secondary', 'study', 'studies', 'effect',
    'effects', 'development', 'management', 'analysis', 'research',
    'general', 'using', 'based', 'among',
    'منتجات', 'منتج', 'ثانوية', 'دراسة', 'تنمية', 'تأثير', 'تحليل',
  };

  static bool titleMatchesTopic(String title, Iterable<String> topicTokens) {
    final hay = title.toLowerCase();
    var hits = 0;
    for (final raw in topicTokens) {
      final token = raw.trim().toLowerCase();
      if (token.length < 3 || _stop.contains(token) || _weakTokens.contains(token)) {
        continue;
      }
      if (hay.contains(token)) hits++;
    }
    return hits >= 1;
  }

  static List<String> relevanceTokens(ResearchGoal goal) {
    final tokens = <String>{};
    void add(String text) {
      for (final part in text
          .toLowerCase()
          .split(RegExp(r'[\s,،/|;:+-]+'))) {
        final t = part.trim();
        if (t.length >= 3 && !_stop.contains(t)) tokens.add(t);
      }
    }

    add(goal.fieldEn);
    add(goal.field);
    for (final q in goal.searchQueries) {
      add(q);
    }
    for (final k in goal.matchKeywords) {
      add(k);
    }
    for (final m in goal.methods) {
      add(m);
    }
    add(goal.searchQuery);
    if (!looksLikePastedManuscript(goal.raw)) add(goal.raw);
    return tokens.toList();
  }

  /// A thesis goal may be a paragraph. Huge pastes are not treated as the goal.
  static bool looksLikePastedManuscript(String raw) {
    final text = raw.trim();
    if (text.length > 2500) return true;
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return words > 400;
  }

  /// Keep paragraph breaks; clip only if the user pasted a manuscript.
  static String contextForAi(String raw, {int maxChars = 2000}) {
    var text = raw.trim().replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}…';
  }

  /// English query for OpenAlex / Semantic Scholar / Crossref — never a pasted manuscript.
  static String englishSearchQuery(ResearchGoal goal) {
    final parts = <String>[];
    void addLatin(String text) {
      final latin = text
          .replaceAll(RegExp(r'[^\x00-\x7F]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (latin.length >= 4) parts.add(latin);
    }

    addLatin(goal.fieldEn);
    for (final q in goal.searchQueries) {
      addLatin(q);
    }
    addLatin(goal.searchQuery);
    var joined = _unique(parts).join(' ');
    joined = joined.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (joined.length > 140) joined = joined.substring(0, 140).trim();
    if (joined.length >= 8) return joined;
    if (goal.fieldEn.trim().length >= 4) return goal.fieldEn.trim();
    final field = goal.field.trim();
    if (field.length >= 4 && field.length <= 100) return field;
    final q = goal.searchQuery.trim();
    if (q.length >= 4 && q.length <= 100) return q;
    return '';
  }

  /// Search strings taken from the user's own field — any discipline.
  static List<String> scientificSearchQueries(
    ResearchGoal goal, {
    bool includeNativeField = false,
  }) {
    final queries = <String>[];
    final primary = englishSearchQuery(goal);
    if (primary.length >= 4) queries.add(primary);
    for (final q in goal.searchQueries) {
      final t = q.trim();
      if (t.length >= 8 && t.length <= 120) queries.add(t);
    }
    if (includeNativeField) {
      final ar = goal.field.trim();
      if (ar.length >= 8 && ar.length <= 80) queries.add(ar);
    }
    return _unique(queries).where((q) => q.length >= 4).take(3).toList();
  }

  static List<String> corePhrases(ResearchGoal goal) {
    final phrases = <String>{};
    void addPhrase(String raw) {
      final t = raw.trim().toLowerCase();
      if (t.length >= 4) phrases.add(t);
    }

    addPhrase(goal.fieldEn);
    addPhrase(goal.field);
    for (final q in goal.searchQueries) {
      addPhrase(q);
    }
    final latin = englishSearchQuery(goal).toLowerCase().split(RegExp(r'\s+'));
    for (var i = 0; i < latin.length; i++) {
      final w = latin[i];
      if (w.length >= 5 && !_weakTokens.contains(w) && !_stop.contains(w)) {
        phrases.add(w);
      }
      if (i + 1 < latin.length) {
        final pair = '${latin[i]} ${latin[i + 1]}';
        if (pair.length >= 8) addPhrase(pair);
      }
    }
    phrases.removeWhere((p) => p.isEmpty);
    return phrases.toList();
  }

  static List<String> strongMatchTokens(ResearchGoal goal) {
    return relevanceTokens(goal)
        .map((t) => t.toLowerCase())
        .where((t) => t.length >= 4 && !_stop.contains(t) && !_weakTokens.contains(t))
        .toList();
  }

  static ResearchGoal applyLocalEnglish(ResearchGoal goal) {
    final queries = <String>[...goal.searchQueries];
    final keywords = <String>[...goal.matchKeywords];
    var fieldEn = goal.fieldEn;

    final latin = RegExp(
      r'[A-Za-z][A-Za-z0-9\-/]+(?:\s+[A-Za-z][A-Za-z0-9\-/]+){0,6}',
    ).allMatches(goal.raw);
    for (final m in latin) {
      final phrase = m.group(0)?.trim() ?? '';
      if (phrase.length >= 3) {
        queries.add(phrase);
        keywords.addAll(phrase.split(RegExp(r'\s+')));
        fieldEn = fieldEn.isEmpty ? phrase : fieldEn;
      }
    }

    final hay = '${goal.raw} ${goal.field}'.toLowerCase();
    for (final entry in _aliases.entries) {
      if (hay.contains(entry.key)) {
        queries.add(entry.value);
        keywords.addAll(entry.value.split(' '));
        if (fieldEn.isEmpty) fieldEn = entry.value;
      }
    }

    final uniqueQueries = _unique(queries);
    final uniqueKw = _unique(keywords);
    final methods = <String>[...goal.methods];
    final hayEn = '${goal.raw} ${goal.field} $fieldEn'.toLowerCase();
    if (hayEn.contains('analytic') || hay.contains('تحليل')) {
      methods.addAll(['HPLC', 'GC-MS', 'UV-Vis', 'titration']);
    }
    if (hayEn.contains('oil') ||
        hay.contains('زيت') ||
        hayEn.contains('refin') ||
        hay.contains('تكرير')) {
      methods.addAll(['acid value', 'peroxide value', 'GC-MS']);
    }
    if (hayEn.contains('adsorp') || hay.contains('امتزاز') || hay.contains('امتصاص')) {
      methods.addAll(['isotherm', 'BET', 'adsorption']);
    }
    return goal.copyWith(
      fieldEn: fieldEn,
      searchQuery: uniqueQueries.isNotEmpty
          ? uniqueQueries.first
          : (fieldEn.isNotEmpty ? fieldEn : goal.searchQuery),
      searchQueries: uniqueQueries,
      matchKeywords: uniqueKw,
      methods: _unique(methods),
    );
  }

  static ResearchGoal? fromAiMap(Map<String, dynamic> map, ResearchGoal base) {
    final fieldEn = map['field_en']?.toString().trim() ?? '';
    final fieldAr = map['field_ar']?.toString().trim() ?? '';
    final queries = _stringList(map['search_queries']);
    final keywords = _stringList(map['match_keywords']);
    final methods = _stringList(map['methods']);
    if (fieldEn.length < 4 && queries.isEmpty) return null;

    final trackRaw = map['track']?.toString().toLowerCase() ?? '';
    final instRaw = map['institution']?.toString().toLowerCase() ?? '';

    return base.copyWith(
      field: fieldAr.length >= 3 ? fieldAr : base.field,
      fieldEn: fieldEn.isNotEmpty ? fieldEn : base.fieldEn,
      searchQuery: queries.isNotEmpty
          ? queries.first
          : (fieldEn.isNotEmpty ? fieldEn : base.searchQuery),
      searchQueries: queries,
      matchKeywords: keywords,
      methods: methods,
      track: switch (trackRaw) {
        'phd' || 'doctorate' || 'دكتوراه' => ResearchDegreeTrack.phd,
        'diploma' || 'دبلوم' => ResearchDegreeTrack.diploma,
        'masters' || 'master' || 'ماجستير' => ResearchDegreeTrack.masters,
        _ => base.track,
      },
      institution: switch (instRaw) {
        'factory' || 'industry' || 'مصنع' => InstitutionTarget.factory,
        'ministry' || 'وزارة' => InstitutionTarget.ministry,
        'development' || 'تنمية' => InstitutionTarget.development,
        'university' || 'جامعة' => InstitutionTarget.university,
        _ => base.institution,
      },
    );
  }

  static List<DegreePlanStage> stagesFromAiText(String text) {
    final stages = <DegreePlanStage>[];
    final blocks = text.split(RegExp(r'(?=^###\s)', multiLine: true));
    for (final block in blocks) {
      final lines = block
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;
      final head = lines.first.replaceFirst(RegExp(r'^###\s*'), '');
      if (head.length < 4) continue;
      final parts = head.split('·');
      final period = parts.first.trim();
      final title = parts.length > 1
          ? parts.sublist(1).join('·').trim()
          : (lines.length > 1 ? lines[1] : head);
      final outcomes = <String>[];
      final actions = <String>[];
      for (final line in lines.skip(1)) {
        if (line.startsWith('→') || line.startsWith('->')) {
          actions.add(line.replaceFirst(RegExp(r'^(→|->)\s*'), ''));
        } else if (line.startsWith('-') || line.startsWith('•')) {
          outcomes.add(line.replaceFirst(RegExp(r'^[-•]\s*'), ''));
        }
      }
      stages.add(
        DegreePlanStage(
          period: period,
          title: title,
          outcomes: outcomes,
          platformActions: actions,
        ),
      );
    }
    return stages.where((s) => s.title.isNotEmpty).take(8).toList();
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.length >= 2)
        .toList();
  }

  static List<String> _unique(List<String> items) {
    final seen = <String>{};
    final out = <String>[];
    for (final item in items) {
      final key = item.trim().toLowerCase();
      if (key.length < 2 || seen.contains(key)) continue;
      seen.add(key);
      out.add(item.trim());
    }
    return out;
  }

  static ResearchGoal parse(String raw, {String? profileDegree}) {
    final text = raw.trim();
    final lower = text.toLowerCase();
    final track = _track(lower, profileDegree);
    final institution = _institution(lower);
    final field = _field(text);
    final years = track == ResearchDegreeTrack.phd
        ? 3
        : track == ResearchDegreeTrack.diploma
            ? 1
            : 2;
    return applyLocalEnglish(
      ResearchGoal(
        raw: text,
        field: field,
        track: track,
        institution: institution,
        searchQuery: field.length >= 4 ? field : text,
        years: years,
      ),
    );
  }

  static ResearchDegreeTrack _track(String lower, String? profileDegree) {
    if (lower.contains('دكتوراه') ||
        lower.contains('phd') ||
        lower.contains('doctorate')) {
      return ResearchDegreeTrack.phd;
    }
    if (lower.contains('دبلوم') || lower.contains('diploma')) {
      return ResearchDegreeTrack.diploma;
    }
    if (lower.contains('ماجستير') ||
        lower.contains('ما جستير') ||
        lower.contains('master') ||
        lower.contains('msc') ||
        lower.contains('mba')) {
      return ResearchDegreeTrack.masters;
    }
    if (profileDegree != null && profileDegree.trim().isNotEmpty) {
      if (isDoctoralDegree(profileDegree)) return ResearchDegreeTrack.phd;
      if (isDiplomaDegree(profileDegree)) return ResearchDegreeTrack.diploma;
      if (isMastersLevelDegree(profileDegree)) {
        return ResearchDegreeTrack.masters;
      }
    }
    return ResearchDegreeTrack.unspecified;
  }

  static InstitutionTarget _institution(String lower) {
    if (lower.contains('مصنع') ||
        lower.contains('factory') ||
        lower.contains('صناع') ||
        lower.contains('industry') ||
        lower.contains('إنتاج')) {
      return InstitutionTarget.factory;
    }
    if (lower.contains('وزار') ||
        lower.contains('ministry') ||
        lower.contains('حكوم') ||
        lower.contains('هيئة')) {
      return InstitutionTarget.ministry;
    }
    if (lower.contains('تنمي') ||
        lower.contains('development') ||
        lower.contains('مؤسس') ||
        lower.contains('تنظيم') ||
        lower.contains('ngo')) {
      return InstitutionTarget.development;
    }
    if (lower.contains('جامع') || lower.contains('university')) {
      return InstitutionTarget.university;
    }
    return InstitutionTarget.unspecified;
  }

  static String _field(String text) {
    final head = _goalHead(text);
    final headLower = head.toLowerCase();
    final markers = ['في', 'عن', ' in ', ' on '];
    var best = '';
    for (final marker in markers) {
      final idx = headLower.indexOf(marker);
      if (idx < 0) continue;
      final after = head.substring(idx + marker.length).trim();
      final cleaned = _stripTail(after);
      if (cleaned.length >= 3 && cleaned.length > best.length) {
        best = cleaned;
      }
    }
    if (best.length >= 3) return best;

    var cleaned = head;
    for (final noise in [
      'أريد',
      'اريد',
      'عايز',
      'عمل',
      'أعمل',
      'اعمل',
      'ماجستير',
      'ما جستير',
      'دكتوراه',
      'دبلوم',
      'دراسات عليا',
      'i want',
      "i'd like",
      'to do',
      'a master\'s',
      'masters',
      'master',
      'phd',
      'in',
      'on',
      'في',
      'عن',
    ]) {
      cleaned = cleaned.replaceAll(
        RegExp(RegExp.escape(noise), caseSensitive: false),
        ' ',
      );
    }
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.length >= 3 ? cleaned : head.trim();
  }

  /// Short label for titles: first clauses only. The full goal stays in [ResearchGoal.raw].
  static String _goalHead(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return normalized;
    final sentences = normalized
        .split(RegExp(r'(?<=[.!?؟。])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (sentences.isEmpty) return normalized;
    if (sentences.length == 1) {
      final first = sentences.first;
      return first.length > 400 ? first.substring(0, 400) : first;
    }
    final two = '${sentences[0]} ${sentences[1]}';
    return two.length > 400 ? two.substring(0, 400) : two;
  }

  static String _stripTail(String value) {
    var text = value.trim();
    final stop = RegExp(r'[.!?؟。]').firstMatch(text);
    if (stop != null && stop.start >= 8) {
      text = text.substring(0, stop.start).trim();
    }
    return text
        .replaceAll(
          RegExp(
            r'(?:لتنمية|لتطوير|لمصنع|لوزارة|حتى|لكي|so that|for a).*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }
}

class DegreePlanEngine {
  DegreePlanEngine._();

  static String methodHint(ResearchGoal goal) {
    if (goal.methods.isNotEmpty) {
      return goal.methods.take(4).join(appTr('، ', ', '));
    }
    final en = goal.fieldEn.toLowerCase();
    if (en.contains('analytic') || en.contains('chromat')) {
      return 'HPLC / GC-MS / UV-Vis / titration';
    }
    if (en.contains('oil') || en.contains('refin')) {
      return 'acid value, peroxide value, GC-MS';
    }
    if (en.contains('adsorp')) {
      return 'isotherm, BET, kinetics';
    }
    if (goal.fieldEn.isNotEmpty) return goal.fieldEn;
    return goal.field.isNotEmpty ? goal.field : goal.raw;
  }

  static List<DegreePlanStage> build(ResearchGoal goal) {
    final field = goal.fieldEn.isNotEmpty
        ? '${goal.field} (${goal.fieldEn})'
        : (goal.field.isEmpty ? goal.raw : goal.field);
    if (goal.track == ResearchDegreeTrack.phd) {
      return _phd(field, goal);
    }
    if (goal.track == ResearchDegreeTrack.diploma) {
      return _diploma(field, goal);
    }
    return _masters(field, goal);
  }

  static List<String> institutionalNotes(ResearchGoal goal) {
    final field = goal.field.isEmpty ? goal.raw : goal.field;
    final notes = <String>[
      appTr(
        'صغ مذكرة تطبيق من صفحة واحدة: المشكلة في $field، النتيجة المتوقعة، ومتطلب التشغيل.',
        'Write a one-page application brief: the $field problem, expected result, and operating need.',
      ),
    ];
    switch (goal.institution) {
      case InstitutionTarget.factory:
        notes.add(appTr(
          'اربط القياس بمؤشر تشغيل (جودة، فاقد، زمن دورة، تكلفة عينة) يمكن لمصنع تتبعه.',
          'Tie measurement to an operations KPI (quality, waste, cycle time, sample cost) a factory can track.',
        ));
        notes.add(appTr(
          'لا تسمِّ جهة تمويل غير موجودة في المنصة. استخدم تحدي صناعة بعربون أو صندوق البحث إن ظهر تطابق.',
          'Do not name a funder that is not on the platform. Use an escrowed industry challenge or the research fund if a match appears.',
        ));
      case InstitutionTarget.ministry:
        notes.add(appTr(
          'صغ الأثر بلغة سياسة عامة: دليل إجرائي، مؤشر خدمة، أو تقليل فجوة بيانات.',
          'Frame impact in public-policy language: an SOP, a service metric, or a data-gap reduction.',
        ));
      case InstitutionTarget.development:
        notes.add(appTr(
          'حدّد المستفيد المؤسسي وآلية نقل النتيجة (تدريب، دليل، نموذج قرار).',
          'Name the institutional beneficiary and the transfer mechanism (training, handbook, decision model).',
        ));
      case InstitutionTarget.university:
        notes.add(appTr(
          'حافظ على فجوة علمية واضحة، ثم أضف فقرة نقل معرفة للكلية أو المعمل الشريك.',
          'Keep a clear scientific gap, then add a knowledge-transfer paragraph for the faculty or partner lab.',
        ));
      case InstitutionTarget.unspecified:
        notes.add(appTr(
          'اختر مستفيداً واحداً قابلاً للتمويل (خط إنتاج، إدارة خدمة، أو برنامج تنمية) قبل طلب الدعم.',
          'Pick one fundable beneficiary (a production line, a service unit, or a development program) before asking for support.',
        ));
    }
    return notes;
  }

  static List<DegreePlanStage> _masters(String field, ResearchGoal goal) {
    final methods = methodHint(goal);
    return [
      DegreePlanStage(
        period: appTr('الفصل 1 · السنة 1', 'Semester 1 · Year 1'),
        title: appTr(
          'فجوة علمية في $field',
          'Scientific gap in $field',
        ),
        outcomes: [
          appTr(
            'سؤال واحد في $field يُقاس بـ $methods، لا بموضوع عام.',
            'One question in $field measured with $methods — not a generic topic.',
          ),
          appTr(
            'مراجعة ≥15 دراسة مؤكدة DOI عن $field من OpenAlex/Crossref — بلا مصادر مختلقة.',
            'Review ≥15 DOI-confirmed studies on $field from OpenAlex/Crossref — no invented sources.',
          ),
        ],
        platformActions: [
          appTr(
            'اختر مشرفاً تظهر كلمات $field في تخصصه أو أعماله، لا لأنه في نفس الكلية فقط.',
            'Pick a supervisor whose speciality or works contain $field — not faculty membership alone.',
          ),
          appTr('احجز عنوان الموضوع إن كان متاحاً في جامعتك.', 'Claim the topic title if available at your university.'),
        ],
      ),
      DegreePlanStage(
        period: appTr('الفصل 2 · السنة 1', 'Semester 2 · Year 1'),
        title: appTr(
          'بروتوكول $methods لـ $field',
          '$methods protocol for $field',
        ),
        outcomes: [
          appTr(
            'مقترح: عينات $field، معايرة $methods، جدول زمني، مخاطر التحليل.',
            'Proposal: $field samples, $methods calibration, timeline, analytical risks.',
          ),
          appTr(
            'قائمة أجهزة/كواشف تطابق $methods فقط — أرفض أي بند بلا كلمة من الموضوع.',
            'Instrument/reagent list that matches $methods only — reject any item with no topic word.',
          ),
        ],
        platformActions: [
          appTr(
            'احجز مختبراً يملك $methods أو خدمة تحليل لنفس النقطة.',
            'Book a lab that owns $methods or analysis for this same point.',
          ),
          appTr(
            'أضف لسلة المتجر مواد يظهر اسمها كاشفاً أو جهازاً لـ $field.',
            'Add store items whose names are reagents or instruments for $field.',
          ),
        ],
      ),
      DegreePlanStage(
        period: appTr('الفصل 3 · السنة 2', 'Semester 3 · Year 2'),
        title: appTr(
          'بيانات $field عبر $methods',
          '$field data via $methods',
        ),
        outcomes: [
          appTr(
            'مجموعة بيانات مكتملة لـ $field (تكرار، بلانك، ضبط جودة).',
            'A complete $field dataset (replicates, blanks, QC).',
          ),
          appTr('سجل انحرافات بروتوكول $methods وقرارات التصحيح.', 'A log of $methods protocol deviations and corrections.'),
        ],
        platformActions: [
          appTr(
            'حلّل العينات أو احجز جلسات $methods حسب الجهاز المطابق.',
            'Analyze samples or book $methods sessions on the matched instrument.',
          ),
        ],
      ),
      DegreePlanStage(
        period: appTr('الفصل 4 · السنة 2', 'Semester 4 · Year 2'),
        title: appTr(
          'نتائج $field ونقلها لـ ${goal.institutionLabel}',
          '$field results and transfer to ${goal.institutionLabel}',
        ),
        outcomes: [
          appTr(
            'مسودة فصول تفسّر قياسات $methods في $field + فحص الاستشهاد.',
            'Chapter draft that interprets $methods measurements in $field + citation check.',
          ),
          appTr(
            'مذكرة تطبيق لـ ${goal.institutionLabel} من نتائج $field فقط، بلا اختراع جهات.',
            'An application brief for ${goal.institutionLabel} from $field results only — no invented organizations.',
          ),
        ],
        platformActions: [
          appTr('محاكاة المناقشة وتقرير صحة الاستشهاد.', 'Viva simulation and citation-health report.'),
          appTr('إن وُجد تحدٍ صناعي مطابق لـ $field: قدّم بروتوكولاً بعد حجز العربون.', 'If a matching industry challenge exists for $field: submit a protocol after the deposit is held.'),
        ],
      ),
    ];
  }

  static List<DegreePlanStage> _phd(String field, ResearchGoal goal) {
    return [
      DegreePlanStage(
        period: appTr('الفصل 1 · السنة 1', 'Semester 1 · Year 1'),
        title: appTr('خريطة الأدبيات والفجوة', 'Literature map and gap'),
        outcomes: [
          appTr(
            'خريطة ≥15 دراسة مؤكدة في $field (${methodHint(goal)})، ثم فجوة واحدة مكتوبة.',
            'A map of ≥15 confirmed studies in $field (${methodHint(goal)}), then one written gap.',
          ),
        ],
        platformActions: [
          appTr('طابق مشرفاً ببصمة OpenAlex قريبة من الفجوة.', 'Match a supervisor whose OpenAlex identity is close to the gap.'),
        ],
      ),
      DegreePlanStage(
        period: appTr('الفصل 2 · السنة 1', 'Semester 2 · Year 1'),
        title: appTr('مقترح الدكتوراه والمنهج', 'PhD proposal and method'),
        outcomes: [
          appTr(
            'مقترح لثلاث سنوات في $field بمنهج ${methodHint(goal)}: أسئلة، إسهام، موارد، أخلاقيات.',
            'A three-year $field proposal using ${methodHint(goal)}: questions, contribution, resources, ethics.',
          ),
        ],
        platformActions: [
          appTr('اربط المختبر والمواد بخطة التجارب لا بوصف عام.', 'Bind the lab and materials to the experiment plan, not a generic description.'),
        ],
      ),
      DegreePlanStage(
        period: appTr('السنة 2', 'Year 2'),
        title: appTr('بيانات، ورقة أولى، مراجعة منتصف', 'Data, first paper, mid-review'),
        outcomes: [
          appTr('مجموعة بيانات أساسية + مسودة ورقة إن سمح المشرف.', 'A core dataset + a paper draft if the supervisor allows.'),
        ],
        platformActions: [
          appTr('استخدم فحص الاستشهاد والنشر فقط بعناوين مؤكدة.', 'Use citation check and publishing only with confirmed titles.'),
        ],
      ),
      DegreePlanStage(
        period: appTr('السنة 3', 'Year 3'),
        title: appTr('التأليف والدفاع والنقل', 'Synthesis, defense, and transfer'),
        outcomes: [
          appTr(
            'رسالة مكتملة + مذكرة أثر لـ ${goal.institutionLabel}.',
            'A completed thesis + an impact brief for ${goal.institutionLabel}.',
          ),
        ],
        platformActions: [
          appTr('المناقشة، ثم عرض التمويل من تطابق حقيقي فقط.', 'Viva, then a funding pitch only from a real match.'),
        ],
      ),
    ];
  }

  static List<DegreePlanStage> _diploma(String field, ResearchGoal goal) {
    return [
      DegreePlanStage(
        period: appTr('الفصل 1', 'Semester 1'),
        title: appTr('تحديد تطبيق $field', 'Define the $field application'),
        outcomes: [
          appTr(
            'سؤال تطبيقي واحد في $field (${methodHint(goal)}) و15 دراسة مؤكدة إن وُجدت.',
            'One applied $field question (${methodHint(goal)}) and 15 confirmed studies if found.',
          ),
        ],
        platformActions: [
          appTr('طابق مشرفاً أو خبيراً ومختبراً قريباً.', 'Match a nearby supervisor or expert and a lab.'),
        ],
      ),
      DegreePlanStage(
        period: appTr('الفصل 2', 'Semester 2'),
        title: appTr('تنفيذ قصير وتسليم', 'Short execution and delivery'),
        outcomes: [
          appTr(
            'تقرير تطبيقي + مذكرة لـ ${goal.institutionLabel}.',
            'An applied report + a brief for ${goal.institutionLabel}.',
          ),
        ],
        platformActions: [
          appTr('مواد المتجر وحجز الجلسة حسب الحاجة فقط.', 'Store materials and session booking only as needed.'),
        ],
      ),
    ];
  }
}
