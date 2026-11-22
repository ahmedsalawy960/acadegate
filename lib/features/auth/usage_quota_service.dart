import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../billing/app_plans.dart';
import 'user_account.dart';

/// Mirrors Cloud Function defaults in [functions/usage_quota.js].
class UsageQuotaLimits {
  static int geminiMonthFor(String tier) {
    switch (tier) {
      case 'admin':
        return 100000;
      case SubscriptionTier.pro:
        return 1500;
      case SubscriptionTier.plus:
        return 300;
      default:
        return 0;
    }
  }

  static int scholarMonthFor(String tier) {
    switch (tier) {
      case 'admin':
        return 100000;
      case SubscriptionTier.pro:
        return 450;
      case SubscriptionTier.plus:
        return 90;
      default:
        return 0;
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

  int get geminiLimit => UsageQuotaLimits.geminiMonthFor(tier);
  int get scholarLimit => UsageQuotaLimits.scholarMonthFor(tier);
  int get geminiRemaining => (geminiLimit - geminiUsed).clamp(0, geminiLimit);
  int get scholarRemaining =>
      (scholarLimit - scholarUsed).clamp(0, scholarLimit);
}

class UsageMeter {
  final String titleAr;
  final String titleEn;
  final int monthUsed;
  final int monthLimit;
  final int dayUsed;
  final int dayLimit;

  const UsageMeter({
    required this.titleAr,
    required this.titleEn,
    required this.monthUsed,
    required this.monthLimit,
    required this.dayUsed,
    required this.dayLimit,
  });

  bool get unlimited => monthLimit >= 100000;

  int get monthRemaining =>
      unlimited ? monthLimit : (monthLimit - monthUsed).clamp(0, monthLimit);

  int get dayRemaining =>
      unlimited ? dayLimit : (dayLimit - dayUsed).clamp(0, dayLimit);
}

class PlanUsageSnapshot {
  final String monthKey;
  final String dayKey;
  final List<UsageMeter> meters;

  const PlanUsageSnapshot({
    required this.monthKey,
    required this.dayKey,
    required this.meters,
  });
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
        .collection('monthly')
        .doc(day.substring(0, 7))
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

  Stream<PlanUsageSnapshot> watchPeriod({required UserAccount account}) {
    final user = FirebaseAuth.instance.currentUser;
    final day = utcDayKey();
    final month = day.substring(0, 7);
    if (user == null) {
      return Stream.value(
        PlanUsageSnapshot(monthKey: month, dayKey: day, meters: const []),
      );
    }

    final controller = StreamController<PlanUsageSnapshot>();
    Map<String, dynamic>? monthData;
    Map<String, dynamic>? dayData;

    void emit() {
      if (monthData == null || dayData == null || controller.isClosed) return;
      controller.add(
        _snapshot(
          account: account,
          monthKey: month,
          dayKey: day,
          monthData: monthData!,
          dayData: dayData!,
        ),
      );
    }

    final monthSub = _db
        .collection('usage')
        .doc(user.uid)
        .collection('monthly')
        .doc(month)
        .snapshots()
        .listen(
      (snap) {
        monthData = snap.data() ?? {};
        emit();
      },
      onError: controller.addError,
    );
    final daySub = _db
        .collection('usage')
        .doc(user.uid)
        .collection('daily')
        .doc(day)
        .snapshots()
        .listen(
      (snap) {
        dayData = snap.data() ?? {};
        emit();
      },
      onError: controller.addError,
    );
    controller.onCancel = () async {
      await monthSub.cancel();
      await daySub.cancel();
    };
    return controller.stream;
  }

  PlanUsageSnapshot _snapshot({
    required UserAccount account,
    required String monthKey,
    required String dayKey,
    required Map<String, dynamic> monthData,
    required Map<String, dynamic> dayData,
  }) {
    final tier = account.effectiveTier;
    final unlimited = account.isAdmin;
    final plan = AppPlans.byId(
      tier == 'admin' ? SubscriptionTier.pro : tier,
    );
    const kinds = ['gemini', 'scholar', 'consensus', 'copyleaks'];
    final dayOverrides = <String, int?>{
      'gemini': account.quotaGeminiDaily,
      'scholar': account.quotaScholarDaily,
      'copyleaks': account.quotaCopyleaksDaily,
    };
    final meters = <UsageMeter>[];
    for (var i = 0; i < kinds.length; i++) {
      final allowance = plan.allowances[i];
      final kind = kinds[i];
      meters.add(
        UsageMeter(
          titleAr: allowance.titleAr,
          titleEn: allowance.titleEn,
          monthUsed: (monthData[kind] as num?)?.toInt() ?? 0,
          monthLimit: unlimited ? 100000 : allowance.perMonth,
          dayUsed: (dayData[kind] as num?)?.toInt() ?? 0,
          dayLimit: unlimited ? 100000 : (dayOverrides[kind] ?? allowance.perDay),
        ),
      );
    }
    return PlanUsageSnapshot(monthKey: monthKey, dayKey: dayKey, meters: meters);
  }
}
