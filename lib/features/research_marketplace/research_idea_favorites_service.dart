import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../academic/academic_models.dart';

/// حفظ الأفكار (مفضلة الطالب) في users/{uid}/favorite_ideas/{ideaId}.
/// لقطة صغيرة فقط للعرض في قائمة المحفوظات؛ التفاصيل الكاملة تُجلب من
/// research_ideas عند الفتح.
class ResearchIdeaFavoritesService {
  ResearchIdeaFavoritesService._();

  static final ResearchIdeaFavoritesService instance =
      ResearchIdeaFavoritesService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _col(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('favorite_ideas');

  Stream<bool> watchIsFavorite(String ideaId) {
    final uid = _uid;
    if (uid == null || ideaId.isEmpty) return Stream.value(false);
    return _col(uid).doc(ideaId).snapshots().map((s) => s.exists);
  }

  Future<bool> toggle(AcademicResearchIdea idea) async {
    final uid = _uid;
    final ideaId = (idea.id ?? '').trim();
    if (uid == null || ideaId.isEmpty) return false;
    final ref = _col(uid).doc(ideaId);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
      return false;
    }
    await ref.set({
      'ideaId': ideaId,
      'title': idea.title,
      'titleEn': idea.titleEn,
      'category': idea.category,
      'savedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  Stream<List<Map<String, dynamic>>> watchFavorites() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _col(uid)
        .orderBy('savedAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (q) => q.docs
              .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
              .toList(),
        );
  }
}
