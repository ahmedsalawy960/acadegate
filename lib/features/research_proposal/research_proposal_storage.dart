import 'package:shared_preferences/shared_preferences.dart';

import 'research_proposal_models.dart';
import 'research_proposal_templates.dart';

class ResearchProposalStorage {
  ResearchProposalStorage._();
  static final ResearchProposalStorage instance = ResearchProposalStorage._();

  static const _kDraft = 'research_proposal_draft_v1';

  Future<ProposalDraft> loadOrCreate({String? facultyId}) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = ProposalDraft.tryDecode(prefs.getString(_kDraft));
    if (existing != null) return existing;
    final tpl = facultyId != null && facultyId.isNotEmpty
        ? proposalTemplateForFaculty(facultyId) ?? proposalFacultyTemplates.first
        : proposalFacultyTemplates.first;
    return ProposalDraft.emptyFor(tpl);
  }

  Future<void> save(ProposalDraft draft) async {
    draft.updatedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDraft, draft.encode());
  }

  /// يطبّق اختصار كلية (تحديد فقرات من الكتالوج) دون إنشاء قالب منفصل.
  Future<void> applyTemplate(ProposalFacultyTemplate template) async {
    final draft = await loadOrCreate();
    draft.applySectionSelection(
      keys: template.requiredSections,
      templateId: template.id,
      facultyId: template.facultyId,
    );
    await save(draft);
  }

  Future<void> applySectionSelection({
    required List<String> keys,
    String templateId = 'catalog_all',
    String facultyId = 'General',
  }) async {
    final draft = await loadOrCreate();
    draft.applySectionSelection(
      keys: keys,
      templateId: templateId,
      facultyId: facultyId,
    );
    await save(draft);
  }
}
