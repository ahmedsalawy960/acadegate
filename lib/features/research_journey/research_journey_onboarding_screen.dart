import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../academic_writing/writing_hub_screen.dart';
import '../matchmaking/matchmaking_screen.dart';
import '../methodology_integrity/methodology_integrity_screen.dart';
import '../research_supply_chain/research_supply_chain_screen.dart';
import '../smart_labs/smart_labs_screen.dart';
import '../viva_simulator/viva_screen.dart';
import 'research_journey_service.dart';
import 'research_journey_stage.dart';

class ResearchJourneyOnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const ResearchJourneyOnboardingScreen({
    super.key,
    required this.onFinished,
  });

  @override
  State<ResearchJourneyOnboardingScreen> createState() =>
      _ResearchJourneyOnboardingScreenState();
}

class _ResearchJourneyOnboardingScreenState
    extends State<ResearchJourneyOnboardingScreen> {
  static const _brand = Color(0xFF1A237E);

  ResearchJourneyStage? _selected;
  bool _saving = false;

  Future<void> _continue() async {
    final stage = _selected;
    if (stage == null || _saving) return;

    setState(() => _saving = true);
    await ResearchJourneyService.instance.completeOnboarding(stage);
    if (!mounted) return;

    widget.onFinished();

    final route = _routeForStage(stage);
    if (route != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => route),
      );
    }
  }

  Widget? _routeForStage(ResearchJourneyStage stage) {
    return switch (stage) {
      ResearchJourneyStage.choosingTopic => const ResearchSupplyChainScreen(),
      ResearchJourneyStage.findingSupervisor =>
        const MatchmakingScreen(supervisorJourney: true),
      ResearchJourneyStage.methodology => const MethodologyIntegrityScreen(),
      ResearchJourneyStage.dataCollection => const SmartLabsScreen(),
      ResearchJourneyStage.writing => const WritingHubScreen(),
      ResearchJourneyStage.defense => const VivaSimulatorScreen(),
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.t(
                  'أين أنت في رحلة البحث؟',
                  'Where are you in your research journey?',
                ),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _brand,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.t(
                  'سؤال واحد — نفتح لك المسار المناسب فوراً',
                  'One question — we open the right path for you instantly',
                ),
                style: TextStyle(color: Colors.grey[700], height: 1.4),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: ResearchJourneyStage.values.map((stage) {
                    final selected = _selected == stage;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: selected
                            ? _brand.withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _selected = stage),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? _brand : Colors.grey.shade300,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: selected ? _brand : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stage.label,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: selected
                                              ? _brand
                                              : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        stage.subtitle,
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
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              FilledButton(
                onPressed: _selected == null || _saving ? null : _continue,
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(context.t('ابدأ مساري', 'Start my path')),
              ),
              TextButton(
                onPressed: _saving
                    ? null
                    : () async {
                        await ResearchJourneyService.instance
                            .completeOnboarding(
                          ResearchJourneyStage.choosingTopic,
                        );
                        if (!mounted) return;
                        widget.onFinished();
                      },
                child: Text(context.t('تخطي — استكشف المنصة', 'Skip — explore')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
