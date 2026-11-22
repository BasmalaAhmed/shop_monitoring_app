import 'package:shop_monitoring_app/features/branch_monitoring/data/models/branch_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/gold_price_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/monitoring_snapshot_model.dart';

abstract class MonitoringLocalDataSource {
  Future<void> cacheBranches({
    required String accountId,
    required List<BranchModel> branches,
  });

  Future<List<BranchModel>?> getCachedBranches({
    required String accountId,
  });

  Future<void> cacheSnapshot({
    required String accountId,
    required MonitoringSnapshotModel snapshot,
  });

  Future<MonitoringSnapshotModel?> getCachedSnapshot({
    required String accountId,
    required String scopeId,
  });

    Future<void> cacheGoldPrice({
    required String accountId,
    required GoldPriceModel goldPrice,
  });

  Future<GoldPriceModel?> getCachedGoldPrice({
    required String accountId,
  });

    Future<void> clearAccount({required String accountId});
}