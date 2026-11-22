import 'dart:async';

import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/connectivity_service.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/gold_price.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_snapshot.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_update.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/repos/gold_price_repo.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/repos/monitoring_repo.dart';

class FakeMonitoringRepo implements MonitoringRepo {
  List<Branch> branches = [];

  Map<String, MonitoringSnapshot> snapshots = {};

  Future<MonitoringSnapshot> Function(String scopeId)? snapshotHandler;

  final Map<String, StreamController<MonitoringUpdate>> _controllers = {};

  Future<List<Branch>> Function()? branchesHandler;

  @override
  Future<List<Branch>> getBranches() async {
    if (branchesHandler != null) return branchesHandler!();

    return branches;
  }

  @override
  Future<MonitoringSnapshot> getSnapshot(String scopeId) async {
    if (snapshotHandler != null) {
      return snapshotHandler!(scopeId);
    }

    return snapshots[scopeId]!;
  }

  final List<MonitoringSnapshot> cachedSnapshots = [];

  @override
  Future<void> cacheSnapshot(MonitoringSnapshot snapshot) async {
    cachedSnapshots.add(snapshot);
  }

  @override
  Stream<MonitoringUpdate> watchUpdates(String scopeId) {
    return _controllers
        .putIfAbsent(
          scopeId,
          () => StreamController<MonitoringUpdate>.broadcast(sync: true),
        )
        .stream;
  }

  void emitUpdate(String scopeId, MonitoringUpdate update) {
    _controllers[scopeId]?.add(update);
  }

  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
  }
}

class FakeGoldPriceRepo implements GoldPriceRepo {
  final _controller = StreamController<GoldPrice>.broadcast();

  int getGoldPriceCalls = 0;

  Future<GoldPrice> Function()? getGoldPriceHandler;

  @override
  Future<GoldPrice> getGoldPrice() async {
    getGoldPriceCalls++;

    if (getGoldPriceHandler != null) {
      return getGoldPriceHandler!();
    }

    return GoldPrice(
      value: 4000,
      sequence: 0,
      updatedAt: DateTime.utc(2026, 11, 20),
    );
  }

  @override
  Stream<GoldPrice> watchGoldPrice() => _controller.stream;

  Future<void> dispose() => _controller.close();

  void emitPrice(GoldPrice price) {
    _controller.add(price);
  }
}

class FakeConnectivityService implements ConnectivityService {
  final _controller = StreamController<bool>.broadcast();

  bool _isOnline = true;

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get changes => _controller.stream;

  void setOnline(bool value) {
    _isOnline = value;
    _controller.add(value);
  }

  Future<void> dispose() => _controller.close();
}
