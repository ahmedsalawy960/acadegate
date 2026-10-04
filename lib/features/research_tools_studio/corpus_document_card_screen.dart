import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../humanities/humanities_faculties.dart';
import '../humanities/humanities_prefs.dart';
import 'literary_instrument_models.dart';
import 'research_tools_branding.dart';
import 'research_tools_storage.dart';

class CorpusDocumentCardScreen extends StatefulWidget {
  const CorpusDocumentCardScreen({super.key});

  @override
  State<CorpusDocumentCardScreen> createState() =>
      _CorpusDocumentCardScreenState();
}

class _CorpusDocumentCardScreenState extends State<CorpusDocumentCardScreen> {
  static const _brand = Color(ResearchToolsBranding.brand);
  CorpusDocumentCard? _card;
  bool _loading = true;
  bool _lawMode = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final track = await HumanitiesPrefs.loadTrack();
    final law = track == HumanitiesTrack.law;
    final saved = await ResearchToolsStorage.instance.loadCorpus();
    if (!mounted) return;
    setState(() {
      _lawMode = law;
      _card = saved ??
          (law
              ? CorpusDocumentCard.templateLaw()
              : CorpusDocumentCard.templateArts());
      _loading = false;
    });
  }

  Future<void> _save() async {
    final c = _card;
    if (c == null) return;
    await ResearchToolsStorage.instance.saveCorpus(c);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('تم الحفظ', 'Saved')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _copy() async {
    final c = _card;
    if (c == null) return;
    await Clipboard.setData(ClipboardData(text: c.summary()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('نُسخت بطاقة المدونة', 'Corpus card copied')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _card == null) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(
            context.t('مدونة نصوص / وثائق', 'Text / document corpus'),
          ),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final c = _card!;
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(
          _lawMode
              ? context.t('بطاقة وثائق قانونية', 'Legal documents card')
              : context.t('مدونة نصوص أدبية', 'Literary corpus card'),
        ),
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
            c.items.add(
              CorpusItem(
                id: 't_${DateTime.now().microsecondsSinceEpoch}',
                title: _lawMode ? 'وثيقة / حكم' : 'نص / عمل',
              ),
            );
          });
        },
        icon: const Icon(Icons.add),
        label: Text(context.t('عنصر', 'Item')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          Text(
            context.t(
              _lawMode
                  ? 'للحقوق: سجّل التشريع/الأحكام ومعايير الاختيار قبل التحليل.'
                  : 'للآداب: حدّد المدونة ومعايير الإدراج قبل القراءة المتأنية/النقد.',
              _lawMode
                  ? 'For law: log statutes/cases and selection criteria before analysis.'
                  : 'For arts: define the corpus and inclusion criteria before close reading/critique.',
            ),
            style: TextStyle(color: const Color(0xFFB7C3D6), height: 1.4),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(context.t('آداب/نصوص', 'Arts/texts')),
                selected: !_lawMode,
                onSelected: (_) {
                  setState(() {
                    _lawMode = false;
                    _card = CorpusDocumentCard.templateArts();
                  });
                },
              ),
              ChoiceChip(
                label: Text(context.t('حقوق/وثائق', 'Law/docs')),
                selected: _lawMode,
                onSelected: (_) {
                  setState(() {
                    _lawMode = true;
                    _card = CorpusDocumentCard.templateLaw();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _tf(context.t('عنوان البطاقة', 'Card title'), c.titleAr, (v) => c.titleAr = v),
          _tf(
            context.t('سؤال البحث', 'Research question'),
            c.researchQuestion,
            (v) => c.researchQuestion = v,
            maxLines: 2,
          ),
          _tf(
            context.t('معايير الاختيار', 'Selection criteria'),
            c.selectionCriteria,
            (v) => c.selectionCriteria = v,
            maxLines: 3,
          ),
          _tf(
            context.t('حقوق نشر / أخلاقيات', 'Copyright / ethics'),
            c.ethicsCopyright,
            (v) => c.ethicsCopyright = v,
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          ...c.items.asMap().entries.map((e) {
            final i = e.key;
            final it = e.value;
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
                            context.t('العنوان ${i + 1}', 'Title ${i + 1}'),
                            it.title,
                            (v) => it.title = v,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => c.items.removeAt(i)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    _tf(
                      context.t('المصدر / الطبعة', 'Source / edition'),
                      it.source,
                      (v) => it.source = v,
                    ),
                    _tf(context.t('السنة', 'Year'), it.year, (v) => it.year = v),
                    _tf(
                      context.t('ملاحظة / مبرر الإدراج', 'Note / inclusion rationale'),
                      it.notes,
                      (v) => it.notes = v,
                      maxLines: 2,
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
