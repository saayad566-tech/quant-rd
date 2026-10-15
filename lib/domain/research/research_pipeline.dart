/// A sequential, distributed-ready quantitative research pipeline.
///
/// Four stages run in order, each a real computation over real bars:
///
///   1. **Data Analyst**  — profiles the dataset (return, volatility, trend,
///      up-bar ratio, average range).
///   2. **Strategy Builder** — deterministically generates candidate strategies
///      from parameter grids. This is statistics, **not** a language model; no
///      number here is invented.
///   3. **Backtester** — runs each candidate through the event-driven engine.
///   4. **Validator** — applies the mandatory [ValidationPolicy] gate.
///
/// Two engineering guarantees:
///  * **Bounded memory** — only the top [keepTop] candidates are retained. Full
///    equity curves are discarded as soon as a candidate's metrics are computed,
///    so a sweep over hundreds of candidates does not grow memory without limit.
///  * **Bounded work queue** — candidates are processed in batches with an
///    explicit yield between them, so a long sweep cannot monopolise the frame
///    loop or spike CPU on a phone.
library;

import 'dart:math' as math;

import '../../data/models/backtest_config.dart';
import '../../data/models/candle.dart';
import '../../data/models/strategy_spec.dart';
import '../engine/backtest_engine.dart';
import '../engine/metrics.dart';
import 'validation.dart';

class DatasetProfile {
  final int bars;
  final DateTime? start;
  final DateTime? end;
  final double meanBarReturnPct;
  final double annualisedVolPct;
  final double totalReturnPct;
  final double upBarRatio;
  final double trendSlopePctPerBar;
  final double avgRangePct;

  const DatasetProfile({
    required this.bars,
    required this.start,
    required this.end,
    required this.meanBarReturnPct,
    required this.annualisedVolPct,
    required this.totalReturnPct,
    required this.upBarRatio,
    required this.trendSlopePctPerBar,
    required this.avgRangePct,
  });

  static const DatasetProfile empty = DatasetProfile(
    bars: 0,
    start: null,
    end: null,
    meanBarReturnPct: 0,
    annualisedVolPct: 0,
    totalReturnPct: 0,
    upBarRatio: 0,
    trendSlopePctPerBar: 0,
    avgRangePct: 0,
  );

  String get regime {
    final trending = trendSlopePctPerBar.abs() > 0.02;
    if (trending) return trendSlopePctPerBar > 0 ? 'Uptrend' : 'Downtrend';
    return annualisedVolPct > 40 ? 'High-volatility range' : 'Range-bound';
  }

  String summary() =>
      '$bars bars · total ${totalReturnPct.toStringAsFixed(1)}% · '
      'vol ${annualisedVolPct.toStringAsFixed(1)}%/yr · '
      'trend ${trendSlopePctPerBar.toStringAsFixed(3)}%/bar · '
      'up-bars ${(upBarRatio * 100).toStringAsFixed(0)}% · regime: $regime';
}

class CandidateResult {
  final StrategySpec strategy;
  final Metrics metrics;
  final ValidationOutcome validation;
  final double score;

  const CandidateResult({
    required this.strategy,
    required this.metrics,
    required this.validation,
    required this.score,
  });
}

class ResearchReport {
  final DatasetProfile profile;
  final List<CandidateResult> leaderboard;
  final int evaluated;
  final int rejected;
  final Duration elapsed;
  final List<String> log;
  final String datasetId;
  final String symbol;

  const ResearchReport({
    required this.profile,
    required this.leaderboard,
    required this.evaluated,
    required this.rejected,
    required this.elapsed,
    required this.log,
    this.datasetId = '',
    this.symbol = '',
  });

  CandidateResult? get best => leaderboard.isEmpty ? null : leaderboard.first;
}

class ResearchPipeline {
  final ValidationPolicy policy;

  const ResearchPipeline({this.policy = const ValidationPolicy()});

  /// A transparent, documented ranking score. Higher is better.
  ///
  ///   score = Sharpe + 0.3 × min(profitFactor, 5) − 0.5 × maxDrawdown(fraction)
  ///
  /// It rewards risk-adjusted return, mildly rewards profit factor, and
  /// penalises deep drawdowns. All three components are shown in the UI, so a
  /// ranking is never a black box.
  static double scoreOf(Metrics m) {
    final pf = m.profitFactor.isFinite ? m.profitFactor.clamp(0.0, 5.0) : 5.0;
    final sharpe = m.sharpe.isFinite ? m.sharpe : 0.0;
    return sharpe + 0.3 * pf - 0.5 * (m.maxDrawdownPct / 100.0);
  }

  // --- Stage 1: Data Analyst ------------------------------------------------

  static DatasetProfile profile(List<Candle> candles, BacktestConfig config) {
    if (candles.length < 2) return DatasetProfile.empty;
    final closes = candles.map((c) => c.close).toList();
    final returns = <double>[];
    for (var i = 1; i < closes.length; i++) {
      final prev = closes[i - 1];
      if (prev != 0) returns.add(closes[i] / prev - 1);
    }
    final mean = returns.isEmpty ? 0.0 : returns.reduce((a, b) => a + b) / returns.length;
    var variance = 0.0;
    for (final r in returns) {
      variance += (r - mean) * (r - mean);
    }
    variance = returns.isEmpty ? 0.0 : variance / returns.length;
    final sd = math.sqrt(variance);
    final vol = sd * math.sqrt(config.barsPerYear.toDouble()) * 100;
    final upRatio = returns.isEmpty ? 0.5 : returns.where((r) => r > 0).length / returns.length;

    final n = closes.length;
    final meanIdx = (n - 1) / 2;
    final meanPrice = closes.reduce((a, b) => a + b) / n;
    var num = 0.0, den = 0.0;
    for (var i = 0; i < n; i++) {
      num += (i - meanIdx) * (closes[i] - meanPrice);
      den += (i - meanIdx) * (i - meanIdx);
    }
    final slope = den == 0 ? 0.0 : num / den;
    final slopePct = meanPrice == 0 ? 0.0 : slope / meanPrice * 100;

    var rangeSum = 0.0;
    for (final c in candles) {
      if (c.close != 0) rangeSum += (c.high - c.low) / c.close;
    }
    final avgRangePct = rangeSum / candles.length * 100;

    return DatasetProfile(
      bars: n,
      start: candles.first.time,
      end: candles.last.time,
      meanBarReturnPct: mean * 100,
      annualisedVolPct: vol,
      totalReturnPct: closes.first == 0 ? 0 : (closes.last / closes.first - 1) * 100,
      upBarRatio: upRatio,
      trendSlopePctPerBar: slopePct,
      avgRangePct: avgRangePct,
    );
  }

  // --- Stage 2: Strategy Builder -------------------------------------------

  /// Deterministically generates a candidate grid. The same dataset always
  /// yields the same candidates in the same order — reproducible research.
  static List<StrategySpec> generate(DatasetProfile p, {int limit = 40, DateTime? stamp}) {
    final now = stamp ?? DateTime.utc(2024, 1, 1);
    final specs = <StrategySpec>[];

    for (final fast in const [5, 10, 20, 50]) {
      for (final slow in const [30, 60, 100, 200]) {
        if (fast >= slow) continue;
        specs.add(_cross('SMA $fast/$slow', SeriesRef(IndicatorType.sma, period: fast), SeriesRef(IndicatorType.sma, period: slow), now));
      }
    }
    for (final fast in const [5, 10, 20]) {
      for (final slow in const [30, 50, 100]) {
        if (fast >= slow) continue;
        specs.add(_cross('EMA $fast/$slow', SeriesRef(IndicatorType.ema, period: fast), SeriesRef(IndicatorType.ema, period: slow), now));
      }
    }
    for (final lo in const [20.0, 25.0, 30.0, 35.0]) {
      for (final hi in const [65.0, 70.0, 75.0, 80.0]) {
        specs.add(_rsi(lo, hi, now));
      }
    }
    specs.add(_macd(now));
    for (final mult in const [2.0, 2.5]) {
      specs.add(_bollinger(mult, now));
    }
    return specs.take(limit).toList(growable: false);
  }

  static StrategySpec _cross(String name, SeriesRef fast, SeriesRef slow, DateTime stamp) => StrategySpec(
        id: 'gen.cross.${fast.period}.${slow.period}.${fast.type.name}',
        frameworkId: 'weinstein-stage',
        name: '$name crossover',
        description: 'Generated: enter when the fast line crosses above the slow line, exit on the reverse cross.',
        entry: [Condition(left: Operand.series(fast), op: ComparisonOp.crossesAbove, right: Operand.series(slow))],
        exit: [Condition(left: Operand.series(fast), op: ComparisonOp.crossesBelow, right: Operand.series(slow))],
        sizing: PositionSizing.allIn,
        updatedAt: stamp,
      );

  static StrategySpec _rsi(double lo, double hi, DateTime stamp) => StrategySpec(
        id: 'gen.rsi.${lo.toInt()}.${hi.toInt()}',
        frameworkId: 'wilder-rsi-atr',
        name: 'RSI mean-reversion ${lo.toInt()}/${hi.toInt()}',
        description: 'Generated: buy while RSI is below $lo, exit when RSI rises above $hi.',
        entry: [Condition(left: const Operand.series(SeriesRef(IndicatorType.rsi, period: 14)), op: ComparisonOp.lessThan, right: Operand.constant(lo))],
        exit: [Condition(left: const Operand.series(SeriesRef(IndicatorType.rsi, period: 14)), op: ComparisonOp.greaterThan, right: Operand.constant(hi))],
        sizing: PositionSizing.allIn,
        updatedAt: stamp,
      );

  static StrategySpec _macd(DateTime stamp) => StrategySpec(
        id: 'gen.macd',
        frameworkId: 'momentum-factor',
        name: 'MACD trend',
        description: 'Generated: enter on a bullish MACD cross, exit on a bearish one.',
        entry: [
          const Condition(
            left: Operand.series(SeriesRef(IndicatorType.macdLine, period: 12, period2: 26, period3: 9)),
            op: ComparisonOp.crossesAbove,
            right: Operand.series(SeriesRef(IndicatorType.macdSignal, period: 12, period2: 26, period3: 9)),
          ),
        ],
        exit: [
          const Condition(
            left: Operand.series(SeriesRef(IndicatorType.macdLine, period: 12, period2: 26, period3: 9)),
            op: ComparisonOp.crossesBelow,
            right: Operand.series(SeriesRef(IndicatorType.macdSignal, period: 12, period2: 26, period3: 9)),
          ),
        ],
        sizing: PositionSizing.allIn,
        updatedAt: stamp,
      );

  static StrategySpec _bollinger(double mult, DateTime stamp) => StrategySpec(
        id: 'gen.boll.${mult.toStringAsFixed(1)}',
        frameworkId: 'turtle-trend',
        name: 'Bollinger breakout ${mult}x',
        description: 'Generated: buy a close above the upper band, exit at the middle band.',
        entry: [
          Condition(
            left: const Operand.series(SeriesRef(IndicatorType.close)),
            op: ComparisonOp.crossesAbove,
            right: Operand.series(SeriesRef(IndicatorType.bollUpper, period: 20, multiplier: mult)),
          ),
        ],
        exit: [
          Condition(
            left: const Operand.series(SeriesRef(IndicatorType.close)),
            op: ComparisonOp.crossesBelow,
            right: Operand.series(SeriesRef(IndicatorType.bollMiddle, period: 20, multiplier: mult)),
          ),
        ],
        sizing: PositionSizing.allIn,
        updatedAt: stamp,
      );

  // --- Orchestration --------------------------------------------------------

  Future<ResearchReport> run({
    required List<Candle> candles,
    required String datasetId,
    required String symbol,
    required String workspaceId,
    required BacktestConfig config,
    int maxCandidates = 40,
    int batchSize = 8,
    int keepTop = 10,
    void Function(double progress, String message)? onProgress,
  }) async {
    final started = DateTime.now();
    final log = <String>[];
    final profile = ResearchPipeline.profile(candles, config);
    log.add('Data Analyst: ${profile.summary()}');

    if (candles.length < 30) {
      log.add('Not enough bars to research (need at least 30).');
      return ResearchReport(
        profile: profile,
        leaderboard: const [],
        evaluated: 0,
        rejected: 0,
        elapsed: DateTime.now().difference(started),
        log: log,
        datasetId: datasetId,
        symbol: symbol,
      );
    }

    final candidates = generate(profile, limit: maxCandidates);
    log.add('Strategy Builder: generated ${candidates.length} candidates from parameter grids.');

    // Bounded leaderboard: only the best `keepTop` survive in memory.
    final kept = <CandidateResult>[];
    var evaluated = 0;
    var rejected = 0;

    final total = candidates.length;
    final size = batchSize < 1 ? 1 : batchSize;

    for (var start = 0; start < total; start += size) {
      final end = math.min(start + size, total);
      for (var i = start; i < end; i++) {
        final spec = candidates[i];
        // Full result is local: its equity curve is released after metrics are
        // read, so memory stays flat across the whole sweep.
        final result = BacktestEngine.run(
          resultId: 'research-${spec.id}',
          candles: candles,
          strategy: spec,
          config: config,
          datasetId: datasetId,
          symbol: symbol,
          workspaceId: workspaceId,
        );
        final outcome = ValidationOutcome.evaluate(result.metrics, policy);
        evaluated++;
        if (!outcome.passed) rejected++;

        final candidate = CandidateResult(
          strategy: spec,
          metrics: result.metrics,
          validation: outcome,
          score: scoreOf(result.metrics),
        );

        kept.add(candidate);
        kept.sort((a, b) => b.score.compareTo(a.score));
        if (kept.length > keepTop) {
          kept.removeRange(keepTop, kept.length);
        }
      }
      onProgress?.call(end / total, 'Evaluated $end of $total candidates…');
      // Yield to the event loop between batches: keeps the UI responsive and
      // prevents a long sweep from saturating the device.
      await Future<void>.delayed(Duration.zero);
    }

    log.add('Backtester: evaluated $evaluated candidates.');
    log.add('Validator: $rejected rejected by policy (${policy.minTrades}+ trades, PF ≥ ${policy.minProfitFactor}, DD ≤ ${policy.maxDrawdownPct}%).');
    if (kept.isNotEmpty) {
      log.add('Top candidate: ${kept.first.strategy.name} (score ${kept.first.score.toStringAsFixed(2)}, ${kept.first.validation.passed ? 'passed' : 'failed'} validation).');
    }

    return ResearchReport(
      profile: profile,
      leaderboard: List.unmodifiable(kept),
      evaluated: evaluated,
      rejected: rejected,
      elapsed: DateTime.now().difference(started),
      log: log,
      datasetId: datasetId,
      symbol: symbol,
    );
  }
}
