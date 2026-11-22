import 'package:flutter_test/flutter_test.dart';
import 'package:shop_monitoring_app/core/errors/network_exception.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/monitoring_api.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/branch_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/monitoring_snapshot_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/monitoring_update_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/repos/monitoring_repo_impl.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch_summary.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_snapshot.dart';
import '../../helpers/fake_local_data_source.dart';


class FakeMonitoringApi implements MonitoringApi {
  Future<List<BranchModel>> Function() branchesHandler = () async => [];

  Future<MonitoringSnapshotModel> Function(String scopeId) snapshotHandler =
      (scopeId) async => throw UnimplementedError();

  @override
  Future<List<BranchModel>> fetchBranches() => branchesHandler();

  @override
  Future<MonitoringSnapshotModel> fetchSnapshot(String scopeId) {
    return snapshotHandler(scopeId);
  }

  @override
  Stream<MonitoringUpdateModel> updates(String scopeId) {
    return Stream<MonitoringUpdateModel>.empty();
  }
}

void main() {
  late FakeMonitoringApi api;
  late FakeLocalDataSource local;
  late MonitoringRepoImpl repo;

  final serverTime = DateTime.utc(2026, 11, 21, 10, 0);
  final cachedTime = DateTime.utc(2026, 11, 21, 9, 0);

  MonitoringSnapshotModel snapshotModel({
    int sequence = 5,
    int sales = 1000,
    required DateTime at,
  }) {
    return MonitoringSnapshotModel(
      scopeId: 'all',
      sequence: sequence,
      totalSales: sales,
      totalCash: 500,
      operations: const [],
      updatedAt: at,
    );
  }

  setUp(() {
    api = FakeMonitoringApi();
    local = FakeLocalDataSource();
    repo = MonitoringRepoImpl(api, local, accountId: 'shop_1');
  });

  group('getSnapshot', () {
    test('returns the server snapshot and caches it', () async {
      api.snapshotHandler = (_) async => snapshotModel(at: serverTime);

      final result = await repo.getSnapshot('all');

      expect(result.sequence, 5);
      expect(result.isFromCache, false);
      expect(result.updatedAt, serverTime);

      final cached = await local.getCachedSnapshot(
        accountId: 'shop_1',
        scopeId: 'all',
      );

      expect(cached, isNotNull);
      expect(cached!.sequence, 5);
    });

    test('falls back to the cache on NetworkException', () async {
      await local.cacheSnapshot(
        accountId: 'shop_1',
        snapshot: snapshotModel(sequence: 3, sales: 700, at: cachedTime),
      );

      api.snapshotHandler = (_) async => throw const NetworkException();

      final result = await repo.getSnapshot('all');

      expect(result.isFromCache, true);
      expect(result.sequence, 3);
      expect(result.summary.totalSales, 700);
      expect(result.updatedAt, cachedTime);
    });

    test('rethrows NetworkException when there is no cache', () async {
      api.snapshotHandler = (_) async => throw const NetworkException();

      expect(() => repo.getSnapshot('all'), throwsA(isA<NetworkException>()));
    });

    test('does not use the cache for other errors', () async {
      await local.cacheSnapshot(
        accountId: 'shop_1',
        snapshot: snapshotModel(at: cachedTime),
      );

      api.snapshotHandler = (_) async => throw StateError('server error');

      expect(() => repo.getSnapshot('all'), throwsA(isA<StateError>()));
    });

    test('does not read the cache of another account', () async {
      await local.cacheSnapshot(
        accountId: 'shop_2',
        snapshot: snapshotModel(at: cachedTime),
      );

      api.snapshotHandler = (_) async => throw const NetworkException();

      expect(() => repo.getSnapshot('all'), throwsA(isA<NetworkException>()));
    });
  });

  group('getBranches', () {
    const cairo = BranchModel(id: 'a1', name: 'القاهرة');
    const alex = BranchModel(id: 'a2', name: 'الإسكندرية');

    test('returns the server branches and caches them', () async {
      api.branchesHandler = () async => [cairo, alex];

      final result = await repo.getBranches();

      expect(result.map((branch) => branch.id), ['a1', 'a2']);

      final cached = await local.getCachedBranches(accountId: 'shop_1');

      expect(cached!.map((branch) => branch.id), ['a1', 'a2']);
    });

    test('falls back to cached branches on NetworkException', () async {
      await local.cacheBranches(accountId: 'shop_1', branches: [cairo]);

      api.branchesHandler = () async => throw const NetworkException();

      final result = await repo.getBranches();

      expect(result.length, 1);
      expect(result.first.id, 'a1');
      expect(result.first.name, 'القاهرة');
    });

    test(
      'rethrows NetworkException when there are no cached branches',
      () async {
        api.branchesHandler = () async => throw const NetworkException();

        expect(() => repo.getBranches(), throwsA(isA<NetworkException>()));
      },
    );
  });

  group('cacheSnapshot', () {
    test(
      'stores the snapshot for the repo account with its stream time',
      () async {
        final streamAt = DateTime.utc(2026, 11, 21, 10, 5);

        await repo.cacheSnapshot(
          MonitoringSnapshot(
            scopeId: 'all',
            sequence: 8,
            summary: BranchSummary(totalSales: 2000, totalCash: 900),
            recentOperations: const [],
            updatedAt: serverTime,
            lastStreamUpdateAt: streamAt,
          ),
        );

        final cached = await local.getCachedSnapshot(
          accountId: 'shop_1',
          scopeId: 'all',
        );

        expect(cached, isNotNull);
        expect(cached!.sequence, 8);
        expect(cached.totalSales, 2000);
        expect(cached.updatedAt, serverTime);
        expect(cached.lastStreamUpdateAt, streamAt);
      },
    );
  });
}
