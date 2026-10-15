/// Dashboard: a command centre with at-a-glance status and quick actions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/providers/feature_providers.dart';
import '../../domain/providers/ui_providers.dart';
import '../widgets/common.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datasets = ref.watch(datasetsProvider);
    final strategies = ref.watch(strategiesProvider);
    final backtests = ref.watch(backtestsProvider);
    final c = context.colors;

    final datasetCount = datasets.maybeWhen(data: (d) => d.length, orElse: () => 0);
    final strategyCount = strategies.maybeWhen(data: (d) => d.length, orElse: () => 0);
    final backtestCount = backtests.maybeWhen(data: (d) => d.length, orElse: () => 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Welcome back',
            subtitle: 'Research, backtest and compare strategies entirely on your device.',
            trailing: Pill(label: 'Offline ready', color: c.success, icon: Icons.offline_bolt_rounded),
          ),
          const SizedBox(height: Spacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 560 ? 2 : 1);
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: Spacing.sm,
                crossAxisSpacing: Spacing.sm,
                childAspectRatio: 2.0,
                children: [
                  MetricTile(label: 'Datasets', value: '$datasetCount', icon: Icons.storage_rounded, accent: c.accent),
                  MetricTile(label: 'Strategies', value: '$strategyCount', icon: Icons.science_rounded, accent: c.accentAlt),
                  MetricTile(label: 'Backtests run', value: '$backtestCount', icon: Icons.play_circle_fill_rounded, accent: c.info),
                  MetricTile(label: 'Mode', value: 'Local', icon: Icons.lock_rounded, accent: c.success, delta: 'No data leaves this device'),
                ],
              );
            },
          ),
          const SizedBox(height: Spacing.lg),
          _QuickStart(),
          const SizedBox(height: Spacing.lg),
          const SectionHeader(title: 'Recent backtests', subtitle: 'Your latest runs, newest first.'),
          const SizedBox(height: Spacing.sm),
          backtests.when(
            loading: () => const Padding(padding: EdgeInsets.all(Spacing.lg), child: LoadingView()),
            error: (e, _) => ErrorView(message: 'Could not load backtests: $e', onRetry: () => ref.invalidate(backtestsProvider)),
            data: (list) {
              if (list.isEmpty) {
                return GlassCard(
                  child: EmptyState(
                    icon: Icons.insights_rounded,
                    title: 'No backtests yet',
                    message: 'Import or load a dataset, pick a strategy, then run your first backtest.',
                    action: FilledButton(
                      onPressed: () => ref.read(navDestinationProvider.notifier).go(NavDestination.backtest),
                      child: const Text('Go to Backtest'),
                    ),
                  ),
                );
              }
              return Column(
                children: list.take(6).map((b) {
                  final positive = b.metrics.totalReturnPct >= 0;
                  return GlassCard(
                    margin: const EdgeInsets.only(bottom: Spacing.sm),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: c.accent.withValues(alpha: 0.12),
                            borderRadius: Radii.rSm,
                          ),
                          child: Icon(Icons.show_chart_rounded, color: c.accent),
                        ),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${b.strategyName} \u00b7 ${b.symbol}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                              Text(
                                '${b.barCount} bars \u00b7 Sharpe ${b.metrics.sharpe.toStringAsFixed(2)} \u00b7 MaxDD ${b.metrics.maxDrawdownPct.toStringAsFixed(1)}%',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${positive ? '+' : ''}${b.metrics.totalReturnPct.toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: positive ? c.success : c.danger,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                          onPressed: () {
                            ref.read(navDestinationProvider.notifier).go(NavDestination.results);
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickStart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final items = [
      _QuickAction('Load sample data', 'Instant, fully offline', Icons.auto_awesome_rounded, () {
        ref.read(navDestinationProvider.notifier).go(NavDestination.data);
      }),
      _QuickAction('Import CSV', 'Bring your own OHLCV file', Icons.upload_file_rounded, () {
        ref.read(navDestinationProvider.notifier).go(NavDestination.data);
      }),
      _QuickAction('Build a strategy', 'Indicators + rules', Icons.tune_rounded, () {
        ref.read(navDestinationProvider.notifier).go(NavDestination.strategies);
      }),
      _QuickAction('Run a backtest', 'Fees & slippage included', Icons.play_circle_fill_rounded, () {
        ref.read(navDestinationProvider.notifier).go(NavDestination.backtest);
      }),
    ];
    return GlassCard(
      blur: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick start', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Spacing.sm),
          LayoutBuilder(builder: (context, constraints) {
            final cols = constraints.maxWidth > 720 ? 4 : (constraints.maxWidth > 420 ? 2 : 1);
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: Spacing.xs,
              crossAxisSpacing: Spacing.xs,
              childAspectRatio: 2.9,
              children: items
                  .map((it) => GestureDetector(
                        onTap: it.onTap,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(Spacing.sm),
                          decoration: BoxDecoration(
                            color: c.glassFill,
                            borderRadius: Radii.rSm,
                            border: Border.all(color: c.border),
                          ),
                          child: Row(
                            children: [
                              Icon(it.icon, color: c.accent, size: 20),
                              const SizedBox(width: Spacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(it.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13)),
                                    Text(it.subtitle, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            );
          }),
        ],
      ),
    );
  }
}

class _QuickAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  _QuickAction(this.title, this.subtitle, this.icon, this.onTap);
}
