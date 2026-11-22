import 'dart:convert';

import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/monitoring_local_data_source.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/branch_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/gold_price_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/monitoring_snapshot_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/recent_operation_model.dart';
import 'package:sqflite/sqflite.dart';
import 'monitoring_database.dart';

class SqfliteMonitoringLocalDataSource implements MonitoringLocalDataSource {
  final MonitoringDatabase _database;

  SqfliteMonitoringLocalDataSource(this._database);

  @override
  Future<void> cacheBranches({
    required String accountId,
    required List<BranchModel> branches,
  }) async {
    final db = await _database.database;

    final batch = db.batch();

    for (final branch in branches) {
      batch.insert('branches', {
        'account_id': accountId,
        'branch_id': branch.id,
        'name': branch.name,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  @override
  Future<List<BranchModel>?> getCachedBranches({
    required String accountId,
  }) async {
    final db = await _database.database;

    final result = await db.query(
      'branches',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );

    if (result.isEmpty) return null;

    return result.map((row) {
      return BranchModel.fromJson({
        'id': row['branch_id'],
        'name': row['name'],
      });
    }).toList();
  }

  @override
  Future<void> cacheSnapshot({
    required String accountId,
    required MonitoringSnapshotModel snapshot,
  }) async {
    final db = await _database.database;

    await db.insert('monitoring_snapshots', {
      'account_id': accountId,
      'scope_id': snapshot.scopeId,
      'sequence': snapshot.sequence,
      'total_sales': snapshot.totalSales,
      'total_cash': snapshot.totalCash,
      'operations_json': jsonEncode(
        snapshot.operations.map((operation) => operation.toJson()).toList(),
      ),
      'updated_at': snapshot.updatedAt.toUtc().toIso8601String(),
      'last_stream_update_at': snapshot.lastStreamUpdateAt
          ?.toUtc()
          .toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<MonitoringSnapshotModel?> getCachedSnapshot({
    required String accountId,
    required String scopeId,
  }) async {
    final db = await _database.database;

    final result = await db.query(
      'monitoring_snapshots',
      where: 'account_id = ? AND scope_id = ?',
      whereArgs: [accountId, scopeId],
      limit: 1,
    );

    if (result.isEmpty) return null;

    final row = result.first;

    final operationsJson = jsonDecode(row['operations_json'] as String) as List;

    final lastStreamUpdateAt = row['last_stream_update_at'] as String?;

    return MonitoringSnapshotModel(
      scopeId: row['scope_id'] as String,
      sequence: row['sequence'] as int,
      totalSales: row['total_sales'] as int,
      totalCash: row['total_cash'] as int,
      operations: operationsJson
          .map(
            (operation) => RecentOperationModel.fromJson(
              operation as Map<String, dynamic>,
            ),
          )
          .toList(),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      lastStreamUpdateAt: lastStreamUpdateAt == null
          ? null
          : DateTime.parse(lastStreamUpdateAt),
    );
  }

  @override
  Future<void> cacheGoldPrice({
    required String accountId,
    required GoldPriceModel goldPrice,
  }) async {
    final db = await _database.database;

    await db.insert('gold_prices', {
      'account_id': accountId,
      'value': goldPrice.value,
      'sequence': goldPrice.sequence,
      'updated_at': goldPrice.updatedAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<GoldPriceModel?> getCachedGoldPrice({
    required String accountId,
  }) async {
    final db = await _database.database;

    final result = await db.query(
      'gold_prices',
      where: 'account_id = ?',
      whereArgs: [accountId],
      limit: 1,
    );

    if (result.isEmpty) return null;

    final row = result.first;

    return GoldPriceModel(
      value: row['value'] as int,
      sequence: row['sequence'] as int,
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  @override
  Future<void> clearAccount({required String accountId}) async {
    final db = await _database.database;

    await db.transaction((txn) async {
      for (final table in const [
        'branches',
        'monitoring_snapshots',
        'gold_prices',
      ]) {
        await txn.delete(
          table,
          where: 'account_id = ?',
          whereArgs: [accountId],
        );
      }
    });
  }
}
