import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../humanities/humanities_faculties.dart';
import '../humanities/humanities_prefs.dart';
import '../methodology_integrity/methodology_integrity_screen.dart';
import 'research_tools_branding.dart';
import 'research_tools_storage.dart';
import 'survey_models.dart';

/// منشئ استبانة متعدد الأبعاد مع حفظ محلي وتصدير نص للمنهجية.
class SurveyBuilderScreen extends StatefulWidget {
  const SurveyBuilderScreen({super.key});

  @override
  State<SurveyBuilderScreen> createState() => _SurveyBuilderScreenState();
}

class _SurveyBuilderScreenState extends State<SurveyBuilderScreen> {
  static const _brand = Color(ResearchToolsBranding.brand);

  SurveyInstrument? _instrument;
  bool _loading = true;
  HumanitiesTrack _track = HumanitiesTrack.education;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final savedTrack = await HumanitiesPrefs.loadTrack();
    final saved = await ResearchToolsStorage.instance.loadInstrument();
    if (!mounted) return;
    setState(() {
      _track = savedTrack ?? HumanitiesTrack.education;
      _instrument = saved ?? SurveyInstrument.templateForTrack(_track.id);
      _loading = false;
    });
  }

  Future<void> _save() async {
    final inst = _instrument;
    if (inst == null) return;
    await ResearchToolsStorage.instance.saveInstrument(inst);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('تم حفظ الأداة', 'Instrument saved')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _newFromTemplate() {
    setState(() {
      _instrument = SurveyInstrument.templateForTrack(_track.id);
    });
  }

  void _addDimension() {
    final inst = _instrument;
    if (inst == null) return;
    setState(() {
      inst.dimensions.add(
        SurveyDimension(
          id: 'd_${DateTime.now().microsecondsSinceEpoch}',
          titleAr: 'بُعد جديد',
          titleEn: 'New dimension',
        ),
      );
    });
  }

  void _addItem(SurveyDimension dim) {
    setState(() {
      dim.items.add(
        SurveyItem(
          id: 'i_${DateTime.now().microsecondsSinceEpoch}',
          textAr: 'بند جديد',
          textEn: 'New item',
        ),
      );
    });
  }

  Future<void> _copySummary() async {
    final inst = _instrument;
    if (inst == null) return;
    await Clipboard.setData(ClipboardData(text: inst.summaryForMethodology()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t(
            'نُسخ ملخص الأداة — الصقه في كاشف المنهجية',
            'Instrument summary copied — paste into methodology check',
          ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _instrument == null) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('منشئ الاستبانة', 'Survey builder')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final inst = _instrument!;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('منشئ الاستبانة', 'Survey builder')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: context.t('حفظ', 'Save'),
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        onPressed: _addDimension,
        icon: const Icon(Icons.add),
        label: Text(context.t('بُعد', 'Dimension')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          Text(
            context.t('مسار القالب', 'Template track'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in HumanitiesTrack.values)
                ChoiceChip(
                  label: Text(context.t(t.titleAr(), t.titleEn())),
                  selected: _track == t,
                  selectedColor: _brand.withValues(alpha: 0.18),
                  onSelected: (_) {
                    setState(() {
                      _track = t;
                      inst.trackId = t.id;
                    });
                  },
                ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: _newFromTemplate,
              child: Text(
                context.t('تحميل قالب لهذا المسار', 'Load template for this track'),
              ),
            ),
          ),
          TextField(
            controller: TextEditingController(text: inst.titleAr),
            decoration: InputDecoration(
              labelText: context.t('عنوان الأداة', 'Instrument title'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => inst.titleAr = v,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: TextEditingController(text: inst.researchQuestion),
            decoration: InputDecoration(
              labelText: context.t('سؤال البحث', 'Research question'),
              border: const OutlineInputBorder(),
            ),
            maxLines: 2,
            onChanged: (v) => inst.researchQuestion = v,
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
              '${inst.dimensions.length} أبعاد · ${inst.itemCount} بنود',
              '${inst.dimensions.length} dimensions · ${inst.itemCount} items',
            ),
            style: TextStyle(color: const Color(0xFFB7C3D6)),
          ),
          const SizedBox(height: 12),
          ...inst.dimensions.asMap().entries.map((entry) {
            final di = entry.key;
            final dim = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(text: dim.titleAr),
                            decoration: InputDecoration(
                              labelText: context.t(
                                'اسم البُعد ${di + 1}',
                                'Dimension ${di + 1} name',
                              ),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (v) => dim.titleAr = v,
                          ),
                        ),
                        IconButton(
                          tooltip: context.t('حذف البُعد', 'Delete dimension'),
                          onPressed: () {
                            setState(() => inst.dimensions.removeAt(di));
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...dim.items.asMap().entries.map((ie) {
                      final ii = ie.key;
                      final item = ie.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          children: [
                            TextField(
                              controller:
                                  TextEditingController(text: item.textAr),
                              decoration: InputDecoration(
                                labelText: context.t(
                                  'البند ${ii + 1}',
                                  'Item ${ii + 1}',
                                ),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (v) => item.textAr = v,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<SurveyScaleType>(
                                    initialValue: item.scale,
                                    isDense: true,
                                    decoration: InputDecoration(
                                      labelText: context.t('المقياس', 'Scale'),
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: [
                                      for (final s in SurveyScaleType.values)
                                        DropdownMenuItem(
                                          value: s,
                                          child: Text(
                                            context.t(s.labelAr(), s.labelEn()),
                                          ),
                                        ),
                                    ],
                                    onChanged: (v) {
                                      if (v == null) return;
                                      setState(() => item.scale = v);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: Text(context.t('عكسي', 'Reversed')),
                                  selected: item.reversed,
                                  onSelected: (v) {
                                    setState(() => item.reversed = v);
                                  },
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() => dim.items.removeAt(ii));
                                  },
                                  icon: const Icon(Icons.close, size: 20),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () => _addItem(dim),
                      icon: const Icon(Icons.add),
                      label: Text(context.t('إضافة بند', 'Add item')),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await _save();
              await _copySummary();
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: Text(
              context.t(
                'حفظ ونسخ ملخص للمنهجية',
                'Save & copy methodology summary',
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _brand),
            onPressed: () async {
              await _save();
              await _copySummary();
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MethodologyIntegrityScreen(),
                ),
              );
            },
            icon: const Icon(Icons.policy_outlined),
            label: Text(
              context.t(
                'فتح كاشف المنهجية',
                'Open methodology check',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
