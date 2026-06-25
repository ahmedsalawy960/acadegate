import 'package:flutter/material.dart';

/// زر تبديل البوابة من شريط التطبيق.
class PortalSwitchButton extends StatelessWidget {
  final VoidCallback onSwitchPortal;
  final String tooltip;

  const PortalSwitchButton({
    super.key,
    required this.onSwitchPortal,
    this.tooltip = 'تبديل البوابة',
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(Icons.swap_horiz),
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تبديل البوابة'),
            content: const Text(
              'هل تريد العودة لشاشة اختيار البوابة؟\n'
              'يمكنك التبديل بين مقدم الخدمة والمستخدم في أي وقت.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تبديل'),
              ),
            ],
          ),
        );
        if (confirm == true) onSwitchPortal();
      },
    );
  }
}
