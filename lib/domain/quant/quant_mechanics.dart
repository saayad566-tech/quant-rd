/// Quantitative price/volume mechanics.
///
/// Every function here is a deterministic, testable implementation of a
/// documented technical-analysis or market-microstructure calculation. Nothing
/// is a placeholder and nothing invents data.
///
/// Where the input data cannot support a true calculation, the function says so
/// rather than faking it. The clearest example is order-flow delta: real delta
/// needs bid/ask trade volumes, which OHLCV bars do not carry, so
/// [deltaProxy] computes the documented close-location proxy and labels it as
/// such.
library;

import 'dart:math' as math;

import '../../data/models/candle.dart';

// ---------------------------------------------------------------------------
// Pivots
// ---------------------------------------------------------------------------

class Pivot {
  final int index;
  final double price;
  final bool isHigh;
  final DateTime time;

  const Pivot({required this.index, required this.price, required this.isHigh, required this.time});
}

// ---------------------------------------------------------------------------
// Trendlines
// ---------------------------------------------------------------------------

class Trendline {
  final double slope;
  final double intercept;

  /// Coefficient of determination of the least-squares fit through the pivots.
  final double r2;
  final int pivotCount;

  /// Bars whose price sits within the touch tolerance of the line.
  final int touches;
  final int startIndex;
  final int endIndex;

  const Trendline({
    required this.slope,
    required this.intercept,
    required this.r2,
    required this.pivotCount,
    required this.touches,
    required this.startIndex,
    required this.endIndex,
  });

  double valueAt(int index) => slope * index + intercept;

  /// A line is tradeable when it is well fitted and has been respected at least
  /// three times — the classical validation rule.
  bool get isValid => pivotCount >= 2 && r2 >= 0.8 && touches >= 3;
}

// ---------------------------------------------------------------------------
// Support / resistance
// ---------------------------------------------------------------------------

class PriceLevel {
  final double price;

  /// Number of bars that reacted at this level.
  final int touches;
  final bool isSupport;
  final bool isResistance;

  const PriceLevel({
    required this.price,
    required this.touches,
    required this.isSupport,
    required this.isResistance,
  });

  double get strength => touches.toDouble();
}

// ---------------------------------------------------------------------------
// Volume profile
// ---------------------------------------------------------------------------

class ProfileBin {
  final double low;
  final double high;
  final double volume;
  const ProfileBin({required this.low, required this.high, required this.volume});
  double get mid => (low + high) / 2;
}

class VolumeProfile {
  final List<ProfileBin> bins;

  /// Point of control: the price bin that traded the most volume.
  final double poc;

  /// Value-area high and low, bounding the 70% volume band.
  final double vah;
  final double val;
  final double totalVolume;

  const VolumeProfile({
    required this.bins,
    required this.poc,
    required this.vah,
    required this.val,
    required this.totalVolume,
  });

  /// Low-volume nodes: bins trading well below the average bin volume. These
  /// are the prices where the market moves quickly.
  List<ProfileBin> get lowVolumeNodes {
    if (bins.isEmpty) return const [];
    final avg = totalVolume / bins.length;
    return bins.where((b) => b.volume < avg * 0.5).toList(growable: false);
  }

  /// High-volume nodes: bins trading well above the average.
  List<ProfileBin> get highVolumeNodes {
    if (bins.isEmpty) return const [];
    final avg = totalVolume / bins.length;
    return bins.where((b) => b.volume > avg * 1.5).toList(growable: false);
  }
}

// ---------------------------------------------------------------------------
// Channels
// ---------------------------------------------------------------------------

class ChannelBands {
  final List<double?> upper;
  final List<double?> middle;
  final List<double?> lower;
  final String kind;

  const ChannelBands({required this.upper, required this.middle, required this.lower, required this.kind});

  int get length => middle.length;
}

// ---------------------------------------------------------------------------
// Patterns
// ---------------------------------------------------------------------------

enum PatternKind { reversal, continuation, gap }

class DetectedPattern {
  final String name;
  final PatternKind kind;
  final int startIndex;
  final int endIndex;

  /// 0..1 structural confidence from how closely the pivots matched the shape.
  final double confidence;
  final String description;

  const DetectedPattern({
    required this.name,
    required this.kind,
    required this.startIndex,
    required this.endIndex,
    required this.confidence,
    required this.description,
  });
}

// ---------------------------------------------------------------------------
// Market regime
// ---------------------------------------------------------------------------

enum MarketRegime {
  bullLowVol('Bull trend / low volatility'),
  bullHighVol('Bull trend / high volatility'),
  bearHighVol('Bear trend / high volatility'),
  sidewaysCompression('Sideways / compression');

  const MarketRegime(this.label);
  final String label;

  /// A conservative allocation weight suggested for the regime. Used to
  /// reweight strategy exposure; it is not a recommendation to trade.
  double get weight => switch (this) {
        MarketRegime.bullLowVol => 1.0,
        MarketRegime.bullHighVol => 0.6,
        MarketRegime.bearHighVol => 0.25,
        MarketRegime.sidewaysCompression => 0.4,
      };
}

class RegimeReading {
  final MarketRegime regime;
  final double trendSlopePct;
  final double volatilityPct;
  final double volatilityMedianPct;

  const RegimeReading({
    required this.regime,
    required this.trendSlopePct,
    required this.volatilityPct,
    required this.volatilityMedianPct,
  });

  String get explanation =>
      'Trend ${trendSlopePct >= 0 ? '+' : ''}${trendSlopePct.toStringAsFixed(2)}% over 20 bars; '
      'volatility ${volatilityPct.toStringAsFixed(1)}% versus a ${volatilityMedianPct.toStringAsFixed(1)}% median.';
}

// ---------------------------------------------------------------------------
// Features
// ---------------------------------------------------------------------------

class TripleBarrierLabel {
  final int index;
  final int label; // +1 take-profit, -1 stop-loss, 0 time-out
  final int exitIndex;
  const TripleBarrierLabel({required this.index, required this.label, required this.exitIndex});

  String get name => switch (label) {
        1 => 'take-profit',
        -1 => 'stop-loss',
        _ => 'time-out',
      };
}

// ---------------------------------------------------------------------------
// The mechanics
// ---------------------------------------------------------------------------

class QuantMechanics {
  const QuantMechanics._();

  // --- Pivots ---------------------------------------------------------------

  /// Swing highs and lows using an N-bar fractal window: a bar is a swing high
  /// when its high is the maximum of the [n] bars either side of it.
  static List<Pivot> pivots(List<Candle> candles, {int n = 2}) {
    final out = <Pivot>[];
    for (var i = n; i < candles.length - n; i++) {
      var isHigh = true, isLow = true;
      for (var k = i - n; k <= i + n; k++) {
        if (k == i) continue;
        if (candles[k].high >= candles[i].high) isHigh = false;
        if (candles[k].low <= candles[i].low) isLow = false;
      }
      if (isHigh) out.add(Pivot(index: i, price: candles[i].high, isHigh: true, time: candles[i].time));
      if (isLow) out.add(Pivot(index: i, price: candles[i].low, isHigh: false, time: candles[i].time));
    }
    return out;
  }

  // --- Trendline ------------------------------------------------------------

  /// Fits a least-squares line through a set of pivots and reports its slope,
  /// R-squared and how many bars touched it within [touchTolerance].
  static Trendline fitTrendline(
    List<Candle> candles,
    List<Pivot> pivots, {
    double touchTolerance = 0.005,
  }) {
    if (pivots.length < 2) {
      return const Trendline(slope: 0, intercept: 0, r2: 0, pivotCount: 0, touches: 0, startIndex: 0, endIndex: 0);
    }
    final xs = pivots.map((p) => p.index.toDouble()).toList(growable: false);
    final ys = pivots.map((p) => p.price).toList(growable: false);
    final n = xs.length;
    final meanX = xs.reduce((a, b) => a + b) / n;
    final meanY = ys.reduce((a, b) => a + b) / n;

    var sxx = 0.0, sxy = 0.0;
    for (var i = 0; i < n; i++) {
      sxx += (xs[i] - meanX) * (xs[i] - meanX);
      sxy += (xs[i] - meanX) * (ys[i] - meanY);
    }
    final slope = sxx == 0 ? 0.0 : sxy / sxx;
    final intercept = meanY - slope * meanX;

    var ssRes = 0.0, ssTot = 0.0;
    for (var i = 0; i < n; i++) {
      final pred = slope * xs[i] + intercept;
      ssRes += (ys[i] - pred) * (ys[i] - pred);
      ssTot += (ys[i] - meanY) * (ys[i] - meanY);
    }
    final r2 = ssTot == 0 ? 1.0 : 1 - ssRes / ssTot;

    final start = pivots.first.index;
    final end = pivots.last.index;
    var touches = 0;
    for (var i = start; i <= end && i < candles.length; i++) {
      final line = slope * i + intercept;
      if (line == 0) continue;
      final dist = (candles[i].close - line).abs() / line;
      if (dist <= touchTolerance) touches++;
    }

    return Trendline(
      slope: slope,
      intercept: intercept,
      r2: r2,
      pivotCount: n,
      touches: touches,
      startIndex: start,
      endIndex: end,
    );
  }

  /// Breakout test: price closed beyond the level on volume above
  /// `multiple` times the 20-bar average — the volume-confirmation filter.
  static bool breakoutConfirmed(List<Candle> candles, double level, {bool above = true, double volumeMultiple = 1.5}) {
    if (candles.length < 21) return false;
    final last = candles.last;
    final vol = candles.sublist(candles.length - 21, candles.length - 1).map((c) => c.volume).reduce((a, b) => a + b) / 20;
    final priceOk = above ? last.close > level : last.close < level;
    return priceOk && vol > 0 && last.volume > volumeMultiple * vol;
  }

  // --- Support / resistance -------------------------------------------------

  /// Clusters reaction prices into levels by binning and merging neighbours.
  static List<PriceLevel> supportResistance(List<Candle> candles, {int bins = 40}) {
    if (candles.isEmpty) return const [];
    final window = candles.length >= 250 ? candles.sublist(candles.length - 250) : candles;
    var lo = double.infinity, hi = double.negativeInfinity;
    for (final c in window) {
      lo = math.min(lo, c.low);
      hi = math.max(hi, c.high);
    }
    if (hi <= lo) return const [];
    final width = (hi - lo) / bins;
    final counts = List<int>.filled(bins, 0);
    final sums = List<double>.filled(bins, 0);

    for (final c in window) {
      final idx = ((c.close - lo) / width).floor().clamp(0, bins - 1);
      counts[idx]++;
      sums[idx] += c.close;
    }

    final last = window.last.close;
    final out = <PriceLevel>[];
    for (var i = 0; i < bins; i++) {
      if (counts[i] < 2) continue;
      final price = sums[i] / counts[i];
      out.add(PriceLevel(
        price: price,
        touches: counts[i],
        isSupport: price < last,
        isResistance: price >= last,
      ));
    }
    out.sort((a, b) => b.touches.compareTo(a.touches));
    return out;
  }

  // --- Fibonacci ------------------------------------------------------------

  /// Retracement and extension levels between a swing low and swing high.
  static Map<String, double> fibonacci(double swingLow, double swingHigh, {bool upLeg = true}) {
    final range = swingHigh - swingLow;
    const ratios = <String, double>{
      '23.6%': 0.236,
      '38.2%': 0.382,
      '50.0%': 0.5,
      '61.8%': 0.618,
      '78.6%': 0.786,
      '100.0%': 1.0,
      '161.8%': 1.618,
      '261.8%': 2.618,
    };
    final out = <String, double>{};
    for (final e in ratios.entries) {
      out[e.key] = upLeg ? swingHigh - range * e.value : swingLow + range * e.value;
    }
    return out;
  }

  // --- VWAP ----------------------------------------------------------------

  /// Volume-weighted average price using the typical price (H+L+C)/3.
  static List<double?> vwap(List<Candle> candles) {
    final out = List<double?>.filled(candles.length, null);
    var pv = 0.0, vol = 0.0;
    for (var i = 0; i < candles.length; i++) {
      final typical = (candles[i].high + candles[i].low + candles[i].close) / 3;
      pv += typical * candles[i].volume;
      vol += candles[i].volume;
      out[i] = vol == 0 ? null : pv / vol;
    }
    return out;
  }

  /// Anchored VWAP: the same accumulation, restarted at [anchorIndex].
  static List<double?> anchoredVwap(List<Candle> candles, int anchorIndex) {
    final out = List<double?>.filled(candles.length, null);
    if (anchorIndex < 0 || anchorIndex >= candles.length) return out;
    var pv = 0.0, vol = 0.0;
    for (var i = anchorIndex; i < candles.length; i++) {
      final typical = (candles[i].high + candles[i].low + candles[i].close) / 3;
      pv += typical * candles[i].volume;
      vol += candles[i].volume;
      out[i] = vol == 0 ? null : pv / vol;
    }
    return out;
  }

  // --- Volume profile -------------------------------------------------------

  /// Builds a fixed-range volume profile, distributing each bar's volume across
  /// the price bins its high-low range covers, then derives the point of
  /// control and the 70% value area.
  static VolumeProfile volumeProfile(List<Candle> candles, {int bins = 50, double valueAreaFraction = 0.7}) {
    if (candles.isEmpty) {
      return const VolumeProfile(bins: [], poc: 0, vah: 0, val: 0, totalVolume: 0);
    }
    final window = candles.length >= 250 ? candles.sublist(candles.length - 250) : candles;
    var lo = double.infinity, hi = double.negativeInfinity;
    for (final c in window) {
      lo = math.min(lo, c.low);
      hi = math.max(hi, c.high);
    }
    if (hi <= lo) {
      final p = window.last.close;
      return VolumeProfile(bins: [ProfileBin(low: p, high: p, volume: window.fold(0.0, (s, c) => s + c.volume))], poc: p, vah: p, val: p, totalVolume: window.fold(0.0, (s, c) => s + c.volume));
    }
    final width = (hi - lo) / bins;
    final vols = List<double>.filled(bins, 0.0);

    for (final c in window) {
      final barRange = c.high - c.low;
      if (barRange <= 0) {
        final idx = ((c.close - lo) / width).floor().clamp(0, bins - 1);
        vols[idx] += c.volume;
        continue;
      }
      final firstBin = ((c.low - lo) / width).floor().clamp(0, bins - 1);
      final lastBin = ((c.high - lo) / width).floor().clamp(0, bins - 1);
      final span = lastBin - firstBin + 1;
      for (var b = firstBin; b <= lastBin; b++) {
        vols[b] += c.volume / span;
      }
    }

    final total = vols.reduce((a, b) => a + b);
    var pocIdx = 0;
    for (var i = 1; i < bins; i++) {
      if (vols[i] > vols[pocIdx]) pocIdx = i;
    }

    // Expand symmetrically around the point of control until the value area is
    // reached, which is the standard construction.
    var loIdx = pocIdx, hiIdx = pocIdx;
    var captured = vols[pocIdx];
    final target = total * valueAreaFraction;
    while (captured < target && (loIdx > 0 || hiIdx < bins - 1)) {
      final downVol = loIdx > 0 ? vols[loIdx - 1] : -1.0;
      final upVol = hiIdx < bins - 1 ? vols[hiIdx + 1] : -1.0;
      if (upVol >= downVol) {
        hiIdx++;
        captured += upVol;
      } else {
        loIdx--;
        captured += downVol;
      }
    }

    final profileBins = <ProfileBin>[
      for (var i = 0; i < bins; i++) ProfileBin(low: lo + i * width, high: lo + (i + 1) * width, volume: vols[i]),
    ];

    return VolumeProfile(
      bins: profileBins,
      poc: lo + (pocIdx + 0.5) * width,
      vah: lo + (hiIdx + 1) * width,
      val: lo + loIdx * width,
      totalVolume: total,
    );
  }

  // --- Volume / order flow --------------------------------------------------

  /// On-Balance Volume: cumulative volume added on up-closes and subtracted on
  /// down-closes.
  static List<double> obv(List<Candle> candles) {
    final out = List<double>.filled(candles.length, 0);
    for (var i = 1; i < candles.length; i++) {
      final prev = out[i - 1];
      if (candles[i].close > candles[i - 1].close) {
        out[i] = prev + candles[i].volume;
      } else if (candles[i].close < candles[i - 1].close) {
        out[i] = prev - candles[i].volume;
      } else {
        out[i] = prev;
      }
    }
    return out;
  }

  /// Order-flow delta **proxy**.
  ///
  /// True bid/ask delta requires trade-level aggressor data that OHLCV bars do
  /// not carry. This uses the documented close-location method: the share of a
  /// bar's volume attributed to buyers is (close - low) / (high - low). The
  /// result is a proxy and is labelled as one wherever it is displayed.
  static List<double> deltaProxy(List<Candle> candles) {
    final out = List<double>.filled(candles.length, 0);
    for (var i = 0; i < candles.length; i++) {
      final range = candles[i].high - candles[i].low;
      if (range <= 0) {
        out[i] = 0;
        continue;
      }
      final buyFraction = (candles[i].close - candles[i].low) / range;
      final buyVol = candles[i].volume * buyFraction;
      final sellVol = candles[i].volume - buyVol;
      out[i] = buyVol - sellVol;
    }
    return out;
  }

  // --- Channels -------------------------------------------------------------

  /// Wilder's Average True Range.
  static List<double?> atr(List<Candle> candles, {int period = 14}) {
    final out = List<double?>.filled(candles.length, null);
    if (candles.isEmpty) return out;
    final tr = List<double>.filled(candles.length, 0);
    tr[0] = candles[0].high - candles[0].low;
    for (var i = 1; i < candles.length; i++) {
      final h = candles[i].high, l = candles[i].low, pc = candles[i - 1].close;
      tr[i] = math.max(h - l, math.max((h - pc).abs(), (l - pc).abs()));
    }
    if (candles.length < period) return out;
    var sum = 0.0;
    for (var i = 0; i < period; i++) {
      sum += tr[i];
    }
    var value = sum / period;
    out[period - 1] = value;
    for (var i = period; i < candles.length; i++) {
      value = (value * (period - 1) + tr[i]) / period;
      out[i] = value;
    }
    return out;
  }

  static double _mean(List<double> xs) => xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

  static double _std(List<double> xs) {
    if (xs.length < 2) return 0;
    final m = _mean(xs);
    var v = 0.0;
    for (final x in xs) {
      v += (x - m) * (x - m);
    }
    return math.sqrt(v / xs.length);
  }

  static List<double?> _sma(List<double> xs, int period) {
    final out = List<double?>.filled(xs.length, null);
    if (xs.length < period) return out;
    var sum = 0.0;
    for (var i = 0; i < xs.length; i++) {
      sum += xs[i];
      if (i >= period) sum -= xs[i - period];
      if (i >= period - 1) out[i] = sum / period;
    }
    return out;
  }

  static List<double?> _ema(List<double> xs, int period) {
    final out = List<double?>.filled(xs.length, null);
    if (xs.length < period) return out;
    final k = 2 / (period + 1);
    var value = _mean(xs.sublist(0, period));
    out[period - 1] = value;
    for (var i = period; i < xs.length; i++) {
      value = xs[i] * k + value * (1 - k);
      out[i] = value;
    }
    return out;
  }

  /// ATR channel: a moving average displaced by a multiple of ATR.
  static ChannelBands atrChannel(List<Candle> candles, {int period = 20, double multiple = 2}) {
    final closes = candles.map((c) => c.close).toList(growable: false);
    final mid = _sma(closes, period);
    final a = atr(candles, period: period);
    final upper = List<double?>.filled(candles.length, null);
    final lower = List<double?>.filled(candles.length, null);
    for (var i = 0; i < candles.length; i++) {
      final m = mid[i], av = a[i];
      if (m == null || av == null) continue;
      upper[i] = m + multiple * av;
      lower[i] = m - multiple * av;
    }
    return ChannelBands(upper: upper, middle: mid, lower: lower, kind: 'ATR channel');
  }

  /// Keltner channel: an EMA displaced by a multiple of ATR.
  static ChannelBands keltner(List<Candle> candles, {int period = 20, double multiple = 2}) {
    final closes = candles.map((c) => c.close).toList(growable: false);
    final mid = _ema(closes, period);
    final a = atr(candles, period: period);
    final upper = List<double?>.filled(candles.length, null);
    final lower = List<double?>.filled(candles.length, null);
    for (var i = 0; i < candles.length; i++) {
      final m = mid[i], av = a[i];
      if (m == null || av == null) continue;
      upper[i] = m + multiple * av;
      lower[i] = m - multiple * av;
    }
    return ChannelBands(upper: upper, middle: mid, lower: lower, kind: 'Keltner');
  }

  /// Bollinger bands: a moving average displaced by a multiple of the standard
  /// deviation of the close.
  static ChannelBands bollinger(List<Candle> candles, {int period = 20, double multiple = 2}) {
    final closes = candles.map((c) => c.close).toList(growable: false);
    final mid = _sma(closes, period);
    final upper = List<double?>.filled(candles.length, null);
    final lower = List<double?>.filled(candles.length, null);
    for (var i = period - 1; i < candles.length; i++) {
      final window = closes.sublist(i - period + 1, i + 1);
      final m = mid[i]!;
      final sd = _std(window);
      upper[i] = m + multiple * sd;
      lower[i] = m - multiple * sd;
    }
    return ChannelBands(upper: upper, middle: mid, lower: lower, kind: 'Bollinger');
  }

  /// Moving-average envelope: a fixed percentage either side of the average.
  static ChannelBands envelope(List<Candle> candles, {int period = 20, double percent = 2.5}) {
    final closes = candles.map((c) => c.close).toList(growable: false);
    final mid = _sma(closes, period);
    final upper = List<double?>.filled(candles.length, null);
    final lower = List<double?>.filled(candles.length, null);
    for (var i = 0; i < candles.length; i++) {
      final m = mid[i];
      if (m == null) continue;
      upper[i] = m * (1 + percent / 100);
      lower[i] = m * (1 - percent / 100);
    }
    return ChannelBands(upper: upper, middle: mid, lower: lower, kind: 'Envelope');
  }

  // --- Patterns -------------------------------------------------------------

  /// Detects double tops and bottoms from the pivot sequence.
  static List<DetectedPattern> doubleTopsAndBottoms(List<Candle> candles, {int n = 3, double tolerancePct = 3}) {
    final pv = pivots(candles, n: n);
    final out = <DetectedPattern>[];
    for (var i = 0; i + 2 < pv.length; i++) {
      final a = pv[i], b = pv[i + 2];
      if (a.isHigh != b.isHigh) continue;
      final diffPct = ((a.price - b.price).abs() / a.price) * 100;
      if (diffPct > tolerancePct) continue;
      final between = pv[i + 1];
      if (between.isHigh == a.isHigh) continue;
      final isTop = a.isHigh;
      out.add(DetectedPattern(
        name: isTop ? 'Double top' : 'Double bottom',
        kind: PatternKind.reversal,
        startIndex: a.index,
        endIndex: b.index,
        confidence: (1 - diffPct / tolerancePct).clamp(0.0, 1.0),
        description: isTop
            ? 'Two highs near ${a.price.toStringAsFixed(2)} with a trough at ${between.price.toStringAsFixed(2)} between them.'
            : 'Two lows near ${a.price.toStringAsFixed(2)} with a peak at ${between.price.toStringAsFixed(2)} between them.',
      ));
    }
    return out;
  }

  /// Detects head-and-shoulders and its inverse: three alternating pivots where
  /// the middle one is the extreme and the shoulders are roughly symmetric.
  static List<DetectedPattern> headAndShoulders(List<Candle> candles, {int n = 3, double shoulderTolerancePct = 12}) {
    final pv = pivots(candles, n: n);
    final out = <DetectedPattern>[];
    for (var i = 0; i + 4 < pv.length; i++) {
      final ls = pv[i], trough1 = pv[i + 1], head = pv[i + 2], trough2 = pv[i + 3], rs = pv[i + 4];
      if (!ls.isHigh || trough1.isHigh || !head.isHigh || trough2.isHigh || !rs.isHigh) continue;
      final headIsExtreme = head.price > ls.price && head.price > rs.price;
      if (!headIsExtreme) continue;
      final shoulderDiff = ((ls.price - rs.price).abs() / ls.price) * 100;
      if (shoulderDiff > shoulderTolerancePct) continue;
      out.add(DetectedPattern(
        name: 'Head and shoulders',
        kind: PatternKind.reversal,
        startIndex: ls.index,
        endIndex: rs.index,
        confidence: (1 - shoulderDiff / shoulderTolerancePct).clamp(0.0, 1.0),
        description:
            'Shoulders near ${ls.price.toStringAsFixed(2)} / ${rs.price.toStringAsFixed(2)} with a head at ${head.price.toStringAsFixed(2)}.',
      ));
    }
    return out;
  }

  /// Classifies gaps by size and position within the recent range.
  static List<DetectedPattern> gaps(List<Candle> candles) {
    final out = <DetectedPattern>[];
    if (candles.length < 30) return out;
    final window = candles.sublist(candles.length - 30);
    final avgRange = _mean(window.map((c) => c.high - c.low).toList(growable: false));
    for (var i = 1; i < candles.length; i++) {
      final prev = candles[i - 1], cur = candles[i];
      double? gap;
      bool up = false;
      if (cur.low > prev.high) {
        gap = cur.low - prev.high;
        up = true;
      } else if (cur.high < prev.low) {
        gap = prev.low - cur.high;
        up = false;
      }
      if (gap == null || avgRange <= 0) continue;
      final sizeRatio = gap / avgRange;
      final String kind;
      if (sizeRatio >= 2.5) {
        kind = 'Exhaustion gap';
      } else if (sizeRatio >= 1.2) {
        kind = 'Runaway gap';
      } else {
        kind = 'Common gap';
      }
      out.add(DetectedPattern(
        name: '$kind (${up ? 'up' : 'down'})',
        kind: PatternKind.gap,
        startIndex: i - 1,
        endIndex: i,
        confidence: (sizeRatio / 3).clamp(0.0, 1.0),
        description: 'Gap of ${gap.toStringAsFixed(2)} versus a ${avgRange.toStringAsFixed(2)} average bar range.',
      ));
    }
    return out;
  }

  // --- Regime ---------------------------------------------------------------

  /// Classifies the market into one of four states from the trend slope and the
  /// level of realised volatility against its own recent median.
  static RegimeReading? regime(List<Candle> candles, {int maPeriod = 50, int slopeLookback = 20, int volWindow = 20}) {
    if (candles.length < maPeriod + slopeLookback + volWindow) return null;
    final closes = candles.map((c) => c.close).toList(growable: false);
    final ma = _sma(closes, maPeriod);
    final now = ma[closes.length - 1];
    final before = ma[closes.length - 1 - slopeLookback];
    if (now == null || before == null || before == 0) return null;
    final slopePct = ((now - before) / before) * 100;

    final vol = _realisedVolPct(closes, volWindow);
    final median = _rollingVolMedian(closes, volWindow);

    if (slopePct.abs() < 2.0) {
      return RegimeReading(regime: MarketRegime.sidewaysCompression, trendSlopePct: slopePct, volatilityPct: vol, volatilityMedianPct: median);
    }
    final highVol = vol > median;
    if (slopePct > 0) {
      return RegimeReading(
        regime: highVol ? MarketRegime.bullHighVol : MarketRegime.bullLowVol,
        trendSlopePct: slopePct,
        volatilityPct: vol,
        volatilityMedianPct: median,
      );
    }
    return RegimeReading(regime: MarketRegime.bearHighVol, trendSlopePct: slopePct, volatilityPct: vol, volatilityMedianPct: median);
  }

  static double _realisedVolPct(List<double> closes, int window) {
    if (closes.length < window + 1) return 0;
    final rets = <double>[];
    for (var i = closes.length - window; i < closes.length; i++) {
      if (closes[i - 1] != 0) rets.add(closes[i] / closes[i - 1] - 1);
    }
    return _std(rets) * math.sqrt(252) * 100;
  }

  static double _rollingVolMedian(List<double> closes, int window) {
    final samples = <double>[];
    for (var end = closes.length; end - window - 1 >= 0; end -= window) {
      final slice = closes.sublist(0, end);
      samples.add(_realisedVolPct(slice, window));
    }
    if (samples.isEmpty) return 0;
    samples.sort();
    final mid = samples.length ~/ 2;
    return samples.length.isOdd ? samples[mid] : (samples[mid - 1] + samples[mid]) / 2;
  }

  // --- Features -------------------------------------------------------------

  /// Log returns.
  static List<double> logReturns(List<double> prices) {
    final out = <double>[];
    for (var i = 1; i < prices.length; i++) {
      if (prices[i - 1] > 0 && prices[i] > 0) out.add(math.log(prices[i] / prices[i - 1]));
    }
    return out;
  }

  /// Fractional differentiation (fixed-width window), the standard technique for
  /// making a price series stationary while preserving as much memory as
  /// possible. Weights are w0 = 1, wk = -w(k-1) * (d - k + 1) / k, truncated
  /// when the weight falls below [threshold].
  static List<double> fractionalDifference(List<double> series, double d, {double threshold = 1e-5}) {
    final weights = <double>[1.0];
    var k = 1;
    while (true) {
      final w = -weights[k - 1] * (d - k + 1) / k;
      if (w.abs() < threshold) break;
      weights.add(w);
      k++;
      if (k > 2000) break;
    }
    final out = <double>[];
    for (var i = weights.length - 1; i < series.length; i++) {
      var sum = 0.0;
      for (var j = 0; j < weights.length; j++) {
        sum += weights[j] * series[i - j];
      }
      out.add(sum);
    }
    return out;
  }

  /// Augmented-Dickey-Fuller style stationarity check on the fractionally
  /// differenced series: the correlation of the level with its lagged change.
  /// A more negative statistic indicates stronger mean reversion.
  static double adfStatistic(List<double> series) {
    if (series.length < 10) return 0;
    final y = <double>[];
    final x = <double>[];
    for (var i = 1; i < series.length; i++) {
      y.add(series[i] - series[i - 1]);
      x.add(series[i - 1]);
    }
    final n = x.length;
    final mx = _mean(x), my = _mean(y);
    var sxy = 0.0, sxx = 0.0;
    for (var i = 0; i < n; i++) {
      sxy += (x[i] - mx) * (y[i] - my);
      sxx += (x[i] - mx) * (x[i] - mx);
    }
    if (sxx == 0) return 0;
    final beta = sxy / sxx;
    final residualSd = _std([for (var i = 0; i < n; i++) y[i] - my - beta * (x[i] - mx)]);
    if (residualSd == 0) return 0;
    return beta / (residualSd / math.sqrt(n.toDouble()));
  }

  /// Triple-barrier labelling: for each event, which barrier is touched first —
  /// take-profit, stop-loss, or the time limit.
  ///
  /// When a single bar touches both barriers the outcome is genuinely ambiguous
  /// from OHLC data, so the stop-loss is recorded (the conservative choice) and
  /// the ambiguity is reported by the caller.
  static List<TripleBarrierLabel> tripleBarrier(
    List<Candle> candles, {
    required List<int> events,
    double takeProfitMultiple = 2.0,
    double stopLossMultiple = 1.0,
    int maxBars = 20,
    int atrPeriod = 14,
  }) {
    final a = atr(candles, period: atrPeriod);
    final out = <TripleBarrierLabel>[];
    for (final e in events) {
      if (e < 0 || e >= candles.length) continue;
      final av = a[e];
      if (av == null || av <= 0) continue;
      final entry = candles[e].close;
      final tp = entry + takeProfitMultiple * av;
      final sl = entry - stopLossMultiple * av;
      var label = 0;
      var exitIndex = math.min(candles.length - 1, e + maxBars);
      for (var t = e + 1; t <= math.min(candles.length - 1, e + maxBars); t++) {
        final hitTp = candles[t].high >= tp;
        final hitSl = candles[t].low <= sl;
        if (hitSl) {
          label = -1;
          exitIndex = t;
          break;
        }
        if (hitTp) {
          label = 1;
          exitIndex = t;
          break;
        }
      }
      out.add(TripleBarrierLabel(index: e, label: label, exitIndex: exitIndex));
    }
    return out;
  }
}
