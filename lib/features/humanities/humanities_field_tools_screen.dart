import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/l10n_lookup.dart';
import '../../core/theme/acadegate_theme.dart';
import '../../core/locale/locale_extensions.dart';
import '../store/store_categories.dart';
import '../store/store_navigator.dart';

/// أدوات الميدان فقط — قائمة تحقق + أرشيف/كتب.
/// بناء الأدوات والتحليل يُفتحان من مراحل البوابة (بدون تكرار).
class HumanitiesFieldToolsScreen extends StatelessWidget {
  const HumanitiesFieldToolsScreen({super.key});

  static const _brand = Color(0xFF5D4037);

  static const _archiveCategoryIds = <String>[
    'humanities',
    'books',
    'office',
    'general',
  ];

  @override
  Widget build(BuildContext context) {
    final archiveCats = _archiveCategoryIds
        .map(storeCategoryById)
        .whereType<StoreCategory>()
        .toList(growable: false);

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('أدوات الميدان البحثي', 'Field research tools')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: _brand.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                context.t(
                  'هنا قائمة التحقق للميدان وأرشيف/كتب فقط.\n'
                  'بناء الاستبانة/المقابلة من مرحلة «استوديو الأدوات»، '
                  'والترميز بعد الجمع من مرحلة «التحليل النوعي» — من البوابة مباشرة.',
                  'Checklist and archive/books only.\n'
                  'Build survey/interview from the Research Tools stage, '
                  'and code after collection from Qualitative Analysis — via the portal.',
                ),
                style: const TextStyle(height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.t('قائمة تحقق للميدان', 'Fieldwork checklist'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 8),
          _CheckLine(
            text: context.t(
              'حدّد أداة الجمع: استبانة / مقابلة / ملاحظة / وثائق وأرشيف',
              'Pick the instrument: survey / interview / observation / documents & archive',
            ),
          ),
          _CheckLine(
            text: context.t(
              'صغ المحاور أو أسئلة المقابلة بما يطابق أسئلة البحث',
              'Align survey dimensions or interview questions with research questions',
            ),
          ),
          _CheckLine(
            text: context.t(
              'احصل على موافقة المشرف/الأخلاقيات قبل التطبيق الميداني',
              'Get supervisor/ethics approval before fieldwork',
            ),
          ),
          _CheckLine(
            text: context.t(
              'طبّق على عينة استطلاعية صغيرة ثم راجع الصياغة',
              'Pilot a small pilot sample, then revise wording',
            ),
          ),
          _CheckLine(
            text: context.t(
              'وثّق كيف جمعت البيانات (زمان، مكان، عدد، طريقة)',
              'Document how data were collected (time, place, n, method)',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.t(
              'أرشيف وكتب وخدمات مكتبية',
              'Archives, books & office services',
            ),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            context.t(
              'أقسام المتجر الخاصة بالبحث الإنساني — وليس المتجر كاملاً',
              'Humanities-relevant store sections — not the full marketplace',
            ),
            style: TextStyle(color: const Color(0xFFB7C3D6), height: 1.35),
          ),
          const SizedBox(height: 10),
          ...archiveCats.map(
            (cat) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cat.color.withValues(alpha: 0.12),
                    foregroundColor: acadegateInk(cat.color),
                    child: Icon(cat.icon),
                  ),
                  title: Text(
                    L10nLookup.storeCategoryTitle(cat.id),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    context.t(cat.audienceAr, cat.audienceEn),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    context.t('تصفح', 'Browse'),
                    style: TextStyle(
                      color: acadegateInk(cat.color),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () =>
                      StoreNavigator.openStoreCategory(context, cat.title),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: const Color(0xFFFFF8E1),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                context.t(
                  'لا تكرار هنا: أدوات البناء والتحليل تُفتح من مراحل البوابة فقط.',
                  'No duplication here: build and analysis tools open only from portal stages.',
                ),
                style: TextStyle(height: 1.45, color: Colors.grey[800]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  final String text;

  const _CheckLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 20, color: const Color(0xFFB7C3D6)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(height: 1.4, color: Color(0xFFF4F7FB)),
            ),
          ),
        ],
      ),
    );
  }
}
