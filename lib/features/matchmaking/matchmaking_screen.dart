import 'package:flutter/material.dart';
import '../academic/academic_content_service.dart';
import '../academic/academic_models.dart';
import '../profile/academic_profile.dart';
import '../profile/academic_profile_screen.dart';
import '../profile/academic_profile_service.dart';
import '../smart_labs/smart_lab_detail_screen.dart';
import 'smart_matchmaking_engine.dart';
class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

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

    final profile = await AcademicProfileService.instance.loadProfile();

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
    _supervisorMatches = SmartMatchmakingEngine.matchSupervisors(
      profile,
      content.supervisors,
    );
    _ideaMatches = SmartMatchmakingEngine.matchResearchIdeas(
      profile,
      content.ideas,
    );
    _labMatches = SmartMatchmakingEngine.matchLabs(
      profile,
      content.labs,
    );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('المطابقة الذكية'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'تعديل الملف الأكاديمي',
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.psychology_alt_outlined, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'أكمل ملفك الأكاديمي أولاً',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'سنقترح لك أفضل المشرفين والأفكار البحثية والمختبرات بناءً على تخصصك واهتمامك.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
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
              label: const Text('إنشاء الملف الأكاديمي'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final hasAnyResults = _supervisorMatches.isNotEmpty ||
        _ideaMatches.isNotEmpty ||
        _labMatches.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _loadAndMatch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileSummaryCard(
            profile: _profile!,
            onEdit: _openProfileEditor,
          ),
          const SizedBox(height: 20),
          if (!hasAnyResults)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'لم نجد توصيات كافية بعد. جرّب توسيع اهتمامك البحثي في ملفك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          if (_supervisorMatches.isNotEmpty) ...[
            _sectionTitle('أفضل المشرفين', Icons.people_alt_rounded),
            ..._supervisorMatches.map(_buildSupervisorCard),
          ],
          if (_ideaMatches.isNotEmpty) ...[
            _sectionTitle('أفكار بحثية مقترحة', Icons.lightbulb_outline),
            ..._ideaMatches.map(_buildIdeaCard),
          ],
          if (_labMatches.isNotEmpty) ...[
            _sectionTitle('مختبرات مناسبة', Icons.science_outlined),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupervisorCard(MatchResult<AcademicSupervisor> result) {
    final supervisor = result.item;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
            const SizedBox(height: 8),
            ...result.reasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(child: Text(reason)),
                  ],
                ),
              ),
            ),
          ],
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
        title: Text(idea.title, style: const TextStyle(fontWeight: FontWeight.bold)),
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
        title: Text(lab.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${lab.location}\n${lab.displayEquipment}'),
        isThreeLine: true,
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
              '${profile.degree} • ${profile.specialization}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              profile.university,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'اهتمام بحثي: ${profile.researchInterest}',
              style: const TextStyle(color: Colors.white),
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
