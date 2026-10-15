/// Quant Engine screen: the mechanics library and the strategy plugin engine,
/// surfaced and wired to real data.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/candle.dart';
import '../../data/models/dataset.dart';
import '../../domain/providers/core_providers.dart';
import '../../domain/providers/feature_providers.dart';
import '../../domain/quant/quant_mechanics.dart';
import '../../domain/quant/quant_risk.dart';
import '../../domain/strategy_engine/strategy_engine.dart';
import '../../domain/tracking/signal_tracker.dart';
import '../widgets/common.dart';
import 'book_intelligence_screen.dart';

class QuantEngineScreen extends ConsumerStatefulWidget {
  const QuantEngineScreen({super.key});

  @override
  ConsumerState<QuantEngineScreen> createState() => _QuantEngineScreenState();
}

class _QuantEngineScreenState extends ConsumerState<QuantEngineScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, Spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Quant Engine',
                subtitle: 'Deterministic mechanics and a plugin strategy engine, computed from your data.',
              ),
              SizedBox(height: Spacing.sm),
              ComplianceBanner(compact: true),
            ],
          ),
        ),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Mechanics'),
            Tab(text: 'Strategy engine'),
            Tab(text: 'Execution tracking'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              _MechanicsTab(),
              _EngineTab(),
              _TrackingTab(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Loads the candles for a dataset, cached for the screen.
final _candleCache = <String, List<Candle>>{};

Future<List<Candle>> _loadCandles(WidgetRef ref, String datasetId) async {
  if (_candleCache.containsKey(datasetId)) return _candleCache[datasetId]!;
  final candles = await ref.read(datasetRepositoryProvider).candles(datasetId);
  _candleCache[datasetId] = candles;
  return candles;
}

class _DatasetPicker extends StatelessWidget {
  final List<Dataset> datasets;
  final String? value;
  final ValueChanged<String?> onChanged;
  const _DatasetPicker({required this.datasets, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (datasets.isEmpty) {
      return Text('No datasets yet — fetch or import market data first.', style: Theme.of(context).textTheme.bodySmall);
    }
    return DropdownButtonFormField<String>(
      initialValue: value ?? datasets.first.id,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Dataset', isDense: true),
      items: datasets
          .map((d) => DropdownMenuItem(
                value: d.id,
                child: Text('${d.symbol} · ${d.interval.label} · ${Fmt.integer(d.barCount)} bars', overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

// ---------------------------------------------------------------------------
// Mechanics
// ---------------------------------------------------------------------------

class _MechanicsTab extends ConsumerStatefulWidget {
  const _MechanicsTab();
  @override
  ConsumerState<_MechanicsTab> createState() => _MechanicsTabState();
}

class _MechanicsTabState extends ConsumerState<_MechanicsTab> {
  String? _datasetId;
  List<Candle>? _candles;
  bool _busy = false;

  Future<void> _compute(String id) async {
    setState(() {
      _datasetId = id;
      _busy = true;
    });
    final c = await _loadCandles(ref, id);
    if (!mounted) return;
    setState(() {
      _candles = c;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final datasets = ref.watch(datasetsProvider);
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Compute', subtitle: 'Pick a dataset to derive its mechanics'),
              const SizedBox(height: Spacing.sm),
              datasets.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(message: '$e'),
                data: (list) => Row(
                  children: [
                    Expanded(child: _DatasetPicker(datasets: list, value: _datasetId, onChanged: (v) => v == null ? null : _compute(v))),
                    const SizedBox(width: Spacing.sm),
                    FilledButton.icon(
                      onPressed: list.isEmpty || _busy ? null : () => _compute(_datasetId ?? list.first.id),
                      icon: const Icon(Icons.calculate_rounded, size: 18),
                      label: Text(_busy ? 'Working…' : 'Analyse'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_candles != null && _candles!.isNotEmpty) ...[
          const SizedBox(height: Spacing.md),
          _regimeCard(context, _candles!),
          const SizedBox(height: Spacing.md),
          _levelsCard(context, _candles!),
          const SizedBox(height: Spacing.md),
          _profileCard(context, _candles!),
          const SizedBox(height: Spacing.md),
          _patternsCard(context, _candles!),
        ],
        if (_candles != null && _candles!.length < 30)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.sm),
            child: Text('That dataset is too short for the regime, profile and pattern calculations.', style: TextStyle(color: c.warning, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _regimeCard(BuildContext context, List<Candle> candles) {
    final r = QuantMechanics.regime(candles);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Market regime', subtitle: 'Trend slope against realised volatility'),
          const SizedBox(height: Spacing.sm),
          if (r == null)
            Text('Not enough history to classify the regime.', style: Theme.of(context).textTheme.bodySmall)
          else ...[
            Pill(label: r.regime.label, color: context.colors.accent),
            const SizedBox(height: Spacing.xs),
            Text(r.explanation, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Spacing.xxs),
            Text('Suggested exposure weight: ${(r.regime.weight * 100).toStringAsFixed(0)}%', style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _levelsCard(BuildContext context, List<Candle> candles) {
    final levels = QuantMechanics.supportResistance(candles);
    final vwap = QuantMechanics.vwap(candles);
    final last = candles.last.close;
    final lastVwap = vwap.isNotEmpty ? vwap.last : null;
    final high252 = candles.length >= 252 ? candles.sublist(candles.length - 252) : candles;
    var hi = double.negativeInfinity, lo = double.infinity;
    for (final b in high252) {
      if (b.high > hi) hi = b.high;
      if (b.low < lo) lo = b.low;
    }
    final fib = QuantMechanics.fibonacci(lo, hi);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Levels', subtitle: 'Reaction clusters, VWAP and Fibonacci retracements'),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              MetricTile(label: 'Last', value: last.toStringAsFixed(2)),
              if (lastVwap != null) MetricTile(label: 'VWAP', value: lastVwap.toStringAsFixed(2)),
              MetricTile(label: '52w high', value: hi.toStringAsFixed(2)),
              MetricTile(label: '52w low', value: lo.toStringAsFixed(2)),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text('SUPPORT / RESISTANCE (by touches)', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: Spacing.xxs),
          if (levels.isEmpty)
            Text('No clustered levels found.', style: Theme.of(context).textTheme.bodySmall)
          else
            for (final l in levels.take(6))
              Text(
                '${l.price.toStringAsFixed(2)} · ${l.touches} touches · ${l.isResistance ? 'resistance' : 'support'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
              ),
          const SizedBox(height: Spacing.sm),
          Text('FIBONACCI', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: Spacing.xxs),
          for (final e in fib.entries)
            Text('${e.key}: ${e.value.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
        ],
      ),
    );
  }

  Widget _profileCard(BuildContext context, List<Candle> candles) {
    final p = QuantMechanics.volumeProfile(candles);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Volume profile', subtitle: 'Point of control and the 70% value area'),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              MetricTile(label: 'POC', value: p.poc.toStringAsFixed(2), accent: context.colors.accent),
              MetricTile(label: 'Value-area high', value: p.vah.toStringAsFixed(2)),
              MetricTile(label: 'Value-area low', value: p.val.toStringAsFixed(2)),
              MetricTile(label: 'High-volume nodes', value: '${p.highVolumeNodes.length}'),
              MetricTile(label: 'Low-volume nodes', value: '${p.lowVolumeNodes.length}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _patternsCard(BuildContext context, List<Candle> candles) {
    final patterns = [
      ...QuantMechanics.doubleTopsAndBottoms(candles),
      ...QuantMechanics.headAndShoulders(candles),
    ];
    final gaps = QuantMechanics.gaps(candles);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Detected structures', subtitle: 'Reversal formations and gap taxonomy'),
          const SizedBox(height: Spacing.sm),
          if (patterns.isEmpty && gaps.isEmpty)
            Text('Nothing detected on this series.', style: Theme.of(context).textTheme.bodySmall)
          else ...[
            for (final p in patterns.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${p.name} · confidence ${(p.confidence * 100).toStringAsFixed(0)}% — ${p.description}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
              ),
            if (gaps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${gaps.length} gaps classified; most recent: ${gaps.last.name}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Strategy engine
// ---------------------------------------------------------------------------

class _EngineTab extends ConsumerStatefulWidget {
  const _EngineTab();
  @override
  ConsumerState<_EngineTab> createState() => _EngineTabState();
}

class _EngineTabState extends ConsumerState<_EngineTab> {
  String? _datasetId;
  String _symbol = '';
  String? _strategyId;
  List<Signal>? _signals;
  TrackerMetrics? _metrics;
  bool _busy = false;

  Future<void> _run() async {
    final sid = _strategyId;
    if (sid == null || _datasetId == null) return;
    setState(() => _busy = true);
    final candles = await _loadCandles(ref, _datasetId!);
    final strategy = StrategyFactory.create(sid);
    if (strategy == null || candles.isEmpty) {
      setState(() => _busy = false);
      return;
    }
    final signals = strategy.generateSignals(_symbol, candles);
    final trades = SignalTracker.simulate(signals, candles);
    if (!mounted) return;
    setState(() {
      _signals = signals;
      _metrics = SignalTracker.metrics(trades);
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final datasets = ref.watch(datasetsProvider);
    final strategies = StrategyFactory.all();
    final selected = _strategyId == null ? null : StrategyFactory.create(_strategyId!);

    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Registered strategies (${strategies.length})',
                subtitle: 'Every strategy declares the book and rule it came from',
              ),
              const SizedBox(height: Spacing.sm),
              if (strategies.isEmpty)
                Text('No strategies registered.', style: Theme.of(context).textTheme.bodySmall)
              else
                DropdownButtonFormField<String>(
                  initialValue: _strategyId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Strategy', isDense: true),
                  items: strategies
                      .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _strategyId = v;
                    _signals = null;
                    _metrics = null;
                  }),
                ),
              if (selected != null) ...[
                const SizedBox(height: Spacing.sm),
                _ProvenanceCard(strategy: selected),
              ],
              const SizedBox(height: Spacing.sm),
              datasets.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => ErrorView(message: '$e'),
                data: (list) => Row(
                  children: [
                    Expanded(
                      child: _DatasetPicker(
                        datasets: list,
                        value: _datasetId,
                        onChanged: (v) => setState(() {
                          _datasetId = v;
                          _symbol = list.firstWhere((d) => d.id == v, orElse: () => list.first).symbol;
                          _signals = null;
                          _metrics = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    FilledButton.icon(
                      onPressed: list.isEmpty || _strategyId == null || _busy ? null : _run,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(_busy ? 'Running…' : 'Run'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_metrics != null) ...[
          const SizedBox(height: Spacing.md),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Execution tracking', subtitle: 'Followed through the bars with the Section 5 trailing stop'),
                const SizedBox(height: Spacing.sm),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: [
                    MetricTile(label: 'Trades', value: '${_metrics!.trades}'),
                    MetricTile(label: 'Win rate', value: '${(_metrics!.winRate * 100).toStringAsFixed(0)}%'),
                    MetricTile(label: 'Profit factor', value: _metrics!.profitFactor.isFinite ? _metrics!.profitFactor.toStringAsFixed(2) : '∞'),
                    MetricTile(label: 'Expectancy', value: '${_metrics!.expectancyPct.toStringAsFixed(2)}%'),
                    MetricTile(label: 'Sharpe', value: _metrics!.sharpe.toStringAsFixed(2)),
                    MetricTile(label: 'Max drawdown', value: '${_metrics!.maxDrawdownPct.toStringAsFixed(1)}%'),
                    MetricTile(label: 'Avg hold', value: '${_metrics!.averageHoldBars.toStringAsFixed(0)} bars'),
                  ],
                ),
                const SizedBox(height: Spacing.xs),
                Text(SignalTracker.complianceMarker, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5, color: context.colors.warning)),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: 'Signals (${_signals?.length ?? 0})', subtitle: 'Newest first, each with its rationale'),
                const SizedBox(height: Spacing.sm),
                if (_signals == null || _signals!.isEmpty)
                  Text('This strategy produced no signals on that dataset.', style: Theme.of(context).textTheme.bodySmall)
                else
                  for (final s in _signals!.reversed.take(15))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${s.time.toIso8601String().split('T').first}  ${s.describe()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: s.isEntry ? context.colors.success : context.colors.danger,
                            ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ProvenanceCard extends StatelessWidget {
  final BaseStrategy strategy;
  const _ProvenanceCard({required this.strategy});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: c.accentAlt.withValues(alpha: 0.08),
        borderRadius: Radii.rSm,
        border: Border.all(color: c.accentAlt.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('[Framework: ${strategy.provenance.frameworkName}]', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 12.5)),
          Text(strategy.provenance.citation, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
          const SizedBox(height: 2),
          Text(strategy.description, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
          for (final e in strategy.provenance.notes.entries)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('${e.key}: ${e.value}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5, color: c.warning)),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Execution tracking (trailing-stop ladder)
// ---------------------------------------------------------------------------

class _TrackingTab extends StatefulWidget {
  const _TrackingTab();
  @override
  State<_TrackingTab> createState() => _TrackingTabState();
}

class _TrackingTabState extends State<_TrackingTab> {
  final _entry = TextEditingController(text: '100');
  final _path = TextEditingController(text: '105, 112, 118, 126, 140, 158, 150');
  TrailingStopResult? _result;

  @override
  void dispose() {
    _entry.dispose();
    _path.dispose();
    super.dispose();
  }

  void _run() {
    final entry = double.tryParse(_entry.text.trim());
    if (entry == null || entry <= 0) return;
    final prices = _path.text
        .split(RegExp(r'[,\s]+'))
        .where((s) => s.isNotEmpty)
        .map(double.tryParse)
        .whereType<double>()
        .toList(growable: false);
    if (prices.isEmpty) return;
    setState(() => _result = TrailingStop(entryPrice: entry).replay(prices));
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Step-up trailing stop',
                subtitle: 'The Section 5 ladder: a -10% floor, break-even at +10%, +5% at +15%, +10% at +20%, a 10% gap to +50%, then 5-point steps',
              ),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  SizedBox(width: 140, child: TextField(controller: _entry, decoration: const InputDecoration(labelText: 'Entry price', isDense: true))),
                  const SizedBox(width: Spacing.sm),
                  Expanded(child: TextField(controller: _path, decoration: const InputDecoration(labelText: 'Price path (comma separated)', isDense: true))),
                  const SizedBox(width: Spacing.sm),
                  FilledButton(onPressed: _run, child: const Text('Replay')),
                ],
              ),
            ],
          ),
        ),
        if (r != null) ...[
          const SizedBox(height: Spacing.md),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: r.exited ? 'Exited at ${r.exitPrice!.toStringAsFixed(2)}' : 'Still open',
                  subtitle: r.exited ? 'Realised ${r.realisedGainPct.toStringAsFixed(2)}%' : 'No stop was touched along that path',
                ),
                const SizedBox(height: Spacing.sm),
                for (final s in r.history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      'peak ${s.peakPrice.toStringAsFixed(2)} → stop ${s.stopPrice.toStringAsFixed(2)}  (${s.description})',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11.5,
                            color: s.isRiskFree ? context.colors.success : context.colors.textMuted,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
