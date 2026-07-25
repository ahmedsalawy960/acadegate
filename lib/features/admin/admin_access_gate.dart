import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/widgets/acadegate_app_bar.dart';
import '../auth/user_account_service.dart';

/// Blocks non-admin users from admin UI surfaces (rules remain source of truth).
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
                child: Text(
                  context.t(
                    'هذه الصفحة للمشرفين فقط.',
                    'This page is for administrators only.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
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
