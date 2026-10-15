/// Technical indicator library. Every function is causal (uses only present and
/// past data), so a series computed once over the full history can be safely
/// indexed bar-by-bar during a backtest without look-ahead bias.
///
/// All series are returned aligned to the input length, with `null` in the
/// warm-up region where the indicator is not yet defined.
library;

import 'dart:math' as math;

import '../../data/models/candle.dart';
import '../../data/models/strategy_spec.dart';

class Indicators {
  const Indicators._();

  /// Simple moving average.
  static List<double?> sma(List<double> src, int period) {
    final out = List<double?>.filled(src.length, null);
    if (period <= 0) return out;
    double sum = 0;
    for (var i = 0; i < src.length; i++) {
      sum += src[i];
      if (i >= period) sum -= src[i - period];
      if (i >= period - 1) out[i] = sum / period;
    }
    return out;
  }

  /// Exponential moving average, seeded with the SMA of the first `period`
  /// values (the conventional Wilder/TA-Lib behaviour).
  static List<double?> ema(List<double> src, int period) {
    final out = List<double?>.filled(src.length, null);
    if (period <= 0 || src.length < period) return out;
    final k = 2 / (period + 1);
    double seed = 0;
    for (var i = 0; i < period; i++) {
      seed += src[i];
    }
    double prev = seed / period;
    out[period - 1] = prev;
    for (var i = period; i < src.length; i++) {
      prev = src[i] * k + prev * (1 - k);
      out[i] = prev;
    }
    return out;
  }

  /// Wilder's Relative Strength Index.
  static List<double?> rsi(List<double> close, int period) {
    final out = List<double?>.filled(close.length, null);
    if (period <= 0 || close.length <= period) return out;
    double gain = 0;
    double loss = 0;
    for (var i = 1; i <= period; i++) {
      final change = close[i] - close[i - 1];
      if (change >= 0) {
        gain += change;
      } else {
        loss -= change;
      }
    }
    double avgGain = gain / period;
    double avgLoss = loss / period;
    out[period] = _rsiValue(avgGain, avgLoss);
    for (var i = period + 1; i < close.length; i++) {
      final change = close[i] - close[i - 1];
      final g = change > 0 ? change : 0.0;
      final l = change < 0 ? -change : 0.0;
      avgGain = (avgGain * (period - 1) + g) / period;
      avgLoss = (avgLoss * (period - 1) + l) / period;
      out[i] = _rsiValue(avgGain, avgLoss);
    }
    return out;
  }

  static double _rsiValue(double avgGain, double avgLoss) {
    if (avgLoss == 0) return 100;
    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }

  /// MACD: returns (line, signal, histogram).
  static (List<double?>, List<double?>, List<double?>) macd(
    List<double> close,
    int fast,
    int slow,
    int signal,
  ) {
    final emaFast = ema(close, fast);
    final emaSlow = ema(close, slow);
    final line = List<double?>.filled(close.length, null);
    for (var i = 0; i < close.length; i++) {
      final f = emaFast[i];
      final s = emaSlow[i];
      if (f != null && s != null) line[i] = f - s;
    }
    // Signal is an EMA of the MACD line over its defined region.
    final defined = <double>[];
    final startIdx = line.indexWhere((e) => e != null);
    for (var i = startIdx; i < line.length; i++) {
      defined.add(line[i] ?? 0);
    }
    final signalDefined = ema(defined, signal);
    final signalLine = List<double?>.filled(close.length, null);
    final hist = List<double?>.filled(close.length, null);
    if (startIdx >= 0) {
      for (var i = 0; i < signalDefined.length; i++) {
        signalLine[startIdx + i] = signalDefined[i];
        if (signalDefined[i] != null && line[startIdx + i] != null) {
          hist[startIdx + i] = line[startIdx + i]! - signalDefined[i]!;
        }
      }
    }
    return (line, signalLine, hist);
  }

  /// Bollinger Bands: returns (upper, middle, lower).
  static (List<double?>, List<double?>, List<double?>) bollinger(
    List<double> close,
    int period,
    double multiplier,
  ) {
    final middle = sma(close, period);
    final upper = List<double?>.filled(close.length, null);
    final lower = List<double?>.filled(close.length, null);
    for (var i = 0; i < close.length; i++) {
      final m = middle[i];
      if (m == null) continue;
      double sumSq = 0;
      for (var j = i - period + 1; j <= i; j++) {
        final d = close[j] - m;
        sumSq += d * d;
      }
      final sd = math.sqrt(sumSq / period);
      upper[i] = m + multiplier * sd;
      lower[i] = m - multiplier * sd;
    }
    return (upper, middle, lower);
  }

  /// Average True Range (Wilder smoothing).
  static List<double?> atr(List<Candle> candles, int period) {
    final out = List<double?>.filled(candles.length, null);
    if (period <= 0 || candles.length <= period) return out;
    final tr = List<double>.filled(candles.length, 0);
    for (var i = 0; i < candles.length; i++) {
      if (i == 0) {
        tr[i] = candles[i].high - candles[i].low;
      } else {
        final prevClose = candles[i - 1].close;
        tr[i] = math.max(
          candles[i].high - candles[i].low,
          math.max((candles[i].high - prevClose).abs(), (candles[i].low - prevClose).abs()),
        );
      }
    }
    double sum = 0;
    for (var i = 0; i < period; i++) {
      sum += tr[i];
    }
    double prev = sum / period;
    out[period - 1] = prev;
    for (var i = period; i < candles.length; i++) {
      prev = (prev * (period - 1) + tr[i]) / period;
      out[i] = prev;
    }
    return out;
  }

  /// Stochastic oscillator: returns (%K, %D).
  static (List<double?>, List<double?>) stochastic(List<Candle> candles, int kPeriod, int dPeriod) {
    final k = List<double?>.filled(candles.length, null);
    for (var i = kPeriod - 1; i < candles.length; i++) {
      double hh = candles[i].high;
      double ll = candles[i].low;
      for (var j = i - kPeriod + 1; j <= i; j++) {
        hh = math.max(hh, candles[j].high);
        ll = math.min(ll, candles[j].low);
      }
      final range = hh - ll;
      k[i] = range == 0 ? 50 : (candles[i].close - ll) / range * 100;
    }
    final defined = k.where((e) => e != null).map((e) => e!).toList();
    final startIdx = k.indexWhere((e) => e != null);
    final dDefined = sma(defined, dPeriod);
    final d = List<double?>.filled(candles.length, null);
    if (startIdx >= 0) {
      for (var i = 0; i < dDefined.length; i++) {
        d[startIdx + i] = dDefined[i];
      }
    }
    return (k, d);
  }

  /// Rate of change, in percent.
  static List<double?> roc(List<double> close, int period) {
    final out = List<double?>.filled(close.length, null);
    for (var i = period; i < close.length; i++) {
      final base = close[i - period];
      out[i] = base == 0 ? 0 : (close[i] - base) / base * 100;
    }
    return out;
  }

  /// Computes the series referenced by a [SeriesRef] over the given candles.
  static List<double?> computeSeries(SeriesRef ref, List<Candle> candles) {
    final close = candles.map((c) => c.close).toList(growable: false);
    switch (ref.type) {
      case IndicatorType.close:
        return close.map<double?>((e) => e).toList();
      case IndicatorType.volume:
        return candles.map<double?>((c) => c.volume).toList();
      case IndicatorType.sma:
        return sma(close, ref.period);
      case IndicatorType.ema:
        return ema(close, ref.period);
      case IndicatorType.rsi:
        return rsi(close, ref.period);
      case IndicatorType.macdLine:
        return macd(close, ref.period, ref.period2, ref.period3).$1;
      case IndicatorType.macdSignal:
        return macd(close, ref.period, ref.period2, ref.period3).$2;
      case IndicatorType.macdHist:
        return macd(close, ref.period, ref.period2, ref.period3).$3;
      case IndicatorType.bollUpper:
        return bollinger(close, ref.period, ref.multiplier).$1;
      case IndicatorType.bollMiddle:
        return bollinger(close, ref.period, ref.multiplier).$2;
      case IndicatorType.bollLower:
        return bollinger(close, ref.period, ref.multiplier).$3;
      case IndicatorType.atr:
        return atr(candles, ref.period);
      case IndicatorType.stochK:
        return stochastic(candles, ref.period, ref.period3).$1;
      case IndicatorType.stochD:
        return stochastic(candles, ref.period, ref.period3).$2;
      case IndicatorType.roc:
        return roc(close, ref.period);
    }
  }
}
