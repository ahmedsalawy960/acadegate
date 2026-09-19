import 'dart:convert';

import '../ai_advisor/gemini_advisor_client.dart';
import '../ai_advisor/grounded_work.dart';
import '../ai_advisor/literature_relevance.dart';
import '../research_supply_chain/research_goal.dart';
import 'thesis_studio_command.dart';
import 'thesis_studio_discipline.dart';
import 'thesis_studio_kind.dart';

class LiteratureSearchPlan {
  final String topic;
  final List<String> queries;
  final List<String> includeTerms;
  final List<String> excludeHints;
  final String homeDiscipline;
  final String thesisGoal;

  const LiteratureSearchPlan({
    required this.topic,
    required this.queries,
    this.includeTerms = const [],
    this.excludeHints = const [],
    this.homeDiscipline = '',
    this.thesisGoal = '',
  });
}

/// Discipline-agnostic: rewrite the user's goal into search queries, then
/// keep only index hits a specialist in THAT field would cite.
class ThesisLiteratureAi {
  ThesisLiteratureAi._();

  static final ThesisLiteratureAi instance = ThesisLiteratureAi._();

  Future<LiteratureSearchPlan> planSearch({
    required String rawGoal,
    required ResearchGoal goal,
    required bool arabicDraft,
    ThesisDiscipline discipline = ThesisDiscipline.empty,
  }) async {
    final local = _localPlan(rawGoal, goal, arabicDraft, discipline);
    if (!GeminiAdvisorClient.isAvailable) {
      return await _ensureEnglishQueries(
        local,
        rawGoal: rawGoal,
        goal: goal,
        discipline: discipline,
      );
    }

    final topic = ThesisCommandSpec.parse(
      rawGoal,
      depth: ThesisChapterDepth.full,
    ).topicText;
    final home = discipline.isPresent
        ? '${discipline.facultyEn} / ${discipline.labelEn} (${discipline.facultyAr} / ${discipline.labelAr})'
        : 'unspecified';
    final arabicInput = ResearchGoalParser.containsArabic(rawGoal) ||
        ResearchGoalParser.containsArabic(goal.raw) ||
        ResearchGoalParser.containsArabic(topic);
    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: '''
You plan bibliographic search for ANY academic field (sciences, humanities, law, education, engineering, arts, social science).
PARENT FRAME = the full thesis goal. SEARCH TARGET = the paragraph command, interpreted only as a facet of that goal.
Papers must match the paragraph command AND remain inside the thesis goal AND the student's home faculty/department.
Never assume chemistry, seeds, medicine, or any other field unless that is the home department and present in the goal.
Do not widen a named species, method, statute, or theory beyond what the goal allows.
Return JSON only, no markdown:
{"topic":"8-16 word ENGLISH topic","queries":["q1","q2","q3","q4"],"include":["term1","term2"],"exclude":["generic false-friend 1"]}
Rules:
- OpenAlex / Crossref / Semantic Scholar are English-first indexes.
- If the thesis goal or paragraph command is in Arabic: UNDERSTAND it, then TRANSLATE the scientific meaning into precise ENGLISH scholarly queries and include terms. Do not copy Arabic words into queries or include.
- Example pattern: Arabic topic about a material + pollutant → English queries naming that material and pollutant with methods (leaching, adsorption, recovery) only if present in the goal.
- queries are 4-16 ENGLISH words, specific enough for OpenAlex/Semantic Scholar.
- Put distinctive nouns from BOTH the thesis goal and the paragraph command in queries (species, methods, named theories, places, statutes).
- Append the home-department scholarly terms to queries so hits stay in that discipline.
- Draft language (Arabic vs English prose) does NOT change this rule: bibliographic queries must be English.
- include terms are distinctive ENGLISH nouns from the goal+command, not words like study, products, characteristics, chemical, functional, development, seeds, crops.
- exclude lists broader near-misses, other faculties, and topics outside the thesis goal.
- Do not invent a different thesis topic.
''',
      userMessage: '''
Draft prose language: ${arabicDraft ? 'Arabic' : 'English'}
Input contains Arabic that must be translated for search: ${arabicInput ? 'YES — translate to English scholarly queries' : 'no'}
HOME FACULTY / DEPARTMENT (mandatory filter): $home
Alien fields to reject: ${discipline.alienHints.join(', ')}

THESIS GOAL (parent frame — every paper must serve this):
${ResearchGoalParser.contextForAi(goal.raw)}
Parsed field: ${goal.field} / ${goal.fieldEn}

PARAGRAPH COMMAND (search target — a subsection of the goal, not a new thesis):
${topic.isNotEmpty ? topic : rawGoal}
''',
      maxOutputTokens: 1200,
      preferPro: true,
    );
    if (!result.isSuccess || result.text == null) {
      return await _ensureEnglishQueries(
        local,
        rawGoal: rawGoal,
        goal: goal,
        discipline: discipline,
      );
    }
    final parsed = parsePlan(result.text!, fallback: local);
    final withHome = LiteratureSearchPlan(
      topic: parsed.topic,
      queries: [
        for (final q in parsed.queries)
          discipline.querySuffix.isEmpty ||
                  q.toLowerCase().contains(discipline.querySuffix.toLowerCase())
              ? q
              : '$q ${discipline.querySuffix}',
      ],
      includeTerms: parsed.includeTerms,
      excludeHints: {
        ...parsed.excludeHints,
        ...discipline.alienHints,
        ...LiteratureRelevance.opportunisticJunk,
      }.toList(),
      homeDiscipline: local.homeDiscipline,
      thesisGoal: local.thesisGoal,
    );
    return await _ensureEnglishQueries(
      withHome.queries.isEmpty ? local : withHome,
      rawGoal: rawGoal,
      goal: goal,
      discipline: discipline,
    );
  }

  /// If Arabic remains in queries/includes, force an English scholarly rewrite.
  Future<LiteratureSearchPlan> _ensureEnglishQueries(
    LiteratureSearchPlan plan, {
    required String rawGoal,
    required ResearchGoal goal,
    required ThesisDiscipline discipline,
  }) async {
    final arabicInInput = ResearchGoalParser.containsArabic(rawGoal) ||
        ResearchGoalParser.containsArabic(goal.raw) ||
        ResearchGoalParser.containsArabic(plan.topic);
    final arabicInQueries = plan.queries.any(ResearchGoalParser.containsArabic) ||
        plan.includeTerms.any(ResearchGoalParser.containsArabic);
    final englishQueries = [
      for (final q in plan.queries)
        if (!ResearchGoalParser.containsArabic(q) && q.trim().length >= 6) q.trim(),
    ];
    final latinFromUser = ResearchGoalParser.englishQueriesFromText(
      '$rawGoal ${goal.raw} ${plan.topic} ${goal.field} ${goal.fieldEn}',
    );

    if (!arabicInInput && !arabicInQueries && englishQueries.length >= 2) {
      return plan;
    }

    if (GeminiAdvisorClient.isAvailable &&
        (arabicInInput || arabicInQueries || englishQueries.isEmpty)) {
      final result = await GeminiAdvisorClient.instance.generateResult(
        systemPrompt: '''
You are a bilingual scientific librarian (Arabic ↔ English).
Convert the user's Arabic (or mixed) thesis topic into ENGLISH bibliographic search queries for OpenAlex/Crossref.
Return JSON only:
{"topic":"short ENGLISH topic","queries":["q1","q2","q3","q4"],"include":["keyword1","keyword2","keyword3"]}
Rules:
- Understand Arabic academic wording; translate the scientific object, method, and context accurately.
- Prefer standard scholarly English for the user's actual topic (do not substitute a different field).
- Keep the same thesis object — do not invent a new topic.
- include = distinctive English nouns/phrases only.
- No Arabic script in topic, queries, or include.
''',
        userMessage: '''
Home department: ${plan.homeDiscipline}
Thesis goal:
${plan.thesisGoal.isNotEmpty ? plan.thesisGoal : goal.raw}
Paragraph / topic:
${plan.topic.isNotEmpty ? plan.topic : rawGoal}
Known English field: ${goal.fieldEn}
Latin phrases already in the user text: ${latinFromUser.join(', ')}
''',
        maxOutputTokens: 900,
        preferPro: true,
      );
      if (result.isSuccess && result.text != null) {
        final parsed = parsePlan(result.text!, fallback: plan);
        final mergedQueries = <String>[
          ...[
            for (final q in parsed.queries)
              if (!ResearchGoalParser.containsArabic(q)) q,
          ],
          ...englishQueries,
          ...latinFromUser,
        ];
        final mergedInclude = <String>[
          ...[
            for (final t in parsed.includeTerms)
              if (!ResearchGoalParser.containsArabic(t)) t,
          ],
          ...[
            for (final t in plan.includeTerms)
              if (!ResearchGoalParser.containsArabic(t)) t,
          ],
          ...latinFromUser,
        ];
        final uniqueQ = <String>{};
        final uniqueI = <String>{};
        return LiteratureSearchPlan(
          topic: ResearchGoalParser.containsArabic(parsed.topic)
              ? (goal.fieldEn.isNotEmpty ? goal.fieldEn : plan.topic)
              : (parsed.topic.isNotEmpty ? parsed.topic : plan.topic),
          queries: [
            for (final q in mergedQueries)
              if (uniqueQ.add(q.toLowerCase()))
                discipline.querySuffix.isEmpty ||
                        q.toLowerCase().contains(discipline.querySuffix.toLowerCase())
                    ? q
                    : '$q ${discipline.querySuffix}',
          ].take(6).toList(),
          includeTerms: [
            for (final t in mergedInclude)
              if (uniqueI.add(t.toLowerCase())) t,
          ].take(14).toList(),
          excludeHints: plan.excludeHints,
          homeDiscipline: plan.homeDiscipline,
          thesisGoal: plan.thesisGoal,
        );
      }
    }

    // Offline / failed AI: keep any Latin phrases already typed by the user.
    if (latinFromUser.isEmpty && englishQueries.isNotEmpty) return plan;
    final uniqueQ = <String>{};
    final merged = [
      ...englishQueries,
      ...latinFromUser,
      ...plan.queries,
    ];
    return LiteratureSearchPlan(
      topic: ResearchGoalParser.containsArabic(plan.topic) && goal.fieldEn.isNotEmpty
          ? goal.fieldEn
          : plan.topic,
      queries: [
        for (final q in merged)
          if (!ResearchGoalParser.containsArabic(q) && uniqueQ.add(q.toLowerCase()))
            q,
      ].take(6).toList(),
      includeTerms: [
        ...[
          for (final t in plan.includeTerms)
            if (!ResearchGoalParser.containsArabic(t)) t,
        ],
        ...latinFromUser,
      ].take(14).toList(),
      excludeHints: plan.excludeHints,
      homeDiscipline: plan.homeDiscipline,
      thesisGoal: plan.thesisGoal,
    );
  }

  Future<List<GroundedWork>> gate({
    required LiteratureSearchPlan plan,
    required List<GroundedWork> works,
    int maxKeep = 40,
  }) async {
    if (works.isEmpty) return const [];
    if (!GeminiAdvisorClient.isAvailable) return works.take(maxKeep).toList();

    final kept = <GroundedWork>[];
    const batch = 12;
    for (var offset = 0; offset < works.length; offset += batch) {
      final slice = works.sublist(
        offset,
        offset + batch > works.length ? works.length : offset + batch,
      );
      final indexes = await _gateBatch(plan, slice);
      // Empty keep from a successful model call = intentional reject for this batch.
      // API failures already return every index from _gateBatch.
      if (indexes.isEmpty) continue;
      for (final i in indexes) {
        if (i >= 1 && i <= slice.length) kept.add(slice[i - 1]);
      }
      if (kept.length >= maxKeep) break;
    }
    final unique = <String, GroundedWork>{};
    for (final w in kept) {
      unique.putIfAbsent(w.mergeKey, () => w);
    }
    if (unique.isEmpty) return works.take(maxKeep).toList();
    return unique.values.take(maxKeep).toList();
  }

  Future<List<int>> _gateBatch(
    LiteratureSearchPlan plan,
    List<GroundedWork> slice,
  ) async {
    final list = StringBuffer();
    for (var i = 0; i < slice.length; i++) {
      final w = slice[i];
      final abs = w.abstractText.trim();
      final cut = abs.length > 220 ? '${abs.substring(0, 220)}…' : abs;
      list.writeln(
        '${i + 1}. ${w.title} (${w.year ?? 'n.d.'}) ${w.journal ?? ''} $cut',
      );
    }
    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: '''
You filter candidate papers for a thesis literature map. Any academic field.
Keep a paper ONLY if a specialist in the HOME faculty/department would cite it for THIS paragraph command as a part of the THESIS GOAL.
Reject immediately:
- Papers outside the thesis goal even if they match a vague word in the paragraph command
- COVID-19 / pandemic / clinical COVID text papers unless the goal/command is about COVID
- Generic machine-learning or blockchain surveys unless the goal/command asks for them
- Pure methodology tutorials ("literature review as a research methodology") unless asked
- Papers that only share a broad faculty word (agriculture, chemistry, education) without the goal's distinctive object
- Papers from another faculty even if the broad topic overlaps
Return JSON only: {"keep":[1,3,5]}
If none qualify, {"keep":[]}
Do not invent DOIs or titles. Prefer keeping fewer papers over noisy ones.
Prefer keeping at least 3–6 papers when several candidates clearly match the goal.
''',
      userMessage: '''
Thesis goal (parent frame):
${plan.thesisGoal.isNotEmpty ? plan.thesisGoal : plan.topic}
Paragraph command / topic: ${plan.topic}
Home faculty/department: ${plan.homeDiscipline}
Must-fit terms: ${plan.includeTerms.join(', ')}
User-sensitive collisions to avoid: ${plan.excludeHints.take(12).join(', ')}

Candidates:
$list
''',
      maxOutputTokens: 400,
      preferPro: true,
    );
    if (!result.isSuccess || result.text == null) {
      // API failure must not empty the literature list.
      return [for (var i = 1; i <= slice.length; i++) i];
    }
    return parseKeepIndexes(result.text!, maxIndex: slice.length);
  }

  static LiteratureSearchPlan parsePlan(
    String raw, {
    required LiteratureSearchPlan fallback,
  }) {
    final map = _jsonMap(raw);
    if (map == null) return fallback;
    final queries = _stringList(map['queries']);
    final include = _stringList(map['include']);
    final exclude = _stringList(map['exclude']);
    final topic = map['topic']?.toString().trim() ?? '';
    return LiteratureSearchPlan(
      topic: topic.length >= 4 ? topic : fallback.topic,
      queries: queries.isNotEmpty ? queries.take(5).toList() : fallback.queries,
      includeTerms: include.isNotEmpty ? include : fallback.includeTerms,
      excludeHints: exclude.isNotEmpty ? exclude : fallback.excludeHints,
      homeDiscipline: fallback.homeDiscipline,
      thesisGoal: fallback.thesisGoal,
    );
  }

  static List<int> parseKeepIndexes(String raw, {required int maxIndex}) {
    final map = _jsonMap(raw);
    if (map == null) return const [];
    final keep = map['keep'];
    if (keep is! List) return const [];
    final out = <int>[];
    for (final item in keep) {
      final n = item is num ? item.toInt() : int.tryParse('$item');
      if (n == null) continue;
      if (n >= 1 && n <= maxIndex) out.add(n);
    }
    return out;
  }

  static LiteratureSearchPlan _localPlan(
    String rawGoal,
    ResearchGoal goal,
    bool arabicDraft,
    ThesisDiscipline discipline,
  ) {
    final topic = ThesisCommandSpec.parse(
      rawGoal,
      depth: ThesisChapterDepth.full,
    ).topicText;
    final fromCommand = queriesFromCommand(rawGoal);
    final latinFromUser = ResearchGoalParser.englishQueriesFromText(
      '$topic ${goal.raw} ${goal.field} ${goal.fieldEn}',
    );
    final fallback = ResearchGoalParser.scientificSearchQueries(
      goal,
      includeNativeField: false,
    );
    final include = [
      ...distinctiveTerms(topic).where((t) => !ResearchGoalParser.containsArabic(t)),
      ...latinFromUser,
    ];
    final suffix = discipline.querySuffix;
    final seedQueries = <String>[
      ...latinFromUser,
      ...[
        for (final q in fromCommand)
          if (!ResearchGoalParser.containsArabic(q)) q,
      ],
      ...fallback,
    ];
    final scoped = <String>[
      for (final q in (seedQueries.isNotEmpty ? seedQueries : fallback))
        suffix.isEmpty || q.toLowerCase().contains(suffix.toLowerCase())
            ? q
            : '$q $suffix',
    ];
    final home = discipline.isPresent
        ? '${discipline.facultyEn} / ${discipline.labelEn}'
        : '';
    return LiteratureSearchPlan(
      topic: () {
        final en = ResearchGoalParser.englishSearchQuery(goal);
        if (en.length >= 4) return en.length > 80 ? en.substring(0, 80) : en;
        if (latinFromUser.isNotEmpty) return latinFromUser.first;
        if (topic.length >= 4) {
          return topic.length > 80 ? topic.substring(0, 80) : topic;
        }
        return goal.field;
      }(),
      queries: scoped.isNotEmpty ? scoped.take(5).toList() : fallback,
      includeTerms: include.isNotEmpty
          ? include.take(12).toList()
          : ResearchGoalParser.corePhrases(goal)
              .where((t) => !ResearchGoalParser.containsArabic(t))
              .take(8)
              .toList(),
      excludeHints: [
        ...discipline.alienHints,
        ...LiteratureRelevance.opportunisticJunk,
      ],
      homeDiscipline: home,
      thesisGoal: ResearchGoalParser.contextForAi(goal.raw),
    );
  }

  static List<String> queriesFromCommand(String command) {
    final topic = ThesisCommandSpec.parse(
      command,
      depth: ThesisChapterDepth.full,
    ).topicText;
    if (topic.length < 4) return const [];
    final queries = <String>[];
    final unique = <String>{};
    void add(String raw) {
      final q = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (q.length < 4) return;
      if (unique.add(q.toLowerCase())) queries.add(q);
    }

    for (final binomial in binomials(topic)) {
      add(binomial);
      add('$binomial ${_nearbyCue(topic, binomial)}'.trim());
    }
    add(topic.length > 110 ? topic.substring(0, 110) : topic);
    final words = topic
        .split(RegExp(r'[^A-Za-z\u0600-\u06FF0-9]+'))
        .where((w) => w.length >= 4)
        .where((w) => !_queryStop.contains(w.toLowerCase()))
        .toList();
    if (words.length >= 2) {
      add(words.take(8).join(' '));
    }
    return queries.take(5).toList();
  }

  static List<String> distinctiveTerms(String topic) {
    final terms = <String>[];
    final unique = <String>{};
    void add(String raw) {
      final t = raw.trim().toLowerCase();
      if (t.length < 4 || _queryStop.contains(t)) return;
      if (unique.add(t)) terms.add(t);
    }

    for (final binomial in binomials(topic)) {
      add(binomial);
    }
    final words = topic
        .toLowerCase()
        .split(RegExp(r'[^a-zA-Z\u0600-\u06FF0-9]+'))
        .where((w) => w.length >= 4)
        .where((w) => !_queryStop.contains(w) && !_broadField.contains(w))
        .where((w) => !LiteratureRelevance.weakAlone.contains(w));
    for (final w in words) {
      add(w);
    }
    return terms.take(10).toList();
  }

  static List<String> binomials(String text) {
    return RegExp(r'\b([A-Z][a-z]{2,})\s+([a-z]{4,})\b')
        .allMatches(text)
        .map((m) => '${m.group(1)} ${m.group(2)}')
        .toList();
  }

  static String _nearbyCue(String topic, String binomial) {
    final cues = distinctiveTerms(topic)
        .where((t) => !binomial.toLowerCase().contains(t))
        .take(3);
    return cues.join(' ');
  }

  static const _queryStop = {
    'the', 'and', 'for', 'with', 'from', 'into', 'that', 'this', 'using',
    'study', 'based', 'among', 'between', 'after', 'before', 'their',
    'introduction', 'paragraph', 'section', 'chapter', 'pages', 'page',
    'words', 'citations', 'references', 'write', 'generate',
    'في', 'عن', 'من', 'على', 'هذا', 'هذه', 'مقدمة', 'فقرة', 'فصل',
    'صفحة', 'صفحات', 'كلمة', 'كلمات', 'استشهادات', 'مراجع',
  };

  static const _broadField = {
    'seeds', 'seed', 'oilseed', 'oilseeds', 'crop', 'crops', 'plant',
    'plants', 'food', 'foods', 'products', 'product', 'chemical',
    'chemistry', 'agricultural', 'agriculture', 'industrial', 'industry',
    'characteristics', 'functional', 'development', 'analysis',
    'بذور', 'بذرة', 'زيوت', 'زيت', 'نبات', 'نباتات', 'منتجات',
  };

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.length >= 3)
        .toList();
  }

  static Map<String, dynamic>? _jsonMap(String raw) {
    var text = raw.trim();
    text = text.replaceAll(RegExp(r'^```json|```$', multiLine: true), '').trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }
}
