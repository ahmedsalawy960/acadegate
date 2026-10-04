import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'user_account_service.dart';
import 'user_role.dart';

/// Shown when Auth login still exists but the Firestore profile was deleted.
class RoleSetupScreen extends StatefulWidget {
  const RoleSetupScreen({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  State<RoleSetupScreen> createState() => _RoleSetupScreenState();
}

class _RoleSetupScreenState extends State<RoleSetupScreen> {
  String _role = UserRole.student;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await UserAccountService.instance.completeRoleSetup(_role);
      if (!mounted) return;
      widget.onCompleted();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red[800]),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('إعداد الحساب', 'Account setup')),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.t(
              'تمت إعادة إنشاء ملفك. اختر دورك من جديد كما في التسجيل لأول مرة.',
              'Your profile was recreated. Choose your role again as in first-time registration.',
            ),
            style: const TextStyle(height: 1.4, color: Color(0xFFB7C3D6)),
          ),
          const SizedBox(height: 16),
          ...UserRole.all.map(
            (role) => RadioListTile<String>(
              value: role,
              groupValue: _role,
              title: Text(UserRole.label(role)),
              onChanged: _saving
                  ? null
                  : (v) {
                      if (v != null) setState(() => _role = v);
                    },
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(context.t('متابعة', 'Continue')),
          ),
        ],
      ),
    );
  }
}
