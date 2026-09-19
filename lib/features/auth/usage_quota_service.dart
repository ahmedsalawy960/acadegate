import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_account.dart';

/// Mirrors Cloud Function defaults in [functions/usage_quota.js].
class UsageQuotaLimits {
  static const freeGemini = 20;
  static const freeScholar = 6;
  static const proGemini = 100;
  static const proScholar = 30;

  static int geminiFor(String tier, {int? override}) {
    if (override != null && override >= 0) return override;
    switch (tier) {
      case 'admin':
        return 100000;
      case SubscriptionTier.pro:
        return proGemini;
      default:
        return freeGemini;
    }
  }

  static int scholarFor(String tier, {int? override}) {
    if (override != null && override >= 0) return override;
    switch (tier) {
      case 'admin':
        return 100000;
      case SubscriptionTier.pro:
        return proScholar;
      default:
        return freeScholar;
    }
  }
}

class DailyUsageSnapshot {
  final int geminiUsed;
  final int scholarUsed;
  final String tier;
  final String day;
  final int? geminiLimitOverride;
  final int? scholarLimitOverride;
  final int? storedGeminiLimit;
  final int? storedScholarLimit;

  const DailyUsageSnapshot({
    required this.geminiUsed,
    required this.scholarUsed,
    required this.tier,
    required this.day,
    this.geminiLimitOverride,
    this.scholarLimitOverride,
    this.storedGeminiLimit,
    this.storedScholarLimit,
  });

  int get geminiLimit =>
      UsageQuotaLimits.geminiFor(tier, override: geminiLimitOverride);
  int get scholarLimit =>
      UsageQuotaLimits.scholarFor(tier, override: scholarLimitOverride);
  int get geminiRemaining => (geminiLimit - geminiUsed).clamp(0, geminiLimit);
  int get scholarRemaining =>
      (scholarLimit - scholarUsed).clamp(0, scholarLimit);
}

class UsageQuotaService {
  UsageQuotaService._();
  static final UsageQuotaService instance = UsageQuotaService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String utcDayKey([DateTime? now]) {
    final d = (now ?? DateTime.now().toUtc());
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Stream<DailyUsageSnapshot?> watchToday({UserAccount? account}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(null);

    final day = utcDayKey();
    final tier = account?.effectiveTier ?? SubscriptionTier.free;

    return _db
        .collection('usage')
        .doc(user.uid)
        .collection('daily')
        .doc(day)
        .snapshots()
        .map((snap) {
      final data = snap.data() ?? {};
      return DailyUsageSnapshot(
        geminiUsed: (data['gemini'] as num?)?.toInt() ?? 0,
        scholarUsed: (data['scholar'] as num?)?.toInt() ?? 0,
        tier: (data['tier'] as String?)?.trim().isNotEmpty == true
            ? data['tier'].toString()
            : tier,
        day: day,
        geminiLimitOverride: account?.quotaGeminiDaily,
        scholarLimitOverride: account?.quotaScholarDaily,
        storedGeminiLimit: (data['limitGemini'] as num?)?.toInt(),
        storedScholarLimit: (data['limitScholar'] as num?)?.toInt(),
      );
    });
  }
}
