import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch_summary.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/recent_operation.dart';

class MonitoringSnapshot {
  final String scopeId;
  final int sequence;
  final BranchSummary summary;
  final List<RecentOperation> recentOperations;
  final DateTime updatedAt;
  final DateTime? lastStreamUpdateAt;
  final bool isFromCache;

  const MonitoringSnapshot({
    required this.scopeId,
    required this.sequence,
    required this.summary,
    required this.recentOperations,
    required this.updatedAt,
    this.lastStreamUpdateAt,
    this.isFromCache = false,
  });

  DateTime get lastDataAt {
    final streamAt = lastStreamUpdateAt;
    if (streamAt != null && streamAt.isAfter(updatedAt)) return streamAt;
    return updatedAt;
  }

  MonitoringSnapshot copyWith({
    int? sequence,
    BranchSummary? summary,
    List<RecentOperation>? recentOperations,
    DateTime? updatedAt,
    DateTime? lastStreamUpdateAt,
    bool? isFromCache,
  }) {
    return MonitoringSnapshot(
      scopeId: scopeId,
      sequence: sequence ?? this.sequence,
      summary: summary ?? this.summary,
      recentOperations: recentOperations ?? this.recentOperations,
      updatedAt: updatedAt ?? this.updatedAt,
      lastStreamUpdateAt: lastStreamUpdateAt ?? this.lastStreamUpdateAt,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }
}
