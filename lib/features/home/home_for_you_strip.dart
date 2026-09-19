import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/widgets/arrow_scroll_view.dart';
import '../academic/academic_content_service.dart';
import '../academic/academic_models.dart';
import '../academic/faculty_categories.dart';
import '../academic/supervisor_profile_screen.dart';
import '../matchmaking/matchmaking_screen.dart';
import '../matchmaking/smart_matchmaking_engine.dart';
import '../profile/academic_profile.dart';
import '../profile/academic_profile_service.dart';
import '../research_marketplace/research_idea_marketplace_detail_screen.dart';
import '../science_news/science_news_feeds.dart';
import '../science_news/science_news_models.dart';
import '../science_news/science_news_personalizer.dart';
import '../science_news/science_news_screen.dart';
import '../science_news/science_news_service.dart';
import '../smart_labs/smart_lab_detail_screen.dart';
import 'home_for_you_ai.dart';

/// شريط «لك اليوم» — مقترحات مقيّدة بالكلية والتخصص، مع ترتيب ذكي اختياري.
class HomeForYouStrip extends StatefulWidget {
  const HomeForYouStrip({super.key});

  @override
  State<HomeForYouStrip> createState() => _HomeForYouStripState();
}

class _HomeForYouStripState extends State<HomeForYouStrip> {
  AcademicSupervisor? _supervisor;
  AcademicResearchIdea? _idea;
  AcademicLab? _lab;
  ScienceNewsItem? _news;
  bool _loading = true;
  bool _aiRanked = false;
  String _interestHint = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await AcademicProfileService.instance.loadProfile();
      if (profile == null || !profile.isComplete) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _interestHint = '';
        });
        return;
      }

      final facultyId = profile.resolvedFacultyCategory?.trim() ?? '';
      final content = await AcademicContentService.instance.fetchAll();
      final labs = await AcademicContentService.instance.searchLabs(
        query: profile.researchInterest.trim().length >= 2
            ? profile.researchInterest.trim()
            : profile.specialization.trim(),
        facultyId: facultyId.isNotEmpty ? facultyId : null,
        limit: 80,
      );

      final daySeed = DateTime.now().year * 1000 +
          DateTime.now().month * 50 +
          DateTime.now().day;
      final rng = Random(
        daySeed ^
            profile.specialization.hashCode ^
            profile.researchInterest.hashCode ^
            facultyId.hashCode,
      );

      // صارم: نفس الكلية + درجة تطابق > 0 (لا سقوط على كتالوج عام).
      final supervisorMatches = SmartMatchmakingEngine.matchSupervisors(
        profile,
        content.supervisors,
        limit: 8,
        softFallback: false,
        restrictFaculty: facultyId.isNotEmpty,
      );
      final ideaMatches = SmartMatchmakingEngine.matchResearchIdeas(
        profile,
        content.ideas,
        limit: 8,
        softFallback: false,
        restrictFaculty: facultyId.isNotEmpty,
      );
      final labMatches = SmartMatchmakingEngine.matchLabs(
        profile,
        labs,
        limit: 8,
        softFallback: false,
        restrictFaculty: facultyId.isNotEmpty,
      );

      var supervisor = _dayPick(supervisorMatches, rng)?.item;
      var idea = _dayPick(ideaMatches, rng)?.item;
      var lab = _dayPick(labMatches, rng)?.item;
      var usedAi = false;

      // ترتيب Gemini على أفضل المرشحين المصفّين محلياً فقط.
      final aiSupervisor = await _aiPickSupervisor(
        profile,
        supervisorMatches,
      );
      if (aiSupervisor != null) {
        supervisor = aiSupervisor;
        usedAi = true;
      }
      final aiIdea = await _aiPickIdea(profile, ideaMatches);
      if (aiIdea != null) {
        idea = aiIdea;
        usedAi = true;
      }
      final aiLab = await _aiPickLab(profile, labMatches);
      if (aiLab != null) {
        lab = aiLab;
        usedAi = true;
      }

      ScienceNewsItem? news;
      try {
        final feed = await ScienceNewsService.instance
            .fetchLiveNews()
            .timeout(const Duration(seconds: 12));
        final digest = ScienceNewsPersonalizer.weeklyDigest(
          items: feed,
          profile: profile,
        );
        // لا تعرض خبراً بدرجة 0 (خارج التخصص).
        final personalized =
            digest.items.where((r) => r.score > 0).toList();
        if (personalized.isNotEmpty) {
          news = personalized.first.item;
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _supervisor = supervisor;
        _idea = idea;
        _lab = lab;
        _news = news;
        _aiRanked = usedAi;
        _interestHint = [
          if (facultyId.isNotEmpty) facultyTitleForCategory(facultyId),
          if (profile.specialization.trim().isNotEmpty)
            profile.specialization.trim(),
        ].join(' · ');
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  MatchResult<T>? _dayPick<T>(List<MatchResult<T>> matches, Random rng) {
    if (matches.isEmpty) return null;
    // نوّع يومياً بين الأعلى درجة فقط (درجة موجبة مسبقاً من المحرك).
    final topScore = matches.first.score;
    final strong = matches
        .where((m) => m.score >= (topScore * 0.7).floor().clamp(1, 100))
        .take(4)
        .toList();
    final pool = strong.isNotEmpty ? strong : matches.take(3).toList();
    return pool[rng.nextInt(pool.length)];
  }

  Future<AcademicSupervisor?> _aiPickSupervisor(
    AcademicProfile profile,
    List<MatchResult<AcademicSupervisor>> matches,
  ) async {
    if (matches.length < 2) return null;
    final top = matches.take(5).toList();
    final idx = await HomeForYouAi.pickBestIndex(
      profile: profile,
      kindAr: 'مشرف',
      kindEn: 'supervisor',
      candidates: [
        for (final m in top)
          '${m.item.name} | ${m.item.speciality} | ${m.item.faculty} | ${m.item.university}',
      ],
    );
    if (idx == null || idx < 0 || idx >= top.length) return null;
    return top[idx].item;
  }

  Future<AcademicResearchIdea?> _aiPickIdea(
    AcademicProfile profile,
    List<MatchResult<AcademicResearchIdea>> matches,
  ) async {
    if (matches.length < 2) return null;
    final top = matches.take(5).toList();
    final idx = await HomeForYouAi.pickBestIndex(
      profile: profile,
      kindAr: 'فكرة بحثية',
      kindEn: 'research idea',
      candidates: [
        for (final m in top)
          '${m.item.title} | ${m.item.category} | ${m.item.tags.take(4).join(", ")}',
      ],
    );
    if (idx == null || idx < 0 || idx >= top.length) return null;
    return top[idx].item;
  }

  Future<AcademicLab?> _aiPickLab(
    AcademicProfile profile,
    List<MatchResult<AcademicLab>> matches,
  ) async {
    if (matches.length < 2) return null;
    final top = matches.take(5).toList();
    final idx = await HomeForYouAi.pickBestIndex(
      profile: profile,
      kindAr: 'مختبر',
      kindEn: 'lab',
      candidates: [
        for (final m in top)
          '${m.item.name} | ${m.item.displayFacultyName} | ${m.item.university} | ${m.item.tags.take(4).join(", ")}',
      ],
    );
    if (idx == null || idx < 0 || idx >= top.length) return null;
    return top[idx].item;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final chips = <Widget>[
      if (_supervisor != null)
        _ForYouChip(
          icon: Icons.person_rounded,
          color: Colors.blue,
          title: context.t('مشرف مقترح', 'Suggested supervisor'),
          subtitle: _supervisor!.name,
          meta: [
            if (_supervisor!.speciality.trim().isNotEmpty)
              _supervisor!.speciality.trim(),
            if (_supervisor!.faculty.trim().isNotEmpty)
              _supervisor!.faculty.trim()
            else if (_supervisor!.category.trim().isNotEmpty)
              facultyTitleForCategory(_supervisor!.category),
          ].join(' · '),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SupervisorProfileScreen(supervisor: _supervisor!),
            ),
          ),
        ),
      if (_idea != null)
        _ForYouChip(
          icon: Icons.lightbulb_rounded,
          color: Colors.orange,
          title: context.t('فكرة لك', 'Idea for you'),
          subtitle: _idea!.title,
          meta: _idea!.category.isNotEmpty
              ? facultyTitleForCategory(_idea!.category)
              : '',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ResearchIdeaMarketplaceDetailScreen(idea: _idea!),
            ),
          ),
        ),
      if (_lab != null)
        _ForYouChip(
          icon: Icons.science_rounded,
          color: Colors.purple,
          title: context.t('مختبر قريب', 'Nearby lab'),
          subtitle: _lab!.name,
          meta: _lab!.displayFacultyName,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SmartLabDetailScreen(lab: _lab!),
            ),
          ),
        ),
      if (_news != null)
        _ForYouChip(
          icon: Icons.newspaper_rounded,
          color: const Color(0xFF0D47A1),
          title: context.t('موجزك هذا الأسبوع', 'Your weekly digest'),
          subtitle: _news!.title,
          meta: _interestHint.isNotEmpty
              ? _interestHint
              : ScienceNewsCategory.label(_news!.category),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScienceNewsScreen()),
          ),
        ),
    ];

    if (chips.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: const Icon(Icons.auto_awesome, color: Color(0xFF283593)),
          title: Text(context.t('مقترحات لك', 'Picks for you')),
          subtitle: Text(
            context.t(
              'أكمل ملفك الأكاديمي (الكلية والتخصص والاهتمام البحثي) لترشيحات أدق',
              'Complete your academic profile (faculty, specialty, research interest) for sharper picks',
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MatchmakingScreen()),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF283593)),
            const SizedBox(width: 6),
            Text(
              context.t('لك اليوم', 'For you today'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF1A237E),
              ),
            ),
            if (_aiRanked) ...[
              const SizedBox(width: 6),
              Text(
                context.t('ذكي', 'AI'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.indigo.shade700,
                ),
              ),
            ],
            const Spacer(),
            if (_interestHint.isNotEmpty)
              Flexible(
                child: Text(
                  _interestHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ArrowOverlayScroller(
          axis: Axis.horizontal,
          height: 140,
          scrollStep: 200,
          builder: (context, controller) => ListView.separated(
            controller: controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 36),
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => chips[i],
          ),
        ),
      ],
    );
  }
}

class _ForYouChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String meta;
  final VoidCallback onTap;

  const _ForYouChip({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.meta = '',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                if (meta.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
