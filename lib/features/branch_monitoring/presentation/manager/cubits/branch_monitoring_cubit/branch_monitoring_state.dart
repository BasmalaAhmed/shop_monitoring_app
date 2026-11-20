import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/gold_price.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_snapshot.dart';

sealed class BranchMonitoringState {
  const BranchMonitoringState();
}

final class BranchMonitoringInitial extends BranchMonitoringState {
  const BranchMonitoringInitial();
}

final class BranchMonitoringLoading extends BranchMonitoringState {
  const BranchMonitoringLoading();
}

final class BranchMonitoringSuccess extends BranchMonitoringState {
  const BranchMonitoringSuccess({
    required this.branches,
    required this.selectedScopeId,
    required this.snapshot,
    required this.goldPrice,
    required this.isOnline,
    this.isRefreshing = false,
  });

  final List<Branch> branches;
  final String selectedScopeId;
  final MonitoringSnapshot snapshot;
  final GoldPrice? goldPrice;
  final bool isOnline;
  final bool isRefreshing;

  BranchMonitoringSuccess copyWith({
    List<Branch>? branches,
    String? selectedScopeId,
    MonitoringSnapshot? snapshot,
    GoldPrice? goldPrice,
    bool? isOnline,
    bool? isRefreshing,
  }) {
    return BranchMonitoringSuccess(
      branches: branches ?? this.branches,
      selectedScopeId: selectedScopeId ?? this.selectedScopeId,
      snapshot: snapshot ?? this.snapshot,
      goldPrice: goldPrice ?? this.goldPrice,
      isOnline: isOnline ?? this.isOnline,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

final class BranchMonitoringFailure extends BranchMonitoringState {
  const BranchMonitoringFailure(this.errorMessage);

  final String errorMessage;
}
