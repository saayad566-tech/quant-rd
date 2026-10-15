/// Providers for the advanced subsystems: the local model hub, the multi-device
/// swarm, the research pipeline and the validation gate.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ids.dart';
import '../../data/models/dataset.dart';
import '../../data/models/local_model.dart';
import '../../data/models/strategy_spec.dart';
import '../../data/remote/model_hub.dart';
import '../../data/remote/model_hub_factory.dart';
import '../../data/sync/swarm.dart';
import '../../data/sync/swarm_factory.dart';
import '../engine/backtest_engine.dart';
import '../research/research_pipeline.dart';
import '../research/validation.dart';
import 'core_providers.dart';
import 'feature_providers.dart';

// ---------------------------------------------------------------------------
// Local model hub
// ---------------------------------------------------------------------------

final modelHubProvider = Provider<ModelHub>((ref) => createModelHub());

final modelManifestProvider = FutureProvider<ModelManifest?>((ref) async {
  final settings = await ref.watch(settingsProvider.future);
  final base = settings.modelBaseUrl.trim();
  if (base.isEmpty) return null;
  final hub = ref.watch(modelHubProvider);
  if (!hub.supported) return null;
  return hub.fetchManifest(base);
});

final installedModelsProvider = FutureProvider<List<InstalledModel>>((ref) async {
  final hub = ref.watch(modelHubProvider);
  if (!hub.supported) return const [];
  return hub.installed();
});

// ---------------------------------------------------------------------------
// Swarm
// ---------------------------------------------------------------------------

final swarmNodeProvider = Provider<SwarmNode>((ref) => createSwarmNode(
      datasets: () async {
        final wsId = await ref.read(workspaceRepositoryProvider).activeId();
        return ref.read(datasetRepositoryProvider).all(wsId);
      },
      candles: (id) => ref.read(datasetRepositoryProvider).candles(id),
    ));

class SwarmState {
  final bool running;
  final int port;
  final String nodeId;
  final String name;
  final List<SwarmPeer> peers;
  final bool busy;
  final String? message;
  final String? error;

  const SwarmState({
    this.running = false,
    this.port = 0,
    this.nodeId = '',
    this.name = '',
    this.peers = const [],
    this.busy = false,
    this.message,
    this.error,
  });

  SwarmState copyWith({
    bool? running,
    int? port,
    String? nodeId,
    String? name,
    List<SwarmPeer>? peers,
    bool? busy,
    String? message,
    String? error,
    bool clearMessage = false,
    bool clearError = false,
  }) =>
      SwarmState(
        running: running ?? this.running,
        port: port ?? this.port,
        nodeId: nodeId ?? this.nodeId,
        name: name ?? this.name,
        peers: peers ?? this.peers,
        busy: busy ?? this.busy,
        message: clearMessage ? null : (message ?? this.message),
        error: clearError ? null : (error ?? this.error),
      );
}

class SwarmController extends Notifier<SwarmState> {
  @override
  SwarmState build() => const SwarmState();

  Future<void> start(String name) async {
    final node = ref.read(swarmNodeProvider);
    if (!node.supported) {
      state = state.copyWith(error: 'Swarm sync is only available in the Android and Windows builds.');
      return;
    }
    final wsId = await ref.read(workspaceRepositoryProvider).activeId();
    await node.start(nodeName: name, workspaceId: wsId);
    state = state.copyWith(
      running: true,
      port: node.port,
      nodeId: node.nodeId,
      name: name,
      peers: node.peers,
      clearError: true,
      message: 'Node online on port ${node.port}.',
    );
    ref.read(activityLogProvider).success('Swarm node started on port ${node.port}.');
  }

  Future<void> stop() async {
    final node = ref.read(swarmNodeProvider);
    await node.stop();
    state = state.copyWith(running: false, port: 0, peers: const [], message: 'Node stopped.');
    ref.read(activityLogProvider).info('Swarm node stopped.');
  }

  Future<SwarmInfo?> probePeer(String host, int port) async {
    state = state.copyWith(busy: true, clearError: true, clearMessage: true);
    try {
      final node = ref.read(swarmNodeProvider);
      final info = await node.probe(host, port);
      node.registerPeer(SwarmPeer(
        nodeId: info.nodeId,
        name: info.name,
        platform: info.platform,
        host: host,
        port: port,
        lastSeen: DateTime.now(),
      ));
      state = state.copyWith(busy: false, peers: node.peers, message: 'Connected to ${info.name}.');
      ref.read(activityLogProvider).success('Swarm: connected to ${info.name} at $host:$port.');
      return info;
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Could not reach $host:$port — $e');
      return null;
    }
  }

  Future<List<RemoteDatasetInfo>> listPeer(String host, int port) async {
    try {
      return await ref.read(swarmNodeProvider).listRemote(host, port);
    } catch (e) {
      state = state.copyWith(error: 'Listing failed — $e');
      return const [];
    }
  }

  /// Pulls a dataset from a peer and stores it in the active workspace.
  Future<String?> pullIntoWorkspace(String host, int port, RemoteDatasetInfo info) async {
    state = state.copyWith(busy: true, clearError: true, clearMessage: true);
    try {
      final candles = await ref.read(swarmNodeProvider).pullDataset(host, port, info.id);
      if (candles.isEmpty) {
        state = state.copyWith(busy: false, error: 'Peer returned no candles for ${info.symbol}.');
        return null;
      }
      final wsId = await ref.read(workspaceRepositoryProvider).activeId();
      final interval = BarInterval.values.firstWhere((e) => e.code == info.interval, orElse: () => BarInterval.d1);
      final result = await ref.read(datasetRepositoryProvider).save(
            workspaceId: wsId,
            symbol: info.symbol,
            interval: interval,
            source: DataSource.custom,
            candles: candles,
            note: 'Pulled from swarm peer $host:$port',
          );
      ref.invalidate(datasetsProvider);
      final saved = result.valueOrNull;
      state = state.copyWith(busy: false, message: 'Pulled ${candles.length} candles for ${info.symbol}.');
      ref.read(activityLogProvider).success('Swarm: pulled ${candles.length} candles for ${info.symbol} from $host.');
      return saved?.id;
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Pull failed — $e');
      return null;
    }
  }
}

final swarmControllerProvider = NotifierProvider<SwarmController, SwarmState>(SwarmController.new);

// ---------------------------------------------------------------------------
// Research pipeline
// ---------------------------------------------------------------------------

class ResearchState {
  final bool running;
  final double progress;
  final String? message;
  final ResearchReport? report;
  final String? error;

  const ResearchState({this.running = false, this.progress = 0, this.message, this.report, this.error});

  ResearchState copyWith({
    bool? running,
    double? progress,
    String? message,
    ResearchReport? report,
    String? error,
    bool clearError = false,
  }) =>
      ResearchState(
        running: running ?? this.running,
        progress: progress ?? this.progress,
        message: message ?? this.message,
        report: report ?? this.report,
        error: clearError ? null : (error ?? this.error),
      );
}

class ResearchController extends Notifier<ResearchState> {
  @override
  ResearchState build() => const ResearchState();

  Future<void> run({required String datasetId, required String symbol, int maxCandidates = 40}) async {
    state = const ResearchState(running: true, progress: 0, message: 'Profiling the dataset…');
    try {
      final candles = await ref.read(datasetRepositoryProvider).candles(datasetId);
      if (candles.isEmpty) {
        state = const ResearchState(error: 'That dataset has no candles.');
        return;
      }
      final config = await ref.read(settingsProvider.future).then((s) => s.defaultConfig);
      final wsId = await ref.read(workspaceRepositoryProvider).activeId();
      final report = await const ResearchPipeline().run(
        candles: candles,
        datasetId: datasetId,
        symbol: symbol,
        workspaceId: wsId,
        config: config,
        maxCandidates: maxCandidates,
        onProgress: (p, m) => state = state.copyWith(progress: p, message: m),
      );
      state = ResearchState(report: report, progress: 1, message: 'Research complete.');
      for (final line in report.log) {
        ref.read(activityLogProvider).info('Research: $line');
      }
    } catch (e) {
      state = ResearchState(error: 'Research failed — $e');
    }
  }

  /// Installs the top-ranked candidate as a real strategy in the active
  /// workspace, carrying its validation record.
  Future<String?> installTop() async {
    final report = state.report;
    if (report == null || report.leaderboard.isEmpty) return null;
    final best = report.leaderboard.first;
    final wsId = await ref.read(workspaceRepositoryProvider).activeId();
    final spec = StrategySpec(
      id: Ids.newId('strat'),
      workspaceId: wsId,
      name: best.strategy.name,
      description: '${best.strategy.description}\nInstalled from the research pipeline (score ${best.score.toStringAsFixed(2)}).',
      entry: best.strategy.entry,
      exit: best.strategy.exit,
      stopLossPct: best.strategy.stopLossPct,
      takeProfitPct: best.strategy.takeProfitPct,
      sizing: best.strategy.sizing,
      sizingValue: best.strategy.sizingValue,
      allowShort: best.strategy.allowShort,
      enabled: false, // must be explicitly enabled after validation
      validation: StrategyValidation.fromMetrics(
        id: Ids.newId('val'),
        workspaceId: wsId,
        strategyId: best.strategy.id,
        datasetId: report.datasetId,
        symbol: report.symbol,
        metrics: best.metrics,
        policy: const ValidationPolicy(),
      ),
      updatedAt: DateTime.now(),
    );
    await ref.read(strategyRepositoryProvider).save(spec);
    ref.invalidate(strategiesProvider);
    ref.read(activityLogProvider).success('Installed top research candidate “${spec.name}”.');
    return spec.id;
  }
}

final researchControllerProvider = NotifierProvider<ResearchController, ResearchState>(ResearchController.new);

// ---------------------------------------------------------------------------
// Validation gate
// ---------------------------------------------------------------------------

class ValidationController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Runs the mandatory backtest gate for [strategy] over [datasetId] and
  /// stores the resulting record on the strategy. Returns the outcome, or null
  /// on failure.
  Future<ValidationOutcome?> validate({
    required StrategySpec strategy,
    required String datasetId,
    required String symbol,
    ValidationPolicy policy = const ValidationPolicy(),
  }) async {
    state = true;
    try {
      final candles = await ref.read(datasetRepositoryProvider).candles(datasetId);
      if (candles.length < 30) {
        ref.read(activityLogProvider).warn('Validation needs at least 30 bars; this dataset has ${candles.length}.');
        return null;
      }
      final config = await ref.read(settingsProvider.future).then((s) => s.defaultConfig);
      final wsId = await ref.read(workspaceRepositoryProvider).activeId();
      final result = BacktestEngine.run(
        resultId: Ids.newId('val'),
        candles: candles,
        strategy: strategy,
        config: config,
        datasetId: datasetId,
        symbol: symbol,
        workspaceId: wsId,
      );
      final validation = StrategyValidation.fromRun(
        id: Ids.newId('val'),
        workspaceId: wsId,
        result: result,
        policy: policy,
      );
      await ref.read(strategyRepositoryProvider).save(strategy.copyWith(validation: validation, updatedAt: DateTime.now()));
      ref.invalidate(strategiesProvider);
      ref.read(activityLogProvider).info(
            'Validated “${strategy.name}” on $symbol: ${validation.passed ? 'PASSED' : 'FAILED'} '
            '(${validation.checks.join('; ')})',
          );
      return ValidationOutcome.evaluate(result.metrics, policy);
    } catch (e) {
      ref.read(activityLogProvider).error('Validation failed — $e');
      return null;
    } finally {
      state = false;
    }
  }
}

final validationControllerProvider = NotifierProvider<ValidationController, bool>(ValidationController.new);

