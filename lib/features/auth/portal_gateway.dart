import 'package:flutter/material.dart';
import 'portal_selection_screen.dart';
import 'portal_service.dart';
import 'portal_type.dart';
import '../home/provider_home_screen.dart';
import '../research_journey/user_portal_shell.dart';

/// يوجّه المستخدم إلى شاشة اختيار البوابة أو البوابة المناسبة.
class PortalGateway extends StatefulWidget {
  const PortalGateway({super.key});

  @override
  State<PortalGateway> createState() => _PortalGatewayState();
}

class _PortalGatewayState extends State<PortalGateway> {
  String? _portal;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPortal();
  }

  Future<void> _loadPortal() async {
    final portal = await PortalService.instance.getActivePortal();
    if (!mounted) return;
    setState(() {
      _portal = portal;
      _loading = false;
    });
  }

  Future<void> _onPortalSelected(String portal) async {
    await PortalService.instance.setActivePortal(portal);
    if (!mounted) return;
    setState(() => _portal = portal);
  }

  Future<void> _openPortalSelection() async {
    await PortalService.instance.clearActivePortal();
    if (!mounted) return;
    setState(() => _portal = null);
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

    if (_portal == null) {
      return PortalSelectionScreen(onSelect: _onPortalSelected);
    }

    if (PortalType.isProvider(_portal)) {
      return ProviderHomeScreen(onSwitchPortal: _openPortalSelection);
    }

    return UserPortalShell(onSwitchPortal: _openPortalSelection);
  }
}
