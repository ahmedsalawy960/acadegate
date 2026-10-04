import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../academic_integrity/academic_integrity_hub_screen.dart';
import '../academic_writing/writing_hub_screen.dart';
import '../acadegate_publish/publish_hub_screen.dart';
import '../ai_advisor/ai_advisor_screen.dart';
import '../community/community_hub_screen.dart';
import '../matchmaking/matchmaking_screen.dart';
import '../research_fund/research_fund_screen.dart';
import '../research_marketplace/research_marketplace_screen.dart';
import '../research_supply_chain/research_supply_chain_screen.dart';
import '../thesis_studio/thesis_studio_screen.dart';
import '../science_news/science_news_screen.dart';
import '../humanities/humanities_hub_screen.dart';
import '../humanities_publish/humanities_publish_screen.dart';
import '../research_proposal/research_proposal_screen.dart';
import '../smart_labs/smart_labs_screen.dart';
import '../store/store_hub_screen.dart';
import 'home_feed_models.dart';

typedef HomeRouteResolver = Widget? Function(String key);

/// يفتح وجهة البنر: مسار داخلي أو رابط خارجي.
Future<void> openHomePromoTarget(
  BuildContext context,
  HomePromoBanner banner, {
  HomeRouteResolver? resolveRoute,
}) async {
  final type = banner.linkType.trim().toLowerCase();
  final target = banner.linkTarget.trim();
  if (target.isEmpty) return;

  if (type == 'url' || target.startsWith('http')) {
    final uri = Uri.tryParse(target);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return;
  }

  final screen = resolveRoute?.call(target) ?? screenForHomeRoute(target);
  if (screen == null) return;
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => screen),
  );
}

Widget? screenForHomeRoute(String key) {
  switch (key.trim().toLowerCase()) {
    case 'matchmaking':
    case 'smart_match':
      return const MatchmakingScreen();
    case 'ideas':
    case 'research_ideas':
      return const ResearchMarketplaceScreen();
    case 'research_path':
    case 'path':
      return const ResearchSupplyChainScreen();
    case 'labs':
    case 'smart_labs':
      return const SmartLabsScreen();
    case 'humanities':
    case 'humanities_hub':
    case 'education_research':
      return const HumanitiesHubScreen();
    case 'research_proposal':
    case 'proposal_path':
    case 'proposal_studio':
      return const ResearchProposalScreen();
    case 'store':
    case 'shop':
      return const StoreHubScreen();
    case 'community':
      return const CommunityHubScreen();
    case 'ai':
    case 'advisor':
      return const AiAdvisorScreen();
    case 'writing':
      return const WritingHubScreen();
    case 'thesis':
    case 'thesis_studio':
      return const ThesisStudioScreen();
    case 'integrity':
      return const AcademicIntegrityHubScreen();
    case 'publish':
      return const PublishHubScreen();
    case 'humanities_publish':
    case 'arabic_publish':
    case 'annals_publish':
      return const HumanitiesPublishScreen();
    case 'fund':
      return const ResearchFundScreen();
    case 'news':
    case 'science_news':
      return const ScienceNewsScreen();
    default:
      return null;
  }
}
