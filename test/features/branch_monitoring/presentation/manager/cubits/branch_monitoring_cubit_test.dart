import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch_summary.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/gold_price.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_snapshot.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_update.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/repos/gold_price_repo.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/repos/monitoring_repo.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/usecases/monitoring_update_processor.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/connectivity_service.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_cubit.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_state.dart';

void main() {
  late FakeMonitoringRepository monitoringRepository;
  late FakeGoldPriceRepository goldPriceRepository;
  late FakeConnectivityService connectivity;
  late BranchMonitoringCubit cubit;

  final now = DateTime.utc(2026, 11, 20);

  MonitoringSnapshot createSnapshot({
    required String scopeId,
    int sequence = 0,
    int sales = 100000,
    int cash = 50000,
  }) {
    return MonitoringSnapshot(
      scopeId: scopeId,
      sequence: sequence,
      summary: BranchSummary(totalSales: sales, totalCash: cash),
      recentOperations: const [],
      updatedAt: now,
    );
  }

  setUp(() {
    monitoringRepository = FakeMonitoringRepository();

    goldPriceRepository = FakeGoldPriceRepository();

    connectivity = FakeConnectivityService();

    monitoringRepository.branches = const [
      Branch(id: 'a1', name: 'فرع القاهرة'),
      Branch(id: 'a2', name: 'فرع الإسكندرية'),
    ];

    monitoringRepository.snapshots = {
      'all': createSnapshot(scopeId: 'all'),
      'a1': createSnapshot(scopeId: 'a1'),
      'a2': createSnapshot(scopeId: 'a2'),
    };

    cubit = BranchMonitoringCubit(
      monitoringRepository: monitoringRepository,
      goldPriceRepository: goldPriceRepository,
      connectivity: connectivity,
      updateProcessor: const MonitoringUpdateProcessor(),
    );
  });

  tearDown(() async {
    await cubit.close();
    await monitoringRepository.dispose();
    await goldPriceRepository.dispose();
    await connectivity.dispose();
  });

  Future<void> loadCubit() async {
    await cubit.load();
  }

  group('BranchMonitoringCubit', () {
    test('loads branches and initial snapshot', () async {
      await loadCubit();

      expect(cubit.state, isA<BranchMonitoringSuccess>());

      final state = cubit.state as BranchMonitoringSuccess;

      expect(state.branches.length, 2);
      expect(state.selectedScopeId, 'all');
      expect(state.snapshot.summary.totalSales, 100000);
    });

    test('applies an update only once', () async {
      await loadCubit();

      final update = MonitoringUpdate(
        scopeId: 'all',
        sequence: 1,
        salesDelta: 1000,
        cashDelta: 500,
        createdAt: now,
      );

      monitoringRepository.emitUpdate('all', update);
      monitoringRepository.emitUpdate('all', update);

      final state = cubit.state as BranchMonitoringSuccess;

      expect(state.snapshot.sequence, 1);
      expect(state.snapshot.summary.totalSales, 101000);
      expect(state.snapshot.summary.totalCash, 50500);
    });

    test('recovers snapshot when a sequence gap is detected', () async {
      await loadCubit();

      monitoringRepository.snapshotHandler = (scopeId) async {
        if (scopeId == 'all') {
          return createSnapshot(
            scopeId: 'all',
            sequence: 2,
            sales: 102000,
            cash: 51000,
          );
        }

        return monitoringRepository.snapshots[scopeId]!;
      };

      final update = MonitoringUpdate(
        scopeId: 'all',
        sequence: 2,
        salesDelta: 2000,
        cashDelta: 1000,
        createdAt: now,
      );

      monitoringRepository.emitUpdate('all', update);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      final state = cubit.state as BranchMonitoringSuccess;

      expect(state.snapshot.sequence, 2);
      expect(state.snapshot.summary.totalSales, 102000);
      expect(state.snapshot.summary.totalCash, 51000);
    });

    test('ignores delayed response from previously selected branch', () async {
      await loadCubit();

      final delayedResponse = Completer<MonitoringSnapshot>();
      final firstRequestStarted = Completer<void>();

      monitoringRepository.snapshotHandler = (scopeId) async {
        if (scopeId == 'a1') {
          if (!firstRequestStarted.isCompleted) {
            firstRequestStarted.complete();
          }

          return delayedResponse.future;
        }

        return monitoringRepository.snapshots[scopeId]!;
      };

      final firstSelection = cubit.selectScope('a1');

      await firstRequestStarted.future;

      await cubit.selectScope('a2');

      delayedResponse.complete(createSnapshot(scopeId: 'a1', sales: 200000));

      await firstSelection;

      final state = cubit.state as BranchMonitoringSuccess;

      expect(state.selectedScopeId, 'a2');
      expect(state.snapshot.scopeId, 'a2');
      expect(state.snapshot.summary.totalSales, 100000);
    });
    test('retries pending updates after recovery failure', () async {
      await loadCubit();

      var recoveryAttempts = 0;

      monitoringRepository.snapshotHandler = (scopeId) async {
        recoveryAttempts++;

        if (recoveryAttempts == 1) {
          throw Exception('Network error');
        }

        return createSnapshot(
          scopeId: 'all',
          sequence: 1,
          sales: 101000,
          cash: 50500,
        );
      };

      final update = MonitoringUpdate(
        scopeId: 'all',
        sequence: 2,
        salesDelta: 2000,
        cashDelta: 1000,
        createdAt: now,
      );

      monitoringRepository.emitUpdate('all', update);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      var state = cubit.state as BranchMonitoringSuccess;

      expect(state.snapshot.sequence, 0);
      expect(state.snapshot.summary.totalSales, 100000);

      await cubit.refresh();

      state = cubit.state as BranchMonitoringSuccess;

      expect(state.snapshot.sequence, 2);
      expect(state.snapshot.summary.totalSales, 103000);
      expect(state.snapshot.summary.totalCash, 51500);
    });
    test('applies pending updates when missing update arrives', () async {
      await loadCubit();

      // Update 2 arrives first, so it should be pending.
      monitoringRepository.emitUpdate(
        'all',
        MonitoringUpdate(
          scopeId: 'all',
          sequence: 2,
          salesDelta: 2000,
          cashDelta: 1000,
          createdAt: now,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Update 1 arrives afterward.
      monitoringRepository.emitUpdate(
        'all',
        MonitoringUpdate(
          scopeId: 'all',
          sequence: 1,
          salesDelta: 1000,
          cashDelta: 500,
          createdAt: now,
        ),
      );

      final state = cubit.state as BranchMonitoringSuccess;

      expect(state.snapshot.sequence, 2);
      expect(state.snapshot.summary.totalSales, 103000);
      expect(state.snapshot.summary.totalCash, 51500);
    });
  });
}

class FakeMonitoringRepository implements MonitoringRepository {
  List<Branch> branches = [];

  Map<String, MonitoringSnapshot> snapshots = {};

  Future<MonitoringSnapshot> Function(String scopeId)? snapshotHandler;

  final Map<String, StreamController<MonitoringUpdate>> _controllers = {};

  @override
  Future<List<Branch>> getBranches() async => branches;

  @override
  Future<MonitoringSnapshot> getSnapshot(String scopeId) async {
    if (snapshotHandler != null) {
      return snapshotHandler!(scopeId);
    }

    return snapshots[scopeId]!;
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

class FakeGoldPriceRepository implements GoldPriceRepository {
  final _controller = StreamController<GoldPrice>.broadcast();

  @override
  Future<GoldPrice> getGoldPrice() async {
    return GoldPrice(
      value: 4000,
      sequence: 0,
      updatedAt: DateTime.utc(2026, 11, 20),
    );
  }

  @override
  Stream<GoldPrice> watchGoldPrice() => _controller.stream;

  Future<void> dispose() => _controller.close();
}

class FakeConnectivityService implements ConnectivityService {
  final _controller = StreamController<bool>.broadcast();

  final bool _isOnline = true;

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get changes => _controller.stream;

  Future<void> dispose() => _controller.close();
}
