/// Feature providers: datasets, strategies, backtests, API keys, backtest
/// runner, activity log and asset-pack state. All data providers are scoped to
/// the active workspace.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ids.dart';
import '../../core/logging/activity_log.dart';
import '../../data/models/api_provider.dart';
import '../../data/models/asset_pack.dart';
import '../../data/models/backtest_config.dart';
import '../../data/models/backtest_result.dart';
import '../../data/models/candle.dart';
import '../../data/models/dataset.dart';
import '../../data/models/strategy_spec.dart';
import '../../data/parsers/csv_candle_parser.dart';
import '../engine/backtest_engine.dart';
import 'core_providers.dart';

// --- Activity log ---------------------------------------------------------

final activityLogStreamProvider = StreamProvider<List<LogEntry>>((ref) {
  return ref.watch(activityLogProvider).watch();
});

// --- Read models (workspace-scoped) ---------------------------------------

final datasetsProvider = FutureProvider<List<Dataset>>((ref) async {
  final wsId = await ref.watch(activeWorkspaceIdProvider.future);
  return ref.watch(datasetRepositoryProvider).all(wsId);
});

/// Candles for a specific dataset, keyed by dataset id.
final datasetCandlesProvider = FutureProvider.family<List<Candle>, String>((ref, datasetId) async {
  return ref.watch(datasetRepositoryProvider).candles(datasetId);
});

final strategiesProvider = FutureProvider<List<StrategySpec>>((ref) async {
  final wsId = await ref.watch(activeWorkspaceIdProvider.future);
  return ref.watch(strategyRepositoryProvider).all(wsId);
});

final backtestsProvider = FutureProvider<List<BacktestSummary>>((ref) async {
  final wsId = await ref.watch(activeWorkspaceIdProvider.future);
  return ref.watch(backtestRepositoryProvider).all(wsId);
});

/// Full result (equity curve + trades) for a specific backtest id.
final backtestResultProvider = FutureProvider.family<BacktestResult?, String>((ref, id) async {
  return ref.watch(backtestRepositoryProvider).byId(id);
});

final apiKeysProvider = FutureProvider<Map<ApiProvider, String>>((ref) async {
  final store = ref.watch(secretStoreProvider);
  final result = <ApiProvider, String>{};
  for (final p in ApiProvider.values) {
    final v = await store.read('apikey.${p.id}');
    if (v != null && v.isNotEmpty) result[p] = v;
  }
  return result;
});

final installedPacksProvider = FutureProvider<Map<String, String>>((ref) async {
  return ref.watch(assetPackManagerProvider).installedVersions();
});

final assetPackManifestProvider = FutureProvider<AssetPackManifest?>((ref) async {
  final settings = await ref.watch(settingsProvider.future);
  final base = settings.assetPackBaseUrl.trim();
  if (base.isEmpty) return null;
  final manager = ref.watch(assetPackManagerProvider);
  if (!manager.supported) return null;
  return manager.fetchManifest(base);
});

// --- Selections -----------------------------------------------------------

class SelectionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
  void clear() => state = null;
}

final selectedDatasetIdProvider = NotifierProvider<SelectionNotifier, String?>(SelectionNotifier.new);
final selectedStrategyIdProvider = NotifierProvider<SelectionNotifier, String?>(SelectionNotifier.new);
final selectedBacktestIdProvider = NotifierProvider<SelectionNotifier, String?>(SelectionNotifier.new);

// --- Backtest runner ------------------------------------------------------

class BacktestRunState {
  final bool running;
  final double progress;
  final String? error;
  final String? resultId;

  const BacktestRunState({this.running = false, this.progress = 0, this.error, this.resultId});

  BacktestRunState copyWith({bool? running, double? progress, String? error, String? resultId, bool clearError = false}) =>
      BacktestRunState(
        running: running ?? this.running,
        progress: progress ?? this.progress,
        error: clearError ? null : (error ?? this.error),
        resultId: resultId ?? this.resultId,
      );
}

class BacktestRunner extends Notifier<BacktestRunState> {
  @override
  BacktestRunState build() => const BacktestRunState();

  Future<void> run({
    required String workspaceId,
    required Dataset dataset,
    required StrategySpec strategy,
    required BacktestConfig config,
  }) async {
    final log = ref.read(activityLogProvider);
    state = const BacktestRunState(running: true, progress: 0.15);
    log.info('Running backtest: ${strategy.name} on ${dataset.symbol}…');
    try {
      final candles = await ref.read(datasetRepositoryProvider).candles(dataset.id);
      if (candles.length < 2) {
        state = const BacktestRunState(error: 'This dataset has too few candles to backtest.');
        log.warn('Backtest skipped: ${dataset.symbol} has too few candles.');
        return;
      }
      state = state.copyWith(progress: 0.6);
      final result = BacktestEngine.run(
        resultId: Ids.newId('bt'),
        candles: candles,
        strategy: strategy,
        config: config,
        datasetId: dataset.id,
        symbol: dataset.symbol,
        workspaceId: workspaceId,
      );
      await ref.read(backtestRepositoryProvider).save(result);
      ref.invalidate(backtestsProvider);
      state = BacktestRunState(resultId: result.id);
      log.success(
        'Backtest finished: ${strategy.name} on ${dataset.symbol} returned '
        '${result.metrics.totalReturnPct.toStringAsFixed(1)}% over ${result.metrics.tradeCount} trade(s).',
      );
    } catch (e) {
      state = BacktestRunState(error: 'Backtest failed: $e');
      log.error('Backtest failed for ${strategy.name} on ${dataset.symbol}.');
    }
  }
}

final backtestRunnerProvider = NotifierProvider<BacktestRunner, BacktestRunState>(BacktestRunner.new);

// --- Data actions ---------------------------------------------------------

/// Handles CSV import and sample-data loading, then refreshes the dataset list.
class DataActions {
  final Ref ref;
  DataActions(this.ref);

  ActivityLog get _log => ref.read(activityLogProvider);

  Future<String?> importCsv({
    required String workspaceId,
    required String symbol,
    required BarInterval interval,
    required CsvParseReport report,
    DataSource source = DataSource.csvImport,
  }) async {
    final repo = ref.read(datasetRepositoryProvider);
    final result = await repo.importCsv(
      workspaceId: workspaceId,
      symbol: symbol,
      interval: interval,
      source: source,
      report: report,
    );
    ref.invalidate(datasetsProvider);
    return result.when(
      success: (d) {
        _log.success('Imported ${d.barCount} candles for ${d.symbol} (${d.interval.label}).');
        return null;
      },
      failure: (m) {
        _log.error('Import failed: $m');
        return m;
      },
    );
  }

  Future<String?> saveCandles({
    required String workspaceId,
    required String symbol,
    required BarInterval interval,
    required List<Candle> candles,
    required DataSource source,
    String? note,
  }) async {
    final repo = ref.read(datasetRepositoryProvider);
    final result = await repo.save(
      workspaceId: workspaceId,
      symbol: symbol,
      interval: interval,
      source: source,
      candles: candles,
      note: note,
    );
    ref.invalidate(datasetsProvider);
    return result.when(
      success: (d) {
        _log.success('Saved ${d.barCount} candles for ${d.symbol} from ${d.source.label}.');
        return null;
      },
      failure: (m) {
        _log.error('Could not save data: $m');
        return m;
      },
    );
  }

  Future<void> deleteDataset(String id) async {
    await ref.read(datasetRepositoryProvider).delete(id);
    ref.invalidate(datasetsProvider);
    _log.info('Deleted a dataset.');
  }

  Future<void> deleteBacktest(String id) async {
    await ref.read(backtestRepositoryProvider).delete(id);
    ref.invalidate(backtestsProvider);
    _log.info('Deleted a backtest result.');
  }
}

final dataActionsProvider = Provider<DataActions>((ref) => DataActions(ref));
