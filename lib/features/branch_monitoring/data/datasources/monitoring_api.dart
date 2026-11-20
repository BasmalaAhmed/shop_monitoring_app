import 'package:shop_monitoring_app/features/branch_monitoring/data/models/branch_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/monitoring_snapshot_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/monitoring_update_model.dart';

abstract class MonitoringApi {
  Future<List<BranchModel>> fetchBranches();

  Future<MonitoringSnapshotModel> fetchSnapshot(String scopeId);

  Stream<MonitoringUpdateModel> updates(String scopeId);
}
