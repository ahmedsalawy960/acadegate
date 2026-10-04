import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/theme/acadegate_theme.dart';

import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../academic_writing/writing_categories.dart';
import '../academic_writing/writing_expert_list_screen.dart';
import '../academic_writing/writing_hub_screen.dart';
import '../acadegate_publish/publish_hub_screen.dart';
import '../data_analysis/statistical_assumptions_screen.dart';
import '../guides/section_guide_catalog.dart';
import '../guides/section_guide_screen.dart';
import '../home/home_screen.dart';
import '../matchmaking/matchmaking_screen.dart';
import '../methodology_integrity/methodology_integrity_screen.dart';
import '../profile/academic_profile.dart';
import '../profile/academic_profile_service.dart';
import '../thesis_studio/thesis_studio_screen.dart';
import '../viva_simulator/viva_screen.dart';
import 'humanities_faculties.dart';
import '../law_lab/law_lab_screen.dart';
import '../qualitative_analysis/qualitative_studio_screen.dart';
import '../research_proposal/research_proposal_screen.dart';
import '../research_tools_studio/research_tools_studio_screen.dart';
import '../humanities_publish/humanities_publish_screen.dart';
import 'humanities_field_tools_screen.dart';
import 'humanities_prefs.dart';
import 'humanities_topics_screen.dart';

/// بوابة البحث الإنساني — كل خدمة لها مدخل واحد فقط (لا تكرار).
class HumanitiesHubScreen extends StatefulWidget {
  const HumanitiesHubScreen({super.key});

  @override
  State<HumanitiesHubScreen> createState() => _HumanitiesHubScreenState();
}

class _HumanitiesHubScreenState extends State<HumanitiesHubScreen> {
  static const _brand = Color(0xFF5D4037);

  HumanitiesTrack _track = HumanitiesTrack.education;
  AcademicProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final saved = await HumanitiesPrefs.loadTrack();
    final profile = await AcademicProfileService.instance.loadProfile();
    final fromFaculty = profile?.resolvedFacultyCategory;
    final track = saved ??
        (fromFaculty != null && HumanitiesFaculties.isHumanities(fromFaculty)
            ? HumanitiesTrackX.fromFacultyId(fromFaculty)
            : HumanitiesTrack.education);
    if (!mounted) return;
    setState(() {
      _track = track;
      _profile = profile;
      _loading = false;
    });
  }

  Future<void> _selectTrack(HumanitiesTrack track) async {
    setState(() => _track = track);
    await HumanitiesPrefs.saveTrack(track);
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  bool get _profileLooksStem {
    final f = _profile?.resolvedFacultyCategory;
    if (f == null || f.isEmpty) return true;
    return !HumanitiesFaculties.isHumanities(f);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('البحث الإنساني', 'Humanities research')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final stages = _stagesFor(_track);

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(
          context.t(
            'بوابة البحث الإنساني والتربوي',
            'Humanities & education portal',
          ),
        ),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: const [
          SectionGuideAppBarButton(
            guideId: SectionGuideCatalog.humanities,
            accent: _brand,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const SectionGuideBanner(
            guideId: SectionGuideCatalog.humanities,
            accent: _brand,
          ),
          const SizedBox(height: 12),
          if (_profileLooksStem) _testerBanner(context),
          _heroCard(context),
          const SizedBox(height: 16),
          Text(
            context.t('١) اختر مسارك', '1) Pick your track'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in HumanitiesTrack.values)
                ChoiceChip(
                  label: Text(context.t(t.titleAr(), t.titleEn())),
                  selected: _track == t,
                  selectedColor: _brand.withValues(alpha: 0.18),
                  labelStyle: TextStyle(
                    fontWeight: _track == t ? FontWeight.w700 : FontWeight.w500,
                    color: _track == t
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFFF4F7FB),
                  ),
                  onSelected: (_) => _selectTrack(t),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.t(_track.blurbAr(), _track.blurbEn()),
            style: const TextStyle(color: Color(0xFFB7C3D6), height: 1.45),
          ),
          const SizedBox(height: 20),
          Text(
            context.t('٢) مسار البحث', '2) Research path'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 10),
          ...stages.asMap().entries.map((e) {
            final i = e.key + 1;
            final stage = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StageCard(
                index: i,
                color: stage.color,
                icon: stage.icon,
                title: context.t(stage.titleAr, stage.titleEn),
                subtitle: context.t(stage.subtitleAr, stage.subtitleEn),
                primaryLabel: context.t(stage.ctaAr, stage.ctaEn),
                onPrimary: () => _open(stage.primaryScreen),
                secondaryLabel: stage.secondaryScreen == null
                    ? null
                    : context.t(stage.cta2Ar!, stage.cta2En!),
                onSecondary: stage.secondaryScreen == null
                    ? null
                    : () => _open(stage.secondaryScreen!),
              ),
            );
          }),
          const SizedBox(height: 12),
          Text(
            context.t('٣) مساعدة في الكتابة', '3) Writing help'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 10),
          _writingShortcuts(context),
        ],
      ),
    );
  }

  /// اختصارات لا تتقاطع مع مراحل المسار.
  Widget _writingShortcuts(BuildContext context) {
    final proposal = writingCategoryById('proposal');
    final stats = writingCategoryById('statistics');
    final editing = writingCategoryById('editing');

    final items = <_ShortcutItem>[
      _ShortcutItem(
        icon: Icons.description_outlined,
        color: const Color(0xFF558B2F),
        labelAr: 'خطة بحث',
        labelEn: 'Proposal',
        onTap: () {
          if (proposal == null) {
            _open(const WritingHubScreen());
            return;
          }
          _open(WritingExpertListScreen(category: proposal));
        },
      ),
      _ShortcutItem(
        icon: Icons.bar_chart_rounded,
        color: const Color(0xFF00838F),
        labelAr: 'إحصاء تربوي',
        labelEn: 'Edu stats',
        onTap: () {
          showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.auto_graph_outlined),
                    title: Text(
                      ctx.t(
                        'معالج الافتراضات الإحصائية',
                        'Statistical assumptions wizard',
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _open(const StatisticalAssumptionsScreen());
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: Text(
                      ctx.t('خبراء إحصاء وتحليل', 'Statistics experts'),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (stats == null) {
                        _open(const WritingHubScreen());
                        return;
                      }
                      _open(WritingExpertListScreen(category: stats));
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      _ShortcutItem(
        icon: Icons.spellcheck_outlined,
        color: const Color(0xFF6A1B9A),
        labelAr: 'تدقيق',
        labelEn: 'Editing',
        onTap: () {
          if (editing == null) {
            _open(const WritingHubScreen());
            return;
          }
          _open(WritingExpertListScreen(category: editing));
        },
      ),
    ];

    return Row(
      children: [
        for (final item in items) ...[
          Expanded(
            child: Material(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: item.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  child: Column(
                    children: [
                      Icon(item.icon, color: acadegateInk(item.color), size: 26),
                      const SizedBox(height: 8),
                      Text(
                        context.t(item.labelAr, item.labelEn),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: acadegateInk(item.color),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (item != items.last) const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _testerBanner(BuildContext context) {
    return Card(
      color: const Color(0xFFE3F2FD),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science_outlined, color: Color(0xFF1565C0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.t(
                      'وضع تجربة (ملفّك ليس كلية أدبية)',
                      'Tester mode (your profile is not a humanities faculty)',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              context.t(
                'اختر مساراً أعلاه (مثلاً تربية أو حقوق) وجرّب المراحل.',
                'Pick a track above (e.g. Education or Law) and try the stages.',
              ),
              style: TextStyle(height: 1.45, color: Colors.grey[800]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context) {
    return Card(
      color: _brand.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories_rounded, color: acadegateInk(_brand), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.t(
                      'بديل المختبرات للكليات الأدبية',
                      'The labs alternative for humanities faculties',
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: acadegateInk(_brand),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.t(
                'مسار متكامل لباحثي التربية والحقوق والآداب: '
                'من اختيار الموضوع حتى المناقشة — بجمع بيانات ميدانية '
                '(استبانة ومقابلات وأرشيف) دون الحاجة لمختبرات أو عينات.',
                'A full path for Education, Law, and Arts researchers: '
                'from topic choice to viva — with field data collection '
                '(surveys, interviews, archives) and no need for labs or samples.',
              ),
              style: const TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  List<_HubStage> _stagesFor(HumanitiesTrack track) {
    final facultyId = track.facultyId;
    final supervisors = SupervisorsListScreen(
      category: facultyId,
      facultyTitle: L10nLookup.facultyTitleStatic(facultyId),
    );
    final proposalCat = writingCategoryById('proposal');

    return [
      _HubStage(
        color: const Color(0xFFEF6C00),
        icon: Icons.lightbulb_outline,
        titleAr: 'اختيار الموضوع',
        titleEn: 'Choose a topic',
        subtitleAr: 'فجوات حسب القسم · فحص تكرار تقريبي · اعتماد بمراجع وأسئلة',
        subtitleEn: 'Gaps by department · approx. duplication check · adopt with refs & questions',
        ctaAr: 'موضوعات المسار',
        ctaEn: 'Track topics',
        primaryScreen: HumanitiesTopicsScreen(initialTrack: track),
      ),
      _HubStage(
        color: const Color(0xFF1565C0),
        icon: Icons.people_alt_outlined,
        titleAr: 'المشرف حسب كليتك',
        titleEn: 'Supervisor by faculty',
        subtitleAr:
            'تصفّح مشرفي ${L10nLookup.facultyTitleStatic(facultyId)} أو اطلب مطابقة ذكية',
        subtitleEn:
            'Browse supervisors in ${L10nLookup.facultyTitleStatic(facultyId)} or get a smart match',
        ctaAr: 'مشرفو المسار',
        ctaEn: 'Track supervisors',
        primaryScreen: supervisors,
        cta2Ar: 'مطابقة ذكية',
        cta2En: 'Smart match',
        secondaryScreen: const MatchmakingScreen(supervisorJourney: true),
      ),
      _HubStage(
        color: const Color(0xFF558B2F),
        icon: Icons.assignment_turned_in_outlined,
        titleAr: 'الخطة البحثية',
        titleEn: 'Research proposal',
        subtitleAr:
            'مدرب تشخيص + دراسات · اختيار فقرات الخطة · جاهزية · مراجعة بشرية',
        subtitleEn:
            'Diagnostic coach + studies · section picker · readiness · human review',
        ctaAr: 'فتح مسار الخطة',
        ctaEn: 'Open proposal path',
        primaryScreen: ResearchProposalScreen(initialFacultyId: facultyId),
        cta2Ar: 'خبراء خطة بحث',
        cta2En: 'Proposal experts',
        secondaryScreen: proposalCat == null
            ? const WritingHubScreen()
            : WritingExpertListScreen(category: proposalCat),
      ),
      _HubStage(
        color: const Color(0xFF2E7D32),
        icon: Icons.policy_outlined,
        titleAr: 'المنهجية والتحكيم',
        titleEn: 'Methodology & validation',
        subtitleAr: 'تحقق من اتساق تصميم البحث والأداة قبل التطبيق',
        subtitleEn: 'Check that your design and instrument align before fieldwork',
        ctaAr: 'كاشف المنهجية',
        ctaEn: 'Methodology check',
        primaryScreen: const MethodologyIntegrityScreen(),
      ),
      _HubStage(
        color: const Color(0xFF6A1B9A),
        icon: Icons.assignment_outlined,
        titleAr: 'استوديو الأدوات البحثية',
        titleEn: 'Research tools studio',
        subtitleAr:
            'بناء الأدوات قبل التطبيق: استبانة · مقابلة · مضمون · ثبات',
        subtitleEn:
            'Build instruments before fieldwork: survey · interview · content sheet · reliability',
        ctaAr: 'فتح الاستوديو',
        ctaEn: 'Open studio',
        primaryScreen: const ResearchToolsStudioScreen(),
        cta2Ar: 'الميدان والأرشيف',
        cta2En: 'Field & archive',
        secondaryScreen: const HumanitiesFieldToolsScreen(),
      ),
      if (track == HumanitiesTrack.law)
        const _HubStage(
          color: Color(0xFF0D47A1),
          icon: Icons.balance_outlined,
          titleAr: 'مختبر القانون (الأسانيد)',
          titleEn: 'Law Lab (authorities)',
          subtitleAr:
              'خريطة مسألة · سجل أسانيد · بطاقة حكم · سلسلة استدلال · مقارنة تشريعية',
          subtitleEn:
              'Issue map · authorities ledger · case brief · argument chain · comparative matrix',
          ctaAr: 'فتح المختبر',
          ctaEn: 'Open lab',
          primaryScreen: LawLabScreen(),
        ),
      _HubStage(
        color: const Color(0xFF00695C),
        icon: Icons.psychology_alt_outlined,
        titleAr: 'استوديو التحليل النوعي',
        titleEn: 'Qualitative analysis studio',
        subtitleAr:
            'بعد الجمع فقط: نصوص · ترميز · موضوعات · مذكرات (Braun & Clarke)',
        subtitleEn:
            'After collection only: transcripts · coding · themes · memos (Braun & Clarke)',
        ctaAr: 'فتح التحليل',
        ctaEn: 'Open analysis',
        primaryScreen: const QualitativeStudioScreen(),
      ),
      if (track != HumanitiesTrack.law)
        const _HubStage(
          color: Color(0xFF0D47A1),
          icon: Icons.balance_outlined,
          titleAr: 'مختبر القانون (اختياري)',
          titleEn: 'Law Lab (optional)',
          subtitleAr:
              'إن احتجت أسانيد قانونية: تشريع · أحكام · مقارنة — بدون تكرار أدوات الجمع',
          subtitleEn:
              'If you need legal authorities: statutes · cases · comparison — no collection-tool overlap',
          ctaAr: 'فتح المختبر',
          ctaEn: 'Open lab',
          primaryScreen: LawLabScreen(),
        ),
      _HubStage(
        color: const Color(0xFF1A237E),
        icon: Icons.menu_book_outlined,
        titleAr: 'كتابة الرسالة',
        titleEn: 'Thesis writing',
        subtitleAr: 'ابنِ فصول رسالتك — يُفضَّل تفعيل النمط الأدبي/الإنساني',
        subtitleEn: 'Build your thesis chapters — prefer literary/humanities mode',
        ctaAr: 'استوديو الرسالة',
        ctaEn: 'Thesis Studio',
        primaryScreen: const ThesisStudioScreen(),
      ),
      _HubStage(
        color: const Color(0xFF4A148C),
        icon: Icons.published_with_changes_outlined,
        titleAr: 'نشر أكاديمي إنساني',
        titleEn: 'Humanities publishing',
        subtitleAr:
            'مجلة عربية محكمة · EKB · شرط نشر الدكتوراه · خطاب قبول · رفع الحولية',
        subtitleEn:
            'Arabic peer-reviewed · EKB · PhD publish rule · acceptance letter · yearbook upload',
        ctaAr: 'فتح مسار النشر',
        ctaEn: 'Open publish path',
        primaryScreen: HumanitiesPublishScreen(initialFacultyId: facultyId),
        cta2Ar: 'محرر المخطوطة',
        cta2En: 'Manuscript editor',
        secondaryScreen: const PublishHubScreen(),
      ),
      _HubStage(
        color: const Color(0xFF880E4F),
        icon: Icons.record_voice_over_outlined,
        titleAr: 'التحضير للمناقشة',
        titleEn: 'Prepare for viva',
        subtitleAr: 'تدرّب على أسئلة لجنة المناقشة قبل الموعد',
        subtitleEn: 'Practice committee questions before the defense date',
        ctaAr: 'محاكي المناقشة',
        ctaEn: 'Viva simulator',
        primaryScreen: const VivaSimulatorScreen(),
      ),
    ];
  }
}

class _ShortcutItem {
  final IconData icon;
  final Color color;
  final String labelAr;
  final String labelEn;
  final VoidCallback onTap;

  const _ShortcutItem({
    required this.icon,
    required this.color,
    required this.labelAr,
    required this.labelEn,
    required this.onTap,
  });
}

class _HubStage {
  final Color color;
  final IconData icon;
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String subtitleEn;
  final String ctaAr;
  final String ctaEn;
  final Widget primaryScreen;
  final String? cta2Ar;
  final String? cta2En;
  final Widget? secondaryScreen;

  const _HubStage({
    required this.color,
    required this.icon,
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.subtitleEn,
    required this.ctaAr,
    required this.ctaEn,
    required this.primaryScreen,
    this.cta2Ar,
    this.cta2En,
    this.secondaryScreen,
  });
}

class _StageCard extends StatelessWidget {
  final int index;
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _StageCard({
    required this.index,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.22),
                  foregroundColor: acadegateInk(color),
                  child: Text(
                    '$index',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(icon, color: acadegateInk(color), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: acadegateInk(color),
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(height: 1.4, color: Color(0xFFB7C3D6)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    foregroundColor: acadegateInk(color),
                    backgroundColor: color.withValues(alpha: 0.22),
                  ),
                  onPressed: onPrimary,
                  child: Text(primaryLabel),
                ),
                if (secondaryLabel != null && onSecondary != null)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: acadegateInk(color),
                    ),
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
