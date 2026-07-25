import 'package:flutter/material.dart';
import '../../core/locale/locale_extensions.dart';

/// زر تبديل البوابة من شريط التطبيق.
class PortalSwitchButton extends StatelessWidget {
  final VoidCallback onSwitchPortal;
  final String? tooltip;

  const PortalSwitchButton({
    super.key,
    required this.onSwitchPortal,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return IconButton(
      tooltip: tooltip ?? l10n.switchPortalTitle,
      icon: const Icon(Icons.swap_horiz),
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.switchPortalTitle),
            content: Text(l10n.switchPortalMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.switchPortalConfirm),
              ),
            ],
          ),
        );
        if (confirm == true) onSwitchPortal();
      },
    );
  }
}
