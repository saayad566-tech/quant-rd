/// Risk, position-sizing and statistical mechanics.
///
/// [TrailingStop] implements the step-up trailing stop specified in the
/// directive's Section 5 exactly as written, including its ratchet behaviour.
library;

import 'dart:math' as math;

// ---------------------------------------------------------------------------
// The step-up trailing stop (Section 5, implemented verbatim)
// ---------------------------------------------------------------------------

class TrailingStopState {
  final double entryPrice;
  final double peakPrice;
  final double stopPrice;
  final double peakGainPct;
  final double stopGainPct;
  final bool stoppedOut;

  const TrailingStopState({
    required this.entryPrice,
    required this.peakPrice,
    required this.stopPrice,
    required this.peakGainPct,
    required this.stopGainPct,
    required this.stoppedOut,
  });

  /// True once the stop has been ratcheted above break-even, so the position can
  /// no longer lose money if the stop holds.
  bool get isRiskFree => stopPrice >= entryPrice;

  String get description =>
      'Peak ${peakGainPct >= 0 ? '+' : ''}${peakGainPct.toStringAsFixed(1)}%, '
      'stop ${stopGainPct >= 0 ? '+' : ''}${stopGainPct.toStringAsFixed(1)}%'
      '${isRiskFree ? ' (risk-free)' : ''}';
}

class TrailingStop {
  /// The hard initial risk floor: -10% from entry.
  static const double initialFloorPct = -10.0;

  /// The step-up ladder from the directive.
  static const double stepOneGainPct = 10.0; // -> move to break-even
  static const double stepTwoGainPct = 15.0; // -> trail to +5%
  static const double stepThreeGainPct = 20.0; // -> trail to +10%
  static const double tightenedGainPct = 50.0; // -> tighten to 5-point intervals

  final double entryPrice;
  double _peak;
  double _stop;

  TrailingStop({required this.entryPrice})
      : _peak = entryPrice,
        _stop = entryPrice * (1 + initialFloorPct / 100);

  /// Advances the stop for a new price observation. The stop only ever moves up
  /// (the ratchet), so a raised stop is never loosened.
  TrailingStopState update(double price) {
    if (price > _peak) _peak = price;
    final peakGainPct = (_peak / entryPrice - 1) * 100;

    // The ladder thresholds are compared with a tolerance: (115/100 - 1) * 100
    // evaluates to 14.999999999999991 in binary floating point, which would
    // otherwise miss the +15% step by a rounding error.
    const eps = 1e-9;
    double candidate;
    if (peakGainPct >= tightenedGainPct - eps) {
      // Gains beyond +50%: tighten to 5 percentage-point intervals, so a peak at
      // +55% locks a stop at +50%.
      final lockedGain = math.max(0.0, peakGainPct - 5.0);
      candidate = entryPrice * (1 + lockedGain / 100);
    } else if (peakGainPct >= stepThreeGainPct - eps) {
      // +20% and above: a 10% trailing gap beneath the highest peak price.
      candidate = _peak * 0.90;
    } else if (peakGainPct >= stepTwoGainPct - eps) {
      candidate = entryPrice * 1.05;
    } else if (peakGainPct >= stepOneGainPct - eps) {
      candidate = entryPrice * 1.00;
    } else {
      candidate = entryPrice * (1 + initialFloorPct / 100);
    }

    if (candidate > _stop) _stop = candidate;

    return TrailingStopState(
      entryPrice: entryPrice,
      peakPrice: _peak,
      stopPrice: _stop,
      peakGainPct: peakGainPct,
      stopGainPct: (_stop / entryPrice - 1) * 100,
      stoppedOut: price <= _stop,
    );
  }

  /// Replays a whole series of closing prices and returns the exit, if any.
  ///
  /// The exit is filled **at the stop level**, which is the standard convention
  /// when only closes are available: a stop order resting in the market fills as
  /// soon as price reaches it. A gap straight through the stop would fill worse
  /// than this, so the result is mildly optimistic on gaps — stated rather than
  /// hidden. Use [SignalTracker.simulate] with bar lows for a per-bar test.
  TrailingStopResult replay(List<double> prices) {
    final history = <TrailingStopState>[];
    for (final p in prices) {
      final s = update(p);
      history.add(s);
      if (s.stoppedOut) {
        return TrailingStopResult(exitPrice: s.stopPrice, exitIndex: history.length - 1, state: s, history: history);
      }
    }
    return TrailingStopResult(
      exitPrice: null,
      exitIndex: null,
      state: history.isEmpty
          ? update(entryPrice)
          : history.last,
      history: history,
    );
  }
}

class TrailingStopResult {
  final double? exitPrice;
  final int? exitIndex;
  final TrailingStopState state;
  final List<TrailingStopState> history;

  const TrailingStopResult({required this.exitPrice, required this.exitIndex, required this.state, required this.history});

  bool get exited => exitPrice != null;

  double get realisedGainPct => exitPrice == null ? 0 : (exitPrice! / state.entryPrice - 1) * 100;
}

// ---------------------------------------------------------------------------
// Position sizing and expectancy
// ---------------------------------------------------------------------------

class ExpectancyReport {
  final double winRate;
  final double averageWin;
  final double averageLoss;
  final double expectancy;
  final double profitFactor;
  final int trades;

  const ExpectancyReport({
    required this.winRate,
    required this.averageWin,
    required this.averageLoss,
    required this.expectancy,
    required this.profitFactor,
    required this.trades,
  });

  static ExpectancyReport fromPnls(List<double> pnls) {
    if (pnls.isEmpty) {
      return const ExpectancyReport(winRate: 0, averageWin: 0, averageLoss: 0, expectancy: 0, profitFactor: 0, trades: 0);
    }
    final wins = pnls.where((p) => p > 0).toList(growable: false);
    final losses = pnls.where((p) => p < 0).toList(growable: false);
    final winRate = wins.length / pnls.length;
    final avgWin = wins.isEmpty ? 0.0 : wins.reduce((a, b) => a + b) / wins.length;
    final avgLoss = losses.isEmpty ? 0.0 : losses.reduce((a, b) => a + b).abs() / losses.length;
    final grossWin = wins.fold(0.0, (a, b) => a + b);
    final grossLoss = losses.fold(0.0, (a, b) => a + b.abs());
    return ExpectancyReport(
      winRate: winRate,
      averageWin: avgWin,
      averageLoss: avgLoss,
      expectancy: winRate * avgWin - (1 - winRate) * avgLoss,
      profitFactor: grossLoss == 0 ? (grossWin > 0 ? double.infinity : 0) : grossWin / grossLoss,
      trades: pnls.length,
    );
  }
}

class QuantRisk {
  const QuantRisk._();

  /// Kelly fraction: f* = (b*p - q) / b, where b is the win/loss payoff ratio.
  /// Returns 0 when the edge is negative. [fraction] applies fractional Kelly.
  static double kellyFraction({
    required double winRate,
    required double payoffRatio,
    double fraction = 1.0,
  }) {
    if (payoffRatio <= 0) return 0;
    final p = winRate.clamp(0.0, 1.0);
    final q = 1 - p;
    final f = (payoffRatio * p - q) / payoffRatio;
    if (f <= 0) return 0;
    return (f * fraction).clamp(0.0, 1.0);
  }

  /// Expected value per unit risked.
  static double expectedValue({required double winRate, required double averageWin, required double averageLoss}) {
    final p = winRate.clamp(0.0, 1.0);
    return p * averageWin - (1 - p) * averageLoss;
  }

  /// Maximum drawdown of an equity curve, as a positive percentage.
  static double maxDrawdownPct(List<double> equity) {
    if (equity.isEmpty) return 0;
    var peak = equity.first;
    var maxDd = 0.0;
    for (final e in equity) {
      if (e > peak) peak = e;
      if (peak != 0) {
        final dd = (peak - e) / peak * 100;
        if (dd > maxDd) maxDd = dd;
      }
    }
    return maxDd;
  }

  /// Annualised Sharpe ratio from a series of period returns.
  static double sharpe(List<double> returns, {double riskFreePerPeriod = 0}) {
    if (returns.length < 2) return 0;
    final excess = returns.map((r) => r - riskFreePerPeriod).toList(growable: false);
    final mean = excess.reduce((a, b) => a + b) / excess.length;
    var variance = 0.0;
    for (final r in excess) {
      variance += (r - mean) * (r - mean);
    }
    final sd = math.sqrt(variance / excess.length);
    if (sd == 0) return 0;
    return mean / sd * math.sqrt(252);
  }

  /// Position size in units for a fixed fractional risk budget.
  /// Returns 0 when the stop distance is zero, rather than dividing by zero.
  static double positionSize({
    required double equity,
    required double riskPerTradePct,
    required double entryPrice,
    required double stopPrice,
  }) {
    final riskPerUnit = (entryPrice - stopPrice).abs();
    if (riskPerUnit <= 0 || entryPrice <= 0) return 0;
    return equity * (riskPerTradePct / 100) / riskPerUnit;
  }
}

// ---------------------------------------------------------------------------
// Statistics
// ---------------------------------------------------------------------------

class CointegrationResult {
  final double hedgeRatio;
  final double intercept;
  final double adfStatistic;
  final bool isCointegrated;

  const CointegrationResult({
    required this.hedgeRatio,
    required this.intercept,
    required this.adfStatistic,
    required this.isCointegrated,
  });

  String get interpretation => isCointegrated
      ? 'Residuals look stationary (ADF ${adfStatistic.toStringAsFixed(2)}); the pair is a candidate for mean-reversion trading.'
      : 'Residuals look non-stationary (ADF ${adfStatistic.toStringAsFixed(2)}); the pair is not cointegrated on this sample.';
}

class QuantStatistics {
  const QuantStatistics._();

  /// Engle-Granger two-step cointegration test: regress y on x by least squares,
  /// then run an ADF test on the residual.
  ///
  /// The critical value used is the commonly cited -2.86 for the residual-based
  /// test at the 5% level on a large sample; it is stated so the reader can see
  /// the threshold rather than trusting a hidden constant.
  static CointegrationResult? engleGranger(List<double> y, List<double> x, {double criticalValue = -2.86}) {
    if (y.length != x.length || y.length < 30) return null;
    final n = y.length;
    final mx = x.reduce((a, b) => a + b) / n;
    final my = y.reduce((a, b) => a + b) / n;
    var sxy = 0.0, sxx = 0.0;
    for (var i = 0; i < n; i++) {
      sxy += (x[i] - mx) * (y[i] - my);
      sxx += (x[i] - mx) * (x[i] - mx);
    }
    if (sxx == 0) return null;
    final beta = sxy / sxx;
    final alpha = my - beta * mx;

    final residuals = [for (var i = 0; i < n; i++) y[i] - (alpha + beta * x[i])];
    final stat = _adf(residuals);
    return CointegrationResult(
      hedgeRatio: beta,
      intercept: alpha,
      adfStatistic: stat,
      isCointegrated: stat < criticalValue,
    );
  }

  static double _adf(List<double> series) {
    if (series.length < 10) return 0;
    final dy = <double>[];
    final lag = <double>[];
    for (var i = 1; i < series.length; i++) {
      dy.add(series[i] - series[i - 1]);
      lag.add(series[i - 1]);
    }
    final n = lag.length;
    final mx = lag.reduce((a, b) => a + b) / n;
    final my = dy.reduce((a, b) => a + b) / n;
    var sxy = 0.0, sxx = 0.0;
    for (var i = 0; i < n; i++) {
      sxy += (lag[i] - mx) * (dy[i] - my);
      sxx += (lag[i] - mx) * (lag[i] - mx);
    }
    if (sxx == 0) return 0;
    final beta = sxy / sxx;
    var ssr = 0.0;
    for (var i = 0; i < n; i++) {
      final pred = my + beta * (lag[i] - mx);
      ssr += (dy[i] - pred) * (dy[i] - pred);
    }
    final sd = math.sqrt(ssr / n);
    if (sd == 0) return 0;
    return beta / (sd / math.sqrt(n.toDouble()));
  }

  /// A scalar Kalman filter, used to track a time-varying mean or hedge ratio
  /// through noise. [processNoise] and [measurementNoise] control how fast the
  /// estimate adapts.
  static List<double> kalman(List<double> observations, {double processNoise = 1e-4, double measurementNoise = 1e-2}) {
    final out = <double>[];
    if (observations.isEmpty) return out;
    var estimate = observations.first;
    var errorCovariance = 1.0;
    for (final z in observations) {
      // Predict
      errorCovariance += processNoise;
      // Update
      final gain = errorCovariance / (errorCovariance + measurementNoise);
      estimate = estimate + gain * (z - estimate);
      errorCovariance = (1 - gain) * errorCovariance;
      out.add(estimate);
    }
    return out;
  }

  /// Rolling z-score of the spread, the standard mean-reversion entry trigger.
  static List<double?> zScore(List<double> series, {int window = 20}) {
    final out = List<double?>.filled(series.length, null);
    for (var i = window - 1; i < series.length; i++) {
      final w = series.sublist(i - window + 1, i + 1);
      final mean = w.reduce((a, b) => a + b) / w.length;
      var v = 0.0;
      for (final x in w) {
        v += (x - mean) * (x - mean);
      }
      final sd = math.sqrt(v / w.length);
      out[i] = sd == 0 ? 0 : (series[i] - mean) / sd;
    }
    return out;
  }
}
