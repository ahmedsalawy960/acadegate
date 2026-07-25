import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import '../../core/locale/locale_extensions.dart';
import '../academic/academic_content_service.dart';
import '../academic/academic_models.dart';
import '../academic/faculty_categories.dart';
import '../academic/supervisor_profile_screen.dart';
import '../profile/academic_profile.dart';
import '../profile/academic_profile_screen.dart';
import '../profile/academic_profile_service.dart';
import '../smart_labs/smart_lab_detail_screen.dart';
import 'smart_matchmaking_engine.dart';

class MatchmakingScreen extends StatefulWidget {
  /// عند فتح الشاشة من رحلة «اختر مشرفاً» — تركيز على المشرفين وشرح أوضح.
  final bool supervisorJourney;

  /// اختياري: فرض كلية معينة (مثلاً من غرفة مجتمع أكاديمي).
  final String? focusFacultyId;

  const MatchmakingScreen({
    super.key,
    this.supervisorJourney = false,
    this.focusFacultyId,
  });

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  bool _isLoading = true;
  AcademicProfile? _profile;
  List<MatchResult<AcademicSupervisor>> _supervisorMatches = [];
  List<MatchResult<AcademicResearchIdea>> _ideaMatches = [];
  List<MatchResult<AcademicLab>> _labMatches = [];

  @override
  void initState() {
    super.initState();
    _loadAndMatch();
  }

  Future<void> _loadAndMatch() async {
    setState(() {
      _isLoading = true;
    });

    var profile = await AcademicProfileService.instance.loadProfile();
    final focus = widget.focusFacultyId?.trim();
    if (profile != null &&
        focus != null &&
        focus.isNotEmpty &&
        focus != 'general') {
      profile = profile.copyWith(facultyCategory: focus);
    }

    if (!mounted) return;

    if (profile != null && profile.isComplete) {
      _profile = profile;
      await _runMatching(profile);
    } else {
      _profile = profile;
      _supervisorMatches = [];
      _ideaMatches = [];
      _labMatches = [];
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _runMatching(AcademicProfile profile) async {
    final content = await AcademicContentService.instance.fetchAll();
    if (!mounted) return;
    _supervisorMatches = SmartMatchmakingEngine.matchSupervisors(
      profile,
      content.supervisors,
    );
    if (!widget.supervisorJourney) {
      _ideaMatches = SmartMatchmakingEngine.matchResearchIdeas(
        profile,
        content.ideas,
      );
      final labs = await AcademicContentService.instance.searchLabs(
        facultyId: profile.resolvedFacultyCategory,
        limit: 60,
      );
      if (!mounted) return;
      _labMatches = SmartMatchmakingEngine.matchLabs(profile, labs);
    } else {
      _ideaMatches = [];
      _labMatches = [];
    }
  }

  Future<void> _openProfileEditor() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AcademicProfileScreen()),
    );

    if (saved == true) {
      await _loadAndMatch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final journey = widget.supervisorJourney;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(
          journey
              ? context.t('اختر مشرفاً', 'Choose a supervisor')
              : context.t('المطابقة الذكية', 'Smart matching'),
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: context.t('تعديل الملف الأكاديمي', 'Edit academic profile'),
            onPressed: _openProfileEditor,
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_profile == null || !_profile!.isComplete)
          ? _buildEmptyProfileState()
          : _buildResults(),
    );
  }

  Widget _buildEmptyProfileState() {
    final journey = widget.supervisorJourney;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            journey
                ? context.t(
                    'الخطوة 1: ملفك الأكاديمي',
                    'Step 1: Your academic profile',
                  )
                : context.t(
                    'أكمل ملفك الأكاديمي أولاً',
                    'Complete your academic profile first',
                  ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            journey
                ? context.t(
                    'نحتاج تخصصك واهتمامك البحثي والمنهجية لاقتراح أفضل المشرفين مع نسبة توافق واضحة.',
                    'We need your field, research interest, and methodology to suggest the best supervisors with a clear match score.',
                  )
                : context.t(
                    'سنقترح لك أفضل المشرفين والأفكار البحثية والمختبرات بناءً على تخصصك واهتمامك.',
                    'We will suggest the best supervisors, research ideas, and labs based on your specialization and interests.',
                  ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, height: 1.45),
          ),
          if (journey) ...[
            const SizedBox(height: 20),
            _JourneySteps(compact: true),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _openProfileEditor,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.edit_note),
              label: Text(
                context.t('إنشاء الملف الأكاديمي', 'Create academic profile'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final journey = widget.supervisorJourney;
    final hasAnyResults = _supervisorMatches.isNotEmpty ||
        _ideaMatches.isNotEmpty ||
        _labMatches.isNotEmpty;
    final demoOnlySupervisors = _supervisorMatches.isNotEmpty &&
        _supervisorMatches.every((match) => match.item.isDemo);
    final facultyId = _profile!.resolvedFacultyCategory;
    final facultyLabel = facultyId != null
        ? facultyTitleForCategory(facultyId)
        : null;

    return RefreshIndicator(
      onRefresh: _loadAndMatch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (journey) ...[
            _JourneySteps(),
            const SizedBox(height: 12),
          ],
          _ProfileSummaryCard(
            profile: _profile!,
            onEdit: _openProfileEditor,
          ),
          if (demoOnlySupervisors) ...[
            const SizedBox(height: 12),
            _DemoDataBanner(facultyLabel: facultyLabel),
          ],
          const SizedBox(height: 20),
          if (!hasAnyResults)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  facultyLabel != null
                      ? context.t(
                          'لم نجد مشرفين مطابقين في $facultyLabel بعد. '
                          'يمكنك تصفح الكليات من الصفحة الرئيسية أو توسيع اهتمامك البحثي.',
                          'No matching supervisors in $facultyLabel yet. '
                          'Browse faculties from the home screen or broaden your research interest.',
                        )
                      : context.t(
                          'لم نجد توصيات كافية بعد. اختر كليتك في ملفك الأكاديمي أو وسّع اهتمامك البحثي.',
                          'Not enough recommendations yet. Select your faculty in your profile or broaden your research interest.',
                        ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, height: 1.45),
                ),
              ),
            ),
          if (_supervisorMatches.isNotEmpty) ...[
            _sectionTitle(
              journey
                  ? context.t(
                      'مشرفون مقترحون لك',
                      'Supervisors recommended for you',
                    )
                  : context.t('أفضل المشرفين', 'Top supervisors'),
              Icons.people_alt_rounded,
            ),
            if (journey)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  context.t(
                    'مرتّبة حسب التوافق مع ملفك — اضغط لعرض الملف وطلب الإشراف',
                    'Ranked by profile fit — tap to view profile and request supervision',
                  ),
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
            ..._supervisorMatches.asMap().entries.map(
              (entry) => _buildSupervisorCard(entry.value, rank: entry.key + 1),
            ),
          ],
          if (!journey && _ideaMatches.isNotEmpty) ...[
            _sectionTitle(
              context.t('أفكار بحثية مقترحة', 'Suggested research ideas'),
              Icons.lightbulb_outline,
            ),
            ..._ideaMatches.map(_buildIdeaCard),
          ],
          if (!journey && _labMatches.isNotEmpty) ...[
            _sectionTitle(
              context.t('مختبرات مناسبة', 'Matching labs'),
              Icons.science_outlined,
            ),
            ..._labMatches.map(_buildLabCard),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1A237E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupervisorCard(
    MatchResult<AcademicSupervisor> result, {
    int? rank,
  }) {
    final supervisor = result.item;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                SupervisorProfileScreen(supervisor: supervisor),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (rank != null) ...[
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF1A237E),
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      supervisor.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _ScoreBadge(score: result.score),
                ],
              ),
              const SizedBox(height: 6),
              Text('${supervisor.speciality} • ${supervisor.university}'),
              if (supervisor.isDemo)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    context.t(
                      'مشرف تجريبي — للعرض حتى يُسجّل مشرفون حقيقيون',
                      'Demo supervisor — shown until real supervisors register',
                    ),
                    style: TextStyle(color: Colors.orange[800], fontSize: 12),
                  ),
                ),
              const SizedBox(height: 8),
              ...result.reasons.map(
                (reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(reason)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    context.t('عرض الملف', 'View profile'),
                    style: const TextStyle(
                      color: Color(0xFF1A237E),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Color(0xFF1A237E),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdeaCard(MatchResult<AcademicResearchIdea> result) {
    final idea = result.item;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: _ScoreBadge(score: result.score, compact: true),
        title: Text(
          idea.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          result.reasons.isEmpty
              ? idea.provider
              : '${idea.provider}\n${result.reasons.first}',
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildLabCard(MatchResult<AcademicLab> result) {
    final lab = result.item;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SmartLabDetailScreen(lab: lab),
          ),
        ),
        leading: _ScoreBadge(score: result.score, compact: true),
        title: Text(
          lab.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${lab.location}\n${lab.displayEquipment}'),
        isThreeLine: true,
      ),
    );
  }
}

class _JourneySteps extends StatelessWidget {
  final bool compact;

  const _JourneySteps({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        Icons.person_outline,
        context.t('ملفك الأكاديمي', 'Academic profile'),
        context.t('تخصص واهتمام ومنهجية', 'Field, interest & methodology'),
      ),
      (
        Icons.auto_awesome,
        context.t('نسبة التوافق', 'Match score'),
        context.t('مقارنة مع قاعدة المشرفين', 'Compared to supervisor database'),
      ),
      (
        Icons.handshake_outlined,
        context.t('تواصل وطلب إشراف', 'Contact & request'),
        context.t('رسالة أو طلب رسمي', 'Message or formal request'),
      ),
    ];

    if (compact) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey[400]),
              ),
            Icon(steps[i].$1, size: 20, color: const Color(0xFF283593)),
          ],
        ],
      );
    }

    return Card(
      color: const Color(0xFF283593).withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('كيف تختار مشرفاً؟', 'How to choose a supervisor?'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF283593),
              ),
            ),
            const SizedBox(height: 12),
            ...steps.asMap().entries.map((entry) {
              final step = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF283593),
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.$2,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            step.$3,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  final AcademicProfile profile;
  final VoidCallback onEdit;

  const _ProfileSummaryCard({
    required this.profile,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A237E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    profile.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_profileDegreeLabel(context, profile.degree)} • ${profile.specialization}',
              style: const TextStyle(color: Colors.white70),
            ),
            if (profile.resolvedFacultyCategory != null)
              Text(
                facultyTitleForCategory(profile.resolvedFacultyCategory!),
                style: const TextStyle(color: Colors.white70),
              ),
            Text(
              profile.university,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              context.t(
                'اهتمام بحثي: ${profile.researchInterest}',
                'Research interest: ${profile.researchInterest}',
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

String _profileDegreeLabel(BuildContext context, String degree) {
  return switch (degree) {
    'ماجستير' => context.t('ماجستير', "Master's"),
    'دكتوراه' => context.t('دكتوراه', 'PhD'),
    _ => degree,
  };
}

class _DemoDataBanner extends StatelessWidget {
  final String? facultyLabel;

  const _DemoDataBanner({this.facultyLabel});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade800),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                facultyLabel != null
                    ? context.t(
                        'المشرفون المعروضون حالياً بيانات تجريبية لـ$facultyLabel. '
                        'عند تسجيل مشرفين حقيقيين في هذه الكلية ستظهر مطابقاتهم تلقائياً.',
                        'Supervisors shown are demo data for $facultyLabel. '
                        'When real supervisors register in this faculty, matches will appear automatically.',
                      )
                    : context.t(
                        'المشرفون المعروضون حالياً بيانات تجريبية. '
                        'عند تسجيل مشرفين حقيقيين ستظهر مطابقاتهم تلقائياً.',
                        'Supervisors shown are demo data. '
                        'When real supervisors register, matches will appear automatically.',
                      ),
                style: TextStyle(color: Colors.orange.shade900, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final int score;
  final bool compact;

  const _ScoreBadge({required this.score, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = score >= 70
        ? Colors.green
        : score >= 40
        ? Colors.orange
        : Colors.red;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        '$score%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: compact ? 12 : 14,
        ),
      ),
    );
  }
}
