import 'package:flutter/material.dart';
import '../../core/locale/locale_extensions.dart';
import '../../core/locale/locale_service.dart';
import 'language_selection_screen.dart';

/// Lets the user switch language before signing in.
class LanguageSwitcherButton extends StatelessWidget {
  const LanguageSwitcherButton({super.key});

  Future<void> _openPicker(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LanguageSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isAr = LocaleService.instance.isArabic;

    return TextButton.icon(
      onPressed: () => _openPicker(context),
      icon: const Icon(Icons.translate, size: 18),
      label: Text(isAr ? 'English' : l10n.languageArabic),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF1A237E),
      ),
    );
  }
}
