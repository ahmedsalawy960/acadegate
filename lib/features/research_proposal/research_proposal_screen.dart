import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/theme/acadegate_theme.dart';
import '../../core/locale/locale_service.dart';
import '../academic_writing/writing_categories.dart';
import '../academic_writing/writing_expert_list_screen.dart';
import '../academic_writing/writing_hub_screen.dart';
import '../methodology_integrity/methodology_integrity_screen.dart';
import '../thesis_studio/thesis_studio_screen.dart';
import 'research_proposal_branding.dart';
import 'research_proposal_coach_screen.dart';
import 'research_proposal_draft_screen.dart';
import 'research_proposal_models.dart';
import 'research_proposal_review_screen.dart';
import 'research_proposal_storage.dart';
import 'research_proposal_templates.dart';
import 'research_proposal_templates_screen.dart';
import 'research_proposal_workshop.dart';
import 'research_proposal_workshop_screen.dart';

/// مسار 6 — الخطة البحثية للكليات المصرية.
class ResearchProposalScreen extends StatefulWidget {
  final String? initialFacultyId;

  const ResearchProposalScreen({super.key, this.initialFacultyId});

  @override
  State<ResearchProposalScreen> createState() => _ResearchProposalScreenState();
}

class _ResearchProposalScreenState extends State<ResearchProposalScreen> {
  static const _brand = Color(ResearchProposalBranding.brand);

  ProposalDraft? _draft;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await ResearchProposalStorage.instance
        .loadOrCreate(facultyId: widget.initialFacultyId);
    if (!mounted) return;
    setState(() {
      _draft = d;
      _loading = false;
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    await _load();
  }

  Future<void> _copyDraft() async {
    final d = _draft;
    if (d == null) return;
    final arabic = !LocaleService.instance.isEnglish;
    await Clipboard.setData(
      ClipboardData(text: d.exportText(arabic: arabic)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t('نُسخت مسودة الخطة', 'Proposal draft copied'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openMethodology() async {
    final d = _draft;
    if (d == null) return;
    final summary = d.summaryForMethodology();
    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MethodologyIntegrityScreen(
          initialTitle: d.titleAr,
          initialResearchQuestion: d.section(ProposalSectionKeys.questions),
          initialStatedMethodology: d.section(ProposalSectionKeys.methodology),
          initialMethodologyText: summary,
          initialAnalysisApproach: d.section(ProposalSectionKeys.analysis),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(ResearchProposalBranding.title),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final draft = _draft!;
    final report = ProposalConsistencyEngine.instance.evaluate(draft);
    final workshopDone =
        draft.workshopChecks.values.where((e) => e).length;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(ResearchProposalBranding.title),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: context.t('نسخ المسودة', 'Copy draft'),
            onPressed: _copyDraft,
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text(
            ResearchProposalBranding.tagline,
            style: const TextStyle(height: 1.45, fontSize: 14.5),
          ),
          const SizedBox(height: 10),
          Card(
            color: _brand.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                ResearchProposalBranding.integrityNote,
                style: TextStyle(height: 1.4, color: const Color(0xFFB7C3D6)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: context.t('اتساق الخطة', 'Consistency'),
                  value: '${report.score}%',
                  color: report.score >= 70
                      ? Colors.green.shade700
                      : Colors.orange.shade800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatChip(
                  label: context.t('ورشة الأخطاء', 'Workshop'),
                  value: '$workshopDone/${proposalWorkshopItems.length}',
                  color: _brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PathCard(
            color: const Color(0xFF1B5E20),
            icon: Icons.fact_check_outlined,
            title: context.t(
              '١) مدرب الخطة — تشخيص + دراسات (الأهم)',
              '1) Proposal coach — diagnose + studies (main value)',
            ),
            subtitle: context.t(
              'اكتب عنواناً/مشكلة → ملاحظات فورية · صياغة مقترحة · جلب دراسات نقدية',
              'Enter title/problem → instant notes · suggested wording · critical studies',
            ),
            onTap: () => _open(const ResearchProposalCoachScreen()),
          ),
          _PathCard(
            color: const Color(0xFFEF6C00),
            icon: Icons.warning_amber_outlined,
            title: context.t(
              '٢) ورشة أخطاء الخطط الشائعة',
              '2) Common proposal faults workshop',
            ),
            subtitle: context.t(
              'قائمة تحقق تعليمية: عنوان · مشكلة · أهداف · حدود · دراسات نقدية · اتساق',
              'Teaching checklist: title · problem · objectives · limits · critical lit · fit',
            ),
            onTap: () => _open(const ResearchProposalWorkshopScreen()),
          ),
          _PathCard(
            color: const Color(0xFF1565C0),
            icon: Icons.account_balance_outlined,
            title: context.t(
              '٣) اختيار فقرات الخطة',
              '3) Choose proposal sections',
            ),
            subtitle: context.t(
              'كتالوج موحّد لكل الفقرات + اختصار اختياري حسب الكلية',
              'One shared catalog + optional faculty shortcut',
            ),
            onTap: () => _open(const ResearchProposalTemplatesScreen()),
          ),
          _PathCard(
            color: _brand,
            icon: Icons.edit_note_outlined,
            title: context.t(
              '٤) مراجعة/تعديل المسودة',
              '4) Review / edit the draft',
            ),
            subtitle: context.t(
              'بعد المدرب: راجع النص المدمج وعدّل قبل التصدير',
              'After the coach: review merged text and edit before export',
            ),
            onTap: () => _open(const ResearchProposalDraftScreen()),
          ),
          _PathCard(
            color: const Color(0xFF6A1B9A),
            icon: Icons.person_search_outlined,
            title: context.t(
              '٥) مراجعة بشرية قبل القسم',
              '5) Human review before the department',
            ),
            subtitle: context.t(
              'خبير تربية / قانون / مقترحات بحث — بعد تحسين الجاهزية',
              'Education / Law / proposal expert — after readiness improves',
            ),
            onTap: () => _open(const ResearchProposalReviewScreen()),
          ),
          const SizedBox(height: 8),
          Text(
            context.t('روابط سريعة', 'Quick links'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.policy_outlined, size: 18),
                label: Text(context.t('كاشف المنهجية', 'Methodology check')),
                onPressed: _openMethodology,
              ),
              ActionChip(
                avatar: const Icon(Icons.menu_book_outlined, size: 18),
                label: Text(context.t('استوديو الرسالة', 'Thesis Studio')),
                onPressed: () {
                  final goal = draft.titleAr.isNotEmpty
                      ? draft.titleAr
                      : draft.section('problem');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ThesisStudioScreen(initialGoal: goal),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.lightbulb_outline, size: 18),
                label: Text(context.t('خبراء خطة بحث', 'Proposal experts')),
                onPressed: () {
                  final cat = writingCategoryById('proposal');
                  if (cat == null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WritingHubScreen(),
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WritingExpertListScreen(category: cat),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6))),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: acadegateInk(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PathCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: acadegateInk(color),
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: const TextStyle(height: 1.35)),
        ),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}
