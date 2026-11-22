import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/monitoring_local_data_source.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/branch_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/gold_price_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/monitoring_snapshot_model.dart';

class FakeLocalDataSource implements MonitoringLocalDataSource {
  final Map<String, List<BranchModel>> branchesByAccount = {};
  final Map<String, MonitoringSnapshotModel> snapshotsByKey = {};
  final Map<String, GoldPriceModel> goldByAccount = {};

  String _key(String accountId, String scopeId) => '$accountId|$scopeId';

  @override
  Future<void> cacheBranches({
    required String accountId,
    required List<BranchModel> branches,
  }) async {
    branchesByAccount[accountId] = branches;
  }

  @override
  Future<List<BranchModel>?> getCachedBranches({
    required String accountId,
  }) async {
    return branchesByAccount[accountId];
  }

  @override
  Future<void> cacheSnapshot({
    required String accountId,
    required MonitoringSnapshotModel snapshot,
  }) async {
    snapshotsByKey[_key(accountId, snapshot.scopeId)] = snapshot;
  }

  @override
  Future<MonitoringSnapshotModel?> getCachedSnapshot({
    required String accountId,
    required String scopeId,
  }) async {
    return snapshotsByKey[_key(accountId, scopeId)];
  }

  @override
  Future<void> cacheGoldPrice({
    required String accountId,
    required GoldPriceModel goldPrice,
  }) async {
    goldByAccount[accountId] = goldPrice;
  }

  @override
  Future<GoldPriceModel?> getCachedGoldPrice({
    required String accountId,
  }) async {
    return goldByAccount[accountId];
  }

  @override
  Future<void> clearAccount({required String accountId}) async {
    branchesByAccount.remove(accountId);
    snapshotsByKey.removeWhere((key, _) => key.startsWith('$accountId|'));
    goldByAccount.remove(accountId);
  }
}
