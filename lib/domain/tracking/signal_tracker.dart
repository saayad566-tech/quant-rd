/// Execution tracking: every generated signal is followed through the bars with
/// the Section 5 step-up trailing stop, and the outcomes are aggregated into the
/// performance metrics the directive asks for.
library;

import 'dart:math' as math;

import '../../data/models/candle.dart';
import '../quant/quant_risk.dart';
import '../strategy_engine/strategy_engine.dart';

class TrackedTrade {
  final Signal signal;
  final int entryIndex;
  final double entryPrice;
  final int exitIndex;
  final double exitPrice;
  final String exitReason;
  final double pnlPct;
  final double maxGainPct;
  final double maxDrawdownPct;

  const TrackedTrade({
    required this.signal,
    required this.entryIndex,
    required this.entryPrice,
    required this.exitIndex,
    required this.exitPrice,
    required this.exitReason,
    required this.pnlPct,
    required this.maxGainPct,
    required this.maxDrawdownPct,
  });

  bool get isWin => pnlPct > 0;
}

class TrackerMetrics {
  final int trades;
  final int wins;
  final int losses;
  final double winRate;
  final double profitFactor;
  final double expectancyPct;
  final double sharpe;
  final double maxDrawdownPct;
  final double averageGainPct;
  final double averageLossPct;
  final double averageHoldBars;

  const TrackerMetrics({
    required this.trades,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.profitFactor,
    required this.expectancyPct,
    required this.sharpe,
    required this.maxDrawdownPct,
    required this.averageGainPct,
    required this.averageLossPct,
    required this.averageHoldBars,
  });

  static const empty = TrackerMetrics(
    trades: 0,
    wins: 0,
    losses: 0,
    winRate: 0,
    profitFactor: 0,
    expectancyPct: 0,
    sharpe: 0,
    maxDrawdownPct: 0,
    averageGainPct: 0,
    averageLossPct: 0,
    averageHoldBars: 0,
  );

  String get summary =>
      '$trades trades · ${(winRate * 100).toStringAsFixed(0)}% win rate · '
      'PF ${profitFactor.isFinite ? profitFactor.toStringAsFixed(2) : '∞'} · '
      'expectancy ${expectancyPct.toStringAsFixed(2)}% · Sharpe ${sharpe.toStringAsFixed(2)} · '
      'max DD ${maxDrawdownPct.toStringAsFixed(1)}%';
}

class SignalTracker {
  const SignalTracker._();

  /// Follows each entry signal forward, applying the step-up trailing stop from
  /// the framework's risk section. An explicit exit signal closes the trade at
  /// that bar; otherwise the stop or the end of the data closes it.
  static List<TrackedTrade> simulate(List<Signal> signals, List<Candle> candles, {bool useTrailingStop = true}) {
    final trades = <TrackedTrade>[];
    if (signals.isEmpty || candles.isEmpty) return trades;

    // Build an index of exit signals so a strategy's own exit closes the trade.
    final exitIndices = <int>{};
    for (final s in signals) {
      if (!s.isEntry) exitIndices.add(s.index);
    }

    for (final entry in signals) {
      if (!entry.isEntry) continue;
      if (entry.index < 0 || entry.index >= candles.length) continue;

      final entryPrice = entry.price;
      if (entryPrice <= 0) continue;

      final stop = TrailingStop(entryPrice: entryPrice);
      var peak = entryPrice;
      var trough = entryPrice;
      var exitIndex = candles.length - 1;
      var exitPrice = candles.last.close;
      var reason = 'End of data';

      for (var i = entry.index; i < candles.length; i++) {
        final high = candles[i].high;
        final low = candles[i].low;
        peak = math.max(peak, high);
        trough = math.min(trough, low);

        if (useTrailingStop) {
          // Advance the stop on the close, then test the bar's low against it.
          final state = stop.update(candles[i].close);
          if (low <= state.stopPrice && i > entry.index) {
            exitIndex = i;
            exitPrice = state.stopPrice;
            reason = state.isRiskFree ? 'Trailing stop (locked in)' : 'Trailing stop';
            break;
          }
        } else if (entry.stop != null && low <= entry.stop! && i > entry.index) {
          exitIndex = i;
          exitPrice = entry.stop!;
          reason = 'Initial stop';
          break;
        }

        if (i > entry.index && exitIndices.contains(i)) {
          exitIndex = i;
          exitPrice = candles[i].close;
          reason = 'Strategy exit';
          break;
        }
      }

      trades.add(TrackedTrade(
        signal: entry,
        entryIndex: entry.index,
        entryPrice: entryPrice,
        exitIndex: exitIndex,
        exitPrice: exitPrice,
        exitReason: reason,
        pnlPct: (exitPrice / entryPrice - 1) * 100,
        maxGainPct: (peak / entryPrice - 1) * 100,
        maxDrawdownPct: (1 - trough / entryPrice) * 100,
      ));
    }
    return trades;
  }

  /// Aggregates trades into the performance dashboard.
  static TrackerMetrics metrics(List<TrackedTrade> trades) {
    if (trades.isEmpty) return TrackerMetrics.empty;

    final pnls = trades.map((t) => t.pnlPct).toList(growable: false);
    final expectancy = ExpectancyReport.fromPnls(pnls);
    final wins = trades.where((t) => t.isWin).toList(growable: false);
    final losses = trades.where((t) => !t.isWin).toList(growable: false);

    // An equal-weight equity curve, one unit of capital per trade, is the honest
    // way to read a signal list that was not sized.
    var equity = 100.0;
    final curve = <double>[];
    for (final p in pnls) {
      equity *= (1 + p / 100);
      curve.add(equity);
    }

    final returns = pnls.map((p) => p / 100).toList(growable: false);
    final holdBars = trades.map((t) => (t.exitIndex - t.entryIndex).toDouble()).toList(growable: false);

    return TrackerMetrics(
      trades: trades.length,
      wins: wins.length,
      losses: losses.length,
      winRate: expectancy.winRate,
      profitFactor: expectancy.profitFactor,
      expectancyPct: expectancy.expectancy,
      sharpe: QuantRisk.sharpe(returns),
      maxDrawdownPct: QuantRisk.maxDrawdownPct(curve),
      averageGainPct: expectancy.averageWin,
      averageLossPct: expectancy.averageLoss,
      averageHoldBars: holdBars.isEmpty ? 0 : holdBars.reduce((a, b) => a + b) / holdBars.length,
    );
  }

  /// The compliance marker that accompanies every tracking output.
  static const String complianceMarker = Signal.complianceMarker;
}
