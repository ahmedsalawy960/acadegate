import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import 'research_proposal_branding.dart';
import 'research_proposal_draft_screen.dart';
import 'research_proposal_storage.dart';
import 'research_proposal_templates.dart';

/// شاشة اختيار فقرات الخطة من كتالوج موحّد (+ اختصارات اختيارية للكليات).
class ResearchProposalTemplatesScreen extends StatefulWidget {
  const ResearchProposalTemplatesScreen({super.key});

  @override
  State<ResearchProposalTemplatesScreen> createState() =>
      _ResearchProposalTemplatesScreenState();
}

class _ResearchProposalTemplatesScreenState
    extends State<ResearchProposalTemplatesScreen> {
  static const _brand = Color(ResearchProposalBranding.brand);

  final Set<String> _selected = {};
  String _presetId = 'catalog_all';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final draft = await ResearchProposalStorage.instance.loadOrCreate();
    if (!mounted) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(draft.activeSections);
      _presetId = draft.templateId;
      _loading = false;
    });
  }

  void _applyPreset(ProposalFacultyTemplate tpl) {
    setState(() {
      _presetId = tpl.id;
      _selected
        ..clear()
        ..addAll(tpl.requiredSections);
    });
  }

  void _toggle(String key, bool on) {
    setState(() {
      if (on) {
        _selected.add(key);
      } else {
        // Keep at least title + problem so the draft stays usable.
        if (key == ProposalSectionKeys.titleAr ||
            key == ProposalSectionKeys.problem) {
          return;
        }
        _selected.remove(key);
      }
      _presetId = 'catalog_all';
    });
  }

  void _selectAll() {
    setState(() {
      _selected
        ..clear()
        ..addAll(allProposalSectionKeys);
      _presetId = 'catalog_all';
    });
  }

  void _selectCore() {
    setState(() {
      _selected
        ..clear()
        ..addAll(const [
          ProposalSectionKeys.titleAr,
          ProposalSectionKeys.titleEn,
          ProposalSectionKeys.problem,
          ProposalSectionKeys.questions,
          ProposalSectionKeys.objectives,
          ProposalSectionKeys.significance,
          ProposalSectionKeys.limits,
          ProposalSectionKeys.priorStudies,
          ProposalSectionKeys.methodology,
          ProposalSectionKeys.references,
        ]);
      _presetId = 'catalog_all';
    });
  }

  Future<void> _save() async {
    if (_selected.isEmpty || _saving) return;
    setState(() => _saving = true);
    final tpl = proposalTemplateById(_presetId);
    await ResearchProposalStorage.instance.applySectionSelection(
      keys: _selected.toList(),
      templateId: tpl?.id ?? 'catalog_all',
      facultyId: tpl?.facultyId ?? 'General',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t(
            'حُفظت ${_selected.length} فقرة للمسودة',
            'Saved ${_selected.length} sections to the draft',
          ),
        ),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: context.t('افتح المسودة', 'Open draft'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ResearchProposalDraftScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openSource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(
          context.t('فقرات الخطة', 'Proposal sections'),
        ),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(
                context.t(
                  'اعتماد ${_selected.length} فقرة',
                  'Apply ${_selected.length} sections',
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                Card(
                  color: Colors.blueGrey.withValues(alpha: 0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      context.t(
                        'كتالوج واحد لكل فقرات الخطة. اختر ما يلزم كليتك، '
                        'أو ابدأ باختصار سريع ثم عدّل التحديد. ليست نماذج رسمية ملزمة.',
                        'One shared catalog of all proposal sections. Pick what your '
                        'faculty needs, or start from a shortcut then edit. Not an official binding form.',
                      ),
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: Text(context.t('تسجيل عين شمس', 'ASU registration')),
                      onPressed: () => _openSource(
                        'https://www.asu.edu.eg/ar/29/page/registration-of-masters-and-phd',
                      ),
                    ),
                    ActionChip(
                      label: Text(context.t('كل الفقرات', 'All sections')),
                      onPressed: _selectAll,
                    ),
                    ActionChip(
                      label: Text(context.t('أساسي فقط', 'Core only')),
                      onPressed: _selectCore,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  context.t(
                    'اختصار سريع حسب الكلية (اختياري)',
                    'Optional faculty shortcut',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tpl in proposalFacultyTemplates)
                      FilterChip(
                        label: Text(context.t(tpl.titleAr, tpl.titleEn)),
                        selected: _presetId == tpl.id,
                        selectedColor: _brand.withValues(alpha: 0.22),
                        checkmarkColor: _brand,
                        onSelected: (_) => _applyPreset(tpl),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final tip = proposalTemplateById(_presetId);
                    if (tip == null || tip.id == 'catalog_all') {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        context.t(tip.summaryAr, tip.summaryEn),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: const Color(0xFFB7C3D6),
                          height: 1.35,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  context.t(
                    'الفقرات (${_selected.length}/${allProposalSectionKeys.length})',
                    'Sections (${_selected.length}/${allProposalSectionKeys.length})',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                for (final group in proposalSectionGroups) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                    child: Text(
                      context.t(group.titleAr, group.titleEn),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _brand,
                      ),
                    ),
                  ),
                  for (final key in group.keys)
                    CheckboxListTile(
                      value: _selected.contains(key),
                      onChanged: (v) => _toggle(key, v == true),
                      activeColor: _brand,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        context.t(
                          ProposalSectionKeys.labelAr(key),
                          ProposalSectionKeys.labelEn(key),
                        ),
                      ),
                      subtitle: Text(
                        ProposalSectionKeys.hintAr(key),
                        style: TextStyle(fontSize: 11.5, color: const Color(0xFFB7C3D6)),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
