import 'package:shared_preferences/shared_preferences.dart';

import '../research_tools_studio/literary_instrument_models.dart';
import '../research_tools_studio/research_tools_storage.dart';
import 'qualitative_models.dart';

class QualitativeStorage {
  QualitativeStorage._();
  static final QualitativeStorage instance = QualitativeStorage._();

  static const _kProject = 'qualitative_analysis_project_v1';

  Future<QualProject> loadOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final parsed = QualProject.tryDecode(prefs.getString(_kProject));
    return parsed ?? QualProject.template();
  }

  Future<void> save(QualProject project) async {
    project.updatedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProject, project.encode());
  }

  /// يستورد رموز ورقة تحليل المضمون من مسار 2 إن وُجدت.
  Future<int> importCodesFromContentSheet(QualProject project) async {
    final sheet = await ResearchToolsStorage.instance.loadContentSheet();
    if (sheet == null || sheet.codes.isEmpty) return 0;
    final existing = project.codes.map((c) => c.label.trim()).toSet();
    var added = 0;
    for (final c in sheet.codes) {
      final label = c.label.trim();
      if (label.isEmpty || existing.contains(label)) continue;
      project.codes.add(
        QualCode(
          id: 'imp_${DateTime.now().microsecondsSinceEpoch}_$added',
          label: label,
          definition: c.definition,
          inclusionNotes: c.example.isEmpty ? '' : 'مثال: ${c.example}',
        ),
      );
      existing.add(label);
      added++;
    }
    if (added > 0) await save(project);
    return added;
  }

  Future<ContentAnalysisSheet?> peekContentSheet() =>
      ResearchToolsStorage.instance.loadContentSheet();
}
