import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/theme/acadegate_theme.dart';
import 'research_file.dart';

/// Files students linked to the signed-in supervisor.
class SupervisorResearchFilesScreen extends StatelessWidget {
  const SupervisorResearchFilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('ملفات الرسائل', 'Thesis files')),
      ),
      body: StreamBuilder<List<ResearchFile>>(
        stream: ResearchFileService.instance.watchForSupervisor(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final files = snap.data ?? const [];
          if (files.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.t(
                    'لا توجد ملفات مرتبطة بحسابك. يربطك الطالب من شاشة تقدم الرسالة.',
                    'No files are linked to your account. A student links you from Thesis progress.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AcadeGateColors.muted),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: files.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final file = files[index];
              return Card(
                color: AcadeGateColors.card,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.studentName.trim().isEmpty
                            ? context.t('باحث', 'Researcher')
                            : file.studentName,
                        style: const TextStyle(color: AcadeGateColors.gold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        file.title.trim().isEmpty
                            ? context.t('بلا عنوان', 'Untitled')
                            : file.title,
                        style: const TextStyle(
                          color: AcadeGateColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (file.aim.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(file.aim, style: const TextStyle(color: AcadeGateColors.text)),
                      ],
                      if (file.questions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          file.questions.join('\n'),
                          style: const TextStyle(color: AcadeGateColors.muted),
                        ),
                      ],
                      if (file.chapters.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          file.chapters.join(' · '),
                          style: const TextStyle(color: AcadeGateColors.muted, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
