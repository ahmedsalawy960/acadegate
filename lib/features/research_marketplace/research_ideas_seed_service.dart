import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/user_account_service.dart';
import '../moderation/approval_status.dart';
import 'seed/egypt_research_ideas_seed.dart';

class ResearchIdeasSeedResult {
  final int imported;
  final int skipped;
  final int total;

  const ResearchIdeasSeedResult({
    required this.imported,
    required this.skipped,
    required this.total,
  });
}

/// ينشر حزمة الأفكار باسم المستخدم الحالي (publisherId = uid).
class ResearchIdeasSeedService {
  ResearchIdeasSeedService._();

  static final ResearchIdeasSeedService instance = ResearchIdeasSeedService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const seedSource = 'egypt_ideas_pack_2026';

  Future<ResearchIdeasSeedResult> publishPack({
    bool autoApprove = true,
    void Function(int done, int total)? onProgress,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول');
    }

    final account = await UserAccountService.instance.watchCurrentAccount().first;
    final canAutoApprove = autoApprove && (account?.isAdmin == true);

    final existing = await _db
        .collection('research_ideas')
        .where('publisherId', isEqualTo: user.uid)
        .where('seedSource', isEqualTo: seedSource)
        .get();
    final existingTitles = existing.docs
        .map((d) => d.data()['title']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .toSet();

    final pack = egyptResearchIdeasSeed;
    var imported = 0;
    var skipped = 0;
    final total = pack.length;

    // Firestore batches max 500; 90 fits in one batch but we chunk for safety.
    const chunk = 40;
    for (var i = 0; i < pack.length; i += chunk) {
      final batch = _db.batch();
      var ops = 0;
      final slice = pack.skip(i).take(chunk);
      for (final idea in slice) {
        if (existingTitles.contains(idea.title)) {
          skipped++;
          onProgress?.call(imported + skipped, total);
          continue;
        }
        final ref = _db.collection('research_ideas').doc();
        batch.set(ref, {
          'title': idea.title,
          'provider': idea.provider,
          'details': idea.details,
          'budget': idea.budget,
          'tags': idea.tags,
          'category': idea.category,
          'status': 'open',
          'approvalStatus': canAutoApprove
              ? ApprovalStatus.approved
              : ApprovalStatus.pending,
          'votesCount': 0,
          'proposalsCount': 0,
          'publisherId': user.uid,
          'seedSource': seedSource,
          'importSource': 'egypt_ideas_pack',
          'createdAt': FieldValue.serverTimestamp(),
        });
        existingTitles.add(idea.title);
        imported++;
        ops++;
        onProgress?.call(imported + skipped, total);
      }
      if (ops > 0) await batch.commit();
    }

    return ResearchIdeasSeedResult(
      imported: imported,
      skipped: skipped,
      total: total,
    );
  }
}
