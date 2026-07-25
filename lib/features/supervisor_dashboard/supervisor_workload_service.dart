import '../../core/locale/app_translate.dart';
import '../supervision/supervision_request_models.dart';
import '../supervision/supervision_request_service.dart';

class SupervisorWorkloadSummary {
  final int pendingCount;
  final int acceptedCount;
  final int totalActive;
  final String loadLabel;
  final double loadRatio;

  const SupervisorWorkloadSummary({
    required this.pendingCount,
    required this.acceptedCount,
    required this.totalActive,
    required this.loadLabel,
    required this.loadRatio,
  });
}

class SupervisorWorkloadService {
  SupervisorWorkloadService._();

  static final SupervisorWorkloadService instance = SupervisorWorkloadService._();

  Stream<SupervisorWorkloadSummary> watchSummary() {
    return SupervisionRequestService.instance.incomingForOwnerStream().map(
      _fromRequests,
    );
  }

  SupervisorWorkloadSummary _fromRequests(List<SupervisionRequest> requests) {
    final pending = requests.where((r) => r.status == 'pending').length;
    final accepted = requests.where((r) => r.status == 'accepted').length;
    final active = pending + accepted;
    const capacity = 8;
    final ratio = (active / capacity).clamp(0.0, 1.0);

    final loadLabel = switch (ratio) {
      >= 0.85 => appTr('حمل مرتفع', 'High load'),
      >= 0.5 => appTr('حمل متوسط', 'Medium load'),
      _ => appTr('متاح لطلاب جدد', 'Available for new students'),
    };

    return SupervisorWorkloadSummary(
      pendingCount: pending,
      acceptedCount: accepted,
      totalActive: active,
      loadLabel: loadLabel,
      loadRatio: ratio,
    );
  }
}
