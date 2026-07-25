import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../academic/academic_content_service.dart';
import '../profile/academic_profile_service.dart';
import 'matchmaking_screen.dart';
import 'smart_matchmaking_engine.dart';

/// أيقونة المطابقة الذكية في الشريط العلوي — مع شارة عند توفر توصيات.
class SmartMatchAppBarButton extends StatefulWidget {
  const SmartMatchAppBarButton({super.key});

  @override
  State<SmartMatchAppBarButton> createState() => _SmartMatchAppBarButtonState();
}

class _SmartMatchAppBarButtonState extends State<SmartMatchAppBarButton> {
  int? _topMatchScore;

  @override
  void initState() {
    super.initState();
    // Defer badge fetch so first home frame is not blocked.
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _loadBadge();
    });
  }

  Future<void> _loadBadge() async {
    final profile = await AcademicProfileService.instance.loadProfile();
    if (!mounted || profile == null || !profile.isComplete) return;

    final content = await AcademicContentService.instance.fetchAll(
      includeLabs: false,
    );
    final matches = SmartMatchmakingEngine.matchSupervisors(
      profile,
      content.supervisors,
      limit: 1,
    );
    if (!mounted || matches.isEmpty) return;

    setState(() => _topMatchScore = matches.first.score);
  }

  void _open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MatchmakingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final score = _topMatchScore;
    final showBadge = score != null && score >= 50;

    return IconButton(
      tooltip: l10n.smartMatchmaking,
      onPressed: () => _open(context),
      icon: Badge(
        isLabelVisible: showBadge,
        label: Text('$score%'),
        backgroundColor: const Color(0xFF43A047),
        child: const Icon(Icons.auto_awesome),
      ),
    );
  }
}
