/// Repository layer: the only place the app talks to the database. Each
/// repository adds validation, error translation and domain logic on top of the
/// raw [AppDatabase], and scopes every read to a workspace.
library;

import 'dart:convert';

import '../../core/constants.dart';
import '../../core/ids.dart';
import '../../core/result.dart';
import '../../domain/engine/builtin_strategies.dart';
import '../models/app_settings.dart';
import '../models/backtest_result.dart';
import '../models/candle.dart';
import '../models/dataset.dart';
import '../models/strategy_spec.dart';
import '../models/workspace.dart';
import '../parsers/csv_candle_parser.dart';
import 'app_database.dart';

class WorkspaceRepository {
  final AppDatabase _db;
  static const String _activeKey = 'active_workspace';
  WorkspaceRepository(this._db);

  Future<List<Workspace>> all() => _db.listWorkspaces();

  Future<Workspace> create(String name) async {
    final ws = Workspace(id: Ids.newId('ws'), name: name.trim().isEmpty ? 'Untitled project' : name.trim(), createdAt: DateTime.now());
    await _db.saveWorkspace(ws);
    return ws;
  }

  Future<void> rename(String id, String name) => _db.renameWorkspace(id, name);

  Future<void> delete(String id) => _db.deleteWorkspace(id);

  Future<void> clear(String id) => _db.clearWorkspace(id);

  /// The id of the active workspace, falling back to the default workspace.
  Future<String> activeId() async {
    final stored = await _db.getSetting(_activeKey);
    if (stored != null && stored.isNotEmpty) {
      final exists = (await _db.listWorkspaces()).any((w) => w.id == stored);
      if (exists) return stored;
    }
    return StorageKeys.defaultWorkspaceId;
  }

  Future<void> setActive(String id) => _db.setSetting(_activeKey, id);
}

class DatasetRepository {
  final AppDatabase _db;
  DatasetRepository(this._db);

  Future<List<Dataset>> all(String workspaceId) => _db.listDatasets(workspaceId);

  Future<List<Candle>> candles(String id) => _db.loadCandles(id);

  Future<Dataset?> byId(String id) => _db.getDataset(id);

  /// Persists a parsed CSV as a new dataset in [workspaceId].
  Future<Result<Dataset>> importCsv({
    required String workspaceId,
    required String symbol,
    required BarInterval interval,
    required DataSource source,
    required CsvParseReport report,
    String? note,
  }) async {
    if (report.candles.isEmpty) {
      return const Failure('No valid OHLCV rows were found in the file.');
    }
    if (symbol.trim().isEmpty) {
      return const Failure('A symbol or name is required.');
    }
    return save(
      workspaceId: workspaceId,
      symbol: symbol,
      interval: interval,
      source: source,
      candles: report.candles,
      note: note,
    );
  }

  /// Persists an already-fetched candle list (from a provider or a sample).
  Future<Result<Dataset>> save({
    required String workspaceId,
    required String symbol,
    required BarInterval interval,
    required DataSource source,
    required List<Candle> candles,
    String? note,
  }) async {
    if (candles.isEmpty) {
      return const Failure('No candles to save.');
    }
    final sorted = List<Candle>.of(candles)..sort((a, b) => a.time.compareTo(b.time));
    final dataset = Dataset(
      id: Ids.newId('ds'),
      workspaceId: workspaceId,
      symbol: symbol.trim().toUpperCase(),
      source: source,
      interval: interval,
      start: sorted.first.time,
      end: sorted.last.time,
      barCount: sorted.length,
      createdAt: DateTime.now(),
      note: note,
    );
    await _db.saveDataset(dataset, sorted);
    return Success(dataset);
  }

  Future<void> delete(String id) => _db.deleteDataset(id);
}

class StrategyRepository {
  final AppDatabase _db;
  StrategyRepository(this._db);

  /// Ensures the global built-in strategies exist, then returns the built-ins
  /// plus the strategies owned by [workspaceId].
  Future<List<StrategySpec>> all(String workspaceId, {bool seedBuiltIns = true}) async {
    final existing = await _db.listStrategies(workspaceId);
    if (seedBuiltIns) {
      final haveIds = existing.map((e) => e.id).toSet();
      for (final builtin in BuiltInStrategies.all()) {
        if (!haveIds.contains(builtin.id)) {
          await _db.saveStrategy(builtin);
        }
      }
      return _db.listStrategies(workspaceId);
    }
    return existing;
  }

  Future<StrategySpec?> byId(String workspaceId, String id) async {
    final all = await _db.listStrategies(workspaceId);
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> save(StrategySpec strategy) => _db.saveStrategy(strategy);

  /// Deletes a user strategy. Built-ins are protected from deletion.
  Future<bool> delete(String workspaceId, String id) async {
    final existing = await byId(workspaceId, id);
    if (existing == null) return false;
    if (existing.isBuiltIn) return false;
    await _db.deleteStrategy(id);
    return true;
  }
}

class BacktestRepository {
  final AppDatabase _db;
  BacktestRepository(this._db);

  Future<List<BacktestSummary>> all(String workspaceId) => _db.listBacktests(workspaceId);
  Future<BacktestResult?> byId(String id) => _db.loadBacktest(id);
  Future<void> save(BacktestResult result) => _db.saveBacktest(result);
  Future<void> delete(String id) => _db.deleteBacktest(id);
}

class SettingsRepository {
  final AppDatabase _db;
  static const String _key = 'app_settings';
  SettingsRepository(this._db);

  Future<AppSettings> load() async {
    final raw = await _db.getSetting(_key);
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      return AppSettings.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) => _db.setSetting(_key, jsonEncode(settings.toMap()));
}
