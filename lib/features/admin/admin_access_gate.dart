import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/widgets/acadegate_app_bar.dart';
import '../auth/user_account_service.dart';

/// Blocks non-admin users from admin UI surfaces (rules remain source of truth).
/// In debug only, offers optional [UserAccountService.tryClaimDevAdmin] when
/// Firestore `config/app.allowBootstrap == true`.
class AdminAccessGate extends StatelessWidget {
  const AdminAccessGate({super.key, required this.child});

  final Widget child;

  static const _brand = Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: UserAccountService.instance.watchCurrentAccount(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: _brand),
            ),
          );
        }

        final isAdmin = snapshot.data?.isAdmin == true;
        if (!isAdmin) {
          return Scaffold(
            appBar: AcadeGateAppBar(
              title: Text(context.t('غير مصرح', 'Not authorized')),
              backgroundColor: _brand,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.t(
                        'هذه الصفحة للمشرفين فقط.',
                        'This page is for administrators only.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 20),
                      _DebugClaimAdminButton(),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        return child;
      },
    );
  }
}

class _DebugClaimAdminButton extends StatefulWidget {
  @override
  State<_DebugClaimAdminButton> createState() => _DebugClaimAdminButtonState();
}

class _DebugClaimAdminButtonState extends State<_DebugClaimAdminButton> {
  bool _claiming = false;

  Future<void> _claim() async {
    setState(() => _claiming = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await UserAccountService.instance.tryClaimDevAdmin();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? context.t(
                    'تم تفعيل صلاحية المدير',
                    'Admin access enabled',
                  )
                : context.t(
                    'فعّل allowBootstrap في Firebase: config/app (Debug فقط)',
                    'Enable allowBootstrap in Firebase: config/app (debug only)',
                  ),
          ),
          backgroundColor: ok ? null : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _claiming ? null : _claim,
      icon: _claiming
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.admin_panel_settings_outlined),
      label: Text(
        context.t(
          'تفعيل المدير (Debug + allowBootstrap)',
          'Claim admin (Debug + allowBootstrap)',
        ),
      ),
    );
  }
}
