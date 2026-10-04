import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import 'bug_report_service.dart';

/// Bottom sheet for researchers and providers to report a problem.
Future<void> showReportProblemSheet(
  BuildContext context, {
  required String portal,
  String? screen,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ReportProblemSheet(
      portal: portal,
      screen: screen,
    ),
  );
}

class _ReportProblemSheet extends StatefulWidget {
  final String portal;
  final String? screen;

  const _ReportProblemSheet({
    required this.portal,
    this.screen,
  });

  @override
  State<_ReportProblemSheet> createState() => _ReportProblemSheetState();
}

class _ReportProblemSheetState extends State<_ReportProblemSheet> {
  final _controller = TextEditingController();
  String _category = 'other';
  bool _sending = false;

  static const _categories = <(String, String, String)>[
    ('crash', 'توقف / تعطل', 'Crash / freeze'),
    ('ui', 'واجهة / عرض', 'UI / display'),
    ('auth', 'دخول / حساب', 'Login / account'),
    ('search', 'بحث / مطابقة', 'Search / matching'),
    ('store', 'متجر / طلبات', 'Store / orders'),
    ('booking', 'حجز مختبر', 'Lab booking'),
    ('payment', 'دفع / اشتراك', 'Payment'),
    ('claim', 'مطالبة ملف', 'Profile claim'),
    ('other', 'أخرى', 'Other'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await BugReportService.instance.submitUserReport(
        description: _controller.text,
        category: _category,
        portal: widget.portal,
        screen: widget.screen,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'شكراً — وصل بلاغك للإدارة',
              'Thanks — your report reached admins',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Bad state: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t('بلّغ عن مشكلة', 'Report a problem'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFF4F7FB),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t(
              'صف ما حدث وما كنت تحاول فعله. نسجّل أيضاً أخطاء التطبيق تلقائياً.',
              'Describe what happened and what you were trying to do. App crashes are also logged automatically.',
            ),
            style: TextStyle(color: const Color(0xFFB7C3D6), fontSize: 13),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _category,
            decoration: InputDecoration(
              labelText: context.t('التصنيف', 'Category'),
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final c in _categories)
                DropdownMenuItem(
                  value: c.$1,
                  child: Text(isAr ? c.$2 : c.$3),
                ),
            ],
            onChanged: _sending
                ? null
                : (v) {
                    if (v != null) setState(() => _category = v);
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            enabled: !_sending,
            maxLines: 5,
            maxLength: 4000,
            decoration: InputDecoration(
              labelText: context.t('التفاصيل', 'Details'),
              hintText: context.t(
                'مثال: ضغطت حجز مختبر فظهرت شاشة بيضاء…',
                'e.g. I tapped book lab and got a blank screen…',
              ),
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.bug_report_outlined),
            label: Text(context.t('إرسال البلاغ', 'Submit report')),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Compact app-bar action for both portals.
class ReportProblemIconButton extends StatelessWidget {
  final String portal;

  const ReportProblemIconButton({super.key, required this.portal});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.t('بلّغ عن مشكلة', 'Report a problem'),
      icon: const Icon(Icons.bug_report_outlined),
      onPressed: () => showReportProblemSheet(context, portal: portal),
    );
  }
}
