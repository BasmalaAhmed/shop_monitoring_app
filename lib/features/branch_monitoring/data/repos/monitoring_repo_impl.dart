import 'package:shop_monitoring_app/core/errors/network_exception.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/monitoring_api.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/monitoring_local_data_source.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/monitoring_snapshot_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_snapshot.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_update.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/repos/monitoring_repo.dart';

class MonitoringRepoImpl implements MonitoringRepo {
  MonitoringRepoImpl(
    this._api,
    this._localDataSource, {
    this.accountId = 'demo_shop',
  });

  final MonitoringApi _api;
  final MonitoringLocalDataSource _localDataSource;
  final String accountId;

  @override
  Future<List<Branch>> getBranches() async {
    try {
      final models = await _api.fetchBranches();

      await _localDataSource.cacheBranches(
        accountId: accountId,
        branches: models,
      );

      return models.map((model) => model.toEntity()).toList();
    } on NetworkException {
      final cachedBranches = await _localDataSource.getCachedBranches(
        accountId: accountId,
      );

      if (cachedBranches != null) {
        return cachedBranches.map((model) => model.toEntity()).toList();
      }

      rethrow;
    }
  }

  @override
  Future<MonitoringSnapshot> getSnapshot(String scopeId) async {
    try {
      final model = await _api.fetchSnapshot(scopeId);

      await _localDataSource.cacheSnapshot(
        accountId: accountId,
        snapshot: model,
      );

      return model.toEntity();
    } on NetworkException {
      final cachedSnapshot = await _localDataSource.getCachedSnapshot(
        accountId: accountId,
        scopeId: scopeId,
      );

      if (cachedSnapshot != null) {
        return cachedSnapshot.toEntity(isFromCache: true);
      }

      rethrow;
    }
  }

  @override
  Future<void> cacheSnapshot(MonitoringSnapshot snapshot) {
    return _localDataSource.cacheSnapshot(
      accountId: accountId,
      snapshot: MonitoringSnapshotModel.fromEntity(snapshot),
    );
  }

  @override
  Stream<MonitoringUpdate> watchUpdates(String scopeId) {
    return _api.updates(scopeId).map((model) => model.toEntity());
  }
}
