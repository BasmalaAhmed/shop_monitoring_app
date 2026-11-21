import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_snapshot.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_update.dart';

enum UpdateProcessingStatus { applied, duplicate, gapDetected }

class UpdateProcessingResult {
  const UpdateProcessingResult({required this.status, required this.snapshot});

  final UpdateProcessingStatus status;
  final MonitoringSnapshot snapshot;
}

class MonitoringUpdateProcessor {
  const MonitoringUpdateProcessor();

  UpdateProcessingResult process({
    required MonitoringSnapshot current,
    required MonitoringUpdate update,
  }) {
    if (current.scopeId != update.scopeId) {
      throw ArgumentError('Update scope does not match snapshot scope.');
    }

    if (update.sequence <= current.sequence) {
      return UpdateProcessingResult(
        status: UpdateProcessingStatus.duplicate,
        snapshot: current,
      );
    }

    if (update.sequence != current.sequence + 1) {
      return UpdateProcessingResult(
        status: UpdateProcessingStatus.gapDetected,
        snapshot: current,
      );
    }

    final operations = [
      if (update.operation != null) update.operation!,
      ...current.recentOperations,
    ].take(20).toList();

    final updatedSnapshot = current.copyWith(
      sequence: update.sequence,
      summary: current.summary.copyWith(
        totalSales: current.summary.totalSales + update.salesDelta,
        totalCash: current.summary.totalCash + update.cashDelta,
      ),
      recentOperations: operations,
      lastStreamUpdateAt: update.createdAt,
    );

    return UpdateProcessingResult(
      status: UpdateProcessingStatus.applied,
      snapshot: updatedSnapshot,
    );
  }
}
