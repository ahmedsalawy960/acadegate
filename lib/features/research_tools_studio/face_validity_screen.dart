import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'research_tools_branding.dart';
import 'research_tools_storage.dart';
import 'survey_models.dart';

/// قائمة تحقق للصدق الظاهري وتحكيم الأداة.
class FaceValidityScreen extends StatefulWidget {
  const FaceValidityScreen({super.key});

  @override
  State<FaceValidityScreen> createState() => _FaceValidityScreenState();
}

class _FaceValidityScreenState extends State<FaceValidityScreen> {
  static const _brand = Color(ResearchToolsBranding.brand);
  List<FaceValidityCheck> _checks = FaceValidityCheck.defaults();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final checks = await ResearchToolsStorage.instance.loadFaceChecks();
    if (!mounted) return;
    setState(() {
      _checks = checks;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    await ResearchToolsStorage.instance.saveFaceChecks(_checks);
  }

  int get _doneCount => _checks.where((c) => c.done).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('الصدق الظاهري', 'Face validity')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  context.t(
                    'أنجز $_doneCount / ${_checks.length} — احفظ ملاحظات المحكّمين تحت كل بند.',
                    'Done $_doneCount / ${_checks.length} — save expert notes under each item.',
                  ),
                  style: const TextStyle(color: Color(0xFFB7C3D6), height: 1.4),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _checks.isEmpty ? 0 : _doneCount / _checks.length,
                  color: _brand,
                  backgroundColor: _brand.withValues(alpha: 0.12),
                ),
                const SizedBox(height: 14),
                ..._checks.asMap().entries.map((e) {
                  final i = e.key;
                  final c = e.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            value: c.done,
                            activeColor: _brand,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              context.t(c.titleAr, c.titleEn),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            onChanged: (v) {
                              setState(() => _checks[i].done = v ?? false);
                              _persist();
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: _NoteField(
                              key: ValueKey(c.id),
                              initial: c.note,
                              hint: context.t(
                                'ملاحظة محكّم / تعديل مقترح',
                                'Expert note / suggested edit',
                              ),
                              onChanged: (v) => _checks[i].note = v,
                              onCommit: _persist,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                TextButton(
                  onPressed: () async {
                    setState(() => _checks = FaceValidityCheck.defaults());
                    await _persist();
                  },
                  child: Text(context.t('إعادة تعيين القائمة', 'Reset checklist')),
                ),
              ],
            ),
    );
  }
}

class _NoteField extends StatefulWidget {
  final String initial;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onCommit;

  const _NoteField({
    super.key,
    required this.initial,
    required this.hint,
    required this.onChanged,
    required this.onCommit,
  });

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        border: const OutlineInputBorder(),
      ),
      maxLines: 2,
      onChanged: widget.onChanged,
      onEditingComplete: widget.onCommit,
      onTapOutside: (_) => widget.onCommit(),
    );
  }
}
