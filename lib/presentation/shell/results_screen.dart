/// Results screen: metrics, equity curve, drawdown, trade log.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/backtest_result.dart';
import '../../data/models/trade.dart';
import '../../domain/providers/core_providers.dart';
import '../../domain/providers/feature_providers.dart';
import '../../data/export/export_service.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/export_helper.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backtests = ref.watch(backtestsProvider);
    final selectedId = ref.watch(selectedBacktestIdProvider);

    return Padding(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Results',
            subtitle: 'Performance analytics for your backtests.',
          ),
          const SizedBox(height: Spacing.md),
          Expanded(
            child: backtests.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: 'Could not load results: $e', onRetry: () => ref.invalidate(backtestsProvider)),
              data: (list) {
                if (list.isEmpty) {
                  return GlassCard(
                    child: EmptyState(
                      icon: Icons.insights_rounded,
                      title: 'No results yet',
                      message: 'Run a backtest to see performance metrics, equity curves and trade logs here.',
                    ),
                  );
                }
                final activeId = (selectedId != null && list.any((b) => b.id == selectedId)) ? selectedId : list.first.id;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 280,
                      child: ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final b = list[i];
                          final isSel = b.id == activeId;
                          final positive = b.metrics.totalReturnPct >= 0;
                          final c = context.colors;
                          return GlassCard(
                            margin: const EdgeInsets.only(bottom: Spacing.sm),
                            onTap: () => ref.read(selectedBacktestIdProvider.notifier).select(b.id),
                            border: isSel ? Border.all(color: c.accent, width: 1.4) : null,
                            padding: const EdgeInsets.all(Spacing.sm),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.strategyName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('${b.symbol} \u00b7 ${Fmt.date(b.runAt)}', style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: 2),
                                Text(
                                  '${positive ? '+' : ''}${b.metrics.totalReturnPct.toStringAsFixed(1)}%  \u00b7  Sharpe ${b.metrics.sharpe.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: positive ? c.success : c.danger),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(child: _ResultDetail(backtestId: activeId)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultDetail extends ConsumerWidget {
  final String backtestId;
  const _ResultDetail({required this.backtestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(backtestResultProvider(backtestId));
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Could not load result: $e', onRetry: () => ref.invalidate(backtestResultProvider(backtestId))),
      data: (result) {
        if (result == null) {
          return const GlassCard(child: EmptyState(icon: Icons.search_off_rounded, title: 'Result not found', message: 'This result may have been deleted.'));
        }
        return _ResultBody(result: result);
      },
    );
  }
}

class _ResultBody extends ConsumerWidget {
  final BacktestResult result;
  const _ResultBody({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final symbol = ref.watch(currencySymbolProvider);
    final m = result.metrics;

    return ListView(
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(result.strategyName, style: Theme.of(context).textTheme.titleLarge),
                        Text('${result.symbol} \u00b7 ${result.barCount} bars \u00b7 run ${Fmt.dateTime(result.runAt)}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Pill(
                    label: '${m.totalReturnPct >= 0 ? '+' : ''}${m.totalReturnPct.toStringAsFixed(1)}%',
                    color: m.totalReturnPct >= 0 ? c.success : c.danger,
                    icon: m.totalReturnPct >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  ),
                  const SizedBox(width: Spacing.xs),
                  PopupMenuButton<String>(
                    tooltip: 'Export',
                    icon: Icon(Icons.download_rounded, color: c.textSecondary),
                    onSelected: (value) async {
                      final stem = '${ExportService.safeName(result.strategyName)}_${ExportService.safeName(result.symbol)}';
                      final (name, content) = switch (value) {
                        'trades' => ('$stem-trades.csv', ExportService.tradesToCsv(result)),
                        'metrics' => ('$stem-metrics.csv', ExportService.metricsToCsv(result)),
                        _ => ('$stem-equity.csv', ExportService.equityToCsv(result)),
                      };
                      if (!context.mounted) return;
                      await exportText(context, fileName: name, content: content, log: ref.read(activityLogProvider));
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'metrics', child: Text('Metrics (CSV)')),
                      PopupMenuItem(value: 'trades', child: Text('Trades (CSV)')),
                      PopupMenuItem(value: 'equity', child: Text('Equity curve (CSV)')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              LayoutBuilder(builder: (context, constraints) {
                final cols = constraints.maxWidth > 760 ? 4 : (constraints.maxWidth > 480 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: Spacing.sm,
                  crossAxisSpacing: Spacing.sm,
                  childAspectRatio: 2.0,
                  children: [
                    MetricTile(label: 'Total return', value: Fmt.percent(m.totalReturnPct, withSign: true), accent: m.totalReturnPct >= 0 ? c.success : c.danger),
                    MetricTile(label: 'CAGR', value: Fmt.percent(m.cagrPct, withSign: true), accent: c.accent),
                    MetricTile(label: 'Sharpe', value: m.sharpe.toStringAsFixed(2), accent: c.info),
                    MetricTile(label: 'Sortino', value: m.sortino.toStringAsFixed(2), accent: c.info),
                    MetricTile(label: 'Max drawdown', value: Fmt.percent(m.maxDrawdownPct), accent: c.danger),
                    MetricTile(label: 'Calmar', value: m.calmar.toStringAsFixed(2), accent: c.accentAlt),
                    MetricTile(label: 'Win rate', value: Fmt.percent(m.winRatePct), accent: c.accentAlt),
                    MetricTile(label: 'Profit factor', value: m.profitFactor.toStringAsFixed(2), accent: c.accentAlt),
                    MetricTile(label: 'Trades', value: '${m.tradeCount}', accent: c.textPrimary),
                    MetricTile(label: 'Expectancy', value: Fmt.money(m.expectancy, symbol: symbol, decimals: 0), accent: m.expectancy >= 0 ? c.success : c.danger),
                    MetricTile(label: 'Exposure', value: Fmt.percent(m.exposurePct), accent: c.textPrimary),
                    MetricTile(label: 'Fees paid', value: Fmt.money(m.totalFees, symbol: symbol, decimals: 0), accent: c.warning),
                  ],
                );
              }),
              const SizedBox(height: Spacing.sm),
              Text(
                'Buy & hold returned ${m.buyHoldReturnPct.toStringAsFixed(1)}% over the same window \u2014 strategy edge: ${(m.totalReturnPct - m.buyHoldReturnPct).toStringAsFixed(1)}pp.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Equity curve', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: Spacing.sm),
              RepaintBoundary(
                child: EquityCurveChart(equity: result.equityCurve, initialCapital: result.config.initialCapital, currencySymbol: symbol),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Drawdown', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: Spacing.sm),
              RepaintBoundary(child: DrawdownChart(equity: result.equityCurve)),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Trade log', style: Theme.of(context).textTheme.titleMedium)),
                  Pill(label: '${result.trades.length} trades'),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              if (result.trades.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
                  child: Center(child: Text('No trades were executed.', style: Theme.of(context).textTheme.bodyMedium)),
                )
              else
                _TradeTable(trades: result.trades, currencySymbol: symbol),
            ],
          ),
        ),
      ],
    );
  }
}

class _TradeTable extends StatelessWidget {
  final List<Trade> trades;
  final String currencySymbol;
  const _TradeTable({required this.trades, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final headerStyle = Theme.of(context).textTheme.labelSmall;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 38,
        dataRowMaxHeight: 44,
        columnSpacing: Spacing.lg,
        headingTextStyle: headerStyle,
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('SIDE')),
          DataColumn(label: Text('ENTRY')),
          DataColumn(label: Text('EXIT')),
          DataColumn(label: Text('QTY')),
          DataColumn(label: Text('PNL')),
          DataColumn(label: Text('PNL %')),
          DataColumn(label: Text('REASON')),
        ],
        rows: trades.map((t) {
          final win = t.pnl >= 0;
          return DataRow(cells: [
            DataCell(Text('${t.id}', style: Theme.of(context).textTheme.bodySmall)),
            DataCell(Text(t.isLong ? 'Long' : 'Short', style: TextStyle(color: t.isLong ? c.success : c.danger, fontSize: 12))),
            DataCell(Text(Fmt.date(t.entryTime), style: Theme.of(context).textTheme.bodySmall)),
            DataCell(Text(Fmt.date(t.exitTime), style: Theme.of(context).textTheme.bodySmall)),
            DataCell(Text(t.quantity.toStringAsFixed(2), style: Theme.of(context).textTheme.bodySmall)),
            DataCell(Text(Fmt.money(t.pnl, symbol: currencySymbol, decimals: 0), style: TextStyle(color: win ? c.success : c.danger, fontSize: 12))),
            DataCell(Text(Fmt.percent(t.pnlPct, withSign: true), style: TextStyle(color: win ? c.success : c.danger, fontSize: 12))),
            DataCell(Text(t.exitReason.label, style: Theme.of(context).textTheme.bodySmall)),
          ]);
        }).toList(),
      ),
    );
  }
}
