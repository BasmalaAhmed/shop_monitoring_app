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
    this.lastStreamUpdateAt,
  });

  final String scopeId;
  final int sequence;
  final int totalSales;
  final int totalCash;
  final List<RecentOperationModel> operations;
  final DateTime updatedAt;
  final DateTime? lastStreamUpdateAt;

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

  factory MonitoringSnapshotModel.fromEntity(MonitoringSnapshot snapshot) {
    return MonitoringSnapshotModel(
      scopeId: snapshot.scopeId,
      sequence: snapshot.sequence,
      totalSales: snapshot.summary.totalSales,
      totalCash: snapshot.summary.totalCash,
      operations: snapshot.recentOperations
          .map(RecentOperationModel.fromEntity)
          .toList(),
      updatedAt: snapshot.updatedAt,
      lastStreamUpdateAt: snapshot.lastStreamUpdateAt,
    );
  }

  MonitoringSnapshot toEntity({bool isFromCache = false}) {
    return MonitoringSnapshot(
      scopeId: scopeId,
      sequence: sequence,
      isFromCache: isFromCache,
      summary: BranchSummary(totalSales: totalSales, totalCash: totalCash),
      recentOperations: operations
          .map((operation) => operation.toEntity())
          .toList(),
      updatedAt: updatedAt,
      lastStreamUpdateAt: lastStreamUpdateAt,
    );
  }
}
