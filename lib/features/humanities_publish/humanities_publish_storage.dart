import 'package:shared_preferences/shared_preferences.dart';

import 'humanities_publish_models.dart';

class HumanitiesPublishStorage {
  HumanitiesPublishStorage._();
  static final HumanitiesPublishStorage instance = HumanitiesPublishStorage._();

  static const _kDraft = 'humanities_publish_draft_v1';

  Future<HumanitiesPublishDraft> loadOrCreate({String? facultyId}) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = HumanitiesPublishDraft.tryDecode(prefs.getString(_kDraft));
    if (existing != null) {
      if (facultyId != null &&
          facultyId.isNotEmpty &&
          existing.facultyId != facultyId &&
          existing.outletId.isEmpty) {
        existing.facultyId = facultyId;
      }
      return existing;
    }
    return HumanitiesPublishDraft(
      facultyId: facultyId?.isNotEmpty == true ? facultyId! : 'Education',
    );
  }

  /// Removes the saved draft (author name, affiliation, abstract, notes).
  /// Called on sign-out so the next person on the same device starts clean.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDraft);
  }

  Future<void> save(HumanitiesPublishDraft draft) async {
    draft.updatedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDraft, draft.encode());
  }
}
