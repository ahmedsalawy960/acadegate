import 'package:flutter/material.dart';

import '../academic_integrity/academic_integrity_hub_screen.dart';
import '../acadegate_publish/publish_hub_screen.dart';
import '../matchmaking/matchmaking_screen.dart';
import '../profile/academic_profile_screen.dart';
import '../research_marketplace/research_marketplace_screen.dart';
import '../research_supply_chain/research_supply_chain_screen.dart';
import '../smart_labs/smart_labs_screen.dart';
import '../thesis_studio/thesis_studio_screen.dart';
import '../viva_simulator/viva_screen.dart';
import 'thesis_progress_activity.dart';

class ThesisProgressNavigation {
  ThesisProgressNavigation._();

  static Future<void> openActivity(
    BuildContext context,
    String? activityId,
  ) async {
    final id = ThesisActivityIdX.parse(activityId);
    final screen = switch (id) {
      ThesisActivityId.profileComplete => const AcademicProfileScreen(),
      ThesisActivityId.topicIdea => const ResearchSupplyChainScreen(),
      ThesisActivityId.supervisorMatch =>
        const MatchmakingScreen(supervisorJourney: true),
      ThesisActivityId.methodologyEthics ||
      ThesisActivityId.citationCheck ||
      ThesisActivityId.originalityCheck =>
        const AcademicIntegrityHubScreen(),
      ThesisActivityId.dataCollection => const SmartLabsScreen(),
      ThesisActivityId.thesisStudio => const ThesisStudioScreen(),
      ThesisActivityId.chapterWriting => const ThesisStudioScreen(),
      ThesisActivityId.publishManuscript => const PublishHubScreen(),
      ThesisActivityId.vivaPractice => const VivaSimulatorScreen(),
      ThesisActivityId.defenseDeadline => const VivaSimulatorScreen(),
      null => const ResearchMarketplaceScreen(),
    };

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}
