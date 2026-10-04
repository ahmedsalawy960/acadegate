import 'package:flutter/material.dart';

import '../home/home_screen.dart';
import 'research_journey_onboarding_screen.dart';
import 'research_journey_service.dart';

/// User portal entry: onboarding once, then home.
class UserPortalShell extends StatefulWidget {
  final VoidCallback? onSwitchPortal;
  final VoidCallback? onBecameProvider;

  const UserPortalShell({
    super.key,
    this.onSwitchPortal,
    this.onBecameProvider,
  });

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
          child: CircularProgressIndicator(color: Color(0xFFF4F7FB)),
        ),
      );
    }

    if (_onboardingDone != true) {
      return ResearchJourneyOnboardingScreen(
        onFinished: () => setState(() => _onboardingDone = true),
        onBecameProvider: widget.onBecameProvider,
      );
    }

    return HomeScreen(onSwitchPortal: widget.onSwitchPortal);
  }
}
