import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/theme/acadegate_theme.dart';
import '../methodology_integrity/methodology_integrity_screen.dart';
import '../thesis_studio/thesis_studio_screen.dart';
import 'law_argument_chain_screen.dart';
import 'law_authorities_screen.dart';
import 'law_case_brief_screen.dart';
import 'law_compare_screen.dart';
import 'law_issues_screen.dart';
import 'law_lab_branding.dart';
import 'law_lab_models.dart';
import 'law_lab_pdf_service.dart';
import 'law_lab_storage.dart';

/// مسار 4 — مختبر القانون (أسانيد · أحكام · مقارنة).
class LawLabScreen extends StatefulWidget {
  const LawLabScreen({super.key});

  @override
  State<LawLabScreen> createState() => _LawLabScreenState();
}

class _LawLabScreenState extends State<LawLabScreen> {
  static const _brand = Color(LawLabBranding.brand);
  LawProject? _project;
  bool _loading = true;
  late final TextEditingController _rqCtrl;
  late final TextEditingController _fieldCtrl;

  @override
  void initState() {
    super.initState();
    _rqCtrl = TextEditingController();
    _fieldCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _rqCtrl.dispose();
    _fieldCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await LawLabStorage.instance.loadOrCreate();
    if (!mounted) return;
    setState(() {
      _project = p;
      _rqCtrl.text = p.researchQuestion;
      _fieldCtrl.text = p.fieldAr;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    final p = _project;
    if (p == null) return;
    p.researchQuestion = _rqCtrl.text;
    p.fieldAr = _fieldCtrl.text;
    await LawLabStorage.instance.save(p);
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    await _load();
  }

  Future<void> _copySummary() async {
    final p = _project;
    if (p == null) return;
    await Clipboard.setData(ClipboardData(text: p.summaryForThesisChapter()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t(
            'نُسخ ملف الأسانيد — الصقه في المنهجية أو الفصل القانوني',
            'Authorities dossier copied — paste into methods or the legal chapter',
          ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _exportPdf() async {
    final p = _project;
    if (p == null) return;
    await _persist();
    try {
      await LawLabPdfService.instance.share(p);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openMethodology() async {
    final p = _project;
    if (p == null) return;
    final analysisHint = context.t(
      'تحليل أسانيد قانونية: خريطة مسألة · سجل أسانيد · سلسلة استدلال · مقارنة تشريعية',
      'Legal authorities analysis: issue map · ledger · argument chain · comparative matrix',
    );
    await _persist();
    final summary = p.summaryForMethodology();
    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MethodologyIntegrityScreen(
          initialResearchQuestion: p.researchQuestion,
          initialMethodologyText: summary,
          initialStatedMethodology: 'نوعي',
          initialTitle: LawLabBranding.title,
          initialAnalysisApproach: analysisHint,
        ),
      ),
    );
  }

  Future<void> _openThesisStudio() async {
    final p = _project;
    if (p == null) return;
    final copiedMsg = context.t(
      'نُسخ ملف الأسانيد — الصقه في فصل الرسالة بعد الفتح',
      'Authorities dossier copied — paste into a thesis chapter after opening',
    );
    await _persist();
    await Clipboard.setData(ClipboardData(text: p.summaryForThesisChapter()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(copiedMsg),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThesisStudioScreen(
          initialGoal: p.researchQuestion.trim().isEmpty
              ? null
              : p.researchQuestion.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _project == null) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(LawLabBranding.title),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final p = _project!;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(LawLabBranding.title),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: context.t('تصدير PDF', 'Export PDF'),
            onPressed: _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: context.t('نسخ الملخص', 'Copy summary'),
            onPressed: _copySummary,
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: context.t('حفظ', 'Save'),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final saved = context.t('تم الحفظ', 'Saved');
              await _persist();
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(saved),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            color: _brand.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LawLabBranding.tagline,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    LawLabBranding.integrityNote,
                    style: TextStyle(height: 1.4, color: const Color(0xFFB7C3D6)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _rqCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: context.t('سؤال البحث القانوني', 'Legal research question'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => p.researchQuestion = v,
            onEditingComplete: _persist,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _fieldCtrl,
            decoration: InputDecoration(
              labelText: context.t('الحقل (جنائي / مدني / إداري…)', 'Field'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => p.fieldAr = v,
            onEditingComplete: _persist,
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
              '${p.issues.length} فرع · ${p.authorities.length} سند · '
              '${p.briefs.length} حكم · ${p.links.length} رابط · '
              '${p.comparisons.length} مقارنة',
              '${p.issues.length} issues · ${p.authorities.length} authorities · '
              '${p.briefs.length} briefs · ${p.links.length} links · '
              '${p.comparisons.length} comparisons',
            ),
            style: TextStyle(color: const Color(0xFFB7C3D6), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Text(
            context.t('أدوات المختبر', 'Lab tools'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
          const SizedBox(height: 8),
          _ToolCard(
            icon: Icons.account_tree_outlined,
            color: const Color(0xFFEF6C00),
            title: context.t('خريطة المسألة', 'Issue map'),
            subtitle: context.t(
              'فرّع السؤال إلى فروع قابلة للإثبات بأسانيد',
              'Break the question into sub-issues you can prove with authorities',
            ),
            onTap: () => _open(const LawIssuesScreen()),
          ),
          _ToolCard(
            icon: Icons.gavel_outlined,
            color: const Color(0xFF0D47A1),
            title: context.t('سجل الأسانيد', 'Authorities ledger'),
            subtitle: context.t(
              'دستور · تشريع · لائحة · حكم · فقه — مع حالة السريان',
              'Constitution · statute · regulation · judgment · doctrine — with status',
            ),
            onTap: () => _open(const LawAuthoritiesScreen()),
          ),
          _ToolCard(
            icon: Icons.description_outlined,
            color: const Color(0xFF6A1B9A),
            title: context.t('بطاقة الحكم', 'Case brief'),
            subtitle: context.t(
              'وقائع · مسألة · منطوق · علة · صلة بالبحث',
              'Facts · issue · holding · ratio · relevance',
            ),
            onTap: () => _open(const LawCaseBriefScreen()),
          ),
          _ToolCard(
            icon: Icons.link_outlined,
            color: const Color(0xFF00695C),
            title: context.t('سلسلة الاستدلال', 'Argument chain'),
            subtitle: context.t(
              'اربط كل فرع بسند يؤيّده أو يقيّده أو يعارضه',
              'Link each sub-issue to an authority that supports, limits, or opposes it',
            ),
            onTap: () => _open(const LawArgumentChainScreen()),
          ),
          _ToolCard(
            icon: Icons.compare_arrows_outlined,
            color: const Color(0xFFAD1457),
            title: context.t('مقارنة تشريعية', 'Comparative matrix'),
            subtitle: context.t(
              'مصر ↔ نظام أجنبي — تشابه / اختلاف / إشارة إصلاح',
              'Egypt ↔ foreign system — similarity / difference / reform hint',
            ),
            onTap: () => _open(const LawCompareScreen()),
          ),
          const SizedBox(height: 16),
          Text(
            context.t('ماذا بعد الملء؟', 'After filling?'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
              'صدّر PDF، افحص الاتساق المنهجي، أو انقل الملخص إلى استوديو الرسالة.',
              'Export PDF, check methodological fit, or carry the summary into Thesis Studio.',
            ),
            style: TextStyle(color: const Color(0xFFB7C3D6), height: 1.4),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(context.t('تصدير ملف الأسانيد PDF', 'Export authorities PDF')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _openMethodology,
            icon: const Icon(Icons.policy_outlined),
            label: Text(
              context.t(
                'فتح كاشف المنهجية مع الملخص',
                'Open methodology check with summary',
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _openThesisStudio,
            icon: const Icon(Icons.menu_book_outlined),
            label: Text(
              context.t(
                'فتح استوديو الرسالة + نسخ الفصل',
                'Open Thesis Studio + copy chapter text',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: acadegateInk(color),
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(height: 1.35)),
        trailing: const Icon(Icons.chevron_left),
        isThreeLine: true,
      ),
    );
  }
}
