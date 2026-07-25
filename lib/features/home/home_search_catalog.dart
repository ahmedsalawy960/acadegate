import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../../l10n/app_localizations.dart';
import '../academic_integrity/academic_integrity_hub_screen.dart';
import '../academic_integrity/citation_check_screen.dart';
import '../academic_integrity/originality_check_screen.dart';
import '../academic_writing/writing_categories.dart';
import '../academic_writing/writing_expert_list_screen.dart';
import '../community/community_data.dart';
import '../community/community_room_screen.dart';
import '../data_analysis/statistical_assumptions_screen.dart';
import '../methodology_integrity/methodology_integrity_screen.dart';
import 'home_search_utils.dart';

class HomeSearchSubService {
  final String title;
  final String parentSection;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final List<String> keywords;
  final Widget screen;

  const HomeSearchSubService({
    required this.title,
    required this.parentSection,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.keywords,
    required this.screen,
  });

  bool matches(String query) => homeSearchMatches(query, [
        title,
        parentSection,
        ?subtitle,
        ...keywords,
      ]);
}

List<HomeSearchSubService> buildHomeSearchSubServices(
  BuildContext context,
  AppLocalizations l10n,
) {
  final entries = <HomeSearchSubService>[];

  for (final category in writingCategories) {
    entries.add(
      HomeSearchSubService(
        title: category.localizedTitle,
        subtitle: category.localizedSubtitle,
        parentSection: l10n.serviceWriting,
        icon: category.icon,
        color: category.color,
        keywords: [
          category.id,
          category.title,
          category.subtitle,
          'writing',
          'thesis',
          'statistics',
          'spss',
          'كتابه',
          'رساله',
          'احصاء',
        ],
        screen: WritingExpertListScreen(category: category),
      ),
    );
  }

  entries.addAll([
    HomeSearchSubService(
      title: context.t('معالج الافتراضات الإحصائية', 'Statistical assumptions wizard'),
      subtitle: context.t('تطبيع، قوة العينة، SPSS/R', 'Normality, power, SPSS/R'),
      parentSection: l10n.serviceWriting,
      icon: Icons.functions_outlined,
      color: const Color(0xFF00838F),
      keywords: const [
        'spss',
        'r',
        'statistics',
        'assumptions',
        'normality',
        'power',
        'افتراضات',
        'احصاء',
        'تطبيع',
      ],
      screen: const StatisticalAssumptionsScreen(),
    ),
    HomeSearchSubService(
      title: context.t('فاحص المراجع', 'Reference checker'),
      subtitle: context.t('Crossref · OpenAlex · DOI', 'Crossref · OpenAlex · DOI'),
      parentSection: l10n.serviceWriting,
      icon: Icons.menu_book_outlined,
      color: const Color(0xFF0D47A1),
      keywords: const [
        'citation',
        'reference',
        'doi',
        'crossref',
        'openalex',
        'مراجع',
        'مرجع',
        'توثيق',
      ],
      screen: const CitationCheckScreen(),
    ),
    HomeSearchSubService(
      title: context.t('فاحص التشابه', 'Similarity checker'),
      subtitle: context.t('Copyleaks · PlagiarismCheck', 'Copyleaks · PlagiarismCheck'),
      parentSection: l10n.serviceWriting,
      icon: Icons.fact_check_outlined,
      color: const Color(0xFF6A1B9A),
      keywords: const [
        'plagiarism',
        'similarity',
        'copyleaks',
        'originality',
        'انتحال',
        'تشابه',
        'اقلاص',
      ],
      screen: const OriginalityCheckScreen(),
    ),
    HomeSearchSubService(
      title: context.t('كاشف الانتحال المنهجي', 'Methodology integrity check'),
      subtitle: context.t('تصميم، عينة، تحليل', 'Design, sample, analysis'),
      parentSection: l10n.serviceWriting,
      icon: Icons.policy_outlined,
      color: const Color(0xFF1B5E20),
      keywords: const [
        'methodology',
        'method',
        'integrity',
        'منهجيه',
        'منهجية',
        'عينه',
        'تصميم',
      ],
      screen: const MethodologyIntegrityScreen(),
    ),
    HomeSearchSubService(
      title: context.t('مركز سلامة أكاديمية', 'Academic integrity hub'),
      parentSection: l10n.serviceWriting,
      icon: Icons.verified_user_rounded,
      color: const Color(0xFF1B5E20),
      keywords: const [
        'integrity',
        'academic',
        'سلامه',
        'سلامة',
        'مراجع',
        'تشابه',
      ],
      screen: const AcademicIntegrityHubScreen(),
    ),
  ]);

  for (final room in communityRooms) {
    entries.add(
      HomeSearchSubService(
        title: room.title,
        subtitle: room.description,
        parentSection: l10n.serviceCommunity,
        icon: room.icon,
        color: room.color,
        keywords: [
          room.id,
          room.title,
          room.description,
          'community',
          'room',
          'مجتمع',
          'غرفه',
          'غرفة',
          'نقاش',
        ],
        screen: CommunityRoomScreen(room: room),
      ),
    );
  }

  return entries;
}
