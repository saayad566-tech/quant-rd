/// Evaluates strategy conditions against pre-computed indicator series.
///
/// The evaluator is pure and side-effect free, which makes it directly unit
/// testable and reusable by both the backtester and the strategy preview UI.
library;

import '../../data/models/candle.dart';
import '../../data/models/strategy_spec.dart';
import '../indicators/indicators.dart';

class StrategyEngine {
  const StrategyEngine._();

  /// Computes every series the strategy needs, keyed by [SeriesRef.key].
  static Map<String, List<double?>> computeSeries(List<SeriesRef> refs, List<Candle> candles) {
    final map = <String, List<double?>>{};
    for (final ref in refs) {
      map[ref.key] = Indicators.computeSeries(ref, candles);
    }
    return map;
  }

  /// The minimum number of bars required before any signal can be valid.
  ///
  /// Only the indicators actually referenced are counted, and one extra bar is
  /// added when a cross operator is used (which needs the previous value).
  static int warmupBars(StrategySpec strategy) {
    final refs = strategy.requiredSeries;
    var usesCross = false;
    for (final c in [...strategy.entry, ...strategy.exit]) {
      if (c.op == ComparisonOp.crossesAbove || c.op == ComparisonOp.crossesBelow) {
        usesCross = true;
        break;
      }
    }
    var maxNeeded = 0;
    for (final r in refs) {
      final needed = switch (r.type) {
        IndicatorType.close || IndicatorType.volume => 0,
        IndicatorType.macdLine || IndicatorType.macdSignal || IndicatorType.macdHist => r.period2 + r.period3,
        IndicatorType.stochD => r.period + r.period3,
        _ => r.period,
      };
      if (needed > maxNeeded) maxNeeded = needed;
    }
    return maxNeeded + (usesCross ? 1 : 0);
  }

  /// True when ALL entry conditions hold at bar [i].
  static bool entrySignal(StrategySpec strategy, int i, Map<String, List<double?>> series) {
    if (strategy.entry.isEmpty) return false;
    return strategy.entry.every((c) => evaluate(c, i, series));
  }

  /// True when ANY exit condition holds at bar [i].
  static bool exitSignal(StrategySpec strategy, int i, Map<String, List<double?>> series) {
    if (strategy.exit.isEmpty) return false;
    return strategy.exit.any((c) => evaluate(c, i, series));
  }

  static bool evaluate(Condition c, int i, Map<String, List<double?>> series) {
    final l = _value(c.left, i, series);
    final r = _value(c.right, i, series);
    if (l == null || r == null) return false;
    switch (c.op) {
      case ComparisonOp.greaterThan:
        return l > r;
      case ComparisonOp.lessThan:
        return l < r;
      case ComparisonOp.crossesAbove:
        if (i == 0) return false;
        final lp = _value(c.left, i - 1, series);
        final rp = _value(c.right, i - 1, series);
        if (lp == null || rp == null) return false;
        return lp <= rp && l > r;
      case ComparisonOp.crossesBelow:
        if (i == 0) return false;
        final lp = _value(c.left, i - 1, series);
        final rp = _value(c.right, i - 1, series);
        if (lp == null || rp == null) return false;
        return lp >= rp && l < r;
    }
  }

  static double? _value(Operand o, int i, Map<String, List<double?>> series) {
    if (o.isConstant) return o.constant;
    final s = series[o.ref!.key];
    if (s == null || i < 0 || i >= s.length) return null;
    return s[i];
  }
}
