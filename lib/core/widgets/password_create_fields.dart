import 'package:flutter/material.dart';

import '../auth/password_strength.dart';
import '../locale/locale_extensions.dart';
import '../theme/acadegate_theme.dart';

/// خانة كلمة المرور وتأكيدها، وتحتها أربعة شروط تخضر عند تحققها.
class PasswordCreateFields extends StatefulWidget {
  const PasswordCreateFields({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  State<PasswordCreateFields> createState() => _PasswordCreateFieldsState();
}

class _PasswordCreateFieldsState extends State<PasswordCreateFields> {
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _confirmController.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _confirmController.removeListener(_onChanged);
    _confirmController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final strength = PasswordStrength(widget.controller.text);
    final rules = <(bool, String)>[
      (
        strength.longEnough,
        context.t('8 أحرف على الأقل', 'At least 8 characters'),
      ),
      (
        strength.hasCapital,
        context.t('حرف كبير (A-Z)', 'A capital letter (A-Z)'),
      ),
      (
        strength.hasLetterAndNumber,
        context.t('حرف ورقم', 'A letter and a number'),
      ),
      (
        strength.hasSymbol,
        context.t('الرموز = قوة إضافية', 'Symbols add extra strength'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: context.t('كلمة المرور', 'Password'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: IconButton(
              tooltip: _obscure
                  ? context.t('إظهار كلمة المرور', 'Show password')
                  : context.t('إخفاء كلمة المرور', 'Hide password'),
              onPressed: widget.enabled
                  ? () => setState(() => _obscure = !_obscure)
                  : null,
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: (value) {
            final text = value ?? '';
            if (text.isEmpty) {
              return context.t('كلمة المرور مطلوبة', 'Password is required');
            }
            if (PasswordStrength(text).isWeak || text.length < 4) {
              return context.t('كلمة المرور ضعيفة', 'Password is weak');
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirmController,
          enabled: widget.enabled,
          obscureText: _obscureConfirm,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: context.t('تأكيد كلمة المرور', 'Confirm password'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: IconButton(
              tooltip: _obscureConfirm
                  ? context.t('إظهار كلمة المرور', 'Show password')
                  : context.t('إخفاء كلمة المرور', 'Hide password'),
              onPressed: widget.enabled
                  ? () => setState(() => _obscureConfirm = !_obscureConfirm)
                  : null,
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: (value) {
            if ((value ?? '').isEmpty) {
              return context.t('أكد كلمة المرور', 'Confirm the password');
            }
            if (value != widget.controller.text) {
              return context.t(
                'كلمتا المرور غير متطابقتين',
                'The two passwords do not match',
              );
            }
            return null;
          },
        ),
        if (strength.isWeak) ...[
          const SizedBox(height: 8),
          Text(
            context.t('كلمة المرور ضعيفة', 'Password is weak'),
            style: const TextStyle(
              color: Color(0xFFFBBF24),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 8),
        for (final rule in rules)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  rule.$1 ? Icons.check_circle : Icons.circle_outlined,
                  size: 18,
                  color: rule.$1
                      ? const Color(0xFF34D399)
                      : AcadeGateColors.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rule.$2,
                    style: TextStyle(
                      color: rule.$1
                          ? const Color(0xFF34D399)
                          : AcadeGateColors.muted,
                      fontWeight: rule.$1 ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
