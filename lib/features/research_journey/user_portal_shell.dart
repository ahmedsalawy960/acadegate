import 'package:flutter/material.dart';

import '../home/home_screen.dart';import 'research_journey_onboarding_screen.dart';
import 'research_journey_service.dart';

/// User portal entry: onboarding once, then home.
class UserPortalShell extends StatefulWidget {
  final VoidCallback? onSwitchPortal;

  const UserPortalShell({super.key, this.onSwitchPortal});

  @override
  State<UserPortalShell> createState() => _UserPortalShellState();
}

class _UserPortalShellState extends State<UserPortalShell> {
  bool? _onboardingDone;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final done = await ResearchJourneyService.instance.hasCompletedOnboarding();
    if (!mounted) return;
    setState(() {
      _onboardingDone = done;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1A237E)),
        ),
      );
    }

    if (_onboardingDone != true) {
      return ResearchJourneyOnboardingScreen(
        onFinished: () => setState(() => _onboardingDone = true),
      );
    }

    return HomeScreen(onSwitchPortal: widget.onSwitchPortal);
  }
}
