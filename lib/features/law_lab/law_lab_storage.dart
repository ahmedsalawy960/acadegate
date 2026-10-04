import 'package:shared_preferences/shared_preferences.dart';

import 'law_lab_models.dart';

class LawLabStorage {
  LawLabStorage._();
  static final LawLabStorage instance = LawLabStorage._();

  static const _kProject = 'law_lab_project_v1';

  Future<LawProject> loadOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    return LawProject.tryDecode(prefs.getString(_kProject)) ??
        LawProject.template();
  }

  Future<void> save(LawProject project) async {
    project.updatedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProject, project.encode());
  }
}
