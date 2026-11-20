import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/recent_operation.dart';

class MonitoringUpdate {
  final String scopeId;
  final int sequence;
  final int salesDelta;
  final int cashDelta;
  final DateTime createdAt;
  final RecentOperation? operation;

  const MonitoringUpdate({
    required this.scopeId,
    required this.sequence,
    required this.salesDelta,
    required this.cashDelta,
    required this.createdAt,
    this.operation,
  });
}
