/// Research screen: run the sequential research pipeline over a dataset and
/// inspect a leaderboard built from real, engine-computed metrics.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/providers/advanced_providers.dart';
import '../../domain/providers/feature_providers.dart';
import '../../domain/research/research_pipeline.dart';
import '../widgets/common.dart';

class ResearchScreen extends ConsumerStatefulWidget {
  const ResearchScreen({super.key});

  @override
  ConsumerState<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends ConsumerState<ResearchScreen> {
  String? _datasetId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final datasets = ref.watch(datasetsProvider);
    final state = ref.watch(researchControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        const SectionHeader(
          title: 'Research Engine',
          subtitle: 'Profile a dataset, generate candidate strategies, backtest every one, and rank them by real metrics.',
        ),
        const SizedBox(height: Spacing.md),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              datasets.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(message: 'Could not load datasets: $e', onRetry: () => ref.invalidate(datasetsProvider)),
                data: (list) {
                  if (list.isEmpty) {
                    return Text(
                      'No datasets yet. Fetch or import market data first, then come back to run research.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    );
                  }
                  final selected = _datasetId ?? list.first.id;
                  return Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selected,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Dataset'),
                          items: list
                              .map((d) => DropdownMenuItem(
                                    value: d.id,
                                    child: Text('${d.symbol} · ${d.interval.label} · ${Fmt.integer(d.barCount)} bars', overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _datasetId = v),
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      FilledButton.icon(
                        onPressed: state.running
                            ? null
                            : () {
                                final d = list.firstWhere((x) => x.id == selected, orElse: () => list.first);
                                ref.read(researchControllerProvider.notifier).run(datasetId: d.id, symbol: d.symbol);
                              },
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(state.running ? 'Running…' : 'Run research'),
                      ),
                    ],
                  );
                },
              ),
              if (state.running) ...[
                const SizedBox(height: Spacing.md),
                LinearProgressIndicator(value: state.progress, backgroundColor: c.surfaceAlt, color: c.accent),
                const SizedBox(height: Spacing.xs),
                Text(state.message ?? 'Working…', style: Theme.of(context).textTheme.bodySmall),
              ],
              if (state.error != null) ...[
                const SizedBox(height: Spacing.sm),
                Text(state.error!, style: TextStyle(color: c.danger, fontSize: 12)),
              ],
            ],
          ),
        ),
        if (state.report != null) ...[
          const SizedBox(height: Spacing.md),
          _ProfileCard(report: state.report!),
          const SizedBox(height: Spacing.md),
          _LeaderboardCard(report: state.report!),
          const SizedBox(height: Spacing.md),
          _LogCard(report: state.report!),
        ],
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final ResearchReport report;
  const _ProfileCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final p = report.profile;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Data Analyst', subtitle: 'What the dataset looks like'),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              MetricTile(label: 'Bars', value: Fmt.integer(p.bars)),
              MetricTile(label: 'Total return', value: Fmt.percent(p.totalReturnPct, withSign: true)),
              MetricTile(label: 'Volatility /yr', value: '${p.annualisedVolPct.toStringAsFixed(1)}%'),
              MetricTile(label: 'Trend', value: '${p.trendSlopePctPerBar.toStringAsFixed(3)}%/bar'),
              MetricTile(label: 'Up-bars', value: '${(p.upBarRatio * 100).toStringAsFixed(0)}%'),
              MetricTile(label: 'Regime', value: p.regime),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderboardCard extends ConsumerWidget {
  final ResearchReport report;
  const _LeaderboardCard({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Leaderboard',
            subtitle: '${report.evaluated} candidates backtested · ${report.rejected} failed the validation gate · '
                'top ${report.leaderboard.length} kept · ${report.elapsed.inMilliseconds} ms',
            trailing: FilledButton.icon(
              onPressed: report.leaderboard.isEmpty
                  ? null
                  : () async {
                      final id = await ref.read(researchControllerProvider.notifier).installTop();
                      if (id != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Top candidate installed in Strategy Lab (disabled until validated).')),
                        );
                      }
                    },
              icon: const Icon(Icons.download_done_rounded, size: 18),
              label: const Text('Install top'),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          if (report.leaderboard.isEmpty)
            Text('No candidates survived. Try a longer history or loosen the policy.', style: Theme.of(context).textTheme.bodySmall)
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 34,
                dataRowMaxHeight: 40,
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Strategy')),
                  DataColumn(label: Text('Score')),
                  DataColumn(label: Text('Trades')),
                  DataColumn(label: Text('Return')),
                  DataColumn(label: Text('Sharpe')),
                  DataColumn(label: Text('Max DD')),
                  DataColumn(label: Text('PF')),
                  DataColumn(label: Text('Gate')),
                ],
                rows: [
                  for (var i = 0; i < report.leaderboard.length; i++)
                    DataRow(cells: [
                      DataCell(Text('${i + 1}')),
                      DataCell(SizedBox(width: 210, child: Text(report.leaderboard[i].strategy.name, overflow: TextOverflow.ellipsis))),
                      DataCell(Text(report.leaderboard[i].score.toStringAsFixed(2))),
                      DataCell(Text('${report.leaderboard[i].metrics.tradeCount}')),
                      DataCell(Text(Fmt.percent(report.leaderboard[i].metrics.totalReturnPct, withSign: true))),
                      DataCell(Text(report.leaderboard[i].metrics.sharpe.toStringAsFixed(2))),
                      DataCell(Text('${report.leaderboard[i].metrics.maxDrawdownPct.toStringAsFixed(1)}%')),
                      DataCell(Text(report.leaderboard[i].metrics.profitFactor.isFinite ? report.leaderboard[i].metrics.profitFactor.toStringAsFixed(2) : '∞')),
                      DataCell(Text(
                        report.leaderboard[i].validation.passed ? 'PASS' : 'FAIL',
                        style: TextStyle(color: report.leaderboard[i].validation.passed ? c.success : c.danger, fontSize: 12, fontWeight: FontWeight.w600),
                      )),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final ResearchReport report;
  const _LogCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Pipeline log', subtitle: 'Each stage, in order'),
          const SizedBox(height: Spacing.xs),
          for (final line in report.log)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.chevron_right_rounded, size: 15, color: c.accent),
                  const SizedBox(width: 4),
                  Expanded(child: Text(line, style: Theme.of(context).textTheme.bodySmall)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
