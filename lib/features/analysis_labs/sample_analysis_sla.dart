import '../../core/locale/app_translate.dart';
import 'sample_analysis_request_service.dart';

enum SampleSlaKind { response, completion, none }

class SampleSlaStatus {
  final SampleSlaKind kind;
  final DateTime? dueAt;
  final int daysOverdue;
  final int daysRemaining;
  final bool isOverdue;
  final bool isDueSoon;

  const SampleSlaStatus({
    required this.kind,
    this.dueAt,
    this.daysOverdue = 0,
    this.daysRemaining = 0,
    this.isOverdue = false,
    this.isDueSoon = false,
  });

  static const none = SampleSlaStatus(kind: SampleSlaKind.none);

  bool get showBadge => isOverdue || isDueSoon;

  String badgeLabel(bool isEnglish) {
    if (isOverdue && daysOverdue >= 3) {
      return appTr(
        'متأخر $daysOverdue أيام',
        '$daysOverdue days overdue',
      );
    }
    if (isOverdue) {
      return appTr(
        'متأخر $daysOverdue ${daysOverdue == 1 ? 'يوم' : 'أيام'}',
        '$daysOverdue ${daysOverdue == 1 ? 'day' : 'days'} overdue',
      );
    }
    if (isDueSoon && daysRemaining > 0) {
      return appTr(
        'بقي $daysRemaining ${daysRemaining == 1 ? 'يوم' : 'أيام'}',
        '$daysRemaining ${daysRemaining == 1 ? 'day' : 'days'} left',
      );
    }
    return '';
  }

  String detailLine(bool isEnglish) {
    if (kind == SampleSlaKind.none || dueAt == null) return '';
    final date =
        '${dueAt!.day}/${dueAt!.month}/${dueAt!.year}';
    if (isOverdue) {
      return appTr(
        'موعد SLA: $date — متأخر $daysOverdue أيام',
        'SLA due: $date — $daysOverdue days overdue',
      );
    }
    return appTr(
      'موعد SLA: $date — بقي $daysRemaining أيام',
      'SLA due: $date — $daysRemaining days remaining',
    );
  }
}

class SampleAnalysisSla {
  SampleAnalysisSla._();

  static const responseDaysDefault = 3;
  static const dueSoonThresholdDays = 1;

  static SampleSlaStatus evaluate(SampleAnalysisRequest request) {
    final response = _responseSla(request);
    if (response.kind != SampleSlaKind.none) return response;

    return _completionSla(request);
  }

  static SampleSlaStatus _responseSla(SampleAnalysisRequest request) {
    if (request.status != 'pending') return SampleSlaStatus.none;

    final created = request.createdAt;
    if (created == null) return SampleSlaStatus.none;

    final due = created.add(Duration(days: request.slaResponseDays));
    return _fromDue(due, SampleSlaKind.response);
  }

  static SampleSlaStatus _completionSla(SampleAnalysisRequest request) {
    if (request.status != 'accepted') return SampleSlaStatus.none;

    final start = request.acceptedAt ?? request.updatedAt ?? request.createdAt;
    if (start == null) return SampleSlaStatus.none;

    final due = start.add(Duration(days: request.turnaroundDays));
    return _fromDue(due, SampleSlaKind.completion);
  }

  static SampleSlaStatus _fromDue(DateTime due, SampleSlaKind kind) {
    final now = DateTime.now();
    final overdueDays = now.isAfter(due) ? now.difference(due).inDays : 0;
    final remainingDays =
        now.isBefore(due) ? due.difference(now).inDays : 0;
    final overdue = overdueDays > 0;
    final dueSoon = !overdue && remainingDays <= dueSoonThresholdDays;

    return SampleSlaStatus(
      kind: kind,
      dueAt: due,
      daysOverdue: overdueDays,
      daysRemaining: remainingDays,
      isOverdue: overdue,
      isDueSoon: dueSoon,
    );
  }

  static bool shouldSendReminder(SampleSlaStatus sla) =>
      sla.isOverdue && sla.daysOverdue >= responseDaysDefault;
}
