import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'literary_instrument_models.dart';
import 'research_tools_branding.dart';
import 'research_tools_storage.dart';

class ContentAnalysisSheetScreen extends StatefulWidget {
  const ContentAnalysisSheetScreen({super.key});

  @override
  State<ContentAnalysisSheetScreen> createState() =>
      _ContentAnalysisSheetScreenState();
}

class _ContentAnalysisSheetScreenState extends State<ContentAnalysisSheetScreen> {
  static const _brand = Color(ResearchToolsBranding.brand);
  ContentAnalysisSheet? _sheet;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final saved = await ResearchToolsStorage.instance.loadContentSheet();
    if (!mounted) return;
    setState(() {
      _sheet = saved ?? ContentAnalysisSheet.template();
      _loading = false;
    });
  }

  Future<void> _save() async {
    final s = _sheet;
    if (s == null) return;
    await ResearchToolsStorage.instance.saveContentSheet(s);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('تم الحفظ', 'Saved')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _copy() async {
    final s = _sheet;
    if (s == null) return;
    await Clipboard.setData(ClipboardData(text: s.summary()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('نُسخت ورقة الترميز', 'Coding sheet copied')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _sheet == null) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('تحليل المضمون', 'Content analysis')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final s = _sheet!;
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('تحليل المضمون', 'Content analysis')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.save_outlined)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        onPressed: () {
          setState(() {
            s.codes.add(
              ContentCode(
                id: 'c_${DateTime.now().microsecondsSinceEpoch}',
                label: 'رمز جديد',
                definition: 'تعريف إجرائي',
              ),
            );
          });
        },
        icon: const Icon(Icons.add),
        label: Text(context.t('رمز', 'Code')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          Text(
            context.t(
              'للإعلام والآداب: عرّف وحدة التحليل والرموز قبل الترميز على المدونة.',
              'For media and arts: define the unit of analysis and codes before coding the corpus.',
            ),
            style: TextStyle(color: const Color(0xFFB7C3D6), height: 1.4),
          ),
          const SizedBox(height: 12),
          _tf(context.t('عنوان الورقة', 'Sheet title'), s.titleAr, (v) => s.titleAr = v),
          _tf(
            context.t('سؤال البحث', 'Research question'),
            s.researchQuestion,
            (v) => s.researchQuestion = v,
            maxLines: 2,
          ),
          _tf(
            context.t('وحدة التحليل', 'Unit of analysis'),
            s.unitOfAnalysis,
            (v) => s.unitOfAnalysis = v,
          ),
          _tf(
            context.t('وصف المدونة', 'Corpus description'),
            s.corpusDescription,
            (v) => s.corpusDescription = v,
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          ...s.codes.asMap().entries.map((e) {
            final i = e.key;
            final c = e.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _tf(
                            context.t('اسم الرمز ${i + 1}', 'Code ${i + 1} label'),
                            c.label,
                            (v) => c.label = v,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => s.codes.removeAt(i)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    _tf(
                      context.t('تعريف إجرائي', 'Operational definition'),
                      c.definition,
                      (v) => c.definition = v,
                      maxLines: 2,
                    ),
                    _tf(
                      context.t('مثال (اختياري)', 'Example (optional)'),
                      c.example,
                      (v) => c.example = v,
                    ),
                  ],
                ),
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: () async {
              await _save();
              await _copy();
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: Text(context.t('حفظ ونسخ الملخص', 'Save & copy summary')),
          ),
        ],
      ),
    );
  }

  Widget _tf(
    String label,
    String initial,
    ValueChanged<String> onChanged, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: TextEditingController(text: initial)
          ..selection = TextSelection.collapsed(offset: initial.length),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        maxLines: maxLines,
        onChanged: onChanged,
      ),
    );
  }
}
