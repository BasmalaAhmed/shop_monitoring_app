import 'package:shop_monitoring_app/core/errors/network_exception.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/monitoring_api.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_snapshot.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_update.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/repos/monitoring_repo.dart';

class MonitoringRepoImpl implements MonitoringRepo {
  MonitoringRepoImpl(this._api);

  final MonitoringApi _api;

  final Map<String, MonitoringSnapshot> _cachedSnapshots = {};

  List<Branch>? _cachedBranches;

  @override
  Future<List<Branch>> getBranches() async {
    try {
      final models = await _api.fetchBranches();

      final branches = models.map((model) => model.toEntity()).toList();

      _cachedBranches = branches;

      return branches;
    } on NetworkException {
      if (_cachedBranches != null) return _cachedBranches!;
      rethrow;
    }
  }

  @override
  Future<MonitoringSnapshot> getSnapshot(String scopeId) async {
    try {
      final model = await _api.fetchSnapshot(scopeId);
      final snapshot = model.toEntity();

      _cachedSnapshots[scopeId] = snapshot;

      return snapshot;
    } on NetworkException {
      final cachedSnapshot = _cachedSnapshots[scopeId];

      if (cachedSnapshot != null) return cachedSnapshot;

      rethrow;
    }
  }

  @override
  Stream<MonitoringUpdate> watchUpdates(String scopeId) {
    return _api.updates(scopeId).map((model) => model.toEntity());
  }
}
