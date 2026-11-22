import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shop_monitoring_app/core/errors/network_exception.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch_summary.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/gold_price.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_snapshot.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_update.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/usecases/monitoring_update_processor.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_cubit.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_state.dart';

import '../../../../../helpers/fake_monitoring_dependencies.dart';

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

    test('updates isOnline when connectivity changes', () async {
      await loadCubit();

      expect((cubit.state as BranchMonitoringSuccess).isOnline, true);

      connectivity.setOnline(false);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect((cubit.state as BranchMonitoringSuccess).isOnline, false);
    });

    test(
      'refreshes snapshot and gold price when connectivity returns',
      () async {
        await loadCubit();

        connectivity.setOnline(false);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final goldCallsBefore = goldPriceRepo.getGoldPriceCalls;
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

        connectivity.setOnline(true);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final state = cubit.state as BranchMonitoringSuccess;

        expect(state.isOnline, true);
        expect(state.snapshot.updatedAt, syncedAt);
        expect(goldPriceRepo.getGoldPriceCalls, goldCallsBefore + 1);
      },
    );

    test('does not refresh when connectivity is lost', () async {
      await loadCubit();

      var snapshotCalls = 0;

      monitoringRepo.snapshotHandler = (scopeId) async {
        snapshotCalls++;
        return monitoringRepo.snapshots[scopeId]!;
      };

      connectivity.setOnline(false);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(snapshotCalls, 0);
    });
    group('failed branch switch', () {
      Future<void> failSwitchTo(String scopeId) async {
        monitoringRepo.snapshotHandler = (id) async {
          if (id == scopeId) throw const NetworkException();

          return monitoringRepo.snapshots[id]!;
        };

        await cubit.selectScope(scopeId);
      }

      test('emits a failure that keeps the previous dashboard', () async {
        await loadCubit();
        await failSwitchTo('a1');

        expect(cubit.state, isA<BranchMonitoringFailure>());

        final failure = cubit.state as BranchMonitoringFailure;

        expect(failure.failedScopeId, 'a1');
        expect(failure.previous, isNotNull);
        expect(failure.previous!.selectedScopeId, 'all');
        expect(failure.isNetworkError, true);
      });

      test('backFromFailure returns to the previous dashboard', () async {
        await loadCubit();
        await failSwitchTo('a1');

        cubit.backFromFailure();

        final state = cubit.state as BranchMonitoringSuccess;

        expect(state.selectedScopeId, 'all');
        expect(state.snapshot.summary.totalSales, 100000);
      });

      test(
        'keeps applying updates of the previous branch after a failure',
        () async {
          await loadCubit();
          await failSwitchTo('a1');

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

          cubit.backFromFailure();

          final state = cubit.state as BranchMonitoringSuccess;

          expect(state.snapshot.sequence, 1);
          expect(state.snapshot.summary.totalSales, 101000);
        },
      );

      test('retryFromFailure reloads the failed branch', () async {
        await loadCubit();
        await failSwitchTo('a1');

        monitoringRepo.snapshotHandler = null;

        await cubit.retryFromFailure();

        final state = cubit.state as BranchMonitoringSuccess;

        expect(state.selectedScopeId, 'a1');
      });

      test(
        'retryFromFailure reloads from scratch after a failed first load',
        () async {
          monitoringRepo.snapshotHandler = (_) async =>
              throw const NetworkException();

          await loadCubit();

          expect(cubit.state, isA<BranchMonitoringFailure>());
          expect((cubit.state as BranchMonitoringFailure).previous, isNull);

          monitoringRepo.snapshotHandler = null;

          await cubit.retryFromFailure();

          final state = cubit.state as BranchMonitoringSuccess;

          expect(state.selectedScopeId, 'all');
          expect(state.branches.length, 2);
        },
      );

      test('backFromFailure does nothing after a failed first load', () async {
        monitoringRepo.snapshotHandler = (_) async =>
            throw const NetworkException();

        await loadCubit();

        cubit.backFromFailure();

        expect(cubit.state, isA<BranchMonitoringFailure>());
      });
      test('marks non-network errors as not network errors', () async {
        await loadCubit();

        monitoringRepo.snapshotHandler = (id) async {
          if (id == 'a1') throw StateError('server error');

          return monitoringRepo.snapshots[id]!;
        };

        await cubit.selectScope('a1');

        final failure = cubit.state as BranchMonitoringFailure;

        expect(failure.isNetworkError, false);
      });
    });

        test('does not emit after close when the first load fails late', () async {
      final slow = Completer<List<Branch>>();

      monitoringRepo.branchesHandler = () => slow.future;

      final loading = cubit.load();

      await cubit.close();

      slow.completeError(const NetworkException());

      await loading;
    });

    test('refresh is ignored while a branch is loading', () async {
      await loadCubit();

      final slow = Completer<MonitoringSnapshot>();
      var a1Calls = 0;

      monitoringRepo.snapshotHandler = (id) {
        if (id == 'a1') {
          a1Calls++;
          return slow.future;
        }

        return Future.value(monitoringRepo.snapshots[id]!);
      };

      final pending = cubit.selectScope('a1');

      await cubit.refresh();

      expect(a1Calls, 1);
      expect((cubit.state as BranchMonitoringSuccess).isRefreshing, false);

      slow.complete(monitoringRepo.snapshots['a1']!);
      await pending;
    });
  });
  group('branch switching state', () {
    test('sets loadingScopeId until the snapshot arrives', () async {
      await loadCubit();

      final slow = Completer<MonitoringSnapshot>();

      monitoringRepo.snapshotHandler = (id) {
        if (id == 'a1') return slow.future;

        return Future.value(monitoringRepo.snapshots[id]!);
      };

      final pending = cubit.selectScope('a1');

      var state = cubit.state as BranchMonitoringSuccess;

      expect(state.loadingScopeId, 'a1');
      expect(state.selectedScopeId, 'all');

      slow.complete(monitoringRepo.snapshots['a1']!);
      await pending;

      state = cubit.state as BranchMonitoringSuccess;

      expect(state.loadingScopeId, isNull);
      expect(state.selectedScopeId, 'a1');
    });

    test(
      'ignores a second tap on the branch that is already loading',
      () async {
        await loadCubit();

        var a1Calls = 0;
        final slow = Completer<MonitoringSnapshot>();

        monitoringRepo.snapshotHandler = (id) {
          if (id == 'a1') {
            a1Calls++;
            return slow.future;
          }

          return Future.value(monitoringRepo.snapshots[id]!);
        };

        final pending = cubit.selectScope('a1');
        await cubit.selectScope('a1');

        expect(a1Calls, 1);

        slow.complete(monitoringRepo.snapshots['a1']!);
        await pending;
      },
    );

    test('restores the displayed branch when a second switch fails while '
        'the first is still loading', () async {
      await loadCubit();

      final slow = Completer<MonitoringSnapshot>();

      monitoringRepo.snapshotHandler = (id) {
        if (id == 'a1') return slow.future;

        if (id == 'a2') {
          return Future<MonitoringSnapshot>.error(const NetworkException());
        }

        return Future.value(monitoringRepo.snapshots[id]!);
      };

      final first = cubit.selectScope('a1');
      await cubit.selectScope('a2');

      final failure = cubit.state as BranchMonitoringFailure;

      expect(failure.failedScopeId, 'a2');
      expect(failure.previous!.selectedScopeId, 'all');
      expect(failure.previous!.loadingScopeId, isNull);

      slow.complete(monitoringRepo.snapshots['a1']!);
      await first;

      expect(cubit.state, isA<BranchMonitoringFailure>());

      cubit.backFromFailure();

      final state = cubit.state as BranchMonitoringSuccess;

      expect(state.selectedScopeId, 'all');
      expect(state.loadingScopeId, isNull);
    });
  });
}
