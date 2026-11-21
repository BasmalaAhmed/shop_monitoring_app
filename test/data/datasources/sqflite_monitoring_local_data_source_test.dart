import 'package:flutter_test/flutter_test.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/branch_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/gold_price_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/monitoring_snapshot_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/monitoring_database.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/sqflite_monitoring_local_data_source.dart';

void main() {
  late Database database;
  late SqfliteMonitoringLocalDataSource dataSource;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

    await MonitoringDatabase.createTables(database);

    dataSource = SqfliteMonitoringLocalDataSource(
      MonitoringDatabase(database: database),
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('Branches local storage', () {
    test('should cache and retrieve branches for an account', () async {
      const branches = [
        BranchModel(id: 'a1', name: 'Cairo'),
        BranchModel(id: 'a2', name: 'Alexandria'),
      ];

      await dataSource.cacheBranches(accountId: 'shop_1', branches: branches);

      final result = await dataSource.getCachedBranches(accountId: 'shop_1');

      expect(result, isNotNull);
      expect(result!.length, 2);
      expect(result[0].id, 'a1');
      expect(result[1].name, 'Alexandria');
    });

    test('should keep branches isolated between accounts', () async {
      const branches = [BranchModel(id: 'a1', name: 'Cairo')];

      await dataSource.cacheBranches(accountId: 'shop_1', branches: branches);

      final result = await dataSource.getCachedBranches(accountId: 'shop_2');

      expect(result, isNull);
    });
  });

  group('Gold price local storage', () {
    final updatedAt = DateTime.utc(2026, 11, 21, 10, 30);

    test('returns null when no gold price is cached', () async {
      final result = await dataSource.getCachedGoldPrice(accountId: 'shop_1');

      expect(result, isNull);
    });

    test('should cache and retrieve gold price', () async {
      await dataSource.cacheGoldPrice(
        accountId: 'shop_1',
        goldPrice: GoldPriceModel(
          value: 4200,
          sequence: 7,
          updatedAt: updatedAt,
        ),
      );

      final result = await dataSource.getCachedGoldPrice(accountId: 'shop_1');

      expect(result, isNotNull);
      expect(result!.value, 4200);
      expect(result.sequence, 7);
      expect(result.updatedAt, updatedAt);
    });

    test('replaces the previous gold price for the same account', () async {
      await dataSource.cacheGoldPrice(
        accountId: 'shop_1',
        goldPrice: GoldPriceModel(
          value: 4200,
          sequence: 7,
          updatedAt: updatedAt,
        ),
      );

      await dataSource.cacheGoldPrice(
        accountId: 'shop_1',
        goldPrice: GoldPriceModel(
          value: 4250,
          sequence: 8,
          updatedAt: updatedAt.add(const Duration(minutes: 1)),
        ),
      );

      final result = await dataSource.getCachedGoldPrice(accountId: 'shop_1');

      expect(result!.value, 4250);
      expect(result.sequence, 8);
    });

    test('should keep gold price isolated between accounts', () async {
      await dataSource.cacheGoldPrice(
        accountId: 'shop_1',
        goldPrice: GoldPriceModel(
          value: 4200,
          sequence: 7,
          updatedAt: updatedAt,
        ),
      );

      final result = await dataSource.getCachedGoldPrice(accountId: 'shop_2');

      expect(result, isNull);
    });
  });

  group('Snapshot local storage', () {
    final updatedAt = DateTime.utc(2026, 11, 21, 10, 0);
    final streamAt = DateTime.utc(2026, 11, 21, 10, 5);

    MonitoringSnapshotModel snapshot({DateTime? lastStreamUpdateAt}) {
      return MonitoringSnapshotModel(
        scopeId: 'all',
        sequence: 5,
        totalSales: 1000,
        totalCash: 500,
        operations: const [],
        updatedAt: updatedAt,
        lastStreamUpdateAt: lastStreamUpdateAt,
      );
    }

    test('stores and reads lastStreamUpdateAt', () async {
      await dataSource.cacheSnapshot(
        accountId: 'shop_1',
        snapshot: snapshot(lastStreamUpdateAt: streamAt),
      );

      final result = await dataSource.getCachedSnapshot(
        accountId: 'shop_1',
        scopeId: 'all',
      );

      expect(result!.updatedAt, updatedAt);
      expect(result.lastStreamUpdateAt, streamAt);
    });

    test('a full sync clears the previous stream time', () async {
      await dataSource.cacheSnapshot(
        accountId: 'shop_1',
        snapshot: snapshot(lastStreamUpdateAt: streamAt),
      );

      await dataSource.cacheSnapshot(accountId: 'shop_1', snapshot: snapshot());

      final result = await dataSource.getCachedSnapshot(
        accountId: 'shop_1',
        scopeId: 'all',
      );

      expect(result!.lastStreamUpdateAt, isNull);
    });
  });
}
