import 'dart:async';
import 'dart:math';

import 'package:shop_monitoring_app/core/errors/network_exception.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/connectivity_service.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/gold_price_api.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/monitoring_api.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/branch_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/gold_price_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/monitoring_snapshot_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/monitoring_update_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/recent_operation_model.dart';

const String allScope = 'all';

class MockMonitoringApi implements MonitoringApi, GoldPriceApi {
  MockMonitoringApi({required this.connectivity, Random? random})
    : _random = random ?? Random() {
    _initialize();
  }

  final ConnectivityService connectivity;
  final Random _random;

  final List<BranchModel> _branches = const [
    BranchModel(id: 'a1', name: 'فرع القاهرة'),
    BranchModel(id: 'a2', name: 'فرع الإسكندرية'),
    BranchModel(id: 'a3', name: 'فرع المنصورة'),
  ];

  final Map<String, _ScopeState> _scopes = {};

  final _updateControllers =
      <String, StreamController<MonitoringUpdateModel>>{};

  final _goldController = StreamController<GoldPriceModel>.broadcast();

  late GoldPriceModel _goldPrice;

  Timer? _timer;
  int _operationCounter = 0;

  void _initialize() {
    var totalSales = 0;
    var totalCash = 0;

    for (final branch in _branches) {
      final sales = 100000 + _random.nextInt(50000);
      final cash = 40000 + _random.nextInt(20000);

      _scopes[branch.id] = _ScopeState(sales: sales, cash: cash);

      totalSales += sales;
      totalCash += cash;
    }

    _scopes[allScope] = _ScopeState(sales: totalSales, cash: totalCash);

    _goldPrice = GoldPriceModel(
      value: 4000,
      sequence: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<List<BranchModel>> fetchBranches() async {
    await _simulateNetworkDelay();

    return List.unmodifiable(_branches);
  }

  @override
  Future<MonitoringSnapshotModel> fetchSnapshot(String scopeId) async {
    await _simulateNetworkDelay();

    final state = _scopes[scopeId];

    if (state == null) {
      throw ArgumentError('Unknown scope: $scopeId');
    }

    return MonitoringSnapshotModel(
      scopeId: scopeId,
      sequence: state.sequence,
      totalSales: state.sales,
      totalCash: state.cash,
      operations: List.unmodifiable(state.operations),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Stream<MonitoringUpdateModel> updates(String scopeId) {
    if (!_scopes.containsKey(scopeId)) {
      throw ArgumentError('Unknown scope: $scopeId');
    }

    return _updateControllers
        .putIfAbsent(
          scopeId,
          () => StreamController<MonitoringUpdateModel>.broadcast(),
        )
        .stream;
  }

  @override
  Future<GoldPriceModel> fetchGoldPrice() async {
    await _simulateNetworkDelay();
    return _goldPrice;
  }

  @override
  Stream<GoldPriceModel> goldPriceUpdates() {
    return _goldController.stream;
  }

  Future<void> _simulateNetworkDelay() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!connectivity.isOnline) {
      throw const NetworkException();
    }
  }

  void startSimulation({Duration every = const Duration(seconds: 3)}) {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => _tick());
  }

  void _tick() {
    if (!connectivity.isOnline) return;

    final branch = _branches[_random.nextInt(_branches.length)];

    final amount = (1 + _random.nextInt(20)) * 500;
    final now = DateTime.now().toUtc();

    final operation = RecentOperationModel(
      id: 'op-${++_operationCounter}',
      title: 'بيع ذهب - ${branch.name}',
      amount: amount,
      at: now,
    );

    _applySale(branch.id, amount, operation, now);
    _applySale(allScope, amount, operation, now);

    if (_random.nextInt(4) == 0) {
      _updateGoldPrice();
    }
  }

  void _applySale(
    String scopeId,
    int amount,
    RecentOperationModel operation,
    DateTime now,
  ) {
    final state = _scopes[scopeId]!;

    state.sequence++;
    state.sales += amount;
    state.cash += amount;

    state.operations.insert(0, operation);

    if (state.operations.length > 20) {
      state.operations.removeLast();
    }

    final update = MonitoringUpdateModel(
      scopeId: scopeId,
      sequence: state.sequence,
      salesDelta: amount,
      cashDelta: amount,
      createdAt: now,
      operation: operation,
    );

    final controller = _updateControllers[scopeId];

    if (controller != null && controller.hasListener) {
      controller.add(update);
    }
  }

  void _updateGoldPrice() {
    final change = _random.nextInt(41) - 20;

    _goldPrice = GoldPriceModel(
      value: _goldPrice.value + change,
      sequence: _goldPrice.sequence + 1,
      updatedAt: DateTime.now().toUtc(),
    );

    if (_goldController.hasListener) {
      _goldController.add(_goldPrice);
    }
  }

  void dispose() {
    _timer?.cancel();

    for (final controller in _updateControllers.values) {
      controller.close();
    }

    _goldController.close();
  }
}

class _ScopeState {
  _ScopeState({required this.sales, required this.cash});

  int sequence = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  int sales;
  int cash;

  final List<RecentOperationModel> operations = [];
}
