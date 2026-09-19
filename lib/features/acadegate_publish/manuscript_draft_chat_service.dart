import '../../core/locale/app_translate.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import 'academic_text.dart';
import 'manuscript_draft_index.dart';
import 'publish_models.dart';

enum DraftQuestionKind {
  locateTable,
  locateFigure,
  abstractVsResults,
  locateSection,
  general,
}

class DraftChatHit {
  final String kind;
  final int? number;
  final String title;
  final String location;
  final int blockIndex;
  final String quote;
  final List<List<String>> tablePreview;

  const DraftChatHit({
    required this.title,
    required this.location,
    required this.blockIndex,
    this.kind = '',
    this.number,
    this.quote = '',
    this.tablePreview = const [],
  });
}

class DraftChatReply {
  final String text;
  final List<DraftChatHit> hits;
  final bool usedCloudAi;
  final DraftQuestionKind kind;

  const DraftChatReply({
    required this.text,
    required this.kind,
    this.hits = const [],
    this.usedCloudAi = false,
  });
}

/// Answers questions from the researcher's uploaded manuscript only.
class ManuscriptDraftChatService {
  ManuscriptDraftChatService._();

  static final ManuscriptDraftChatService instance =
      ManuscriptDraftChatService._();

  static final _tableAsk = RegExp(
    r'(?:table|جدول|tab\.?)\s*(\d+)',
    caseSensitive: false,
  );
  static final _figureAsk = RegExp(
    r'(?:fig(?:ure)?|شكل|scheme)\s*(\d+)',
    caseSensitive: false,
  );
  static final _sectionAsk = RegExp(
    r'(?:أين|where(?:\s+is)?)\s+(?:ال)?(ملخص|نتائج|مناقشة|مقدمة|خاتمة|abstract|results?|discussion|introduction|conclusion)',
    caseSensitive: false,
  );

  static const _stop = {
    'the', 'and', 'of', 'in', 'to', 'for', 'with', 'a', 'an', 'this', 'that',
    'from', 'were', 'was', 'are', 'is', 'by', 'on', 'as', 'at', 'be', 'or',
    'which', 'their', 'these', 'those', 'using', 'used', 'than', 'have',
    'has', 'been', 'not', 'but', 'also', 'into', 'over', 'after', 'before',
    'في', 'من', 'على', 'إلى', 'عن', 'هذا', 'هذه', 'التي', 'الذي', 'كان',
    'كانت', 'يتم', 'حيث', 'كما', 'بين', 'ذلك', 'مع', 'أو', 'لا', 'ما',
  };

  static bool looksLikeDraftQuestion(String message) {
    final t = AcademicText.westernDigits(message).toLowerCase();
    if (_tableAsk.hasMatch(t) || _figureAsk.hasMatch(t)) return true;
    if (_sectionAsk.hasMatch(t)) return true;
    final hasAbs = t.contains('ملخص') || t.contains('abstract');
    final hasRes = t.contains('نتائج') || t.contains('result');
    if (hasAbs && hasRes) return true;
    if (t.contains('مسود') ||
        t.contains('مخطوط') ||
        t.contains('الملف المرفوع') ||
        t.contains('ورقتي') ||
        t.contains('this draft') ||
        t.contains('this manuscript') ||
        t.contains('uploaded file')) {
      return true;
    }
    return false;
  }

  static DraftQuestionKind classify(String message) {
    final t = AcademicText.westernDigits(message).toLowerCase();
    if (_tableAsk.hasMatch(t)) return DraftQuestionKind.locateTable;
    if (_figureAsk.hasMatch(t)) return DraftQuestionKind.locateFigure;
    final hasAbs = t.contains('ملخص') || t.contains('abstract');
    final hasRes = t.contains('نتائج') || t.contains('result');
    if (hasAbs && hasRes) return DraftQuestionKind.abstractVsResults;
    if (_sectionAsk.hasMatch(t)) return DraftQuestionKind.locateSection;
    return DraftQuestionKind.general;
  }

  static int? askedTableNumber(String message) {
    final t = AcademicText.westernDigits(message);
    return int.tryParse(_tableAsk.firstMatch(t)?.group(1) ?? '');
  }

  static int? askedFigureNumber(String message) {
    final t = AcademicText.westernDigits(message);
    return int.tryParse(_figureAsk.firstMatch(t)?.group(1) ?? '');
  }

  ManuscriptDraftIndex indexOf(PublishManuscript manuscript) =>
      ManuscriptDraftIndex.fromManuscript(manuscript);

  Future<DraftChatReply> ask({
    required PublishManuscript manuscript,
    required String question,
    bool allowCloud = true,
  }) async {
    final q = question.trim();
    final index = indexOf(manuscript);
    if (index.isEmpty) {
      return DraftChatReply(
        kind: DraftQuestionKind.general,
        text: appTr(
          'لا يوجد نص مستخرج من ملف بعد. ارفع PDF أو Word من تبويب التحرير، ثم اسأل '
          '«هل الملخص يطابق النتائج؟» أو «أين جدول 3؟».',
          'No extracted text yet. Upload a PDF or Word file from the Edit tab, then ask '
          '"Does the abstract match the results?" or "Where is Table 3?".',
        ),
      );
    }

    final kind = classify(q);
    var reply = switch (kind) {
      DraftQuestionKind.locateTable => _locateTable(index, q),
      DraftQuestionKind.locateFigure => _locateFigure(index, q),
      DraftQuestionKind.abstractVsResults => _abstractVsResults(index),
      DraftQuestionKind.locateSection => _locateSection(index, q),
      DraftQuestionKind.general => _general(index, q),
    };

    if (!allowCloud || !GeminiAdvisorClient.isAvailable) return reply;

    final cloud = await _enrichWithCloud(
      question: q,
      index: index,
      local: reply,
    );
    if (cloud == null || cloud.trim().isEmpty) return reply;
    return DraftChatReply(
      kind: reply.kind,
      hits: reply.hits,
      usedCloudAi: true,
      text: '${reply.text}\n\n**${appTr('تحليل إضافي من المسودة', 'Further reading of this draft')}**\n$cloud',
    );
  }

  DraftChatReply _locateTable(ManuscriptDraftIndex index, String question) {
    final n = askedTableNumber(question);
    final found = n == null ? null : index.tableByNumber(n);
    if (n != null && found != null) {
      return DraftChatReply(
        kind: DraftQuestionKind.locateTable,
        hits: [_hitFromFloat(found, index.blockCount)],
        text: appTr(
          '**${found.label} موجود في مسودتك.**\n'
          '${found.locationLabel(index.blockCount)}.\n\n'
          '${found.caption.trim().isEmpty ? '' : 'العنوان: ${found.caption.trim()}\n\n'}'
          '${found.gridPreview.isEmpty ? '' : 'معاينة الصفوف الأولى:\n${found.gridPreview}'}',
          '**${found.label} is in this draft.**\n'
          '${found.locationLabel(index.blockCount)}.\n\n'
          '${found.caption.trim().isEmpty ? '' : 'Caption: ${found.caption.trim()}\n\n'}'
          '${found.gridPreview.isEmpty ? '' : 'First rows:\n${found.gridPreview}'}',
        ),
      );
    }

    final listed = index.tables.isEmpty
        ? appTr('لا توجد جداول مستخرجة في هذا الملف.', 'No tables were extracted from this file.')
        : index.tables
            .map((t) =>
                '• ${t.label}${t.caption.trim().isEmpty ? '' : ': ${_short(t.caption, 80)}'}')
            .join('\n');

    if (n == null) {
      return DraftChatReply(
        kind: DraftQuestionKind.locateTable,
        hits: index.tables.take(6).map((t) => _hitFromFloat(t, index.blockCount)).toList(),
        text: appTr(
          'الجداول في هذه المسودة:\n$listed',
          'Tables in this draft:\n$listed',
        ),
      );
    }

    final ordinal = n >= 1 && n <= index.tables.length ? index.tables[n - 1] : null;
    final extra = ordinal == null
        ? ''
        : appTr(
            '\n\nلا يوجد عنوان «جدول $n»، لكن الجدول رقم $n بترتيب الملف هو: ${ordinal.label}'
            '${ordinal.caption.trim().isEmpty ? '' : ' — ${ordinal.caption.trim()}'}'
            ' (${ordinal.locationLabel(index.blockCount)}).',
            '\n\nNo caption "Table $n", but the ${n}th table in file order is: ${ordinal.label}'
            '${ordinal.caption.trim().isEmpty ? '' : ' — ${ordinal.caption.trim()}'}'
            ' (${ordinal.locationLabel(index.blockCount)}).',
          );

    return DraftChatReply(
      kind: DraftQuestionKind.locateTable,
      hits: [
        if (ordinal != null) _hitFromFloat(ordinal, index.blockCount),
      ],
      text: appTr(
        '**جدول $n غير موجود بهذا الرقم في الملف المرفوع.**\n\n$listed$extra',
        '**Table $n is not labeled in the uploaded file.**\n\n$listed$extra',
      ),
    );
  }

  DraftChatReply _locateFigure(ManuscriptDraftIndex index, String question) {
    final n = askedFigureNumber(question);
    final found = n == null ? null : index.figureByNumber(n);
    if (n != null && found != null) {
      return DraftChatReply(
        kind: DraftQuestionKind.locateFigure,
        hits: [_hitFromFloat(found, index.blockCount)],
        text: appTr(
          '**${found.label} موجود.** ${found.locationLabel(index.blockCount)}.\n'
          '${found.caption.trim()}',
          '**${found.label} is here.** ${found.locationLabel(index.blockCount)}.\n'
          '${found.caption.trim()}',
        ),
      );
    }
    final listed = index.figures.isEmpty
        ? appTr('لا أشكال مستخرجة في هذا الملف.', 'No figures extracted in this file.')
        : index.figures.map((f) => '• ${f.label}: ${_short(f.caption, 80)}').join('\n');
    return DraftChatReply(
      kind: DraftQuestionKind.locateFigure,
      text: n == null
          ? listed
          : appTr(
              '**شكل $n غير موجود بهذا الرقم.**\n$listed',
              '**Figure $n is not labeled in this file.**\n$listed',
            ),
    );
  }

  DraftChatReply _abstractVsResults(ManuscriptDraftIndex index) {
    final abs = index.abstractSection;
    final res = index.resultsSection;
    final hits = <DraftChatHit>[];
    final buffer = StringBuffer();

    buffer.writeln(index.inventoryLine);
    buffer.writeln();

    if (abs == null || abs.text.trim().length < 40) {
      buffer.writeln(appTr(
        '**الملخص غير مكتمل في المسودة** — لا يمكن المقارنة. أضفه في حقل الملخص أو في قسم Abstract داخل الملف.',
        '**The abstract is missing or too short** — cannot compare. Add it in the Abstract field or in an Abstract section.',
      ));
    } else {
      hits.add(DraftChatHit(
        kind: 'section',
        title: abs.heading,
        location: abs.fromAbstractField
            ? appTr('حقل الملخص أعلى المحرر', 'Abstract field at the top of the editor')
            : appTr('قسم ${abs.heading}', 'Section ${abs.heading}'),
        blockIndex: abs.headingBlockIndex,
        quote: abs.excerpt(280),
      ));
      buffer.writeln(appTr(
        '**الملخص** (${abs.wordCount} كلمة):\n«${abs.excerpt(280)}»',
        '**Abstract** (${abs.wordCount} words):\n"${abs.excerpt(280)}"',
      ));
      buffer.writeln();
    }

    if (res == null || res.text.trim().length < 40) {
      buffer.writeln(appTr(
        '**قسم النتائج غير موجود أو قصير جداً في الملف المستخرج.** '
        'ابحث عن عنوان Results / النتائج كما هو مكتوب في ورقتك.',
        '**A Results section is missing or too short in the extracted file.** '
        'Look for a Results heading as printed in your paper.',
      ));
    } else {
      hits.add(DraftChatHit(
        kind: 'section',
        title: res.heading,
        location: appTr(
          'بعد العنوان — العنصر ${res.headingBlockIndex + 1}',
          'after heading — item ${res.headingBlockIndex + 1}',
        ),
        blockIndex: res.headingBlockIndex,
        quote: res.excerpt(280),
      ));
      buffer.writeln(appTr(
        '**${res.heading}** (${res.wordCount} كلمة):\n«${res.excerpt(280)}»',
        '**${res.heading}** (${res.wordCount} words):\n"${res.excerpt(280)}"',
      ));
      buffer.writeln();
    }

    if (abs != null && res != null && abs.text.trim().length >= 40 && res.text.trim().length >= 40) {
      final resultsHaystack = StringBuffer(res.text);
      for (final t in index.tables) {
        resultsHaystack.write('\n${t.caption}\n${t.gridPreview}');
      }
      final hay = resultsHaystack.toString();
      final claims = extractNumericClaims(abs.text);
      final missing = <String>[];
      final present = <String>[];
      for (final c in claims) {
        if (claimAppearsIn(c, hay)) {
          present.add(c);
        } else {
          missing.add(c);
        }
      }

      final overlap = _keywordOverlap(abs.text, hay);
      buffer.writeln(appTr('**مطابقة من نصك أنت:**', '**Match from your own text:**'));
      if (claims.isEmpty) {
        buffer.writeln(appTr(
          'الملخص لا يذكر أرقاماً واضحة (نسب، p-value، وحدات). المقارنة هنا بالموضوع فقط.',
          'The abstract has no clear numbers (% , p-values, units). Comparison is topical only.',
        ));
      } else {
        if (present.isNotEmpty) {
          buffer.writeln(appTr(
            'أرقام الملخص الموجودة في النتائج/الجداول: ${present.join('، ')}.',
            'Abstract numbers found in results/tables: ${present.join(', ')}.',
          ));
        }
        if (missing.isNotEmpty) {
          buffer.writeln(appTr(
            'أرقام في الملخص **لم تظهر** في النتائج المستخرجة: ${missing.join('، ')}. '
            'إما أنها غير مذكورة في النتائج، أو الجدول لم يُستخرج بالكامل.',
            'Abstract numbers **not found** in the extracted results: ${missing.join(', ')}. '
            'They may be missing from Results, or a table was not fully extracted.',
          ));
        }
      }
      buffer.writeln(appTr(
        'تداخل الكلمات المفتاحية بين الملخص والنتائج: ${(overlap * 100).round()}٪.',
        'Keyword overlap between abstract and results: ${(overlap * 100).round()}%.',
      ));

      if (missing.isNotEmpty) {
        buffer.writeln(appTr(
          '\n**الخلاصة:** الملخص يذكر نتائج غير ظاهرة في قسم النتائج كما استُخرج من ملفك — راجع تلك الأرقام قبل الإرسال.',
          '\n**Verdict:** the abstract states findings that are not visible in the extracted Results — check those numbers before submission.',
        ));
      } else if (claims.isNotEmpty && present.isNotEmpty) {
        buffer.writeln(appTr(
          '\n**الخلاصة:** الأرقام الواردة في الملخص موجودة في النتائج/الجداول في هذه المسودة.',
          '\n**Verdict:** numbers stated in the abstract appear in Results/tables in this draft.',
        ));
      } else if (overlap < 0.12) {
        buffer.writeln(appTr(
          '\n**الخلاصة:** التداخل الموضوعي ضعيف — الملخص قد لا يعكس ما في النتائج.',
          '\n**Verdict:** topical overlap is weak — the abstract may not reflect the results.',
        ));
      } else {
        buffer.writeln(appTr(
          '\n**الخلاصة:** الملخص والنتائج يتحدثان عن موضوع متقارب في هذا الملف. لا توجد أرقام متعارضة ظاهرة.',
          '\n**Verdict:** abstract and results discuss a similar topic in this file. No obvious numeric conflict.',
        ));
      }
    }

    for (final t in index.tables.take(8)) {
      hits.add(_hitFromFloat(t, index.blockCount));
    }

    return DraftChatReply(
      kind: DraftQuestionKind.abstractVsResults,
      hits: hits,
      text: buffer.toString().trim(),
    );
  }

  DraftChatReply _locateSection(ManuscriptDraftIndex index, String question) {
    final t = AcademicText.westernDigits(question).toLowerCase();
    String? key;
    if (t.contains('ملخص') || t.contains('abstract')) key = 'abstract';
    if (t.contains('نتائج') || t.contains('result')) key = 'results';
    if (t.contains('مناقشة') || t.contains('discussion')) key = 'discussion';
    if (t.contains('مقدمة') || t.contains('introduction')) key = 'introduction';
    if (t.contains('خاتمة') || t.contains('conclusion')) key = 'conclusion';
    final section = key == null ? null : index.sectionByKey(key);
    if (section == null) {
      final names = index.sections.map((s) => '• ${s.heading}').join('\n');
      return DraftChatReply(
        kind: DraftQuestionKind.locateSection,
        text: appTr(
          'لم أجد هذا القسم في الملف المستخرج. العناوين الموجودة:\n$names',
          'That section was not found in the extracted file. Headings present:\n$names',
        ),
      );
    }
    return DraftChatReply(
      kind: DraftQuestionKind.locateSection,
      hits: [
        DraftChatHit(
          kind: 'section',
          title: section.heading,
          location: appTr(
            'العنصر ${section.headingBlockIndex + 1} من ${index.blockCount}',
            'item ${section.headingBlockIndex + 1} of ${index.blockCount}',
          ),
          blockIndex: section.headingBlockIndex,
          quote: section.excerpt(320),
        ),
      ],
      text: appTr(
        '**${section.heading}** — العنصر ${section.headingBlockIndex + 1} من ${index.blockCount}.\n\n«${section.excerpt(360)}»',
        '**${section.heading}** — item ${section.headingBlockIndex + 1} of ${index.blockCount}.\n\n"${section.excerpt(360)}"',
      ),
    );
  }

  DraftChatReply _general(ManuscriptDraftIndex index, String question) {
    final scored = <(int, DraftSection)>[];
    for (final s in index.sections) {
      if (s.key == 'references') continue;
      final score = _overlapScore(question, '${s.heading} ${s.text}');
      if (score > 0) scored.add((score, s));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    final top = scored.take(3).map((e) => e.$2).toList();

    if (top.isEmpty) {
      return DraftChatReply(
        kind: DraftQuestionKind.general,
        text: appTr(
          'لم أجد في المسودة المرفوعة مقطعاً واضحاً يجيب على هذا السؤال.\n'
          '${index.inventoryLine}\n\n'
          'جرّب: «هل الملخص يطابق النتائج؟» أو «أين جدول 3؟» أو اذكر كلمة من عنوان قسم في ملفك.',
          'Nothing in the uploaded draft clearly answers that.\n'
          '${index.inventoryLine}\n\n'
          'Try: "Does the abstract match the results?" or "Where is Table 3?" or a word from a section heading.',
        ),
      );
    }

    final buffer = StringBuffer(appTr(
      'من **ملف الباحث نفسه** (ليست مصادر خارجية):\n',
      'From **this researcher\'s file** (no outside sources):\n',
    ));
    final hits = <DraftChatHit>[];
    for (final s in top) {
      buffer.writeln('\n**${s.heading}**\n«${s.excerpt(300)}»');
      hits.add(DraftChatHit(
        kind: 'section',
        title: s.heading,
        location: appTr(
          'العنصر ${s.headingBlockIndex + 1}',
          'item ${s.headingBlockIndex + 1}',
        ),
        blockIndex: s.headingBlockIndex,
        quote: s.excerpt(300),
      ));
    }
    return DraftChatReply(
      kind: DraftQuestionKind.general,
      hits: hits,
      text: buffer.toString().trim(),
    );
  }

  Future<String?> _enrichWithCloud({
    required String question,
    required ManuscriptDraftIndex index,
    required DraftChatReply local,
  }) async {
    try {
      final pack = _packExcerpts(index, local);
      if (pack.trim().isEmpty) return null;
      final system = appTr(
        'أنت تقرأ مسودة الباحث المرفقة فقط. ممنوع اختراع جدول أو رقم أو نتيجة غير موجودة في المقتطفات. '
        'إن لم تجد الجواب في المقتطفات فقل ذلك صراحة. اقتبس عبارة قصيرة واذكر القسم أو رقم الجدول. أجب بالعربية إذا كان السؤال بالعربية.',
        'You are reading only this researcher\'s draft excerpts. Never invent a table, number, or finding that is not in the excerpts. '
        'If the answer is not there, say so. Quote a short phrase and name the section or Table N. Match the question language.',
      );
      final user = '${appTr('السؤال', 'Question')}: $question\n\n'
          '${appTr('حقائق محلية (لا تناقضها)', 'Local facts (do not contradict)')}:\n${_short(local.text, 1200)}\n\n'
          '${appTr('مقتطفات المسودة', 'Draft excerpts')}:\n$pack';
      final result = await GeminiAdvisorClient.instance.generateResult(
        systemPrompt: system,
        userMessage: user,
        maxOutputTokens: 1024,
      );
      if (!result.isSuccess) return null;
      return result.text!.trim();
    } catch (_) {
      return null;
    }
  }

  String _packExcerpts(ManuscriptDraftIndex index, DraftChatReply local) {
    final buffer = StringBuffer();
    if (index.title.isNotEmpty) {
      buffer.writeln('Title: ${index.title}');
    }
    void add(String label, String? text, [int max = 1800]) {
      final t = (text ?? '').trim();
      if (t.isEmpty) return;
      buffer.writeln('\n## $label\n${t.length > max ? t.substring(0, max) : t}');
    }

    add('Abstract', index.abstractSection?.text, 1600);
    add('Results', index.resultsSection?.text, 2200);
    add('Discussion', index.discussionSection?.text, 1200);
    if (index.tables.isNotEmpty) {
      buffer.writeln('\n## Tables');
      for (final t in index.tables.take(12)) {
        buffer.writeln('${t.label}: ${_short(t.caption, 160)}');
        if (t.gridPreview.isNotEmpty) {
          buffer.writeln(t.gridPreview);
        }
      }
    }
    for (final hit in local.hits.take(4)) {
      if (hit.quote.trim().isEmpty) continue;
      buffer.writeln('\n## Hit ${hit.title}\n${hit.quote}');
    }
    final packed = buffer.toString();
    if (packed.length <= 9000) return packed;
    return packed.substring(0, 9000);
  }

  static DraftChatHit _hitFromFloat(DraftFloat f, int total) {
    return DraftChatHit(
      kind: f.kind,
      number: f.number,
      title: f.label,
      location: f.locationLabel(total),
      blockIndex: f.blockIndex,
      quote: f.preview,
      tablePreview: f.rows.take(4).map((r) => r.take(6).toList()).toList(),
    );
  }

  static List<String> extractNumericClaims(String text) {
    final western = AcademicText.westernDigits(text);
    final found = <String>{};
    for (final m in RegExp(r'\d+(?:\.\d+)?\s*%').allMatches(western)) {
      found.add(_canonClaim(m.group(0)!));
    }
    for (final m in RegExp(
      r'p\s*[<≤=]\s*\d+(?:\.\d+)?',
      caseSensitive: false,
    ).allMatches(western)) {
      found.add(_canonClaim(m.group(0)!));
    }
    for (final m in RegExp(
      r'\b\d+(?:\.\d+)?\s*(?:mg|g|ml|nm|ppm|°c)\b',
      caseSensitive: false,
    ).allMatches(western)) {
      found.add(_canonClaim(m.group(0)!));
    }
    return found.toList();
  }

  static bool claimAppearsIn(String claim, String haystack) {
    final h = _canonClaim(haystack);
    final c = _canonClaim(claim);
    if (c.isEmpty) return false;
    if (h.contains(c)) return true;
    final num = RegExp(r'\d+(?:\.\d+)?').firstMatch(c)?.group(0);
    if (num != null && c.contains('%')) {
      final compact = num.replaceFirst(RegExp(r'\.0+$'), '');
      if (h.contains('$compact%')) return true;
    }
    return false;
  }

  static String _canonClaim(String s) {
    return AcademicText.westernDigits(s)
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceFirst(RegExp(r'\.0+%'), '%');
  }

  static double _keywordOverlap(String a, String b) {
    final wa = _keywords(a);
    final wb = _keywords(b);
    if (wa.isEmpty) return 0;
    var hit = 0;
    for (final w in wa) {
      if (wb.contains(w)) hit++;
    }
    return hit / wa.length;
  }

  static int _overlapScore(String query, String text) {
    final q = _keywords(query);
    if (q.isEmpty) return 0;
    final hay = AcademicText.westernDigits(text).toLowerCase();
    var n = 0;
    for (final w in q) {
      if (hay.contains(w)) n++;
    }
    return n;
  }

  static Set<String> _keywords(String text) {
    final t = AcademicText.westernDigits(text).toLowerCase();
    final out = <String>{};
    for (final raw in t.split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))) {
      final w = raw.trim();
      if (w.length < 4) continue;
      if (_stop.contains(w)) continue;
      out.add(w);
    }
    return out;
  }

  static String _short(String s, int max) {
    final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.length <= max) return t;
    return '${t.substring(0, max).trim()}…';
  }
}
