import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/theme/acadegate_theme.dart';
import '../academic_writing/writing_hub_screen.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';
import '../humanities/field_or_lab_gateway_screen.dart';
import '../matchmaking/matchmaking_screen.dart';
import '../research_supply_chain/research_supply_chain_screen.dart';
import 'research_journey_service.dart';
import 'research_journey_stage.dart';

enum _OnboardIntent { undecided, researcher, provider }

/// First screen after entering the user portal: researcher path or provider.
class ResearchJourneyOnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;
  final VoidCallback? onBecameProvider;

  const ResearchJourneyOnboardingScreen({
    super.key,
    required this.onFinished,
    this.onBecameProvider,
  });

  @override
  State<ResearchJourneyOnboardingScreen> createState() =>
      _ResearchJourneyOnboardingScreenState();
}

class _ResearchJourneyOnboardingScreenState
    extends State<ResearchJourneyOnboardingScreen> {
  static const _brand = Color(0xFF1A237E);
  static const _providerAccent = Color(0xFF2E7D32);

  _OnboardIntent _intent = _OnboardIntent.undecided;
  ResearchJourneyStage? _selectedStage;
  String? _selectedProviderRole;
  bool _saving = false;

  /// مراحل أبسط للباحث (بدون منهجية/مناقشة كخيارات مستقلة).
  static const _researcherStages = <ResearchJourneyStage>[
    ResearchJourneyStage.choosingTopic,
    ResearchJourneyStage.findingSupervisor,
    ResearchJourneyStage.dataCollection,
    ResearchJourneyStage.writing,
  ];

  static const _providerRoles = <String>[
    UserRole.merchant,
    UserRole.labManager,
    UserRole.supervisor,
    UserRole.writer,
    UserRole.ideaPublisher,
  ];

  String _stageSubtitle(ResearchJourneyStage stage) {
    // في شاشة الاختيار نفضّل صياغة ميدانية أولاً (بلا عينات) مع خيار المختبر لاحقاً.
    return stage.subtitleFor(fieldMode: true);
  }

  String _stageLabel(ResearchJourneyStage stage) {
    return stage.labelFor(fieldMode: true);
  }

  String _providerRoleSubtitle(String role) {
    return switch (role) {
      UserRole.merchant => context.t(
          'بيع أجهزة ومستلزمات بحثية',
          'Sell research equipment & supplies',
        ),
      UserRole.labManager => context.t(
          'تسجيل مختبرك وطلبات التحليل',
          'Register your lab and analysis orders',
        ),
      UserRole.supervisor => context.t(
          'تقديم الإشراف للباحثين',
          'Offer supervision to researchers',
        ),
      UserRole.writer => context.t(
          'مساعدة واستشارة في الكتابة الأكاديمية',
          'Academic writing help and consultation',
        ),
      UserRole.ideaPublisher => context.t(
          'نشر أفكار ومشاريع بحثية',
          'Publish research ideas & projects',
        ),
      _ => '',
    };
  }

  Future<void> _continueResearcher() async {
    final stage = _selectedStage;
    if (stage == null || _saving) return;

    setState(() => _saving = true);
    try {
      await ResearchJourneyService.instance.completeOnboarding(stage);
      if (!mounted) return;
      widget.onFinished();
      final route = _routeForStage(stage);
      if (route != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => route),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _continueProvider() async {
    final role = _selectedProviderRole;
    if (role == null || _saving) return;

    setState(() => _saving = true);
    try {
      await UserAccountService.instance.adoptServiceProviderRole(role);
      await ResearchJourneyService.instance.completeOnboardingWithoutStage();
      if (!mounted) return;
      final onProvider = widget.onBecameProvider;
      if (onProvider != null) {
        onProvider();
      } else {
        widget.onFinished();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red[800]),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _skip() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ResearchJourneyService.instance.completeOnboarding(
        ResearchJourneyStage.choosingTopic,
      );
      if (!mounted) return;
      widget.onFinished();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget? _routeForStage(ResearchJourneyStage stage) {
    return switch (stage) {
      ResearchJourneyStage.choosingTopic => const ResearchSupplyChainScreen(),
      ResearchJourneyStage.findingSupervisor =>
        const MatchmakingScreen(supervisorJourney: true),
      ResearchJourneyStage.methodology ||
      ResearchJourneyStage.dataCollection =>
        const FieldOrLabGatewayScreen(),
      ResearchJourneyStage.writing ||
      ResearchJourneyStage.defense =>
        const WritingHubScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('AcadeGate', 'AcadeGate')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        showBackButton: false,
        leading: _intent == _OnboardIntent.undecided || _saving
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: context.t('رجوع', 'Back'),
                onPressed: () => setState(() {
                  _intent = _OnboardIntent.undecided;
                  _selectedStage = null;
                  _selectedProviderRole = null;
                }),
              ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: switch (_intent) {
            _OnboardIntent.undecided => _buildIntentStep(),
            _OnboardIntent.researcher => _buildResearcherStep(),
            _OnboardIntent.provider => _buildProviderStep(),
          },
        ),
      ),
    );
  }

  Widget _buildIntentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t('كيف تريد أن تبدأ؟', 'How do you want to start?'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AcadeGateColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.t(
            'اختر مسارك — باحث أو مقدم خدمة',
            'Choose your path — researcher or service provider',
          ),
          style: const TextStyle(color: AcadeGateColors.muted, height: 1.4),
        ),
        const SizedBox(height: 24),
        _IntentCard(
          title: context.t('باحث / طالب', 'Researcher / student'),
          subtitle: context.t(
            'موضوع · مشرف · ميدان/مختبر · كتابة',
            'Topic · supervisor · field/lab · writing',
          ),
          icon: Icons.school_outlined,
          accent: _brand,
          onTap: () => setState(() => _intent = _OnboardIntent.researcher),
        ),
        const SizedBox(height: 14),
        _IntentCard(
          title: context.t('مقدم خدمة', 'Service provider'),
          subtitle: context.t(
            'مورد · مختبر · مشرف · كاتب · ناشر أفكار',
            'Merchant · lab · supervisor · writer · ideas',
          ),
          icon: Icons.storefront_outlined,
          accent: _providerAccent,
          onTap: () => setState(() => _intent = _OnboardIntent.provider),
        ),
        const Spacer(),
        TextButton(
          onPressed: _saving ? null : _skip,
          style: TextButton.styleFrom(foregroundColor: AcadeGateColors.gold),
          child: Text(
            context.t('تخطي — استكشف المنصة', 'Skip — explore'),
          ),
        ),
      ],
    );
  }

  Widget _buildResearcherStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t(
            'أين أنت في رحلة البحث؟',
            'Where are you in your research journey?',
          ),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AcadeGateColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.t(
            'اختر مرحلتك الحالية لفتح المسار المناسب',
            'Pick your current stage to open the right path',
          ),
          style: const TextStyle(color: AcadeGateColors.muted, height: 1.4),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: _researcherStages.map((stage) {
              final selected = _selectedStage == stage;
              return _OptionTile(
                selected: selected,
                title: _stageLabel(stage),
                subtitle: _stageSubtitle(stage),
                onTap: () => setState(() => _selectedStage = stage),
              );
            }).toList(),
          ),
        ),
        FilledButton(
          onPressed:
              _selectedStage == null || _saving ? null : _continueResearcher,
          style: FilledButton.styleFrom(
            backgroundColor: AcadeGateColors.gold,
            foregroundColor: AcadeGateColors.page,
            disabledBackgroundColor: AcadeGateColors.card,
            disabledForegroundColor: AcadeGateColors.muted,
            minimumSize: const Size.fromHeight(48),
          ),
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AcadeGateColors.page,
                  ),
                )
              : Text(context.t('ابدأ مساري', 'Start my path')),
        ),
      ],
    );
  }

  Widget _buildProviderStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t(
            'ما نوع الخدمة التي تقدّمها؟',
            'What type of service do you offer?',
          ),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AcadeGateColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.t(
            'سنفتح لك بوابة مقدم الخدمة حسب دورك',
            'We will open the provider portal for your role',
          ),
          style: const TextStyle(color: AcadeGateColors.muted, height: 1.4),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: _providerRoles.map((role) {
              final selected = _selectedProviderRole == role;
              return _OptionTile(
                selected: selected,
                title: UserRole.label(role),
                subtitle: _providerRoleSubtitle(role),
                onTap: () => setState(() => _selectedProviderRole = role),
              );
            }).toList(),
          ),
        ),
        FilledButton(
          onPressed: _selectedProviderRole == null || _saving
              ? null
              : _continueProvider,
          style: FilledButton.styleFrom(
            backgroundColor: AcadeGateColors.gold,
            foregroundColor: AcadeGateColors.page,
            disabledBackgroundColor: AcadeGateColors.card,
            disabledForegroundColor: AcadeGateColors.muted,
            minimumSize: const Size.fromHeight(48),
          ),
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AcadeGateColors.page,
                  ),
                )
              : Text(
                  context.t(
                    'الدخول إلى بوابة مقدم الخدمة',
                    'Enter provider portal',
                  ),
                ),
        ),
      ],
    );
  }
}

class _IntentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _IntentCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = acadegateInk(accent);
    return Material(
      color: AcadeGateColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AcadeGateColors.line),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: ink.withValues(alpha: 0.16),
                child: Icon(icon, color: ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: AcadeGateColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AcadeGateColors.muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: ink),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? const Color(0xFF1E3358) : AcadeGateColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AcadeGateColors.gold : AcadeGateColors.line,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AcadeGateColors.gold : AcadeGateColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AcadeGateColors.text,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AcadeGateColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
