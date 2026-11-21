

import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_snapshot.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_update.dart';

abstract class MonitoringRepo {
  Future<List<Branch>> getBranches();

  Future<MonitoringSnapshot> getSnapshot(String scopeId);

  Stream<MonitoringUpdate> watchUpdates(String scopeId);

    Future<void> cacheSnapshot(MonitoringSnapshot snapshot);
}