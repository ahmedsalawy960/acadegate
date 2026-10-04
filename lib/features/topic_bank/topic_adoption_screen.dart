import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/theme/acadegate_theme.dart';
import '../../core/locale/locale_service.dart';
import '../academic/academic_models.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import '../methodology_integrity/methodology_integrity_screen.dart';
import '../research_marketplace/research_marketplace_service.dart';
import '../thesis_studio/thesis_studio_screen.dart';
import 'topic_adoption_service.dart';
import 'topic_similarity.dart';

/// مسار 5 — فحص تكرار تقريبي + اعتماد نقطة بمراجع وأسئلة.
class TopicAdoptionScreen extends StatefulWidget {
  final AcademicResearchIdea? idea;
  final String? initialTitle;
  final String? initialDetails;
  final String? initialCategory;

  const TopicAdoptionScreen({
    super.key,
    this.idea,
    this.initialTitle,
    this.initialDetails,
    this.initialCategory,
  });

  @override
  State<TopicAdoptionScreen> createState() => _TopicAdoptionScreenState();
}

class _TopicAdoptionScreenState extends State<TopicAdoptionScreen> {
  static const _brand = Color(0xFFEF6C00);

  TopicAdoptionPack? _pack;
  bool _loading = true;
  String? _error;
  bool _claiming = false;

  String get _title =>
      (widget.idea?.title ?? widget.initialTitle ?? '').trim();
  String get _details =>
      (widget.idea?.details ?? widget.initialDetails ?? '').trim();
  String get _category =>
      (widget.idea?.category ?? widget.initialCategory ?? '').trim();

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pack = await TopicAdoptionService.instance.buildPack(
        title: _title,
        details: _details,
        category: _category,
        idea: widget.idea,
      );
      if (!mounted) return;
      setState(() {
        _pack = pack;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _copy() async {
    final pack = _pack;
    if (pack == null) return;
    final arabic = !LocaleService.instance.isEnglish;
    await Clipboard.setData(
      ClipboardData(text: pack.summaryText(arabic: arabic)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('نُسخت حزمة الاعتماد', 'Adoption pack copied')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _claim() async {
    final idea = widget.idea;
    if (idea == null || !idea.isFromFirebase) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'الحجز الحصري متاح للأفكار المنشورة في المنصة. يمكنك نسخ الحزمة والمتابعة مع المشرف.',
              'Exclusive claim is available for published platform ideas. You can copy the pack and continue with your supervisor.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _claiming = true);
    try {
      await ResearchMarketplaceService.instance.claimIdea(idea);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تم اعتماد/حجز النقطة — راجع المراجع والأسئلة أدناه',
              'Point adopted/claimed — review references and questions below',
            ),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(
          context.t('اعتماد نقطة البحث', 'Adopt research point'),
        ),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          if (_pack != null)
            IconButton(
              tooltip: context.t('نسخ', 'Copy'),
              onPressed: _copy,
              icon: const Icon(Icons.copy_outlined),
            ),
          IconButton(
            tooltip: context.t('إعادة', 'Refresh'),
            onPressed: _loading ? null : _run,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 14),
                  Text(
                    context.t(
                      'جاري فحص التكرار وجمع مراجع وأسئلة…',
                      'Checking duplication and gathering references & questions…',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!GeminiAdvisorClient.isAvailable) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        TopicAdoptionService.instance.emptyAiHint(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: const Color(0xFFB7C3D6), fontSize: 12.5),
                      ),
                    ),
                  ],
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _run, child: Text(context.t('إعادة', 'Retry'))),
                      ],
                    ),
                  ),
                )
              : _buildBody(context, _pack!),
    );
  }

  Widget _buildBody(BuildContext context, TopicAdoptionPack pack) {
    final arabic = !LocaleService.instance.isEnglish;
    final questions =
        arabic ? pack.suggestedQuestionsAr : pack.suggestedQuestionsEn;
    final steps = arabic ? pack.nextStepsAr : pack.nextStepsEn;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Text(
          pack.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _brand,
          ),
        ),
        if (pack.englishSearchTopic.isNotEmpty &&
            pack.englishSearchTopic.trim().toLowerCase() !=
                pack.title.trim().toLowerCase()) ...[
          const SizedBox(height: 8),
          Card(
            color: Colors.blueGrey.withValues(alpha: 0.06),
            child: ListTile(
              dense: true,
              leading: Icon(Icons.translate, color: acadegateInk(_brand)),
              title: Text(
                context.t(
                  'استعلام البحث بالإنجليزية (لفهرس Scholar/OpenAlex)',
                  'English search query (for Scholar/OpenAlex indexes)',
                ),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              subtitle: Text(
                pack.englishSearchTopic,
                style: const TextStyle(height: 1.35),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Card(
          color: _brand.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              context.t(
                'فحص التكرار تقريبي (سوق الأفكار + أدبيات مفهرسة). '
                'العناوين العربية تُترجم لاستعلام إنجليزي لأن أغلب الدراسات المفهرسة بالإنجليزية. '
                'أكّد يدوياً عبر دار المنظومة/EKB/مستودع كليتك قبل الاعتماد النهائي.',
                'Duplication check is approximate (idea marketplace + indexed literature). '
                'Arabic titles are translated into English queries because most indexed studies are in English. '
                'Confirm manually via Mandumah/EKB/your faculty repository before final adoption.',
              ),
              style: const TextStyle(height: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          context.t('١) فحص التكرار', '1) Duplication check'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: Icon(
              pack.duplication.maxMarketplaceScore >= 0.55
                  ? Icons.warning_amber_rounded
                  : Icons.verified_outlined,
              color: pack.duplication.maxMarketplaceScore >= 0.55
                  ? Colors.orange[800]
                  : Colors.green[700],
            ),
            title: Text(
              arabic
                  ? pack.duplication.overallRiskAr()
                  : pack.duplication.overallRiskEn(),
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
            ),
            subtitle: pack.usedAi
                ? Text(context.t('تم تحسين الأسئلة', 'Questions refined'))
                : null,
          ),
        ),
        if (pack.duplication.marketplaceHits.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            context.t('أقرب عناوين داخل التطبيق', 'Closest in-app titles'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (final h in pack.duplication.marketplaceHits.take(6))
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                title: Text(h.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${h.source} · ${context.t(TopicSimilarity.riskLabelAr(h.score), TopicSimilarity.riskLabelEn(h.score))} (${(h.score * 100).round()}%)',
                ),
              ),
            ),
        ],
        if (pack.duplication.literatureHits.isNotEmpty) ...[
          const SizedBox(height: 8),
            Text(
              context.t(
                'أعمال مفهرسة ذات صلة (OpenAlex / Scholar / …)',
                'Related indexed works (OpenAlex / Scholar / …)',
              ),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 6),
          for (final h in pack.duplication.literatureHits.take(5))
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                title: Text(h.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(h.source),
                trailing: h.url == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        onPressed: () => _openUrl(h.url!),
                      ),
              ),
            ),
        ],
        const SizedBox(height: 8),
        Text(
          context.t('تحقق خارجي (يدوي)', 'External checks (manual)'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final link in pack.duplication.externalChecks)
              ActionChip(
                label: Text(context.t(link.labelAr, link.labelEn)),
                onPressed: () => _openUrl(link.url),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          context.t('٢) مراجع أولية (دراسات سابقة)', '2) Starter references (prior studies)'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(
          context.t(
            'نفس أسلوب استوديو الرسالة: OpenAlex · Crossref · Semantic Scholar · '
            'Europe PMC · Google Scholar (عند التفعيل). DOI اختياري — يُقبل الرابط أو العنوان.',
            'Same as Thesis Studio: OpenAlex · Crossref · Semantic Scholar · '
            'Europe PMC · Google Scholar (when enabled). DOI optional — link or title is enough.',
          ),
          style: TextStyle(color: const Color(0xFFB7C3D6), height: 1.35, fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        if (pack.starterReferences.isEmpty)
          Text(
            context.t(
              'لم تُجلب مراجع الآن — أعد المحاولة أو افتح Google Scholar من الروابط.',
              'No references fetched now — retry or open Google Scholar from the links.',
            ),
          )
        else
          for (final w in pack.starterReferences.take(10))
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                title: Text(w.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [
                    if (w.year != null) '${w.year}',
                    w.source,
                    if (w.hasDoi) w.doi else context.t('بدون DOI', 'No DOI'),
                    if (w.authors.trim().isNotEmpty) w.authors,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: w.primaryUrl.isEmpty
                    ? null
                    : IconButton(
                        tooltip: context.t('فتح المصدر', 'Open source'),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        onPressed: () => _openUrl(w.primaryUrl),
                      ),
              ),
            ),
        const SizedBox(height: 16),
        Text(
          context.t('٣) أسئلة مقترحة', '3) Suggested questions'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < questions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: _brand.withValues(alpha: 0.15),
                  foregroundColor: _brand,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(questions[i], style: const TextStyle(height: 1.4))),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text(
          context.t('٤) ماذا بعد؟', '4) What next?'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 8),
        for (final s in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(child: Text(s, style: const TextStyle(height: 1.35))),
              ],
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: _claiming ? null : _claim,
          icon: _claiming
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.bookmark_added_outlined),
          label: Text(
            context.t('اعتماد/حجز هذه النقطة', 'Adopt / claim this point'),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _copy,
          icon: const Icon(Icons.copy_all_outlined),
          label: Text(context.t('نسخ الحزمة كاملة', 'Copy full pack')),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MethodologyIntegrityScreen(
                  initialResearchQuestion: pack.suggestedQuestionsAr.isNotEmpty
                      ? pack.suggestedQuestionsAr.first
                      : pack.title,
                  initialMethodologyText: pack.summaryText(arabic: true),
                  initialTitle: pack.title,
                  initialStatedMethodology: 'نوعي',
                ),
              ),
            );
          },
          icon: const Icon(Icons.policy_outlined),
          label: Text(
            context.t('فتح كاشف المنهجية بالحزمة', 'Open methodology check with pack'),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(text: pack.summaryText(arabic: arabic)),
            );
            if (!context.mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ThesisStudioScreen(initialGoal: pack.title),
              ),
            );
          },
          icon: const Icon(Icons.menu_book_outlined),
          label: Text(
            context.t(
              'فتح استوديو الرسالة + نسخ الحزمة',
              'Open Thesis Studio + copy pack',
            ),
          ),
        ),
      ],
    );
  }
}
