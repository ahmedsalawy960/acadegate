import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../community/community_starter_content.dart';
import 'admin_access_gate.dart';

/// Admin-only screen that publishes the official starter posts and circles.
class AdminCommunityStarterScreen extends StatefulWidget {
  const AdminCommunityStarterScreen({super.key});

  @override
  State<AdminCommunityStarterScreen> createState() =>
      _AdminCommunityStarterScreenState();
}

class _AdminCommunityStarterScreenState
    extends State<AdminCommunityStarterScreen> {
  bool _running = false;
  String? _message;
  bool _failed = false;

  Future<void> _run() async {
    if (_running) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.t('نشر المحتوى الأولي؟', 'Publish starter content?'),
        ),
        content: Text(
          context.t(
            'سيُنشر ${kStarterPosts.length} منشورات رسمية (معتمدة فوراً) و${kStarterCircles.length} دوائر دراسة. لن يتكرر أي عنصر لو نُشر من قبل.',
            'This publishes ${kStarterPosts.length} official posts (approved right away) and ${kStarterCircles.length} study circles. Nothing is duplicated if it was published before.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.t('نشر', 'Publish')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _running = true;
      _message = null;
      _failed = false;
    });
    try {
      final r = await CommunityStarterSeeder.instance.seed();
      if (!mounted) return;
      setState(() {
        _message = context.t(
          'تم: ${r.postsApproved} منشورات معتمدة، ${r.circlesCreated} دوائر جديدة. تم تخطي ${r.postsSkipped} منشورات و${r.circlesSkipped} دوائر موجودة من قبل.',
          'Done: ${r.postsApproved} posts approved, ${r.circlesCreated} new circles. Skipped ${r.postsSkipped} posts and ${r.circlesSkipped} circles that already existed.',
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _message = context.t(
          'تعذر النشر: $e. يمكنك المحاولة مرة أخرى بأمان.',
          'Could not publish: $e. It is safe to try again.',
        );
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminAccessGate(
      child: Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(
            context.t('محتوى المجتمع الأولي', 'Community starter content'),
          ),
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              context.t(
                'منشورات رسمية بالعربية والإنجليزية تظهر في كل غرف الكليات، ودائرتا دراسة.',
                'Official Arabic and English posts that appear in every faculty room, plus two study circles.',
              ),
            ),
            const SizedBox(height: 12),
            for (final p in kStarterPosts)
              ListTile(
                dense: true,
                leading: const Icon(Icons.article_outlined),
                title: Text(context.t(p.titleAr, p.titleEn)),
              ),
            for (final c in kStarterCircles)
              ListTile(
                dense: true,
                leading: const Icon(Icons.groups_outlined),
                title: Text(context.t(c.titleAr, c.titleEn)),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _running ? null : _run,
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish_outlined),
              label: Text(
                context.t('نشر المحتوى الأولي', 'Publish starter content'),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(
                  color: _failed ? Colors.red.shade800 : Colors.green.shade800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
