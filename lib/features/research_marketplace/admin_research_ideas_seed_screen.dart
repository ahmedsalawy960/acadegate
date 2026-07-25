import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../academic/faculty_categories.dart';
import '../auth/user_account_service.dart';
import 'research_ideas_seed_service.dart';
import 'seed/egypt_research_ideas_seed.dart';

/// ينشر 90 فكرة كاملة (5 لكل كلية) باسم الحساب الحالي.
class AdminResearchIdeasSeedScreen extends StatefulWidget {
  const AdminResearchIdeasSeedScreen({super.key});

  @override
  State<AdminResearchIdeasSeedScreen> createState() =>
      _AdminResearchIdeasSeedScreenState();
}

class _AdminResearchIdeasSeedScreenState
    extends State<AdminResearchIdeasSeedScreen> {
  bool _publishing = false;
  int _done = 0;
  int _total = egyptResearchIdeasSeed.length;
  String? _lastMessage;

  Future<void> _publish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('نشر حزمة الأفكار', 'Publish ideas pack')),
        content: Text(
          context.t(
            'سيتم نشر ${egyptResearchIdeasSeed.length} فكرة بحثية كاملة '
            '(5 لكل كلية) باسم حسابك الحالي. الأفكار المكررة تُتخطى.',
            'This will publish ${egyptResearchIdeasSeed.length} full research ideas '
            '(5 per faculty) under your current account. Duplicates are skipped.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('نشر', 'Publish')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _publishing = true;
      _done = 0;
      _lastMessage = null;
    });

    try {
      final result = await ResearchIdeasSeedService.instance.publishPack(
        autoApprove: true,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _done = done;
            _total = total;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _lastMessage = context.t(
          'تم: ${result.imported} جديدة · ${result.skipped} مكررة من ${result.total}',
          'Done: ${result.imported} new · ${result.skipped} skipped of ${result.total}',
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_lastMessage!)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final byFaculty = <String, int>{};
    for (final idea in egyptResearchIdeasSeed) {
      byFaculty[idea.category] = (byFaculty[idea.category] ?? 0) + 1;
    }

    return StreamBuilder(
      stream: UserAccountService.instance.watchCurrentAccount(),
      builder: (context, snap) {
        final isAdmin = snap.data?.isAdmin == true;
        return Scaffold(
          appBar: AcadeGateAppBar(
            title: Text(context.t(
              'حزمة أفكار بحثية',
              'Research ideas pack',
            )),
            backgroundColor: Colors.orange[800],
            foregroundColor: Colors.white,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Colors.orange.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t(
                          '${egyptResearchIdeasSeed.length} فكرة كاملة — 5 لكل كلية',
                          '${egyptResearchIdeasSeed.length} full ideas — 5 per faculty',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.t(
                          'أفكار مكتملة (مشكلة، فجوة 2024–2026، أهداف، منهج، مخرجات) '
                          'وتُنشر باسمك كناشر. المدير يعتمدها مباشرة.',
                          'Complete ideas (problem, 2024–2026 gap, goals, method, outcomes) '
                          'published under your account. Admins auto-approve.',
                        ),
                        style: TextStyle(color: Colors.grey[800], height: 1.4),
                      ),
                      if (!isAdmin) ...[
                        const SizedBox(height: 8),
                        Text(
                          context.t(
                            'لست مديراً: الأفكار ستُرسل للمراجعة قبل الظهور.',
                            'Not admin: ideas will be pending until approved.',
                          ),
                          style: TextStyle(color: Colors.orange[900]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.t('التوزيع حسب الكلية', 'Per faculty'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...facultyCategories.map((f) {
                final n = byFaculty[f.id] ?? 0;
                return ListTile(
                  dense: true,
                  leading: Icon(f.icon, color: f.color),
                  title: Text(f.titleAr),
                  trailing: Text('$n'),
                );
              }),
              const SizedBox(height: 16),
              if (_publishing) ...[
                LinearProgressIndicator(
                  value: _total == 0 ? null : _done / _total,
                ),
                const SizedBox(height: 8),
                Text(context.t(
                  'جاري النشر $_done / $_total',
                  'Publishing $_done / $_total',
                )),
                const SizedBox(height: 12),
              ],
              if (_lastMessage != null) ...[
                Text(_lastMessage!, style: TextStyle(color: Colors.green[800])),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: _publishing ? null : _publish,
                icon: const Icon(Icons.publish_outlined),
                label: Text(context.t(
                  'نشر الحزمة باسمي',
                  'Publish pack as me',
                )),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
