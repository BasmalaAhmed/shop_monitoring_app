import 'package:shop_monitoring_app/features/branch_monitoring/data/models/recent_operation_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch_summary.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_snapshot.dart';

class MonitoringSnapshotModel {
  const MonitoringSnapshotModel({
    required this.scopeId,
    required this.sequence,
    required this.totalSales,
    required this.totalCash,
    required this.operations,
    required this.updatedAt,
  });

  final String scopeId;
  final int sequence;
  final int totalSales;
  final int totalCash;
  final List<RecentOperationModel> operations;
  final DateTime updatedAt;

  factory MonitoringSnapshotModel.fromJson(Map<String, dynamic> json) {
    return MonitoringSnapshotModel(
      scopeId: json['scope'] as String,
      sequence: (json['seq'] as num).toInt(),
      totalSales: (json['sales'] as num).toInt(),
      totalCash: (json['cash'] as num).toInt(),
      operations: (json['operations'] as List)
          .map(
            (operation) => RecentOperationModel.fromJson(
              operation as Map<String, dynamic>,
            ),
          )
          .toList(),
      updatedAt: DateTime.parse(json['at'] as String),
    );
  }

  MonitoringSnapshot toEntity() {
    return MonitoringSnapshot(
      scopeId: scopeId,
      sequence: sequence,
      summary: BranchSummary(totalSales: totalSales, totalCash: totalCash),
      recentOperations: operations
          .map((operation) => operation.toEntity())
          .toList(),
      updatedAt: updatedAt,
    );
  }
}
