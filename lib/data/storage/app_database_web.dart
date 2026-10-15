/// In-memory implementation used on web (and in tests). Data is session-scoped;
/// the web build is a lightweight demo target — Android and Windows use SQLite.
library;

import '../../core/constants.dart';
import '../models/backtest_result.dart';
import '../models/candle.dart';
import '../models/dataset.dart';
import '../models/strategy_spec.dart';
import '../models/workspace.dart';
import 'app_database.dart';

class WebAppDatabase implements AppDatabase {
  final Map<String, Workspace> _workspaces = {};
  final Map<String, Dataset> _datasets = {};
  final Map<String, List<Candle>> _candles = {};
  final Map<String, StrategySpec> _strategies = {};
  final Map<String, BacktestResult> _backtests = {};
  final Map<String, String> _settings = {};

  @override
  Future<void> open() async {
    _workspaces.putIfAbsent(
      StorageKeys.defaultWorkspaceId,
      () => Workspace(
        id: StorageKeys.defaultWorkspaceId,
        name: StorageKeys.defaultWorkspaceName,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> close() async {}

  // --- Workspaces ---------------------------------------------------------

  @override
  Future<List<Workspace>> listWorkspaces() async {
    final list = _workspaces.values.toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<void> saveWorkspace(Workspace workspace) async {
    _workspaces[workspace.id] = workspace;
  }

  @override
  Future<void> renameWorkspace(String id, String name) async {
    final w = _workspaces[id];
    if (w != null) _workspaces[id] = w.copyWith(name: name);
  }

  @override
  Future<void> deleteWorkspace(String id) async {
    if (id == StorageKeys.defaultWorkspaceId) return;
    await clearWorkspace(id);
    _workspaces.remove(id);
  }

  // --- Datasets -----------------------------------------------------------

  @override
  Future<List<Dataset>> listDatasets(String workspaceId) async {
    final list = _datasets.values.where((d) => d.workspaceId == workspaceId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<Dataset?> getDataset(String id) async => _datasets[id];

  @override
  Future<void> saveDataset(Dataset dataset, List<Candle> candles) async {
    _datasets[dataset.id] = dataset;
    _candles[dataset.id] = List.of(candles);
  }

  @override
  Future<void> deleteDataset(String id) async {
    _datasets.remove(id);
    _candles.remove(id);
  }

  @override
  Future<List<Candle>> loadCandles(String datasetId) async => _candles[datasetId] ?? const [];

  // --- Strategies ---------------------------------------------------------

  @override
  Future<List<StrategySpec>> listStrategies(String workspaceId) async {
    final list = _strategies.values.where((s) => s.workspaceId == workspaceId || s.workspaceId.isEmpty).toList();
    list.sort((a, b) {
      if (a.isBuiltIn != b.isBuiltIn) return a.isBuiltIn ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  @override
  Future<void> saveStrategy(StrategySpec strategy) async {
    _strategies[strategy.id] = strategy;
  }

  @override
  Future<void> deleteStrategy(String id) async {
    if (_strategies[id]?.isBuiltIn ?? false) return;
    _strategies.remove(id);
  }

  // --- Backtests ----------------------------------------------------------

  @override
  Future<List<BacktestSummary>> listBacktests(String workspaceId) async {
    final list = _backtests.values
        .where((r) => r.workspaceId == workspaceId)
        .map((r) => BacktestSummary(
              id: r.id,
              strategyId: r.strategyId,
              strategyName: r.strategyName,
              datasetId: r.datasetId,
              symbol: r.symbol,
              metrics: r.metrics,
              barCount: r.barCount,
              runAt: r.runAt,
            ))
        .toList();
    list.sort((a, b) => b.runAt.compareTo(a.runAt));
    return list;
  }

  @override
  Future<void> saveBacktest(BacktestResult result) async {
    _backtests[result.id] = result;
  }

  @override
  Future<BacktestResult?> loadBacktest(String id) async => _backtests[id];

  @override
  Future<void> deleteBacktest(String id) async {
    _backtests.remove(id);
  }

  // --- Settings -----------------------------------------------------------

  @override
  Future<String?> getSetting(String key) async => _settings[key];

  @override
  Future<void> setSetting(String key, String value) async {
    _settings[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    _settings.remove(key);
  }

  // --- Maintenance --------------------------------------------------------

  @override
  Future<void> clearWorkspace(String workspaceId) async {
    final datasetIds = _datasets.values.where((d) => d.workspaceId == workspaceId).map((d) => d.id).toList();
    for (final id in datasetIds) {
      _datasets.remove(id);
      _candles.remove(id);
    }
    _strategies.removeWhere((_, s) => s.workspaceId == workspaceId && !s.isBuiltIn);
    _backtests.removeWhere((_, r) => r.workspaceId == workspaceId);
  }
}
