import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch_summary.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/recent_operation.dart';

class MonitoringSnapshot {
  final String scopeId;
  final int sequence;
  final BranchSummary summary;
  final List<RecentOperation> recentOperations;
  final DateTime updatedAt;
  


  const MonitoringSnapshot({
    required this.scopeId,
    required this.sequence,
    required this.summary,
    required this.recentOperations,
    required this.updatedAt,
  });
}
