/// SQLite-backed implementation for Android, Windows and other dart:io targets.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import '../../core/constants.dart';
import '../models/backtest_result.dart';
import '../models/candle.dart';
import '../../domain/research/validation.dart';
import '../models/dataset.dart';
import '../models/strategy_spec.dart';
import '../models/workspace.dart';
import 'app_database.dart';

class IoAppDatabase implements AppDatabase {
  Database? _db;

  @override
  Future<void> open() async {
    if (_db != null) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      ffi.sqfliteFfiInit();
      databaseFactory = ffi.databaseFactoryFfi;
    }
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final path = p.join(dir.path, StorageKeys.databaseName);
    _db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: int.parse(StorageKeys.databaseVersion),
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    await _ensureDefaultWorkspace();
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE workspaces(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE datasets(
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL,
        symbol TEXT NOT NULL,
        source TEXT NOT NULL,
        interval TEXT NOT NULL,
        start INTEGER NOT NULL,
        end INTEGER NOT NULL,
        bar_count INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        note TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_datasets_ws ON datasets(workspace_id, created_at)');
    await db.execute('''
      CREATE TABLE candles(
        dataset_id TEXT NOT NULL,
        ts INTEGER NOT NULL,
        o REAL NOT NULL,
        h REAL NOT NULL,
        l REAL NOT NULL,
        c REAL NOT NULL,
        v REAL NOT NULL,
        PRIMARY KEY(dataset_id, ts)
      )
    ''');
    await db.execute('CREATE INDEX idx_candles_dataset ON candles(dataset_id, ts)');
    await db.execute('''
      CREATE TABLE strategies(
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        is_built_in INTEGER NOT NULL,
        entry TEXT NOT NULL,
        exit TEXT NOT NULL,
        stop_loss_pct REAL NOT NULL,
        take_profit_pct REAL NOT NULL,
        sizing TEXT NOT NULL,
        sizing_value REAL NOT NULL,
        allow_short INTEGER NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        validation_json TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE backtests(
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL DEFAULT '',
        strategy_id TEXT NOT NULL,
        strategy_name TEXT NOT NULL,
        dataset_id TEXT NOT NULL,
        symbol TEXT NOT NULL,
        config TEXT NOT NULL,
        equity TEXT NOT NULL,
        trades TEXT NOT NULL,
        metrics TEXT NOT NULL,
        bar_count INTEGER NOT NULL,
        run_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_backtests_ws ON backtests(workspace_id, run_at)');
    await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    await _insertDefaultWorkspace(db);
  }

  /// Migrates a v1 database (no workspaces) to v2.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS workspaces(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
      await _addColumnIfMissing(db, 'datasets', 'workspace_id', "TEXT NOT NULL DEFAULT ''");
      await _addColumnIfMissing(db, 'strategies', 'workspace_id', "TEXT NOT NULL DEFAULT ''");
      await _addColumnIfMissing(db, 'backtests', 'workspace_id', "TEXT NOT NULL DEFAULT ''");
      await _insertDefaultWorkspace(db);
      // Assign any pre-existing rows to the default workspace.
      for (final table in ['datasets', 'strategies', 'backtests']) {
        await db.update(table, {'workspace_id': StorageKeys.defaultWorkspaceId}, where: "workspace_id = ''");
      }
      await db.execute('CREATE INDEX IF NOT EXISTS idx_datasets_ws ON datasets(workspace_id, created_at)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_backtests_ws ON backtests(workspace_id, run_at)');
    }
    if (oldVersion < 3) {
      // v3: strategies gain an enabled/active flag.
      await _addColumnIfMissing(db, 'strategies', 'enabled', 'INTEGER NOT NULL DEFAULT 1');
    }
    if (oldVersion < 4) {
      // v4: strategies record the result of the mandatory validation gate.
      await _addColumnIfMissing(db, 'strategies', 'validation_json', 'TEXT');
    }
  }

  Future<void> _addColumnIfMissing(Database db, String table, String column, String definition) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final has = info.any((row) => row['name'] == column);
    if (!has) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> _insertDefaultWorkspace(DatabaseExecutor db) async {
    await db.insert(
      'workspaces',
      {
        'id': StorageKeys.defaultWorkspaceId,
        'name': StorageKeys.defaultWorkspaceName,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> _ensureDefaultWorkspace() async {
    final rows = await _database.query('workspaces', limit: 1);
    if (rows.isEmpty) {
      await _insertDefaultWorkspace(_database);
    }
  }

  Database get _database {
    final db = _db;
    if (db == null) throw StateError('Database has not been opened. Call open() first.');
    return db;
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // --- Workspaces ---------------------------------------------------------

  @override
  Future<List<Workspace>> listWorkspaces() async {
    final rows = await _database.query('workspaces', orderBy: 'created_at ASC');
    return rows.map(Workspace.fromMap).toList();
  }

  @override
  Future<void> saveWorkspace(Workspace workspace) async {
    await _database.insert('workspaces', workspace.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> renameWorkspace(String id, String name) async {
    await _database.update('workspaces', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteWorkspace(String id) async {
    if (id == StorageKeys.defaultWorkspaceId) return; // never delete the default
    await _database.transaction((txn) async {
      await _clearWorkspace(txn, id);
      await txn.delete('workspaces', where: 'id = ?', whereArgs: [id]);
    });
  }

  // --- Datasets -----------------------------------------------------------

  @override
  Future<List<Dataset>> listDatasets(String workspaceId) async {
    final rows = await _database.query(
      'datasets',
      where: 'workspace_id = ?',
      whereArgs: [workspaceId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Dataset.fromMap).toList();
  }

  @override
  Future<Dataset?> getDataset(String id) async {
    final rows = await _database.query('datasets', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Dataset.fromMap(rows.first);
  }

  @override
  Future<void> saveDataset(Dataset dataset, List<Candle> candles) async {
    await _database.transaction((txn) async {
      await txn.insert('datasets', dataset.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('candles', where: 'dataset_id = ?', whereArgs: [dataset.id]);
      final batch = txn.batch();
      for (final c in candles) {
        batch.insert('candles', {
          'dataset_id': dataset.id,
          'ts': c.time.millisecondsSinceEpoch,
          'o': c.open,
          'h': c.high,
          'l': c.low,
          'c': c.close,
          'v': c.volume,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> deleteDataset(String id) async {
    await _database.transaction((txn) async {
      await txn.delete('candles', where: 'dataset_id = ?', whereArgs: [id]);
      await txn.delete('datasets', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<List<Candle>> loadCandles(String datasetId) async {
    final rows = await _database.query(
      'candles',
      where: 'dataset_id = ?',
      whereArgs: [datasetId],
      orderBy: 'ts ASC',
    );
    return rows
        .map((r) => Candle(
              time: DateTime.fromMillisecondsSinceEpoch((r['ts'] as num).toInt(), isUtc: true),
              open: (r['o'] as num).toDouble(),
              high: (r['h'] as num).toDouble(),
              low: (r['l'] as num).toDouble(),
              close: (r['c'] as num).toDouble(),
              volume: (r['v'] as num).toDouble(),
            ))
        .toList();
  }

  // --- Strategies ---------------------------------------------------------

  @override
  Future<List<StrategySpec>> listStrategies(String workspaceId) async {
    // Global built-ins (workspace_id = '') plus this workspace's strategies.
    final rows = await _database.query(
      'strategies',
      where: "workspace_id = ? OR workspace_id = ''",
      whereArgs: [workspaceId],
      orderBy: 'is_built_in DESC, updated_at DESC',
    );
    return rows.map(_strategyFromRow).toList();
  }

  StrategySpec _strategyFromRow(Map<String, Object?> r) => StrategySpec(
        id: r['id'] as String,
        workspaceId: (r['workspace_id'] as String?) ?? '',
        name: r['name'] as String,
        description: r['description'] as String,
        isBuiltIn: (r['is_built_in'] as num).toInt() == 1,
        entry: DbCodec.decodeConditions(r['entry'] as String),
        exit: DbCodec.decodeConditions(r['exit'] as String),
        stopLossPct: (r['stop_loss_pct'] as num).toDouble(),
        takeProfitPct: (r['take_profit_pct'] as num).toDouble(),
        sizing: PositionSizing.values.firstWhere((e) => e.name == r['sizing'], orElse: () => PositionSizing.percentOfEquity),
        sizingValue: (r['sizing_value'] as num).toDouble(),
        allowShort: (r['allow_short'] as num).toInt() == 1,
        enabled: ((r['enabled'] as num?)?.toInt() ?? 1) == 1,
        validation: _validationFromRow(r['validation_json']),
        updatedAt: DateTime.fromMillisecondsSinceEpoch((r['updated_at'] as num).toInt()),
      );

  static StrategyValidation? _validationFromRow(Object? raw) {
    if (raw == null) return null;
    try {
      return StrategyValidation.fromMap(jsonDecode(raw as String) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveStrategy(StrategySpec strategy) async {
    await _database.insert(
      'strategies',
      {
        'id': strategy.id,
        'workspace_id': strategy.workspaceId,
        'name': strategy.name,
        'description': strategy.description,
        'is_built_in': strategy.isBuiltIn ? 1 : 0,
        'entry': DbCodec.encodeConditions(strategy.entry),
        'exit': DbCodec.encodeConditions(strategy.exit),
        'stop_loss_pct': strategy.stopLossPct,
        'take_profit_pct': strategy.takeProfitPct,
        'sizing': strategy.sizing.name,
        'sizing_value': strategy.sizingValue,
        'allow_short': strategy.allowShort ? 1 : 0,
        'enabled': strategy.enabled ? 1 : 0,
        'validation_json': strategy.validation == null ? null : jsonEncode(strategy.validation!.toMap()),
        'updated_at': strategy.updatedAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteStrategy(String id) async {
    await _database.delete('strategies', where: 'id = ? AND is_built_in = 0', whereArgs: [id]);
  }

  // --- Backtests ----------------------------------------------------------

  @override
  Future<List<BacktestSummary>> listBacktests(String workspaceId) async {
    final rows = await _database.query(
      'backtests',
      columns: ['id', 'strategy_id', 'strategy_name', 'dataset_id', 'symbol', 'metrics', 'bar_count', 'run_at'],
      where: 'workspace_id = ?',
      whereArgs: [workspaceId],
      orderBy: 'run_at DESC',
    );
    return rows.map(BacktestSummary.fromMap).toList();
  }

  @override
  Future<void> saveBacktest(BacktestResult result) async {
    await _database.insert('backtests', result.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<BacktestResult?> loadBacktest(String id) async {
    final rows = await _database.query('backtests', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : BacktestResult.fromMap(rows.first);
  }

  @override
  Future<void> deleteBacktest(String id) async {
    await _database.delete('backtests', where: 'id = ?', whereArgs: [id]);
  }

  // --- Settings -----------------------------------------------------------

  @override
  Future<String?> getSetting(String key) async {
    final rows = await _database.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    await _database.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteSetting(String key) async {
    await _database.delete('settings', where: 'key = ?', whereArgs: [key]);
  }

  // --- Maintenance --------------------------------------------------------

  @override
  Future<void> clearWorkspace(String workspaceId) async {
    await _database.transaction((txn) => _clearWorkspace(txn, workspaceId));
  }

  Future<void> _clearWorkspace(DatabaseExecutor txn, String workspaceId) async {
    await txn.rawDelete(
      'DELETE FROM candles WHERE dataset_id IN (SELECT id FROM datasets WHERE workspace_id = ?)',
      [workspaceId],
    );
    await txn.delete('datasets', where: 'workspace_id = ?', whereArgs: [workspaceId]);
    await txn.delete('strategies', where: 'workspace_id = ? AND is_built_in = 0', whereArgs: [workspaceId]);
    await txn.delete('backtests', where: 'workspace_id = ?', whereArgs: [workspaceId]);
  }
}
