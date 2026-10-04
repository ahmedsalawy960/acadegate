import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import 'research_proposal_branding.dart';
import 'research_proposal_coach_service.dart';
import 'research_proposal_draft_screen.dart';
import 'research_proposal_models.dart';
import 'research_proposal_storage.dart';
import 'research_proposal_templates.dart';

/// الشاشة ذات القيمة الحقيقية: تشخيص + اقتراح + دراسات — لا ملء أعمى.
class ResearchProposalCoachScreen extends StatefulWidget {
  const ResearchProposalCoachScreen({super.key});

  @override
  State<ResearchProposalCoachScreen> createState() =>
      _ResearchProposalCoachScreenState();
}

class _ResearchProposalCoachScreenState
    extends State<ResearchProposalCoachScreen> {
  static const _brand = Color(ResearchProposalBranding.brand);

  ProposalDraft? _draft;
  ProposalCoachResult? _result;
  bool _loading = true;
  bool _running = false;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _problemCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _problemCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _problemCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final d = await ResearchProposalStorage.instance.loadOrCreate();
    if (!mounted) return;
    setState(() {
      _draft = d;
      _titleCtrl.text = d.titleAr;
      _problemCtrl.text = d.section(ProposalSectionKeys.problem);
      _loading = false;
    });
  }

  Future<void> _persistSeed() async {
    final d = _draft;
    if (d == null) return;
    d.setSection(ProposalSectionKeys.titleAr, _titleCtrl.text.trim());
    d.setSection(ProposalSectionKeys.problem, _problemCtrl.text.trim());
    await ResearchProposalStorage.instance.save(d);
  }

  Future<void> _run() async {
    final d = _draft;
    if (d == null) return;
    if (_titleCtrl.text.trim().length < 8 &&
        _problemCtrl.text.trim().length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'اكتب العنوان أو المشكلة أولاً لتشخيص خطتك',
              'Enter a title or problem first to diagnose your plan',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _running = true);
    try {
      await _persistSeed();
      final result =
          await ResearchProposalCoachService.instance.diagnoseAndAssist(d);
      // Auto-fill empty draft paragraphs from suggestions + studies.
      ResearchProposalCoachService.instance.applySuggestions(
        d,
        result,
        overwriteFilled: false,
        insertPriorStudies: true,
      );
      await ResearchProposalStorage.instance.save(d);
      if (!mounted) return;
      setState(() => _result = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'شُخّصت الخطة ومُلئت الفقرات الفارغة في المسودة تلقائياً',
              'Plan diagnosed and empty draft sections filled automatically',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: context.t('المسودة', 'Draft'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ResearchProposalDraftScreen(),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _apply({required bool overwrite}) async {
    final d = _draft;
    final r = _result;
    if (d == null || r == null) return;
    ResearchProposalCoachService.instance.applySuggestions(
      d,
      r,
      overwriteFilled: overwrite,
      insertPriorStudies: true,
    );
    await ResearchProposalStorage.instance.save(d);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t(
            'أُدمجت الاقتراحات والدراسات في المسودة',
            'Suggestions and studies merged into your draft',
          ),
        ),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: context.t('المسودة', 'Draft'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ResearchProposalDraftScreen(),
              ),
            );
          },
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('مدرب الخطة', 'Proposal coach')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final result = _result;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('مدرب الخطة (القيمة الحقيقية)', 'Proposal coach (real value)')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            color: _brand.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(
                      'الاستفادة للباحث (ليست ملء بيانات)',
                      'Value for you (not form-filling)',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.t(
                      '• تشخيص أخطاء خطتك قبل القسم\n'
                      '• اقتراح صياغة أفضل للعنوان/المشكلة/الأسئلة/الأهداف\n'
                      '• جلب دراسات سابقة بصياغة نقدية (لا سرد)\n'
                      '• درجة جاهزية قبل طلب مراجعة بشرية',
                      '• Diagnose proposal faults before the department\n'
                      '• Better wording for title/problem/questions/objectives\n'
                      '• Fetch prior studies with a critical skeleton\n'
                      '• Readiness score before human review',
                    ),
                    style: const TextStyle(height: 1.45),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.t('اكتب ما لديك فقط', 'Write only what you already have'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: context.t('العنوان (أو مسودة عنوان)', 'Title (or draft title)'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _problemCtrl,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: context.t('المشكلة / الفكرة', 'Problem / idea'),
              border: const OutlineInputBorder(),
              hintText: context.t(
                'مثال: رغم انتشار … في المدارس المصرية، ما زالت الدراسات تفتقر إلى … مما يخلق فجوة في …',
                'e.g. Despite … in Egyptian schools, studies still lack … creating a gap in …',
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _running ? null : _run,
            icon: _running
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.fact_check_outlined),
            label: Text(
              _running
                  ? context.t('جاري التشخيص…', 'Diagnosing…')
                  : context.t(
                      'شخّص الخطة واقترح + اجلب دراسات',
                      'Diagnose, suggest & fetch studies',
                    ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _brand,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          if (!GeminiAdvisorClient.isAvailable) ...[
            const SizedBox(height: 8),
            Text(
              context.t(
                'بدون تسجيل دخول: تشخيص محلي ودراسات. سجّل الدخول لتحسين الصياغة.',
                'Signed out: local diagnosis and studies. Sign in for stronger wording.',
              ),
              style: TextStyle(fontSize: 12.5, color: const Color(0xFFB7C3D6)),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('جاهزية العرض', 'Readiness'),
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFFB7C3D6),
                            ),
                          ),
                          Text(
                            '${result.readinessScore}%',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: result.readinessScore >= 70
                                  ? Colors.green.shade700
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('المخرجات', 'Outputs'),
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFFB7C3D6),
                            ),
                          ),
                          Text(
                            context.t(
                              '${result.findings.length} ملاحظات · '
                              '${result.suggestedSections.length} اقتراحات · '
                              '${result.priorWorks.length} دراسة',
                              '${result.findings.length} notes · '
                              '${result.suggestedSections.length} suggestions · '
                              '${result.priorWorks.length} studies',
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              context.t(result.summaryAr, result.summaryEn),
              style: const TextStyle(height: 1.4, fontWeight: FontWeight.w600),
            ),
            if (result.englishSearchTopic.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                context.t(
                  'استعلام الدراسات (إنجليزي): ${result.englishSearchTopic}',
                  'Studies query (EN): ${result.englishSearchTopic}',
                ),
                style: TextStyle(fontSize: 12.5, color: const Color(0xFFB7C3D6)),
              ),
            ],
            if (result.searchQueriesUsed.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                context.t('استعلامات الجلب:', 'Fetch queries:'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final q in result.searchQueriesUsed.take(6))
                    Chip(
                      label: Text(q, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Text(
              context.t('التشخيص التفصيلي', 'Detailed diagnosis'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 6),
            for (final f in result.findings.take(14))
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                color: f.severity == 'ok'
                    ? Colors.green.withValues(alpha: 0.06)
                    : f.severity == 'high'
                        ? Colors.red.withValues(alpha: 0.06)
                        : Colors.orange.withValues(alpha: 0.06),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    f.severity == 'ok'
                        ? Icons.check_circle_outline
                        : f.severity == 'high'
                            ? Icons.error_outline
                            : Icons.info_outline,
                    color: f.severity == 'ok'
                        ? Colors.green.shade700
                        : f.severity == 'high'
                            ? Colors.red.shade700
                            : Colors.orange.shade800,
                  ),
                  title: Text(
                    context.t(f.titleAr, f.titleEn),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(context.t(f.detailAr, f.detailEn)),
                ),
              ),
            if (result.suggestedSections.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                context.t('اقتراحات صياغة جاهزة (بدون خانات فارغة)', 'Ready wording (no empty placeholders)'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                context.t(
                  'مصاغة من موضوعك مباشرة (مجتمع، متغيرات، أبعاد أداة). راجعها وعدّل الأسماء المؤسسية إن لزم.',
                  'Derived from your topic (population, variables, instrument dimensions). Review and adjust institution names if needed.',
                ),
                style: TextStyle(fontSize: 12.5, color: const Color(0xFFB7C3D6), height: 1.35),
              ),
              const SizedBox(height: 6),
              for (final e in result.suggestedSections.entries)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    title: Text(
                      context.t(
                        ProposalSectionKeys.labelAr(e.key),
                        ProposalSectionKeys.labelEn(e.key),
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(e.value, style: const TextStyle(height: 1.4)),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: e.value),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.t('نُسخ الاقتراح', 'Suggestion copied'),
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: Text(context.t('نسخ', 'Copy')),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (result.priorWorks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                context.t(
                  'دراسات سابقة مُجلبة (${result.priorWorks.length}) — أدرجها نقدياً',
                  'Fetched prior studies (${result.priorWorks.length}) — insert critically',
                ),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 6),
              for (final w in result.priorWorks.take(10))
                Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    title: Text(
                      w.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        [
                          w.source,
                          if (w.year != null) '${w.year}',
                          if (!w.hasDoi) context.t('بدون DOI', 'no DOI'),
                          if (w.abstractText.trim().isNotEmpty)
                            (w.abstractText.trim().length > 140
                                ? '${w.abstractText.trim().substring(0, 140)}…'
                                : w.abstractText.trim()),
                        ].join(' · '),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(height: 1.35),
                      ),
                    ),
                    isThreeLine: true,
                    trailing: w.primaryUrl.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.open_in_new, size: 18),
                            onPressed: () => _openUrl(w.primaryUrl),
                          ),
                  ),
                ),
            ],
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: () => _apply(overwrite: false),
              icon: const Icon(Icons.merge_type),
              label: Text(
                context.t(
                  'أدرج الاقتراحات في الخانات الفارغة فقط',
                  'Fill empty sections only',
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _apply(overwrite: true),
              icon: const Icon(Icons.sync),
              label: Text(
                context.t(
                  'استبدال المسودة بالاقتراحات (بحذر)',
                  'Overwrite draft with suggestions (careful)',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
