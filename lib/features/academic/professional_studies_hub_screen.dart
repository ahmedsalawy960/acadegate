import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../../core/locale/locale_service.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';
import 'faculty_categories.dart';
import 'professional_institution_interest_service.dart';
import 'professional_institutions_catalog.dart';
import 'professional_programs_catalog.dart';

/// Hub for professional master's / doctorates / diplomas + institutions.
class ProfessionalStudiesHubScreen extends StatefulWidget {
  const ProfessionalStudiesHubScreen({super.key});

  @override
  State<ProfessionalStudiesHubScreen> createState() =>
      _ProfessionalStudiesHubScreenState();
}

class _ProfessionalStudiesHubScreenState
    extends State<ProfessionalStudiesHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  ProfessionalProgramKind? _filter;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<ProfessionalProgramSuggestion> get _visiblePrograms {
    if (_filter == null) return professionalProgramsCatalog;
    return professionalProgramsByKind(_filter!);
  }

  @override
  Widget build(BuildContext context) {
    final title = L10nLookup.facultyTitleStatic('ProfessionalStudies');

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF4527A0),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: context.t('البرامج', 'Programs')),
            Tab(
              text: context.t(
                'المؤسسات (${professionalInstitutionsCatalog.length})',
                'Institutions (${professionalInstitutionsCatalog.length})',
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SupervisorsListScreen(
                category: 'ProfessionalStudies',
                facultyTitle: title,
              ),
            ),
          );
        },
        backgroundColor: const Color(0xFF4527A0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.people_alt_outlined),
        label: Text(
          context.t('مشرفو المسار المهني', 'Professional-track supervisors'),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ProgramsTab(
            filter: _filter,
            programs: _visiblePrograms,
            onFilter: (f) => setState(() => _filter = f),
            onBrowseInstitutions: () => _tabs.animateTo(1),
          ),
          _InstitutionsTab(
            onApply: (institution) =>
                _showInterestDialog(context, institution),
          ),
        ],
      ),
    );
  }

  Future<void> _showInterestDialog(
    BuildContext context,
    ProfessionalInstitution institution,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.t('تسجيل الدخول مطلوب', 'Sign-in required')),
          content: Text(
            context.t(
              'سجّل الدخول لتسجيل اهتمامك أو التقديم عبر AcadeGate.',
              'Sign in to register interest or apply via AcadeGate.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.t('لاحقاً', 'Later')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.t('تسجيل الدخول', 'Sign in')),
            ),
          ],
        ),
      );
      if (go == true && context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    }

    final nameCtrl = TextEditingController(
      text: user.displayName?.trim() ?? '',
    );
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var program = institution.programAbbrs.isNotEmpty
        ? institution.programAbbrs.first
        : 'MBA';
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      institution.isPartnered
                          ? context.t(
                              'تقديم عبر AcadeGate',
                              'Apply via AcadeGate',
                            )
                          : context.t(
                              'تسجيل اهتمام (قبل الشراكة)',
                              'Register interest (pre-partnership)',
                            ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      LocaleService.instance.isEnglish
                          ? institution.nameEn
                          : institution.nameAr,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    if (!institution.isPartnered) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          context.t(
                            'التقديم الرسمي داخل التطبيق يُفعَّل بعد توقيع الشراكة مع المؤسسة. '
                            'الآن يمكنك تسجيل اهتمامك وزيارة صفحة القبول الخارجية.',
                            'In-app official applications unlock after a partnership. '
                            'You can register interest now and open the external admissions page.',
                          ),
                          style: const TextStyle(height: 1.45, fontSize: 13),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: program,
                      decoration: InputDecoration(
                        labelText: context.t('البرنامج', 'Program'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final p in institution.programAbbrs)
                          DropdownMenuItem(value: p, child: Text(p)),
                      ],
                      onChanged: (v) {
                        if (v != null) setModal(() => program = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: context.t('الاسم الكامل', 'Full name'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: context.t('الهاتف / واتساب', 'Phone / WhatsApp'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: context.t(
                          'ملاحظات (اختياري)',
                          'Notes (optional)',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              final phone = phoneCtrl.text.trim();
                              if (name.length < 2 || phone.length < 6) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.t(
                                        'أكمل الاسم ورقم الهاتف',
                                        'Enter name and phone',
                                      ),
                                    ),
                                  ),
                                );
                                return;
                              }
                              setModal(() => saving = true);
                              try {
                                await ProfessionalInstitutionInterestService
                                    .instance
                                    .submitInterest(
                                  institution: institution,
                                  programAbbr: program,
                                  fullName: name,
                                  phone: phone,
                                  notes: notesCtrl.text,
                                );
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      institution.isPartnered
                                          ? context.t(
                                              'تم إرسال طلب التقديم',
                                              'Application submitted',
                                            )
                                          : context.t(
                                              'تم تسجيل اهتمامك — سنربطك بعد الشراكة',
                                              'Interest saved — we will connect you after partnership',
                                            ),
                                    ),
                                    backgroundColor: Colors.green.shade700,
                                  ),
                                );
                              } catch (e) {
                                setModal(() => saving = false);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4527A0),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              institution.isPartnered
                                  ? context.t('إرسال الطلب', 'Submit application')
                                  : context.t(
                                      'تسجيل الاهتمام',
                                      'Register interest',
                                    ),
                            ),
                    ),
                    TextButton(
                      onPressed: () => _openUrl(institution.applyLink),
                      child: Text(
                        context.t(
                          'فتح صفحة القبول على الموقع',
                          'Open admissions website',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _ProgramsTab extends StatelessWidget {
  final ProfessionalProgramKind? filter;
  final List<ProfessionalProgramSuggestion> programs;
  final ValueChanged<ProfessionalProgramKind?> onFilter;
  final VoidCallback onBrowseInstitutions;

  const _ProgramsTab({
    required this.filter,
    required this.programs,
    required this.onFilter,
    required this.onBrowseInstitutions,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        const _IntroCard(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onBrowseInstitutions,
          icon: const Icon(Icons.account_balance_outlined),
          label: Text(
            context.t(
              'تصفح المؤسسات التي تقدّم هذه البرامج',
              'Browse institutions that offer these programs',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.t('مقترحات البرامج', 'Program suggestions'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF311B92),
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: Text(context.t('الكل', 'All')),
              selected: filter == null,
              onSelected: (_) => onFilter(null),
            ),
            FilterChip(
              label: Text(context.t('ماجستير مهني', 'Prof. Master\'s')),
              selected: filter == ProfessionalProgramKind.masters,
              onSelected: (_) => onFilter(ProfessionalProgramKind.masters),
            ),
            FilterChip(
              label: Text(context.t('دكتوراه مهنية', 'Prof. Doctorate')),
              selected: filter == ProfessionalProgramKind.doctorate,
              onSelected: (_) => onFilter(ProfessionalProgramKind.doctorate),
            ),
            FilterChip(
              label: Text(context.t('دبلومات هامة', 'Key diplomas')),
              selected: filter == ProfessionalProgramKind.diploma,
              onSelected: (_) => onFilter(ProfessionalProgramKind.diploma),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...programs.map((p) => _ProgramCard(program: p)),
      ],
    );
  }
}

class _InstitutionsTab extends StatelessWidget {
  final void Function(ProfessionalInstitution institution) onApply;

  const _InstitutionsTab({required this.onApply});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.deepPurple.shade100),
          ),
          child: Text(
            context.t(
              'دليل مؤسسات تقدّم ماجستير/دكتوراه مهنية ودبلومات. '
              'التقديم داخل التطبيق يُفعَّل بعد شراكة AcadeGate مع الجامعة — '
              'يمكنك الآن تصفح البرامج وتسجيل اهتمامك أو فتح صفحة القبول.',
              'Directory of institutions offering professional master\'s/doctorates '
              'and diplomas. In-app applications unlock after an AcadeGate partnership — '
              'browse programs, register interest, or open admissions pages now.',
            ),
            style: const TextStyle(height: 1.5, fontSize: 13.5),
          ),
        ),
        const SizedBox(height: 14),
        ...professionalInstitutionsCatalog.map(
          (inst) => _InstitutionCard(
            institution: inst,
            onApply: () => onApply(inst),
          ),
        ),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4527A0), Color(0xFF7E57C2)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(
              'دراسات عليا مهنية ودبلومات',
              'Professional postgraduate & diplomas',
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
              'المسار المهني يركّز على التطبيق وسوق العمل، والمسار الأكاديمي على البحث. '
              'من تبويب المؤسسات تصل لجهات القبول وتسجّل اهتمامك للشراكة.',
              'Professional tracks emphasize applied skills; academic tracks emphasize research. '
              'Use the Institutions tab to reach admissions and register partnership interest.',
            ),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.55,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final ProfessionalProgramSuggestion program;

  const _ProgramCard({required this.program});

  String get _kindLabelAr => switch (program.kind) {
        ProfessionalProgramKind.masters => 'ماجستير مهني',
        ProfessionalProgramKind.doctorate => 'دكتوراه مهنية',
        ProfessionalProgramKind.diploma => 'دبلوم دراسات عليا',
      };

  String get _kindLabelEn => switch (program.kind) {
        ProfessionalProgramKind.masters => 'Professional Master\'s',
        ProfessionalProgramKind.doctorate => 'Professional Doctorate',
        ProfessionalProgramKind.diploma => 'Postgraduate Diploma',
      };

  @override
  Widget build(BuildContext context) {
    final isAr = !LocaleService.instance.isEnglish;
    final title = isAr ? program.titleAr : program.titleEn;
    final summary = isAr ? program.summaryAr : program.summaryEn;
    final focuses = isAr ? program.focusAreasAr : program.focusAreasEn;
    final kindLabel = isAr ? _kindLabelAr : _kindLabelEn;
    final related = program.relatedFacultyId == null
        ? null
        : facultyById(program.relatedFacultyId!);
    final providers = professionalInstitutionsCatalog
        .where((i) => i.programAbbrs.contains(program.abbr))
        .take(3)
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.deepPurple.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4527A0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    program.abbr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kindLabel,
                    style: TextStyle(
                      color: Colors.deepPurple.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              summary,
              style: TextStyle(
                color: Colors.grey.shade800,
                height: 1.5,
                fontSize: 13.2,
              ),
            ),
            if (focuses.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: focuses
                    .map(
                      (f) => Chip(
                        label: Text(f, style: const TextStyle(fontSize: 11.5)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: Colors.deepPurple.shade50,
                        side: BorderSide.none,
                        padding: EdgeInsets.zero,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (providers.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                context.t('يُقدَّم لدى:', 'Offered at:'),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                providers
                    .map(
                      (p) => LocaleService.instance.isEnglish
                          ? p.nameEn
                          : p.nameAr,
                    )
                    .join(' · '),
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.deepPurple.shade800,
                  height: 1.4,
                ),
              ),
            ],
            if (related != null) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SupervisorsListScreen(
                        category: related.id,
                        facultyTitle:
                            L10nLookup.facultyTitleStatic(related.id),
                      ),
                    ),
                  );
                },
                icon: Icon(related.icon, size: 18, color: related.color),
                label: Text(
                  context.t(
                    'مشرفون ذوو صلة: ${L10nLookup.facultyTitleStatic(related.id)}',
                    'Related supervisors: ${L10nLookup.facultyTitleStatic(related.id)}',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InstitutionCard extends StatelessWidget {
  final ProfessionalInstitution institution;
  final VoidCallback onApply;

  const _InstitutionCard({
    required this.institution,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = !LocaleService.instance.isEnglish;
    final name = isAr ? institution.nameAr : institution.nameEn;
    final type = isAr ? institution.typeAr : institution.typeEn;
    final summary = isAr ? institution.summaryAr : institution.summaryEn;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.deepPurple.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF4527A0),
                  child: Icon(
                    institution.isPartnered
                        ? Icons.verified
                        : Icons.account_balance,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$type · ${institution.city}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: institution.isPartnered
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    institution.isPartnered
                        ? context.t('شريك', 'Partner')
                        : context.t('دليل', 'Directory'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: institution.isPartnered
                          ? Colors.green.shade800
                          : Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              summary,
              style: TextStyle(
                height: 1.5,
                fontSize: 13.2,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: institution.programAbbrs
                  .map(
                    (p) => Chip(
                      label: Text(p, style: const TextStyle(fontSize: 11.5)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Colors.deepPurple.shade50,
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApply,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4527A0),
                    ),
                    icon: Icon(
                      institution.isPartnered
                          ? Icons.send_outlined
                          : Icons.bookmark_add_outlined,
                      size: 18,
                    ),
                    label: Text(
                      institution.isPartnered
                          ? context.t('قدّم الآن', 'Apply now')
                          : context.t('سجّل اهتمامك', 'Register interest'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: context.t('الموقع', 'Website'),
                  onPressed: () => _openUrl(institution.website),
                  icon: const Icon(Icons.language),
                ),
              ],
            ),
            if (institution.email.isNotEmpty || institution.phone.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  [
                    if (institution.phone.isNotEmpty) institution.phone,
                    if (institution.email.isNotEmpty) institution.email,
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
