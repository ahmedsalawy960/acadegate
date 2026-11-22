import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/theme/acadegate_theme.dart';
import '../academic/academic_content_service.dart';
import '../academic/academic_models.dart';
import 'research_file.dart';

/// Thesis file summary on the progress screen: title, aim, chapters, and
/// the supervisor link the assistant and the supervisor both read.
class ResearchFileCard extends StatelessWidget {
  const ResearchFileCard({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ResearchFile?>(
      stream: ResearchFileService.instance.watchMine(),
      builder: (context, snap) {
        final file = snap.data;
        return Card(
          color: AcadeGateColors.card,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('ملف الرسالة', 'Thesis file'),
                  style: const TextStyle(
                    color: AcadeGateColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t(
                    'يقرأه المساعد واستوديو الرسالة والمشرف المرتبط.',
                    'Read by the assistant, Thesis Studio, and the linked supervisor.',
                  ),
                  style: const TextStyle(color: AcadeGateColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  file == null || file.title.trim().isEmpty
                      ? context.t('العنوان غير محدد بعد', 'Title not set yet')
                      : file.title,
                  style: const TextStyle(
                    color: AcadeGateColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (file != null && file.aim.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    file.aim,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AcadeGateColors.muted),
                  ),
                ],
                if (file != null && file.chapters.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.t(
                      '${file.chapters.length} فصول في الخطة',
                      '${file.chapters.length} chapters in the plan',
                    ),
                    style: const TextStyle(color: AcadeGateColors.text, fontSize: 13),
                  ),
                ],
                if (file != null && file.supervisorName.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.t(
                      'المشرف: ${file.supervisorName}',
                      'Supervisor: ${file.supervisorName}',
                    ),
                    style: const TextStyle(color: AcadeGateColors.gold, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _edit(context, file),
                      child: Text(context.t('العنوان والهدف', 'Title and aim')),
                    ),
                    OutlinedButton(
                      onPressed: () => _link(context),
                      child: Text(context.t('ربط مشرف', 'Link a supervisor')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, ResearchFile? file) async {
    final title = TextEditingController(text: file?.title ?? '');
    final aim = TextEditingController(text: file?.aim ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('ملف الرسالة', 'Thesis file')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: InputDecoration(labelText: context.t('العنوان', 'Title')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: aim,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(labelText: context.t('الهدف', 'Aim')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('حفظ', 'Save')),
          ),
        ],
      ),
    );
    if (saved != true) {
      title.dispose();
      aim.dispose();
      return;
    }
    await ResearchFileService.instance.upsert(
      title: title.text,
      aim: aim.text,
      field: file?.field ?? '',
      questions: file?.questions ?? const [],
      chapters: file?.chapters ?? const [],
    );
    title.dispose();
    aim.dispose();
  }

  Future<void> _link(BuildContext context) async {
    final query = TextEditingController();
    List<AcademicSupervisor> results = const [];
    var searching = false;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(context.t('ربط مشرف', 'Link a supervisor')),
          content: SizedBox(
            width: 420,
            height: 360,
            child: Column(
              children: [
                TextField(
                  controller: query,
                  decoration: InputDecoration(
                    labelText: context.t('اسم المشرف أو تخصصه', 'Supervisor name or specialty'),
                  ),
                  onSubmitted: (_) async {
                    setLocal(() => searching = true);
                    final found = await AcademicContentService.instance.searchSupervisors(
                      query: query.text,
                      limit: 8,
                    );
                    setLocal(() {
                      results = found;
                      searching = false;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: searching
                        ? null
                        : () async {
                            setLocal(() => searching = true);
                            final found = await AcademicContentService.instance.searchSupervisors(
                              query: query.text,
                              limit: 8,
                            );
                            setLocal(() {
                              results = found;
                              searching = false;
                            });
                          },
                    child: Text(context.t('بحث', 'Search')),
                  ),
                ),
                if (searching) const LinearProgressIndicator(),
                Expanded(
                  child: ListView(
                    children: [
                      for (final supervisor in results)
                        ListTile(
                          title: Text(supervisor.name),
                          subtitle: Text(
                            supervisor.ownerId.trim().isEmpty
                                ? context.t(
                                    'ليس له حساب على المنصة بعد',
                                    'No platform account yet',
                                  )
                                : supervisor.speciality,
                          ),
                          onTap: () async {
                            if (supervisor.ownerId.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(context.t(
                                    'هذا المشرف بلا حساب، فلا يستطيع فتح الملف.',
                                    'This supervisor has no account, so they cannot open the file.',
                                  )),
                                ),
                              );
                              return;
                            }
                            await ResearchFileService.instance.linkSupervisor(
                              supervisorUid: supervisor.ownerId,
                              supervisorName: supervisor.name,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.t('إغلاق', 'Close')),
            ),
          ],
        ),
      ),
    );
    query.dispose();
  }
}
