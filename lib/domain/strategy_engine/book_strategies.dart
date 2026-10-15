/// Concrete strategies derived from the literature, expressed as executable
/// rules rather than book names.
///
/// Each class states its provenance (book and rule), exposes bounded
/// parameters, and implements a pure `generateSignals`. The formulas come from
/// [QuantMechanics]; nothing is hardcoded into a UI layer.
///
/// Two honest notes that recur below:
///  * Relative-strength *percentiles* are cross-sectional. When a strategy is
///    run on a single symbol there is no universe to rank against, so the
///    single-symbol path uses absolute momentum and says so in its provenance.
///    The cross-sectional percentile is applied by the framework screener.
///  * Fundamental criteria (EPS growth, ROIC, institutional ownership) cannot be
///    evaluated without a fundamentals feed. Strategies that need them declare
///    which criteria they could not check rather than assuming they passed.
library;

import '../../data/models/candle.dart';
import '../indicators/indicators.dart';
import '../quant/quant_mechanics.dart';
import 'strategy_engine.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

double _highest(List<Candle> c, int from, int to) {
  var h = double.negativeInfinity;
  for (var i = from; i < to; i++) {
    if (c[i].high > h) h = c[i].high;
  }
  return h;
}

double _lowest(List<Candle> c, int from, int to) {
  var l = double.infinity;
  for (var i = from; i < to; i++) {
    if (c[i].low < l) l = c[i].low;
  }
  return l;
}

double _avgVolume(List<Candle> c, int from, int to) {
  if (to <= from) return 0;
  var s = 0.0;
  for (var i = from; i < to; i++) {
    s += c[i].volume;
  }
  return s / (to - from);
}

/// Registers every book-derived strategy in the factory. Call once at startup.
void registerBookStrategies() {
  StrategyFactory.registerAll([
    MinerviniTrendTemplateStrategy(),
    WeinsteinStage2Strategy(),
    TurtleBreakoutStrategy(),
    WilderRsiStrategy(),
    CanSlimTechnicalStrategy(),
    Momentum121Strategy(),
    VolumeProfileBreakoutStrategy(),
    WyckoffSpringStrategy(),
    VcpBreakoutStrategy(),
    TrendlineBreakoutStrategy(),
    DoubleBottomReversalStrategy(),
    GapAndGoStrategy(),
  ]);
}

// ---------------------------------------------------------------------------
// 1. Minervini — Trend Template
// ---------------------------------------------------------------------------

class MinerviniTrendTemplateStrategy extends BaseStrategy {
  static const _params = [
    StrategyParameter(key: 'minMomentumPct', label: 'Minimum 12-month return', value: 0, min: -50, max: 100, description: 'Stand-in for the relative-strength rating when only one symbol is available.'),
    StrategyParameter(key: 'atrStopMultiple', label: 'ATR stop multiple', value: 2, min: 0.5, max: 5, description: 'Initial stop distance in ATR units.'),
  ];

  MinerviniTrendTemplateStrategy({this.values = const {}});
  final Map<String, double> values;

  @override
  String get id => 'book.minervini.trend_template';
  @override
  String get name => 'Trend Template (Minervini)';
  @override
  String get description => 'Eight-point Stage-2 template: moving-average stack, rising 200-day, 30% off the low, within 25% of the high, momentum floor.';
  @override
  StrategyProvenance get provenance => const StrategyProvenance(
        frameworkId: 'minervini-trend-template',
        frameworkName: 'Trend Template (SEPA / VCP)',
        source: 'Mark Minervini, "Trade Like a Stock Market Wizard" (2013)',
        rule: 'The eight-point Trend Template, applied as an entry filter',
        notes: {
          'relative strength': 'Uses absolute 12-month momentum on a single symbol; the cross-sectional percentile is applied by the screener.',
          'not checked': 'Institutional sponsorship is not in the template.',
        },
      );
  @override
  List<StrategyParameter> get parameters => _params;
  @override
  BaseStrategy configure(Map<String, double> v) => MinerviniTrendTemplateStrategy(values: {...values, ...v});

  double _p(String k) {
    if (values.containsKey(k)) {
      for (final p in _params) {
        if (p.key == k) return values[k]!.clamp(p.min, p.max);
      }
    }
    for (final p in _params) {
      if (p.key == k) return p.value;
    }
    throw ArgumentError(k);
  }

  @override
  List<Signal> generateSignals(String symbol, List<Candle> candles) {
    final out = <Signal>[];
    if (candles.length < 260) return out;
    final closes = candles.map((c) => c.close).toList(growable: false);
    final s50 = Indicators.sma(closes, 50);
    final s150 = Indicators.sma(closes, 150);
    final s200 = Indicators.sma(closes, 200);
    final a = Indicators.atr(candles, 14);

    for (var i = 260; i < candles.length; i++) {
      final p = closes[i];
      final m50 = s50[i], m150 = s150[i], m200 = s200[i], m200Prev = s200[i - 30], av = a[i];
      if (m50 == null || m150 == null || m200 == null || m200Prev == null || av == null) continue;
      if (!(p > m150 && p > m200)) continue;
      if (!(m150 > m200)) continue;
      if (!(m200 > m200Prev)) continue;
      if (!(m50 > m150 && m50 > m200)) continue;
      if (!(p > m50)) continue;

      final low252 = _lowest(candles, i - 251, i + 1);
      final high252 = _highest(candles, i - 251, i + 1);
      if (low252 <= 0 || high252 <= 0) continue;
      if (!(p >= low252 * 1.30)) continue;
      if (!(p >= high252 * 0.75)) continue;

      final momentum = closes[i - 252] == 0 ? 0.0 : (p / closes[i - 252] - 1) * 100;
      if (momentum < _p('minMomentumPct')) continue;

      out.add(Signal(
        symbol: symbol,
        time: candles[i].time,
        index: i,
        side: SignalSide.long,
        price: p,
        stop: p - _p('atrStopMultiple') * av,
        rationale: 'Stage-2 stack confirmed (50>150>200, 200 rising), ${((p / low252 - 1) * 100).toStringAsFixed(0)}% above the low, '
            '${((1 - p / high252) * 100).toStringAsFixed(0)}% below the high, 12-month momentum ${momentum.toStringAsFixed(1)}%',
        provenance: provenance,
        parameters: {'atrStopMultiple': _p('atrStopMultiple')},
      ));
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// 2. Weinstein — Stage 2 breakout
// ---------------------------------------------------------------------------

class WeinsteinStage2Strategy extends BaseStrategy {
  static const _params = [
    StrategyParameter(key: 'volumeMultiple', label: 'Breakout volume multiple', value: 1.5, min: 1.0, max: 5, description: 'Breakout volume versus the 20-bar average.'),
    StrategyParameter(key: 'slopeLookback', label: 'Average slope lookback', value: 20, min: 5, max: 60, description: 'Bars used to test that the 30-week average is rising.'),
  ];

  WeinsteinStage2Strategy({this.values = const {}});
  final Map<String, double> values;

  @override
  String get id => 'book.weinstein.stage2';
  @override
  String get name => 'Stage 2 Breakout (Weinstein)';
  @override
  String get description => 'Buy only in Stage 2: price above a rising 30-week average, breaking out on above-average volume.';
  @override
  StrategyProvenance get provenance => const StrategyProvenance(
        frameworkId: 'weinstein-stage',
        frameworkName: 'Stage Analysis',
        source: 'Stan Weinstein, "Secrets for Profiting in Bull and Bear Markets" (1988)',
        rule: 'Trade only Stage 2 — price above a rising 30-week moving average, on breakout volume',
      );
  @override
  List<StrategyParameter> get parameters => _params;
  @override
  BaseStrategy configure(Map<String, double> v) => WeinsteinStage2Strategy(values: {...values, ...v});

  double _p(String k) => values[k] ?? _params.firstWhere((p) => p.key == k).value;

  @override
  List<Signal> generateSignals(String symbol, List<Candle> candles) {
    final out = <Signal>[];
    if (candles.length < 180) return out;
    final closes = candles.map((c) => c.close).toList(growable: false);
    final s150 = Indicators.sma(closes, 150);
    final a = Indicators.atr(candles, 14);
    final lookback = _p('slopeLookback').toInt();

    for (var i = 180; i < candles.length; i++) {
      final m150 = s150[i], prev = s150[i - lookback], av = a[i];
      if (m150 == null || prev == null || av == null) continue;
      if (!(closes[i] > m150 && m150 > prev)) continue;
      final vol = _avgVolume(candles, i - 20, i);
      if (!(vol > 0 && candles[i].volume > _p('volumeMultiple') * vol)) continue;
      final priorHigh = _highest(candles, i - 40, i);
      if (!(closes[i] > priorHigh)) continue;

      out.add(Signal(
        symbol: symbol,
        time: candles[i].time,
        index: i,
        side: SignalSide.long,
        price: closes[i],
        stop: closes[i] - 2 * av,
        rationale: 'Stage 2: price above a rising 30-week average, breaking the 40-bar high on '
            '${(candles[i].volume / vol).toStringAsFixed(1)}x average volume',
        provenance: provenance,
      ));
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// 3. Turtle — N-day breakout
// ---------------------------------------------------------------------------

class TurtleBreakoutStrategy extends BaseStrategy {
  static const _params = [
    StrategyParameter(key: 'entryPeriod', label: 'Breakout period', value: 20, min: 5, max: 120, description: 'Highest-high lookback for the entry.'),
    StrategyParameter(key: 'exitPeriod', label: 'Exit period', value: 10, min: 3, max: 60, description: 'Lowest-low lookback for the exit.'),
    StrategyParameter(key: 'atrStopMultiple', label: 'ATR stop multiple', value: 2, min: 0.5, max: 6, description: 'Initial stop in ATR units.'),
  ];

  TurtleBreakoutStrategy({this.values = const {}});
  final Map<String, double> values;

  @override
  String get id => 'book.turtle.breakout';
  @override
  String get name => 'Turtle Breakout';
  @override
  String get description => 'Enter on an N-day high breakout with a volatility-scaled stop, exit on the shorter M-day low.';
  @override
  StrategyProvenance get provenance => const StrategyProvenance(
        frameworkId: 'turtle-trend',
        frameworkName: 'Turtle Trend Following',
        source: 'Curtis Faith, "Way of the Turtle" (2007)',
        rule: 'N-day breakout entry with an ATR-scaled stop and an M-day exit',
      );
  @override
  List<StrategyParameter> get parameters => _params;
  @override
  BaseStrategy configure(Map<String, double> v) => TurtleBreakoutStrategy(values: {...values, ...v});

  double _p(String k) => values[k] ?? _params.firstWhere((p) => p.key == k).value;

  @override
  List<Signal> generateSignals(String symbol, List<Candle> candles) {
    final out = <Signal>[];
    final entry = _p('entryPeriod').toInt();
    final exitP = _p('exitPeriod').toInt();
    if (candles.length < entry + 5) return out;
    final a = Indicators.atr(candles, 14);
    var inPosition = false;

    for (var i = entry; i < candles.length; i++) {
      final av = a[i];
      if (av == null) continue;
      final priorHigh = _highest(candles, i - entry, i);
      final priorLow = _lowest(candles, i - exitP, i);

      if (!inPosition && candles[i].close > priorHigh) {
        inPosition = true;
        out.add(Signal(
          symbol: symbol,
          time: candles[i].time,
          index: i,
          side: SignalSide.long,
          price: candles[i].close,
          stop: candles[i].close - _p('atrStopMultiple') * av,
          rationale: 'Breakout above the $entry-day high of ${priorHigh.toStringAsFixed(2)}',
          provenance: provenance,
        ));
      } else if (inPosition && candles[i].close < priorLow) {
        inPosition = false;
        out.add(Signal(
          symbol: symbol,
          time: candles[i].time,
          index: i,
          side: SignalSide.exit,
          price: candles[i].close,
          rationale: 'Close below the $exitP-day low of ${priorLow.toStringAsFixed(2)}',
          provenance: provenance,
        ));
      }
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// 4. Wilder — RSI mean reversion
// ---------------------------------------------------------------------------

class WilderRsiStrategy extends BaseStrategy {
  static const _params = [
    StrategyParameter(key: 'oversold', label: 'Oversold level', value: 30, min: 5, max: 45, description: 'RSI entry threshold.'),
    StrategyParameter(key: 'overbought', label: 'Overbought level', value: 70, min: 55, max: 95, description: 'RSI exit threshold.'),
  ];

  WilderRsiStrategy({this.values = const {}});
  final Map<String, double> values;

  @override
  String get id => 'book.wilder.rsi';
  @override
  String get name => 'RSI Mean Reversion (Wilder)';
  @override
  String get description => 'Buy oversold RSI, exit overbought, with an ATR stop.';
  @override
  StrategyProvenance get provenance => const StrategyProvenance(
        frameworkId: 'wilder-rsi-atr',
        frameworkName: 'RSI & Volatility Units',
        source: 'J. Welles Wilder Jr., "New Concepts in Technical Trading Systems" (1978)',
        rule: 'Relative Strength Index thresholds with ATR-scaled risk',
      );
  @override
  List<StrategyParameter> get parameters => _params;
  @override
  BaseStrategy configure(Map<String, double> v) => WilderRsiStrategy(values: {...values, ...v});

  double _p(String k) => values[k] ?? _params.firstWhere((p) => p.key == k).value;

  @override
  List<Signal> generateSignals(String symbol, List<Candle> candles) {
    final out = <Signal>[];
    if (candles.length < 30) return out;
    final closes = candles.map((c) => c.close).toList(growable: false);
    final rsi = Indicators.rsi(closes, 14);
    final a = Indicators.atr(candles, 14);
    var inPosition = false;

    for (var i = 15; i < candles.length; i++) {
      final r = rsi[i], av = a[i];
      if (r == null || av == null) continue;
      if (!inPosition && r < _p('oversold')) {
        inPosition = true;
        out.add(Signal(
          symbol: symbol,
          time: candles[i].time,
          index: i,
          side: SignalSide.long,
          price: closes[i],
          stop: closes[i] - 2 * av,
          rationale: 'RSI(14) ${r.toStringAsFixed(1)} below ${_p('oversold').toStringAsFixed(0)}',
          provenance: provenance,
        ));
      } else if (inPosition && r > _p('overbought')) {
        inPosition = false;
        out.add(Signal(
          symbol: symbol,
          time: candles[i].time,
          index: i,
          side: SignalSide.exit,
          price: closes[i],
          rationale: 'RSI(14) ${r.toStringAsFixed(1)} above ${_p('overbought').toStringAsFixed(0)}',
          provenance: provenance,
        ));
      }
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// 5. O'Neil — CAN SLIM, technical subset
// ---------------------------------------------------------------------------

class CanSlimTechnicalStrategy extends BaseStrategy {
  static const _params = [
    StrategyParameter(key: 'highProximityPct', label: 'Max distance below the 52-week high', value: 15, min: 1, max: 40, description: 'The N factor: new highs.'),
    StrategyParameter(key: 'volumeMultiple', label: 'Breakout volume multiple', value: 1.5, min: 1.0, max: 5, description: 'The S factor: demand.'),
  ];

  CanSlimTechnicalStrategy({this.values = const {}});
  final Map<String, double> values;

  @override
  String get id => 'book.oneil.canslim_technical';
  @override
  String get name => 'CAN SLIM — Technical Subset (O\u2019Neil)';
  @override
  String get description => 'The N, S and L factors that price data can support: near the 52-week high, volume expansion, positive momentum.';
  @override
  StrategyProvenance get provenance => const StrategyProvenance(
        frameworkId: 'canslim',
        frameworkName: 'CAN SLIM',
        source: 'William J. O\u2019Neil, "How to Make Money in Stocks" (1988)',
        rule: 'Factors N (new highs), S (supply and demand) and L (leadership)',
        notes: {
          'cannot check': 'C and A (quarterly and annual earnings growth) and I (institutional sponsorship) need a fundamentals feed, which this build does not have. They are not assumed to pass.',
          'risk rule': 'Losses are cut at 7-8% below the entry, as the framework requires.',
        },
      );
  @override
  List<StrategyParameter> get parameters => _params;
  @override
  BaseStrategy configure(Map<String, double> v) => CanSlimTechnicalStrategy(values: {...values, ...v});

  double _p(String k) => values[k] ?? _params.firstWhere((p) => p.key == k).value;

  @override
  List<Signal> generateSignals(String symbol, List<Candle> candles) {
    final out = <Signal>[];
    if (candles.length < 260) return out;
    for (var i = 252; i < candles.length; i++) {
      final high252 = _highest(candles, i - 251, i + 1);
      final low252 = _lowest(candles, i - 251, i + 1);
      if (high252 <= 0) continue;
      final belowHighPct = (1 - candles[i].close / high252) * 100;
      if (belowHighPct > _p('highProximityPct')) continue;
      if (candles[i].close <= low252 * 1.3) continue;
      final vol = _avgVolume(candles, i - 20, i);
      if (!(vol > 0 && candles[i].volume > _p('volumeMultiple') * vol)) continue;
      final momentum = candles[i - 252].close == 0 ? 0.0 : (candles[i].close / candles[i - 252].close - 1) * 100;
      if (momentum <= 0) continue;

      out.add(Signal(
        symbol: symbol,
        time: candles[i].time,
        index: i,
        side: SignalSide.long,
        price: candles[i].close,
        stop: candles[i].close * 0.925, // the 7.5% loss limit
        rationale: 'Within ${belowHighPct.toStringAsFixed(1)}% of the 52-week high on '
            '${(candles[i].volume / vol).toStringAsFixed(1)}x volume, 12-month momentum ${momentum.toStringAsFixed(1)}%',
        provenance: provenance,
      ));
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// 6. Momentum 12-1
// ---------------------------------------------------------------------------

class Momentum121Strategy extends BaseStrategy {
  static const _params = [
    StrategyParameter(key: 'minMomentumPct', label: 'Minimum 12-1 momentum', value: 5, min: -20, max: 100, description: 'The momentum floor.'),
    StrategyParameter(key: 'skipBars', label: 'Skip the most recent bars', value: 21, min: 0, max: 60, description: 'The 1 in 12-1: excludes the most recent month.'),
  ];

  Momentum121Strategy({this.values = const {}});
  final Map<String, double> values;

  @override
  String get id => 'book.momentum.12_1';
  @override
  String get name => 'Cross-Sectional Momentum (12-1)';
  @override
  String get description => 'Enter when trailing momentum, excluding the most recent month, clears a floor, in an uptrend.';
  @override
  StrategyProvenance get provenance => const StrategyProvenance(
        frameworkId: 'momentum-factor',
        frameworkName: 'Cross-Sectional Momentum',
        source: 'Jegadeesh & Titman, "Returns to Buying Winners and Selling Losers" (1993)',
        rule: 'Formation return over 12 months, skipping the most recent month',
        notes: {
          'cross-section': 'The top-decile rank is applied by the screener; the single-symbol path uses the absolute floor.',
        },
      );
  @override
  List<StrategyParameter> get parameters => _params;
  @override
  BaseStrategy configure(Map<String, double> v) => Momentum121Strategy(values: {...values, ...v});

  double _p(String k) => values[k] ?? _params.firstWhere((p) => p.key == k).value;

  @override
  List<Signal> generateSignals(String symbol, List<Candle> candles) {
    final out = <Signal>[];
    if (candles.length < 280) return out;
    final closes = candles.map((c) => c.close).toList(growable: false);
    final s200 = Indicators.sma(closes, 200);
    final skip = _p('skipBars').toInt();
    var inPosition = false;

    for (var i = 260; i < candles.length; i++) {
      final start = i - 252;
      final end = i - skip;
      if (start < 0 || end <= start || closes[start] == 0) continue;
      final momentum = (closes[end] / closes[start] - 1) * 100;
      final m200 = s200[i];
      if (m200 == null) continue;

      if (!inPosition && momentum >= _p('minMomentumPct') && closes[i] > m200) {
        inPosition = true;
        out.add(Signal(
          symbol: symbol,
          time: candles[i].time,
          index: i,
          side: SignalSide.long,
          price: closes[i],
          rationale: '12-1 momentum ${momentum.toStringAsFixed(1)}% with price above the 200-day average',
          provenance: provenance,
        ));
      } else if (inPosition && closes[i] < m200) {
        inPosition = false;
        out.add(Signal(
          symbol: symbol,
          time: candles[i].time,
          index: i,
          side: SignalSide.exit,
          price: closes[i],
          rationale: 'Price closed below the 200-day average',
          provenance: provenance,
        ));
      }
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// 7. Volume-profile breakout
// ---------------------------------------------------------------------------

class VolumeProfileBreakoutStrategy extends BaseStrategy {
  static const _params = [
    StrategyParameter(key: 'profileWindow', label: 'Profile window (bars)', value: 120, min: 40, max: 400, description: 'Bars used to build the volume profile.'),
    StrategyParameter(key: 'volumeMultiple', label: 'Volume multiple', value: 1.5, min: 1.0, max: 5, description: 'Breakout volume versus the 20-bar average.'),
  ];

  VolumeProfileBreakoutStrategy({this.values = const {}});
  final Map<String, double> values;

  @override
  String get id => 'book.profile.vah_breakout';
  @override
  String get name => 'Value-Area Breakout';
  @override
  String get description => 'Break above the value-area high of the trailing volume profile on expanding volume.';
  @override
  StrategyProvenance get provenance => const StrategyProvenance(
        frameworkId: 'weinstein-stage',
        frameworkName: 'Volume & Market Profile',
        source: 'Steidlmayer & Dalton, Market Profile and volume-distribution methods',
        rule: 'Acceptance above the value-area high (VAH) on expanding volume',
      );
  @override
  List<StrategyParameter> get parameters => _params;
  @override
  BaseStrategy configure(Map<String, double> v) => VolumeProfileBreakoutStrategy(values: {...values, ...v});

  double _p(String k) => values[k] ?? _params.firstWhere((p) => p.key == k).value;

  @override
  List<Signal> generateSignals(String symbol, List<Candle> candles) {
    final out = <Signal>[];
    final window = _p('profileWindow').toInt();
    if (candles.length < window + 25) return out;
    final a = Indicators.atr(candles, 14);

    // Rebuild the trailing profile periodically; the levels are otherwise held.
    double vah = 0;
    var lastBuilt = -1;
    var inPosition = false;

    for (var i = window; i < candles.length; i++) {
      if (i - lastBuilt >= 10 || vah == 0) {
        final profile = QuantMechanics.volumeProfile(candles.sublist(i - window, i), bins: 40);
        vah = profile.vah;
        lastBuilt = i;
      }
      final av = a[i];
      if (av == null || vah <= 0) continue;
      final vol = _avgVolume(candles, i - 20, i);
      final expanding = vol > 0 && candles[i].volume > _p('volumeMultiple') * vol;

      if (!inPosition && candles[i].close > vah && expanding) {
        inPosition = true;
        out.add(Signal(
          symbol: symbol,
          time: candles[i].time,
          index: i,
          side: SignalSide.long,
          price: candles[i].close,
          stop: candles[i].close - 2 * av,
          rationale: 'Accepted above the value-area high ${vah.toStringAsFixed(2)} on '
              '${(candles[i].volume / vol).toStringAsFixed(1)}x volume',
          provenance: provenance,
        ));
      } else if (inPosition && candles[i].close < vah) {
        inPosition = false;
        out.add(Signal(
          symbol: symbol,
          time: candles[i].time,
          index: i,
          side: SignalSide.exit,
          price: candles[i].close,
          rationale: 'Lost the value-area high ${vah.toStringAsFixed(2)}',
          provenance: provenance,
        ));
      }
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// 8. Wyckoff spring
// ---------------------------------------------------------------------------

class WyckoffSpringStrategy extends BaseStrategy {
  static const _params = [
    StrategyParameter(key: 'rangeLookback', label: 'Support lookback (bars)', value: 40, min: 10, max: 120, description: 'Bars defining the trading range low.'),
    StrategyParameter(key: 'maxVolumeRatio', label: 'Max volume ratio on the spring', value: 1.0, min: 0.2, max: 2.0, description: 'A spring should occur on drying volume.'),
  ];

  WyckoffSpringStrategy({this.values = const {}});
  final Map<String, double> values;

  @override
  String get id => 'book.wyckoff.spring';
  @override
  String get name => 'Wyckoff Spring';
  @override
  String get description => 'A false breakdown below range support that recovers by the close, on drying volume.';
  @override
  StrategyProvenance get provenance => const StrategyProvenance(
        frameworkId: 'weinstein-stage',
        frameworkName: 'Wyckoff Accumulation',
        source: 'Richard Wyckoff, the accumulation schematic',
        rule: 'Spring: an undercut of support that recovers, marking the end of accumulation',
      );
  @override
  List<StrategyParameter> get parameters => _params;
  @override
  BaseStrategy configure(Map<String, double> v) => WyckoffSpringStrategy(values: {...values, ...v});

  double _p(String k) => values[k] ?? _params.firstWhere((p) => p.key == k).value;

  @override
  List<Signal> generateSignals(String symbol, List<Candle> candles) {
    final out = <Signal>[];
    final lookback = _p('rangeLookback').toInt();
    if (candles.length < lookback + 25) return out;
    final a = Indicators.atr(candles, 14);

    for (var i = lookback; i < candles.length; i++) {
      final support = _lowest(candles, i - lookback, i);
      final bar = candles[i];
      final av = a[i];
      if (av == null) continue;
      // Undercut the support, then close back above it.
      if (!(bar.low < support && bar.close > support)) continue;
      final vol = _avgVolume(candles, i - 20, i);
      if (!(vol > 0 && bar.volume <= _p('maxVolumeRatio') * vol)) continue;

      out.add(Signal(
        symbol: symbol,
        time: bar.time,
        index: i,
        side: SignalSide.long,
        price: bar.close,
        stop: bar.low - 0.5 * av,
        rationale: 'Spring: undercut support ${support.toStringAsFixed(2)} to ${bar.low.toStringAsFixed(2)} and recovered, '
            'on ${(bar.volume / vol).toStringAsFixed(2)}x volume',
        provenance: provenance,
      ));
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// 9. VCP breakout
// ---------------------------------------------------------------------------

class VcpBreakoutStrategy extends BaseStrategy {
  static const _params = [
    StrategyParameter(key: 'baseLookback', label: 'Base lookback (bars)', value: 60, min: 20, max: 200, description: 'Bars scanned for contractions.'),
    StrategyParameter(key: 'volumeMultiple', label: 'Breakout volume multiple', value: 1.5, min: 1.0, max: 5, description: 'Volume on the pivot breakout.'),
  ];

  VcpBreakoutStrategy({this.values = const {}});
  final Map<String, double> values;

  @override
  String get id => 'book.minervini.vcp';
  @override
  String get name => 'VCP Breakout (Minervini)';
  @override
  String get description => 'Successive shallower pullbacks on drying volume, then a pivot breakout on expanding volume.';
  @override
  StrategyProvenance get provenance => const StrategyProvenance(
        frameworkId: 'minervini-trend-template',
        frameworkName: 'Trend Template (SEPA / VCP)',
        source: 'Mark Minervini, "Trade Like a Stock Market Wizard" (2013)',
        rule: 'Volatility Contraction Pattern: shrinking pullbacks, volume dry-up, pivot breakout',
      );
  @override
  List<StrategyParameter> get parameters => _params;
  @override
  BaseStrategy configure(Map<String, double> v) => VcpBreakoutStrategy(values: {...values, ...v});

  double _p(String k) => values[k] ?? _params.firstWhere((p) => p.key == k).value;

  @override
  List<Signal> generateSignals(String symbol, List<Candle> candles) {
    final out = <Signal>[];
    final base = _p('baseLookback').toInt();
    if (candles.length < base + 30) return out;
    final closes = candles.map((c) => c.close).toList(growable: false);
    final s150 = Indicators.sma(closes, 150);
    final a = Indicators.atr(candles, 14);

    for (var i = base; i < candles.length; i++) {
      final m150 = s150[i];
      final av = a[i];
      if (m150 == null || av == null) continue;
      if (closes[i] <= m150) continue; // must be in an uptrend

      // Contraction test: the recent half's average bar range is materially
      // smaller than the earlier half's, and volume is drying up.
      final half = base ~/ 2;
      final early = candles.sublist(i - base, i - half);
      final late = candles.sublist(i - half, i);
      final earlyRange = early.map((c) => c.high - c.low).reduce((x, y) => x + y) / early.length;
      final lateRange = late.map((c) => c.high - c.low).reduce((x, y) => x + y) / late.length;
      final earlyVol = early.map((c) => c.volume).reduce((x, y) => x + y) / early.length;
      final lateVol = late.map((c) => c.volume).reduce((x, y) => x + y) / late.length;
      if (!(lateRange < earlyRange * 0.75)) continue;
      if (!(lateVol < earlyVol)) continue;

      final pivot = _highest(candles, i - half, i);
      final vol = _avgVolume(candles, i - 20, i);
      if (!(closes[i] > pivot && vol > 0 && candles[i].volume > _p('volumeMultiple') * vol)) continue;

      out.add(Signal(
        symbol: symbol,
        time: candles[i].time,
        index: i,
        side: SignalSide.long,
        price: closes[i],
        stop: closes[i] - 2 * av,
        rationale: 'VCP: bar range tightened to ${(lateRange / earlyRange * 100).toStringAsFixed(0)}% of the base, volume dried, '
            'pivot ${pivot.toStringAsFixed(2)} broken on ${(candles[i].volume / vol).toStringAsFixed(1)}x volume',
        provenance: provenance,
      ));
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// 10. Trendline breakout
// ---------------------------------------------------------------------------

class TrendlineBreakoutStrategy extends BaseStrategy {
  static const _params = [
    StrategyParameter(key: 'lookback', label: 'Pivot lookback (bars)', value: 80, min: 30, max: 250, description: 'Bars used to fit the line.'),
    StrategyParameter(key: 'minR2', label: 'Minimum R-squared', value: 0.8, min: 0.3, max: 0.99, description: 'Fit quality required to trust the line.'),
  ];

  TrendlineBreakoutStrategy({this.values = const {}});
  final Map<String, double> values;

  @override
  String get id => 'book.trendline.breakout';
  @override
  String get name => 'Regression Trendline Breakout';
  @override
  String get description => 'A validated least-squares resistance line (R-squared and touch count) broken with volume.';
  @override
  StrategyProvenance get provenance => const StrategyProvenance(
        frameworkId: 'weinstein-stage',
        frameworkName: 'Classical Technical Analysis',
        source: 'Edwards & Magee, "Technical Analysis of Stock Trends"',
        rule: 'A trendline needs three touches and a good fit before a break is tradeable',
      );
  @override
  List<StrategyParameter> get parameters => _params;
  @override
  BaseStrategy configure(Map<String, double> v) => TrendlineBreakoutStrategy(values: {...values, ...v});

  double _p(String k) => values[k] ?? _params.firstWhere((p) => p.key == k).value;

  @override
  List<Signal> generateSignals(String symbol, List<Candle> candles) {
    final out = <Signal>[];
    final lookback = _p('lookback').toInt();
    if (candles.length < lookback + 20) return out;
    final a = Indicators.atr(candles, 14);

    for (var i = lookback; i < candles.length; i++) {
      final window = candles.sublist(i - lookback, i);
      final pv = QuantMechanics.pivots(window, n: 3).where((p) => p.isHigh).toList(growable: false);
      if (pv.length < 3) continue;
      final line = QuantMechanics.fitTrendline(window, pv);
      if (!line.isValid) continue;
      if (line.r2 < _p('minR2')) continue;

      final level = line.valueAt(lookback - 1);
      final av = a[i];
      if (av == null || level <= 0) continue;
      if (candles[i].close <= level) continue;
      if (!QuantMechanics.breakoutConfirmed(candles.sublist(0, i + 1), level, volumeMultiple: 1.5)) continue;

      out.add(Signal(
        symbol: symbol,
        time: candles[i].time,
        index: i,
        side: SignalSide.long,
        price: candles[i].close,
        stop: candles[i].close - 2 * av,
        rationale: 'Broke a validated resistance line at ${level.toStringAsFixed(2)} '
            '(R-squared ${line.r2.toStringAsFixed(2)}, ${line.touches} touches) on expanding volume',
        provenance: provenance,
      ));
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// 11. Double-bottom reversal
// ---------------------------------------------------------------------------

class DoubleBottomReversalStrategy extends BaseStrategy {
  static const _params = [
    StrategyParameter(key: 'tolerancePct', label: 'Bottom tolerance (%)', value: 3, min: 0.5, max: 10, description: 'How close the two lows must be.'),
  ];

  DoubleBottomReversalStrategy({this.values = const {}});
  final Map<String, double> values;

  @override
  String get id => 'book.pattern.double_bottom';
  @override
  String get name => 'Double-Bottom Reversal';
  @override
  String get description => 'Two matching lows, then an entry on the break of the intervening peak.';
  @override
  StrategyProvenance get provenance => const StrategyProvenance(
        frameworkId: 'weinstein-stage',
        frameworkName: 'Classical Technical Analysis',
        source: 'Edwards & Magee, "Technical Analysis of Stock Trends"',
        rule: 'Double bottom confirmed by a break of the intervening reaction high',
      );
  @override
  List<StrategyParameter> get parameters => _params;
  @override
  BaseStrategy configure(Map<String, double> v) => DoubleBottomReversalStrategy(values: {...values, ...v});

  double _p(String k) => values[k] ?? _params.firstWhere((p) => p.key == k).value;

  @override
  List<Signal> generateSignals(String symbol, List<Candle> candles) {
    final out = <Signal>[];
    if (candles.length < 80) return out;
    final a = Indicators.atr(candles, 14);
    final patterns = QuantMechanics.doubleTopsAndBottoms(candles, n: 3, tolerancePct: _p('tolerancePct'));

    for (final p in patterns) {
      if (p.name != 'Double bottom') continue;
      final between = _highest(candles, p.startIndex, p.endIndex + 1);
      // Find the first bar after the pattern that closes above the neckline.
      for (var i = p.endIndex + 1; i < candles.length; i++) {
        final av = a[i];
        if (av == null) continue;
        if (candles[i].close > between) {
          out.add(Signal(
            symbol: symbol,
            time: candles[i].time,
            index: i,
            side: SignalSide.long,
            price: candles[i].close,
            stop: candles[i].close - 2 * av,
            rationale: 'Double bottom confirmed by a close above the neckline ${between.toStringAsFixed(2)}',
            provenance: provenance,
          ));
          break;
        }
      }
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// 12. Gap and go
// ---------------------------------------------------------------------------

class GapAndGoStrategy extends BaseStrategy {
  static const _params = [
    StrategyParameter(key: 'minGapRatio', label: 'Minimum gap ratio', value: 1.2, min: 0.5, max: 4, description: 'Gap size versus the average bar range.'),
    StrategyParameter(key: 'maxGapRatio', label: 'Maximum gap ratio', value: 2.5, min: 1.0, max: 6, description: 'Beyond this the gap is treated as exhaustion.'),
  ];

  GapAndGoStrategy({this.values = const {}});
  final Map<String, double> values;

  @override
  String get id => 'book.pattern.gap_and_go';
  @override
  String get name => 'Gap-and-Go';
  @override
  String get description => 'A runaway gap up that holds, entered as continuation rather than exhaustion.';
  @override
  StrategyProvenance get provenance => const StrategyProvenance(
        frameworkId: 'weinstein-stage',
        frameworkName: 'Gap Analysis',
        source: 'Classical gap taxonomy (common, breakaway, runaway, exhaustion)',
        rule: 'Runaway gaps continue; exhaustion gaps do not',
      );
  @override
  List<StrategyParameter> get parameters => _params;
  @override
  BaseStrategy configure(Map<String, double> v) => GapAndGoStrategy(values: {...values, ...v});

  double _p(String k) => values[k] ?? _params.firstWhere((p) => p.key == k).value;

  @override
  List<Signal> generateSignals(String symbol, List<Candle> candles) {
    final out = <Signal>[];
    if (candles.length < 40) return out;
    final a = Indicators.atr(candles, 14);

    for (var i = 25; i < candles.length; i++) {
      final gap = candles[i].low - candles[i - 1].high;
      if (gap <= 0) continue;
      final avgRange = _avgRange(candles, i - 20, i);
      if (avgRange <= 0) continue;
      final ratio = gap / avgRange;
      if (ratio < _p('minGapRatio') || ratio > _p('maxGapRatio')) continue;
      final av = a[i];
      if (av == null) continue;
      // The gap must hold: the bar closes above the prior high.
      if (candles[i].close <= candles[i - 1].high) continue;

      out.add(Signal(
        symbol: symbol,
        time: candles[i].time,
        index: i,
        side: SignalSide.long,
        price: candles[i].close,
        stop: candles[i - 1].high, // a failed gap closes the hole
        rationale: 'Runaway gap of ${gap.toStringAsFixed(2)} (${ratio.toStringAsFixed(1)}x the average range) that held',
        provenance: provenance,
      ));
    }
    return out;
  }

  double _avgRange(List<Candle> c, int from, int to) {
    if (to <= from) return 0;
    var s = 0.0;
    for (var i = from; i < to; i++) {
      s += c[i].high - c[i].low;
    }
    return s / (to - from);
  }
}
