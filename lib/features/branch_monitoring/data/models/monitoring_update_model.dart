import 'package:shop_monitoring_app/features/branch_monitoring/data/models/recent_operation_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_update.dart';

class MonitoringUpdateModel {
  const MonitoringUpdateModel({
    required this.scopeId,
    required this.sequence,
    required this.salesDelta,
    required this.cashDelta,
    required this.createdAt,
    this.operation,
  });

  final String scopeId;
  final int sequence;
  final int salesDelta;
  final int cashDelta;
  final DateTime createdAt;
  final RecentOperationModel? operation;

  factory MonitoringUpdateModel.fromJson(Map<String, dynamic> json) {
    return MonitoringUpdateModel(
      scopeId: json['scope'] as String,
      sequence: (json['seq'] as num).toInt(),
      salesDelta: (json['salesDelta'] as num).toInt(),
      cashDelta: (json['cashDelta'] as num).toInt(),
      createdAt: DateTime.parse(json['at'] as String),
      operation: json['operation'] == null
          ? null
          : RecentOperationModel.fromJson(
              json['operation'] as Map<String, dynamic>,
            ),
    );
  }

  MonitoringUpdate toEntity() {
    return MonitoringUpdate(
      scopeId: scopeId,
      sequence: sequence,
      salesDelta: salesDelta,
      cashDelta: cashDelta,
      createdAt: createdAt,
      operation: operation?.toEntity(),
    );
  }
}
