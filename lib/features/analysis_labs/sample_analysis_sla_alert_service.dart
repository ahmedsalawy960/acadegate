import '../../core/locale/app_translate.dart';
import '../../core/offline/local_profile_store.dart';
import '../notifications/notification_service.dart';
import 'sample_analysis_request_service.dart';
import 'sample_analysis_sla.dart';

/// تذكيرات SLA داخل التطبيق لطلبات تحليل العينات.
class SampleAnalysisSlaAlertService {
  SampleAnalysisSlaAlertService._();

  static final SampleAnalysisSlaAlertService instance =
      SampleAnalysisSlaAlertService._();

  final _requests = SampleAnalysisRequestService.instance;
  final _local = LocalProfileStore.instance;

  Future<void> maybeNotify() async {
    await Future.wait([
      _notifyStudentOverdue(),
      _notifyLabOwnerOverdue(),
    ]);
  }

  Future<void> _notifyStudentOverdue() async {
    final requests = await _requests.myRequestsStream().first;
    for (final request in requests) {
      if (request.id == null) continue;
      final sla = SampleAnalysisSla.evaluate(request);
      if (!SampleAnalysisSla.shouldSendReminder(sla)) continue;
      if (await _local.wasSampleSlaReminderSent(request.id!)) continue;

      final body = switch (sla.kind) {
        SampleSlaKind.response => appTr(
            'طلبك لدى ${request.labName} — ${request.serviceName} — '
                'متأخر ${sla.daysOverdue} أيام دون رد من المختبر',
            'Your request at ${request.labName} — ${request.serviceName} — '
                '${sla.daysOverdue} days overdue without lab response',
          ),
        SampleSlaKind.completion => appTr(
            'تحليل ${request.serviceName} في ${request.labName} — '
                'متأخر ${sla.daysOverdue} أيام عن موعد التسليم',
            '${request.serviceName} at ${request.labName} — '
                '${sla.daysOverdue} days past delivery SLA',
          ),
        SampleSlaKind.none => '',
      };
      if (body.isEmpty) continue;

      await NotificationService.instance.notifySelf(
        title: appTr(
          'تذكير SLA — تحليل عينة',
          'SLA reminder — sample analysis',
        ),
        body: body,
        type: 'sample_analysis_sla',
      );
      await _local.markSampleSlaReminderSent(request.id!);
    }
  }

  Future<void> _notifyLabOwnerOverdue() async {
    final requests = await _requests.incomingForLabOwnerStream().first;
    for (final request in requests) {
      if (request.id == null) continue;
      if (request.status != 'pending' && request.status != 'accepted') {
        continue;
      }

      final sla = SampleAnalysisSla.evaluate(request);
      if (!SampleAnalysisSla.shouldSendReminder(sla)) continue;

      final reminderKey = 'owner_${request.id!}';
      if (await _local.wasSampleSlaReminderSent(reminderKey)) continue;

      final body = switch (sla.kind) {
        SampleSlaKind.response => appTr(
            '${request.studentName} — ${request.serviceName} — '
                'متأخر ${sla.daysOverdue} أيام دون رد',
            '${request.studentName} — ${request.serviceName} — '
                '${sla.daysOverdue} days overdue — no response',
          ),
        SampleSlaKind.completion => appTr(
            '${request.studentName} — ${request.serviceName} — '
                'متأخر ${sla.daysOverdue} أيام عن موعد التسليم',
            '${request.studentName} — ${request.serviceName} — '
                '${sla.daysOverdue} days past delivery SLA',
          ),
        SampleSlaKind.none => '',
      };
      if (body.isEmpty) continue;

      await NotificationService.instance.notifySelf(
        title: appTr(
          'طلب تحليل عينة متأخر',
          'Overdue sample analysis request',
        ),
        body: body,
        type: 'sample_analysis_sla',
      );
      await _local.markSampleSlaReminderSent(reminderKey);
    }
  }
}
