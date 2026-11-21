import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class MonitoringDatabase {
  // ignore: prefer_initializing_formals
  MonitoringDatabase({Database? database}) : _database = database;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'shop_monitoring.db');

    _database = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createGoldPricesTable(db);
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE monitoring_snapshots '
            'ADD COLUMN last_stream_update_at TEXT',
          );
        }
      },
    );

    return _database!;
  }

  static Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE branches (
        account_id TEXT NOT NULL,
        branch_id TEXT NOT NULL,
        name TEXT NOT NULL,
        PRIMARY KEY (account_id, branch_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE monitoring_snapshots (
        account_id TEXT NOT NULL,
        scope_id TEXT NOT NULL,
        sequence INTEGER NOT NULL,
        total_sales INTEGER NOT NULL,
        total_cash INTEGER NOT NULL,
        operations_json TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_stream_update_at TEXT,
        PRIMARY KEY (account_id, scope_id)
      )
    ''');

    await _createGoldPricesTable(db);
  }

  static Future<void> _createGoldPricesTable(Database db) async {
    await db.execute('''
      CREATE TABLE gold_prices (
        account_id TEXT PRIMARY KEY,
        value INTEGER NOT NULL,
        sequence INTEGER NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }
}
