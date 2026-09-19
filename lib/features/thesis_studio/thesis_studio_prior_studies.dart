import '../ai_advisor/gemini_advisor_client.dart';
import '../ai_advisor/grounded_work.dart';
import '../research_supply_chain/research_goal.dart';
import 'thesis_studio_prose.dart';

/// Thesis "previous studies" paragraphs from confirmed abstracts.
class ThesisPriorStudiesWriter {
  ThesisPriorStudiesWriter._();

  static final ThesisPriorStudiesWriter instance = ThesisPriorStudiesWriter._();

  Future<String> summarizeStudy({
    required GroundedWork work,
    required ResearchGoal goal,
    required bool arabic,
    int studyIndex = 0,
  }) async {
    final abs = work.abstractText.trim();
    final local = _localStudyBlock(work, arabic, studyIndex: studyIndex);
    if (abs.length < 40) return local;
    if (!GeminiAdvisorClient.isAvailable) return local;

    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: arabic
          ? '''
أنت تكتب فقرة «دراسة سابقة» بالعربية انطلاقاً من Abstract دراسة واحدة فقط.
اكتب فقرة أكاديمية سردية مكتملة المعنى (عدة جمل)، تنتهي بجملة تامة — بلا اقتطاع وبلا «…».

أسلوب الافتتاح (توجيه فقط، ليست جملاً إلزامية):
ابدأ بصياغة طبيعية تبيّن أنك تلخّص دراسة، مثل ما يفعله كتّاب الرسائل عند عرض دراسة سابقة (ذكر الباحث والسنة ثم موضوع الدراسة ونتائجها). اختر الافتتاح الأنسب للمحتوى؛ لا تكرر قالباً واحداً في كل الفقرات.

ممنوع تماماً:
- لصق عنوان البحث ثم عبارة مثل «من الملخص» أو «وفقاً للملخص» كجسر ركيك.
- اختصار مخلّ يضيّع الفكرة أو النتائج الأساسية الواردة في الملخص.
- Markdown أو DOI أو الحديث عن دراسات أخرى.

المطلوب من الملخص: الهدف/الموضوع، المنهج أو النطاق إن وُجد، وأهم النتائج بأمانة.
'''
          : '''
You write one "previous studies" paragraph from ONE paper Abstract only.
Write a complete academic paragraph (several sentences) that ends with a finished sentence — no mid-cut, no trailing ellipsis.

Opening style (guidance only — NOT mandatory fixed phrases):
Open in a natural scholarly way that clearly presents a summarised study, e.g. openings of the kind researchers use such as "This study examined…", "The study identified…", "This review focused on…", or "Author et al. (Year) investigated…". Choose whatever fits THIS abstract; do not force one template for every paragraph.

Never:
- Paste the paper title then a clumsy bridge like "From the abstract:" / "Key points from the abstract:".
- Over-compress so the core claim or main findings disappear.
- Use Markdown, DOI, or mention other studies.

From the abstract keep: aim/topic, method/scope if present, and the main findings faithfully.
''',
      userMessage: '''
Thesis goal (context only — do not invent links beyond the abstract):
${ResearchGoalParser.contextForAi(goal.raw, maxChars: 800)}

Paragraph index among prior studies (for variety only): $studyIndex
Authors: ${work.authors}
Year: ${work.year ?? 'n.d.'}
Title (metadata only — do not dump it as a heading inside the prose): ${work.title}
Journal: ${work.journal ?? ''}

Abstract (source of truth):
$abs
''',
      maxOutputTokens: 1400,
      preferPro: true,
    );
    if (!result.isSuccess || result.text == null) return local;
    var cleaned = ThesisStudioProse.sanitize(result.text!).trim();
    cleaned = _stripAwkwardBridges(cleaned);
    cleaned = _stripTrailingEllipsis(cleaned);
    if (_wordCount(cleaned) >= 40 && _looksComplete(cleaned)) {
      return cleaned;
    }
    return local;
  }

  Future<List<({GroundedWork work, String paragraph})>> summarizeAllStudies({
    required List<GroundedWork> works,
    required ResearchGoal goal,
    required bool arabic,
    void Function(String label)? onProgress,
  }) async {
    final out = <({GroundedWork work, String paragraph})>[];
    for (var i = 0; i < works.length; i++) {
      onProgress?.call(
        arabic
            ? 'تلخيص Abstract للدراسة ${i + 1}/${works.length}...'
            : 'Summarising Abstract for study ${i + 1}/${works.length}...',
      );
      final paragraph = await summarizeStudy(
        work: works[i],
        goal: goal,
        arabic: arabic,
        studyIndex: i,
      );
      out.add((work: works[i], paragraph: paragraph));
    }
    return out;
  }

  static int _wordCount(String text) =>
      text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  static String _stripTrailingEllipsis(String text) {
    return text
        .replaceAll(RegExp(r'\s*\.\.\.\s*$'), '')
        .replaceAll(RegExp(r'\s*…\s*$'), '')
        .trim();
  }

  static String _stripAwkwardBridges(String text) {
    return text
        .replaceAll(
          RegExp(
            r'\b(Key points from the abstract|From the abstract|According to the available abstract)\s*:\s*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'(وفقاً للملخص المتاح|ومن أهم ما ورد في الملخص|ونص الملخص المتاح كما يلي)\s*:?\s*',
          ),
          '',
        )
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  static bool _looksComplete(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    if (t.endsWith('…') || t.endsWith('...')) return false;
    return RegExp(r'[.!?؟۔]$').hasMatch(t);
  }

  /// Fallback without title dumps or "From the abstract:" bridges.
  static String _localStudyBlock(
    GroundedWork work,
    bool arabic, {
    int studyIndex = 0,
  }) {
    final who = _shortAuthors(work.authors, arabic);
    final year = work.year?.toString() ?? (arabic ? 'د.ت.' : 'n.d.');
    final abs = work.abstractText.trim();
    if (abs.isEmpty) {
      return arabic
          ? 'تناول $who ($year) موضوع الدراسة، غير أن نص Abstract غير متاح في الفهارس المفتوحة.'
          : '$who ($year) addressed this topic, but no open Abstract was available from indexes.';
    }
    final core = _firstCompleteSentences(abs, maxSentences: 3);
    if (arabic) {
      final lead = studyIndex == 0
          ? 'تناولت دراسة $who ($year)'
          : 'كما تناولت دراسة $who ($year)';
      return '$lead الموضوع ذاته في سياق البحث. $core';
    }
    final lead = studyIndex == 0
        ? 'This study by $who ($year) examined the topic as follows.'
        : 'Another study by $who ($year) examined the topic as follows.';
    return '$lead $core';
  }

  static String _firstCompleteSentences(String text, {int maxSentences = 3}) {
    final sentences = text
        .split(RegExp(r'(?<=[.!?؟۔])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (sentences.isEmpty) {
      // No clear sentence breaks — keep a bounded but word-boundary-safe slice.
      if (text.length <= 420) return text.trim();
      final cut = text.substring(0, 420);
      final sp = cut.lastIndexOf(' ');
      return '${(sp > 200 ? cut.substring(0, sp) : cut).trim()}.';
    }
    return sentences.take(maxSentences).join(' ').trim();
  }

  static String shortAuthors(String raw, bool arabic) =>
      _shortAuthors(raw, arabic);

  static String _shortAuthors(String raw, bool arabic) {
    final parts = raw
        .split(RegExp(r'\s*;\s*|\s+and\s+|\s+و\s+|,'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return arabic ? 'مؤلف غير مسمى' : 'Unnamed author';
    if (parts.length == 1) return parts.first;
    if (parts.length == 2) {
      return arabic ? '${parts[0]} و${parts[1]}' : '${parts[0]} and ${parts[1]}';
    }
    return arabic ? '${parts.first} وآخرون' : '${parts.first} et al.';
  }
}
