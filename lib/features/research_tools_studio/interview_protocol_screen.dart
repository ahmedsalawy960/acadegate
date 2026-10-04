import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'literary_instrument_models.dart';
import 'research_tools_branding.dart';
import 'research_tools_storage.dart';

class InterviewProtocolScreen extends StatefulWidget {
  const InterviewProtocolScreen({super.key});

  @override
  State<InterviewProtocolScreen> createState() => _InterviewProtocolScreenState();
}

class _InterviewProtocolScreenState extends State<InterviewProtocolScreen> {
  static const _brand = Color(ResearchToolsBranding.brand);
  InterviewProtocol? _protocol;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await ResearchToolsStorage.instance.loadInterview();
    if (!mounted) return;
    setState(() {
      _protocol = saved ?? InterviewProtocol.template();
      _loading = false;
    });
  }

  Future<void> _save() async {
    final p = _protocol;
    if (p == null) return;
    await ResearchToolsStorage.instance.saveInterview(p);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('تم الحفظ', 'Saved')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _copy() async {
    final p = _protocol;
    if (p == null) return;
    await Clipboard.setData(ClipboardData(text: p.summary()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('نُسخ البروتوكول', 'Protocol copied')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _protocol == null) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('بروتوكول المقابلة', 'Interview protocol')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final p = _protocol!;
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('بروتوكول المقابلة', 'Interview protocol')),
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
            p.questions.add(
              InterviewQuestion(
                id: 'q_${DateTime.now().microsecondsSinceEpoch}',
                text: 'سؤال جديد',
                probeType: 'core',
              ),
            );
          });
        },
        icon: const Icon(Icons.add),
        label: Text(context.t('سؤال', 'Question')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          Text(
            context.t(
              'لأبحاث الآداب والتربية النوعية والإعلام: أسئلة محورية + متابعة + أخلاقيات.',
              'For arts, qualitative education, and media: core questions + probes + ethics.',
            ),
            style: TextStyle(color: const Color(0xFFB7C3D6), height: 1.4),
          ),
          const SizedBox(height: 12),
          _field(
            label: context.t('عنوان البروتوكول', 'Protocol title'),
            initial: p.titleAr,
            onChanged: (v) => p.titleAr = v,
          ),
          _field(
            label: context.t('سؤال البحث', 'Research question'),
            initial: p.researchQuestion,
            onChanged: (v) => p.researchQuestion = v,
            maxLines: 2,
          ),
          _field(
            label: context.t('من يُقابَل؟', 'Who is interviewed?'),
            initial: p.participantProfile,
            onChanged: (v) => p.participantProfile = v,
          ),
          _field(
            label: context.t('المدة (دقيقة)', 'Duration (min)'),
            initial: p.durationMinutes,
            onChanged: (v) => p.durationMinutes = v,
          ),
          _field(
            label: context.t('أخلاقيات مختصرة', 'Brief ethics note'),
            initial: p.ethicsNote,
            onChanged: (v) => p.ethicsNote = v,
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          ...p.questions.asMap().entries.map((e) {
            final i = e.key;
            final q = e.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: q.probeType,
                            decoration: InputDecoration(
                              labelText: context.t('نوع السؤال', 'Question type'),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'opening',
                                child: Text(context.t('افتتاح', 'Opening')),
                              ),
                              DropdownMenuItem(
                                value: 'core',
                                child: Text(context.t('محوري', 'Core')),
                              ),
                              DropdownMenuItem(
                                value: 'probe',
                                child: Text(context.t('تعمّق', 'Probe')),
                              ),
                              DropdownMenuItem(
                                value: 'closing',
                                child: Text(context.t('ختام', 'Closing')),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => q.probeType = v);
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              setState(() => p.questions.removeAt(i)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _field(
                      label: context.t('نص السؤال ${i + 1}', 'Question ${i + 1}'),
                      initial: q.text,
                      onChanged: (v) => q.text = v,
                      maxLines: 2,
                    ),
                    _field(
                      label: context.t('سؤال متابعة (اختياري)', 'Follow-up (optional)'),
                      initial: q.followUp,
                      onChanged: (v) => q.followUp = v,
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

  Widget _field({
    required String label,
    required String initial,
    required ValueChanged<String> onChanged,
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
