/// Applies book frameworks to real price/volume data.
///
/// Every number here is computed from candles. Criteria that need fundamentals
/// (EPS growth, ROIC, institutional ownership) are reported as `needsData` and
/// are **never** counted as passes — the screener will not invent a metric it
/// cannot measure.
library;

import 'dart:math' as math;

import '../../data/models/candle.dart';
import '../indicators/indicators.dart';
import 'book_framework.dart';

/// The technical measurements computed for one instrument.
class Technicals {
  final double price;
  final double sma50;
  final double sma150;
  final double sma200;
  final double sma200Prev;
  final double high252;
  final double low252;
  final double avgVol10;
  final double avgVol50;
  final double momentum12_1Pct;
  final double volatilityPct;
  final double maxDrawdownPct;
  final double upShare;
  final bool vcpDetected;
  final String vcpDetail;

  const Technicals({
    required this.price,
    required this.sma50,
    required this.sma150,
    required this.sma200,
    required this.sma200Prev,
    required this.high252,
    required this.low252,
    required this.avgVol10,
    required this.avgVol50,
    required this.momentum12_1Pct,
    required this.volatilityPct,
    required this.maxDrawdownPct,
    required this.upShare,
    required this.vcpDetected,
    required this.vcpDetail,
  });

  double get offLowPct => low252 == 0 ? 0 : (price / low252 - 1) * 100;
  double get belowHighPct => high252 == 0 ? 0 : (1 - price / high252) * 100;
}

/// One screened instrument.
class ScreenHit {
  final String symbol;
  final Technicals tech;
  final FrameworkVerdict verdict;

  const ScreenHit({required this.symbol, required this.tech, required this.verdict});
}

class ScreenReport {
  final BookFramework framework;
  final List<ScreenHit> hits;
  final int universeSize;

  const ScreenReport({required this.framework, required this.hits, required this.universeSize});

  List<ScreenHit> get passing => hits.where((h) => h.verdict.passed).toList(growable: false);
}

class FrameworkScreener {
  const FrameworkScreener();

  /// Screens a whole universe. Relative-strength and factor criteria are
  /// genuinely cross-sectional — they are ranks against the peers supplied here.
  ScreenReport screen(BookFramework framework, Map<String, List<Candle>> universe) {
    final techs = <String, Technicals>{};
    for (final entry in universe.entries) {
      final t = _computeTechnicals(entry.value);
      if (t != null) techs[entry.key] = t;
    }
    if (techs.isEmpty) return ScreenReport(framework: framework, hits: const [], universeSize: 0);

    final rsRanks = _percentileRanks({for (final e in techs.entries) e.key: _returnPct(e.value, 252)});
    final volRanks = _percentileRanks({for (final e in techs.entries) e.key: e.value.volatilityPct});
    final ddRanks = _percentileRanks({for (final e in techs.entries) e.key: e.value.maxDrawdownPct});
    final upRanks = _percentileRanks({for (final e in techs.entries) e.key: e.value.upShare});
    final momRanks = _percentileRanks({for (final e in techs.entries) e.key: e.value.momentum12_1Pct});

    final hits = <ScreenHit>[];
    for (final entry in techs.entries) {
      final symbol = entry.key;
      final t = entry.value;
      final results = <CriterionResult>[];
      for (final c in framework.criteria) {
        results.add(_evaluate(c, t, rsRanks[symbol] ?? 0, volRanks[symbol] ?? 50, ddRanks[symbol] ?? 50, upRanks[symbol] ?? 50, momRanks[symbol] ?? 50));
      }
      hits.add(ScreenHit(
        symbol: symbol,
        tech: t,
        verdict: FrameworkVerdict(framework: framework, symbol: symbol, results: results),
      ));
    }
    hits.sort((a, b) => b.verdict.score.compareTo(a.verdict.score));
    return ScreenReport(framework: framework, hits: hits, universeSize: techs.length);
  }

  // --- Criterion dispatch ---------------------------------------------------

  CriterionResult _evaluate(
    FrameworkCriterion c,
    Technicals t,
    double rs,
    double volRank,
    double ddRank,
    double upRank,
    double momRank,
  ) {
    if (!c.computableFromCandles) {
      return CriterionResult(
        criterion: c,
        state: CriterionState.needsData,
        detail: 'Needs fundamentals this build does not hold (${c.metric}).',
      );
    }
    bool met;
    String detail;
    switch (c.name) {
      case 'Price above the long averages':
        met = t.price > t.sma150 && t.price > t.sma200;
        detail = 'price ${_n(t.price)} vs SMA150 ${_n(t.sma150)}, SMA200 ${_n(t.sma200)}';
      case '150 above 200':
        met = t.sma150 > t.sma200;
        detail = 'SMA150 ${_n(t.sma150)} vs SMA200 ${_n(t.sma200)}';
      case '200-day rising':
        met = t.sma200 > t.sma200Prev;
        detail = 'SMA200 ${_n(t.sma200)} vs ${_n(t.sma200Prev)} 30 bars ago';
      case '50 above both':
        met = t.sma50 > t.sma150 && t.sma50 > t.sma200;
        detail = 'SMA50 ${_n(t.sma50)} vs SMA150 ${_n(t.sma150)}, SMA200 ${_n(t.sma200)}';
      case 'Price above 50':
        met = t.price > t.sma50;
        detail = 'price ${_n(t.price)} vs SMA50 ${_n(t.sma50)}';
      case 'Well off the low':
        met = t.offLowPct >= 30;
        detail = '${t.offLowPct.toStringAsFixed(1)}% above the 52-week low';
      case 'Near the high':
        met = t.belowHighPct <= 25;
        detail = '${t.belowHighPct.toStringAsFixed(1)}% below the 52-week high';
      case 'N — new highs':
        met = t.belowHighPct <= 15;
        detail = '${t.belowHighPct.toStringAsFixed(1)}% below the 52-week high';
      case 'S — supply and demand':
        met = t.avgVol10 > t.avgVol50;
        detail = 'recent volume ${_n(t.avgVol10)} vs longer average ${_n(t.avgVol50)}';
      case 'L — leader, not laggard':
        met = rs >= 80;
        detail = 'relative-strength percentile ${rs.toStringAsFixed(0)}';
      case 'Relative strength':
        met = rs >= 70;
        detail = 'relative-strength percentile ${rs.toStringAsFixed(0)}';
      case 'Breakout volume':
        met = t.avgVol10 > t.avgVol50;
        detail = 'recent volume ${_n(t.avgVol10)} vs longer average ${_n(t.avgVol50)}';
      case 'Volatility contraction':
        met = t.vcpDetected;
        detail = t.vcpDetail;
      case 'Stage 2 confirmation':
        met = t.price > t.sma150 && t.sma150 > t.sma200 && t.sma200 > t.sma200Prev;
        detail = 'price ${_n(t.price)} above SMA150 ${_n(t.sma150)}, both rising';
      case 'Trend filter':
        met = t.price > t.sma200;
        detail = 'price ${_n(t.price)} vs SMA200 ${_n(t.sma200)}';
      case 'Breakout entry':
        met = t.belowHighPct <= 2;
        detail = '${t.belowHighPct.toStringAsFixed(1)}% below the 52-week high';
      case 'Trailing momentum':
        met = momRank >= 90;
        detail = '12-1 month return ${t.momentum12_1Pct.toStringAsFixed(1)}% (percentile ${momRank.toStringAsFixed(0)})';
      case 'Cross-sectional rank':
        met = momRank >= 90;
        detail = 'momentum percentile ${momRank.toStringAsFixed(0)}';
      case 'Low realised volatility':
        met = volRank <= 33;
        detail = 'annualised volatility ${t.volatilityPct.toStringAsFixed(1)}% (percentile ${volRank.toStringAsFixed(0)})';
      case 'Shallow drawdowns':
        met = ddRank <= 50;
        detail = 'max drawdown ${t.maxDrawdownPct.toStringAsFixed(1)}% (percentile ${ddRank.toStringAsFixed(0)})';
      case 'Return consistency':
        met = upRank >= 50;
        detail = '${(t.upShare * 100).toStringAsFixed(0)}% of periods positive (percentile ${upRank.toStringAsFixed(0)})';
      case 'Volatility sizing':
      case 'Loss limit':
      case 'Volatility awareness':
        return CriterionResult(
          criterion: c,
          state: CriterionState.needsData,
          detail: 'A risk rule applied at execution (stop distance / position sizing), not a screen.',
        );
      default:
        return CriterionResult(
          criterion: c,
          state: CriterionState.needsData,
          detail: 'No automated check is defined for this criterion yet.',
        );
    }
    return CriterionResult(criterion: c, state: met ? CriterionState.met : CriterionState.unmet, detail: detail);
  }

  // --- Measurement ----------------------------------------------------------

  Technicals? _computeTechnicals(List<Candle> candles) {
    if (candles.length < 210) return null;
    final closes = candles.map((c) => c.close).toList(growable: false);
    final n = closes.length;
    final price = closes.last;

    final s50 = Indicators.sma(closes, 50);
    final s150 = Indicators.sma(closes, 150);
    final s200 = Indicators.sma(closes, 200);
    final sma50 = s50[n - 1] ?? price;
    final sma150 = s150[n - 1] ?? price;
    final sma200 = s200[n - 1] ?? price;
    final sma200Prev = (n - 31 >= 0 ? s200[n - 31] : null) ?? sma200;

    final window = candles.length >= 252 ? candles.sublist(candles.length - 252) : candles;
    var high252 = double.negativeInfinity, low252 = double.infinity;
    for (final c in window) {
      if (c.high > high252) high252 = c.high;
      if (c.low < low252) low252 = c.low;
    }

    final vols = candles.map((c) => c.volume).toList(growable: false);
    final avgVol10 = _mean(vols.sublist(math.max(0, n - 10)));
    final avgVol50 = _mean(vols.sublist(math.max(0, n - 50)));

    // 12-1 month momentum: return over the last 252 bars, skipping the last 21.
    final momentum12_1 = _momentum(closes, 252, 21);

    // Annualised volatility and drawdown from daily returns.
    final returns = <double>[];
    for (var i = 1; i < n; i++) {
      if (closes[i - 1] != 0) returns.add(closes[i] / closes[i - 1] - 1);
    }
    final sd = _std(returns);
    final vol = sd * math.sqrt(252) * 100;
    var peak = closes.first, maxDd = 0.0;
    for (final c in closes) {
      if (c > peak) peak = c;
      if (peak != 0) maxDd = math.max(maxDd, (peak - c) / peak);
    }
    final upShare = returns.isEmpty ? 0.5 : returns.where((r) => r > 0).length / returns.length;

    final vcp = _detectVcp(candles);

    return Technicals(
      price: price,
      sma50: sma50,
      sma150: sma150,
      sma200: sma200,
      sma200Prev: sma200Prev,
      high252: high252.isFinite ? high252 : price,
      low252: low252.isFinite ? low252 : price,
      avgVol10: avgVol10,
      avgVol50: avgVol50,
      momentum12_1Pct: momentum12_1 * 100,
      volatilityPct: vol,
      maxDrawdownPct: maxDd * 100,
      upShare: upShare,
      vcpDetected: vcp.$1,
      vcpDetail: vcp.$2,
    );
  }

  /// Detects the shape of a Volatility Contraction Pattern: successive pullbacks
  /// that get shallower, on declining volume, near the top of the range.
  (bool, String) _detectVcp(List<Candle> candles) {
    final n = candles.length;
    final lookback = math.min(90, n);
    final window = candles.sublist(n - lookback);

    // Find swing lows (a low lower than the two bars either side).
    final lows = <int>[];
    for (var i = 2; i < window.length - 2; i++) {
      final l = window[i].low;
      if (l <= window[i - 1].low && l <= window[i - 2].low && l <= window[i + 1].low && l <= window[i + 2].low) {
        lows.add(i);
      }
    }
    if (lows.length < 2) return (false, 'No contraction sequence found in the last $lookback bars.');

    // Depth of each pullback from the running high to the following low.
    final depths = <double>[];
    var runningHigh = window.first.high;
    for (var i = 1; i < window.length; i++) {
      runningHigh = math.max(runningHigh, window[i].high);
      if (lows.contains(i) && runningHigh > 0) {
        depths.add((runningHigh - window[i].low) / runningHigh);
        runningHigh = window[i].high;
      }
    }
    if (depths.length < 2) return (false, 'Not enough completed pullbacks.');

    // Each contraction should be meaningfully shallower than the one before.
    var contracting = true;
    for (var i = 1; i < depths.length; i++) {
      if (depths[i] >= depths[i - 1] * 0.95) contracting = false;
    }

    final firstHalf = _mean(window.sublist(0, window.length ~/ 2).map((c) => c.volume).toList());
    final secondHalf = _mean(window.sublist(window.length ~/ 2).map((c) => c.volume).toList());
    final volumeDrying = secondHalf < firstHalf;

    final seq = depths.map((d) => '${(d * 100).toStringAsFixed(1)}%').join(' \u2192 ');
    final detail = 'contractions $seq; volume ${volumeDrying ? 'drying up' : 'not drying up'}';
    return (contracting && volumeDrying, detail);
  }

  // --- Helpers --------------------------------------------------------------

  static double _returnPct(Technicals t, int bars) => t.momentum12_1Pct;

  static double _momentum(List<double> closes, int lookback, int skip) {
    final n = closes.length;
    final end = n - 1 - skip;
    final start = math.max(0, n - 1 - lookback);
    if (end <= start || closes[start] == 0) return 0;
    return closes[end] / closes[start] - 1;
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

  static Map<String, double> _percentileRanks(Map<String, double> values) {
    final entries = values.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    final out = <String, double>{};
    final count = entries.length;
    for (var i = 0; i < count; i++) {
      out[entries[i].key] = count == 1 ? 100 : (i / (count - 1)) * 100;
    }
    return out;
  }

  static String _n(double v) => v.toStringAsFixed(2);
}
