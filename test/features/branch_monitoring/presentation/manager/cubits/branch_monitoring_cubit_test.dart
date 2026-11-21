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
  late FakeMonitoringRepo monitoringRepo;
  late FakeGoldPriceRepo goldPriceRepo;
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
    monitoringRepo = FakeMonitoringRepo();

    goldPriceRepo = FakeGoldPriceRepo();

    connectivity = FakeConnectivityService();

    monitoringRepo.branches = const [
      Branch(id: 'a1', name: 'فرع القاهرة'),
      Branch(id: 'a2', name: 'فرع الإسكندرية'),
    ];

    monitoringRepo.snapshots = {
      'all': createSnapshot(scopeId: 'all'),
      'a1': createSnapshot(scopeId: 'a1'),
      'a2': createSnapshot(scopeId: 'a2'),
    };

    cubit = BranchMonitoringCubit(
      monitoringRepo: monitoringRepo,
      goldPriceRepo: goldPriceRepo,
      connectivity: connectivity,
      updateProcessor: const MonitoringUpdateProcessor(),
    );
  });

  tearDown(() async {
    await cubit.close();
    await monitoringRepo.dispose();
    await goldPriceRepo.dispose();
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

      monitoringRepo.emitUpdate('all', update);
      monitoringRepo.emitUpdate('all', update);

      final state = cubit.state as BranchMonitoringSuccess;

      expect(state.snapshot.sequence, 1);
      expect(state.snapshot.summary.totalSales, 101000);
      expect(state.snapshot.summary.totalCash, 50500);
    });

    test('recovers snapshot when a sequence gap is detected', () async {
      await loadCubit();

      monitoringRepo.snapshotHandler = (scopeId) async {
        if (scopeId == 'all') {
          return createSnapshot(
            scopeId: 'all',
            sequence: 2,
            sales: 102000,
            cash: 51000,
          );
        }

        return monitoringRepo.snapshots[scopeId]!;
      };

      final update = MonitoringUpdate(
        scopeId: 'all',
        sequence: 2,
        salesDelta: 2000,
        cashDelta: 1000,
        createdAt: now,
      );

      monitoringRepo.emitUpdate('all', update);

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

      monitoringRepo.snapshotHandler = (scopeId) async {
        if (scopeId == 'a1') {
          if (!firstRequestStarted.isCompleted) {
            firstRequestStarted.complete();
          }

          return delayedResponse.future;
        }

        return monitoringRepo.snapshots[scopeId]!;
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

      monitoringRepo.snapshotHandler = (scopeId) async {
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

      monitoringRepo.emitUpdate('all', update);

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

      monitoringRepo.emitUpdate(
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

      monitoringRepo.emitUpdate(
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
    test('updates gold price without changing branch snapshot', () async {
      await loadCubit();

      final initialState = cubit.state as BranchMonitoringSuccess;

      final initialSequence = initialState.snapshot.sequence;
      final initialSales = initialState.snapshot.summary.totalSales;
      final initialCash = initialState.snapshot.summary.totalCash;

      goldPriceRepo.emitPrice(
        GoldPrice(value: 4200, sequence: 1, updatedAt: now),
      );

      await Future<void>.delayed(Duration.zero);

      final updatedState = cubit.state as BranchMonitoringSuccess;

      expect(updatedState.goldPrice?.value, 4200);
      expect(updatedState.goldPrice?.sequence, 1);

      expect(updatedState.snapshot.sequence, initialSequence);
      expect(updatedState.snapshot.summary.totalSales, initialSales);
      expect(updatedState.snapshot.summary.totalCash, initialCash);
    });

    test('ignores outdated and duplicate gold price updates', () async {
      await loadCubit();

      goldPriceRepo.emitPrice(
        GoldPrice(value: 4200, sequence: 2, updatedAt: now),
      );

      await Future<void>.delayed(Duration.zero);

      goldPriceRepo.emitPrice(
        GoldPrice(value: 4100, sequence: 1, updatedAt: now),
      );

      await Future<void>.delayed(Duration.zero);

      var state = cubit.state as BranchMonitoringSuccess;

      expect(state.goldPrice?.value, 4200);
      expect(state.goldPrice?.sequence, 2);

      goldPriceRepo.emitPrice(
        GoldPrice(value: 4200, sequence: 2, updatedAt: now),
      );

      await Future<void>.delayed(Duration.zero);

      state = cubit.state as BranchMonitoringSuccess;

      expect(state.goldPrice?.value, 4200);
      expect(state.goldPrice?.sequence, 2);
    });
    test(
      'ignores outdated refresh response when a newer refresh completes',
      () async {
        await loadCubit();

        final oldRequest = Completer<MonitoringSnapshot>();
        var requestCount = 0;

        monitoringRepo.snapshotHandler = (scopeId) {
          requestCount++;

          if (requestCount == 1) {
            return oldRequest.future;
          }

          return Future.value(
            createSnapshot(
              scopeId: 'all',
              sequence: 1,
              sales: 101000,
              cash: 50500,
            ),
          );
        };

        final firstRefresh = cubit.refresh();

        await Future<void>.delayed(Duration.zero);

        final secondRefresh = cubit.refresh();

        await secondRefresh;

        oldRequest.complete(
          createSnapshot(
            scopeId: 'all',
            sequence: 0,
            sales: 100000,
            cash: 50000,
          ),
        );

        await firstRefresh;

        final state = cubit.state as BranchMonitoringSuccess;

        expect(state.snapshot.sequence, 1);
        expect(state.snapshot.summary.totalSales, 101000);
        expect(state.snapshot.summary.totalCash, 50500);
        expect(state.isRefreshing, false);
      },
    );

    test(
      'updates updatedAt on successful refresh even if data is unchanged',
      () async {
        await loadCubit();

        final syncedAt = now.add(const Duration(minutes: 10));

        monitoringRepo.snapshotHandler = (scopeId) async {
          return MonitoringSnapshot(
            scopeId: scopeId,
            sequence: 0,
            summary: BranchSummary(totalSales: 100000, totalCash: 50000),
            recentOperations: const [],
            updatedAt: syncedAt,
          );
        };

        await cubit.refresh();

        final state = cubit.state as BranchMonitoringSuccess;

        expect(state.snapshot.sequence, 0);
        expect(state.snapshot.summary.totalSales, 100000);
        expect(state.snapshot.updatedAt, syncedAt);
        expect(state.isRefreshing, false);
      },
    );

    test(
      'keeps in-memory data and times when refresh falls back to older cache',
      () async {
        await loadCubit();

        final streamTime = now.add(const Duration(minutes: 5));

        monitoringRepo.emitUpdate(
          'all',
          MonitoringUpdate(
            scopeId: 'all',
            sequence: 1,
            salesDelta: 1000,
            cashDelta: 500,
            createdAt: streamTime,
          ),
        );

        monitoringRepo.snapshotHandler = (scopeId) async {
          return MonitoringSnapshot(
            scopeId: scopeId,
            sequence: 0,
            summary: BranchSummary(totalSales: 100000, totalCash: 50000),
            recentOperations: const [],
            updatedAt: now,
            isFromCache: true,
          );
        };

        await cubit.refresh();

        final state = cubit.state as BranchMonitoringSuccess;

        expect(state.snapshot.sequence, 1);
        expect(state.snapshot.summary.totalSales, 101000);
        expect(state.snapshot.updatedAt, now);
        expect(state.snapshot.lastStreamUpdateAt, streamTime);
        expect(state.snapshot.lastDataAt, streamTime);
        expect(state.isRefreshing, false);
      },
    );
    test('caches the snapshot after an applied update', () async {
      await loadCubit();

      final streamTime = now.add(const Duration(minutes: 5));

      monitoringRepo.emitUpdate(
        'all',
        MonitoringUpdate(
          scopeId: 'all',
          sequence: 1,
          salesDelta: 1000,
          cashDelta: 500,
          createdAt: streamTime,
        ),
      );

      expect(monitoringRepo.cachedSnapshots.length, 1);

      final cached = monitoringRepo.cachedSnapshots.single;

      expect(cached.sequence, 1);
      expect(cached.summary.totalSales, 101000);
      expect(cached.updatedAt, now);
      expect(cached.lastStreamUpdateAt, streamTime);
    });

    test('does not cache again for a duplicate update', () async {
      await loadCubit();

      final update = MonitoringUpdate(
        scopeId: 'all',
        sequence: 1,
        salesDelta: 1000,
        cashDelta: 500,
        createdAt: now,
      );

      monitoringRepo.emitUpdate('all', update);
      monitoringRepo.emitUpdate('all', update);

      expect(monitoringRepo.cachedSnapshots.length, 1);
    });
  });
}

class FakeMonitoringRepo implements MonitoringRepo {
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

  void emitPrice(GoldPrice price) {
    _controller.add(price);
  }
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
