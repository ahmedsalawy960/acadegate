import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'section_guide_catalog.dart';
import 'section_guide_models.dart';

/// شاشة دليل تفصيلي خطوة بخطوة.
class SectionGuideScreen extends StatelessWidget {
  final String guideId;
  final Color accent;

  const SectionGuideScreen({
    super.key,
    required this.guideId,
    this.accent = const Color(0xFF1A237E),
  });

  @override
  Widget build(BuildContext context) {
    final guide = SectionGuideCatalog.byId(guideId);
    final en = Localizations.localeOf(context).languageCode == 'en';

    if (guide == null) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('الدليل', 'Guide')),
          backgroundColor: accent,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(context.t('الدليل غير متاح', 'Guide unavailable')),
        ),
      );
    }

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(guide.title(en)),
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Card(
            color: accent.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('قبل أن تبدأ', 'Before you start'),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    guide.intro(en),
                    style: const TextStyle(height: 1.55, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.t('الخطوات بالتفصيل', 'Detailed steps'),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: accent,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < guide.steps.length; i++)
            _StepCard(
              index: i + 1,
              step: guide.steps[i],
              accent: accent,
              english: en,
            ),
          if (guide.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              context.t('ملاحظات مهمة', 'Important notes'),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: accent,
              ),
            ),
            const SizedBox(height: 8),
            for (final note in guide.notes)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(Icons.info_outline, color: accent),
                  title: Text(
                    note.title(en),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      note.body(en),
                      style: const TextStyle(height: 1.45),
                    ),
                  ),
                  isThreeLine: true,
                ),
              ),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(context.t('فهمت — ابدأ الاستخدام', 'Got it — start using')),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int index;
  final SectionGuideStep step;
  final Color accent;
  final bool english;

  const _StepCard({
    required this.index,
    required this.step,
    required this.accent,
    required this.english,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: accent.withValues(alpha: 0.15),
              child: Text(
                '$index',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(step.icon, size: 18, color: accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          step.title(english),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step.body(english),
                    style: TextStyle(
                      height: 1.55,
                      fontSize: 13.5,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// زر دليل في شريط التطبيق.
class SectionGuideAppBarButton extends StatelessWidget {
  final String guideId;
  final Color accent;

  const SectionGuideAppBarButton({
    super.key,
    required this.guideId,
    this.accent = const Color(0xFF1A237E),
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.t('دليل القسم', 'Section guide'),
      icon: const Icon(Icons.help_outline),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SectionGuideScreen(
              guideId: guideId,
              accent: accent,
            ),
          ),
        );
      },
    );
  }
}

/// شريط أعلى القسم يدعو المبتدئ لفتح الدليل.
class SectionGuideBanner extends StatelessWidget {
  final String guideId;
  final Color accent;

  const SectionGuideBanner({
    super.key,
    required this.guideId,
    this.accent = const Color(0xFF1A237E),
  });

  @override
  Widget build(BuildContext context) {
    final guide = SectionGuideCatalog.byId(guideId);
    if (guide == null) return const SizedBox.shrink();
    final en = Localizations.localeOf(context).languageCode == 'en';

    return Material(
      color: accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SectionGuideScreen(
                guideId: guideId,
                accent: accent,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.menu_book_outlined, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(
                        'جديد هنا؟ اقرأ الدليل الكامل',
                        'New here? Read the full guide',
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: accent,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      en
                          ? 'Step-by-step: ${guide.titleEn}'
                          : 'خطوة بخطوة: ${guide.titleAr}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
