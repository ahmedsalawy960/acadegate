import '../../core/locale/app_translate.dart';
import '../../core/offline/local_profile_store.dart';
import '../academic/academic_content_service.dart';
import '../matchmaking/smart_matchmaking_engine.dart';
import '../notifications/notification_service.dart';
import '../profile/academic_profile_service.dart';
import '../supervision/supervision_request_service.dart';

class SmartMatchAlertService {
  SmartMatchAlertService._();

  static final SmartMatchAlertService instance = SmartMatchAlertService._();

  static const _minHoursBetweenAlerts = 24;
  static const _minScoreToNotify = 75;

  static Future<void>? _running;

  Future<void> maybeNotify() async {
    if (_running != null) {
      await _running;
      return;
    }

    _running = _maybeNotifyImpl();
    try {
      await _running;
    } finally {
      _running = null;
    }
  }

  Future<void> _maybeNotifyImpl() async {
    final profile = await AcademicProfileService.instance.loadProfile();
    if (profile == null || !profile.isComplete) return;

    final last = await LocalProfileStore.instance.lastSmartMatchAlertAt();
    if (last != null &&
        DateTime.now().difference(last).inHours < _minHoursBetweenAlerts) {
      return;
    }

    final content = await AcademicContentService.instance.fetchAll(
      includeLabs: false,
    );
    final realSupervisors =
        content.supervisors.where((s) => !s.isDemo && s.id != null).toList();
    if (realSupervisors.isEmpty) return;

    final matches = SmartMatchmakingEngine.matchSupervisors(
      profile,
      realSupervisors,
      limit: 1,
    );
    if (matches.isEmpty) return;

    final top = matches.first;
    if (top.score < _minScoreToNotify) return;

    final supervisorId = top.item.id!;
    if (await LocalProfileStore.instance.wasSmartMatchSupervisorNotified(
      supervisorId,
    )) {
      return;
    }

    if (await SupervisionRequestService.instance.hasExistingSupervisorLink(
      supervisorId,
    )) {
      await LocalProfileStore.instance.markSmartMatchSupervisorNotified(
        supervisorId,
      );
      return;
    }

    final body = appTr(
      '${top.item.name} — توافق ${top.score}%',
      '${top.item.name} — ${top.score}% match',
    );

    if (await NotificationService.instance.hasRecent(
      type: 'smart_match',
      body: body,
    )) {
      await LocalProfileStore.instance.markSmartMatchSupervisorNotified(
        supervisorId,
      );
      return;
    }

    // Reserve the slot before writing to avoid duplicate alerts on rapid rebuilds.
    await LocalProfileStore.instance.setLastSmartMatchAlertAt(DateTime.now());
    await LocalProfileStore.instance.markSmartMatchSupervisorNotified(
      supervisorId,
    );

    await NotificationService.instance.notifySelf(
      title: appTr('مشرف مناسب ظهر', 'A suitable supervisor appeared'),
      body: body,
      type: 'smart_match',
    );
  }
}
