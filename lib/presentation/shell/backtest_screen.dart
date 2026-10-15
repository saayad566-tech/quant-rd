/// Backtest screen: pick a dataset and strategy, set costs, run.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/constants.dart';
import '../../data/models/backtest_config.dart';
import '../../data/models/dataset.dart';
import '../../data/models/strategy_spec.dart';
import '../../domain/providers/core_providers.dart';
import '../../domain/providers/feature_providers.dart';
import '../../domain/providers/ui_providers.dart';
import '../widgets/common.dart';

class BacktestScreen extends ConsumerStatefulWidget {
  const BacktestScreen({super.key});

  @override
  ConsumerState<BacktestScreen> createState() => _BacktestScreenState();
}

class _BacktestScreenState extends ConsumerState<BacktestScreen> {
  final _capital = TextEditingController(text: '100000');
  final _fee = TextEditingController(text: '5');
  final _slip = TextEditingController(text: '2');
  final _rf = TextEditingController(text: '6');
  final _bars = TextEditingController(text: '252');
  bool _hydrated = false;

  @override
  void dispose() {
    for (final c in [_capital, _fee, _slip, _rf, _bars]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final datasets = ref.watch(datasetsProvider);
    final strategies = ref.watch(strategiesProvider);
    final selectedDatasetId = ref.watch(selectedDatasetIdProvider);
    final selectedStrategyId = ref.watch(selectedStrategyIdProvider);
    final runner = ref.watch(backtestRunnerProvider);
    final settings = ref.watch(settingsProvider);
    final c = context.colors;

    if (!_hydrated) {
      settings.whenData((s) {
        _capital.text = s.defaultConfig.initialCapital.toStringAsFixed(0);
        _fee.text = s.defaultConfig.feeBps.toStringAsFixed(1);
        _slip.text = s.defaultConfig.slippageBps.toStringAsFixed(1);
        _rf.text = s.defaultConfig.riskFreeRatePct.toStringAsFixed(1);
        _bars.text = s.defaultConfig.barsPerYear.toString();
        _hydrated = true;
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Backtest',
            subtitle: 'Signals execute on the next bar\u2019s open. Fees and slippage are charged on both sides.',
          ),
          const SizedBox(height: Spacing.lg),
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 820;
            final selection = _SelectionCard(
              datasets: datasets,
              strategies: strategies,
              selectedDatasetId: selectedDatasetId,
              selectedStrategyId: selectedStrategyId,
            );
            final config = _ConfigCard(
              capital: _capital,
              fee: _fee,
              slip: _slip,
              rf: _rf,
              bars: _bars,
            );
            if (!wide) {
              return Column(children: [selection, const SizedBox(height: Spacing.md), config]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: selection),
                const SizedBox(width: Spacing.md),
                Expanded(child: config),
              ],
            );
          }),
          const SizedBox(height: Spacing.lg),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (runner.running) ...[
                  LinearProgressIndicator(value: runner.progress == 0 ? null : runner.progress),
                  const SizedBox(height: Spacing.sm),
                  Text('Running backtest\u2026', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: Spacing.md),
                ],
                if (runner.error != null) ...[
                  Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: c.danger, size: 18),
                      const SizedBox(width: Spacing.xs),
                      Expanded(child: Text(runner.error!, style: TextStyle(color: c.danger))),
                    ],
                  ),
                  const SizedBox(height: Spacing.md),
                ],
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: runner.running ? null : () => _run(selectedDatasetId, selectedStrategyId),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('Run backtest'),
                      ),
                    ),
                    if (runner.resultId != null) ...[
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ref.read(selectedBacktestIdProvider.notifier).select(runner.resultId);
                            ref.read(navDestinationProvider.notifier).go(NavDestination.results);
                          },
                          icon: const Icon(Icons.insights_rounded, size: 18),
                          label: const Text('View results'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _run(String? datasetId, String? strategyId) async {
    if (datasetId == null) {
      _snack('Select a dataset first.', error: true);
      return;
    }
    if (strategyId == null) {
      _snack('Select a strategy first.', error: true);
      return;
    }
    final datasets = await ref.read(datasetsProvider.future);
    final strategies = await ref.read(strategiesProvider.future);
    Dataset? dataset;
    for (final d in datasets) {
      if (d.id == datasetId) {
        dataset = d;
        break;
      }
    }
    StrategySpec? strategy;
    for (final s in strategies) {
      if (s.id == strategyId) {
        strategy = s;
        break;
      }
    }
    if (dataset == null || strategy == null) {
      _snack('Selection is no longer available.', error: true);
      return;
    }
    final config = BacktestConfig(
      initialCapital: double.tryParse(_capital.text) ?? 100000,
      feeBps: double.tryParse(_fee.text) ?? 0,
      slippageBps: double.tryParse(_slip.text) ?? 0,
      riskFreeRatePct: double.tryParse(_rf.text) ?? 0,
      barsPerYear: int.tryParse(_bars.text) ?? 252,
    );
    await ref.read(backtestRunnerProvider.notifier).run(
          workspaceId: ref.read(activeWorkspaceIdProvider).value ?? StorageKeys.defaultWorkspaceId,
          dataset: dataset,
          strategy: strategy,
          config: config,
        );
    if (!mounted) return;
    final state = ref.read(backtestRunnerProvider);
    if (state.resultId != null) {
      ref.read(selectedBacktestIdProvider.notifier).select(state.resultId);
      _snack('Backtest complete.');
    } else if (state.error != null) {
      _snack(state.error!, error: true);
    }
  }

  void _snack(String message, {bool error = false}) {
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? c.danger.withValues(alpha: 0.9) : c.surfaceAlt,
    ));
  }
}

class _SelectionCard extends ConsumerWidget {
  final AsyncValue<List<Dataset>> datasets;
  final AsyncValue<List<StrategySpec>> strategies;
  final String? selectedDatasetId;
  final String? selectedStrategyId;

  const _SelectionCard({
    required this.datasets,
    required this.strategies,
    required this.selectedDatasetId,
    required this.selectedStrategyId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selection', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Spacing.md),
          datasets.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: '$e'),
            data: (list) => FieldLabel(
              label: 'Dataset',
              hint: list.isEmpty ? 'No datasets — add one in Market Data.' : null,
              child: DropdownButtonFormField<String>(
                initialValue: list.any((d) => d.id == selectedDatasetId) ? selectedDatasetId : null,
                isExpanded: true,
                hint: const Text('Select a dataset'),
                items: list
                    .map((d) => DropdownMenuItem(
                          value: d.id,
                          child: Text('${d.symbol} \u00b7 ${d.interval.label} \u00b7 ${d.barCount} bars', overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => ref.read(selectedDatasetIdProvider.notifier).select(v),
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          strategies.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: '$e'),
            data: (list) => FieldLabel(
              label: 'Strategy',
              child: DropdownButtonFormField<String>(
                initialValue: list.any((s) => s.id == selectedStrategyId) ? selectedStrategyId : null,
                isExpanded: true,
                hint: const Text('Select a strategy'),
                items: list.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => ref.read(selectedStrategyIdProvider.notifier).select(v),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigCard extends StatelessWidget {
  final TextEditingController capital;
  final TextEditingController fee;
  final TextEditingController slip;
  final TextEditingController rf;
  final TextEditingController bars;

  const _ConfigCard({required this.capital, required this.fee, required this.slip, required this.rf, required this.bars});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Costs & capital', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Spacing.md),
          FieldLabel(label: 'Initial capital', child: TextField(controller: capital, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              Expanded(child: FieldLabel(label: 'Fee (bps/side)', child: TextField(controller: fee, keyboardType: const TextInputType.numberWithOptions(decimal: true)))),
              const SizedBox(width: Spacing.sm),
              Expanded(child: FieldLabel(label: 'Slippage (bps/side)', child: TextField(controller: slip, keyboardType: const TextInputType.numberWithOptions(decimal: true)))),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              Expanded(child: FieldLabel(label: 'Risk-free rate %', child: TextField(controller: rf, keyboardType: const TextInputType.numberWithOptions(decimal: true)))),
              const SizedBox(width: Spacing.sm),
              Expanded(child: FieldLabel(label: 'Bars / year', child: TextField(controller: bars, keyboardType: TextInputType.number))),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            '1 bp = 0.01%. These defaults are editable in the Configs tab.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
