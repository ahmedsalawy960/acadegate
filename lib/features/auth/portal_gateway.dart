import 'package:flutter/material.dart';
import 'portal_selection_screen.dart';
import 'portal_service.dart';
import 'portal_type.dart';
import 'role_setup_screen.dart';
import 'user_account_service.dart';
import 'user_role.dart';
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
  String? _role;
  bool _loading = true;
  bool _needsRoleSetup = false;

  @override
  void initState() {
    super.initState();
    _loadPortal();
  }

  Future<void> _loadPortal() async {
    final account = await UserAccountService.instance.loadCurrentAccount();
    if (!mounted) return;

    if (account?.needsRoleSetup == true) {
      setState(() {
        _needsRoleSetup = true;
        _loading = false;
        _portal = null;
        _role = account?.role;
      });
      return;
    }

    var portal = await PortalService.instance.getActivePortal();

    // Students must stay on the researcher/user portal.
    final role = account?.role ?? '';
    if (role == UserRole.student && PortalType.isProvider(portal)) {
      await PortalService.instance.setActivePortal(PortalType.user);
      portal = PortalType.user;
    }

    if (!mounted) return;
    setState(() {
      _needsRoleSetup = false;
      _portal = portal;
      _role = role.isEmpty ? null : role;
      _loading = false;
    });
  }

  Future<void> _onPortalSelected(String portal) async {
    final account = await UserAccountService.instance.loadCurrentAccount();
    if (account?.role == UserRole.student &&
        PortalType.isProvider(portal)) {
      portal = PortalType.user;
    }
    await PortalService.instance.setActivePortal(portal);
    if (!mounted) return;
    setState(() {
      _portal = portal;
      _role = account?.role;
    });
  }

  Future<void> _openPortalSelection() async {
    await PortalService.instance.clearActivePortal();
    if (!mounted) return;
    setState(() => _portal = null);
  }

  Future<void> _enterProviderPortal() async {
    await PortalService.instance.setActivePortal(PortalType.provider);
    final account = await UserAccountService.instance.loadCurrentAccount();
    if (!mounted) return;
    setState(() {
      _portal = PortalType.provider;
      _role = account?.role;
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

    if (_needsRoleSetup) {
      return RoleSetupScreen(onCompleted: _loadPortal);
    }

    if (_portal == null) {
      return PortalSelectionScreen(onSelect: _onPortalSelected);
    }

    final onSwitch =
        PortalType.canUseProviderPortal(_role) ? _openPortalSelection : null;

    if (PortalType.isProvider(_portal)) {
      return ProviderHomeScreen(onSwitchPortal: onSwitch);
    }

    return UserPortalShell(
      onSwitchPortal: onSwitch,
      onBecameProvider: _enterProviderPortal,
    );
  }
}
