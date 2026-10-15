/// Abstract local database contract. Implemented by a SQLite backend on
/// Android/Windows/desktop and an in-memory backend on web.
///
/// The interface is domain-oriented (it speaks in [Workspace], [Dataset],
/// [StrategySpec], [BacktestResult]) so the rest of the app never touches SQL.
/// Every data query is scoped to a workspace so separate research projects stay
/// fully isolated.
library;

import 'dart:convert';

import '../models/backtest_result.dart';
import '../models/candle.dart';
import '../models/dataset.dart';
import '../models/strategy_spec.dart';
import '../models/workspace.dart';

abstract class AppDatabase {
  Future<void> open();
  Future<void> close();

  // Workspaces.
  Future<List<Workspace>> listWorkspaces();
  Future<void> saveWorkspace(Workspace workspace);
  Future<void> deleteWorkspace(String id);
  Future<void> renameWorkspace(String id, String name);

  // Datasets & candles (workspace-scoped listing).
  Future<List<Dataset>> listDatasets(String workspaceId);
  Future<void> saveDataset(Dataset dataset, List<Candle> candles);
  Future<void> deleteDataset(String id);
  Future<List<Candle>> loadCandles(String datasetId);
  Future<Dataset?> getDataset(String id);

  // Strategies (returns global built-ins plus this workspace's strategies).
  Future<List<StrategySpec>> listStrategies(String workspaceId);
  Future<void> saveStrategy(StrategySpec strategy);
  Future<void> deleteStrategy(String id);

  // Backtests.
  Future<List<BacktestSummary>> listBacktests(String workspaceId);
  Future<void> saveBacktest(BacktestResult result);
  Future<BacktestResult?> loadBacktest(String id);
  Future<void> deleteBacktest(String id);

  // Settings (single JSON blob under a fixed key).
  Future<String?> getSetting(String key);
  Future<void> setSetting(String key, String value);
  Future<void> deleteSetting(String key);

  /// Removes all data owned by [workspaceId] (datasets, their candles,
  /// user strategies and backtests). Built-in strategies are untouched.
  Future<void> clearWorkspace(String workspaceId);
}

/// Shared helpers for serialising strategy rule lists.
class DbCodec {
  const DbCodec._();

  static String encodeConditions(List<Condition> conditions) =>
      jsonEncode(conditions.map((c) => c.toMap()).toList());

  static List<Condition> decodeConditions(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Condition.fromMap(e as Map<String, dynamic>)).toList();
  }
}
