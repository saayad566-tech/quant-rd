import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/data/models/candle.dart';
import 'package:quant_rd/data/models/strategy_spec.dart';
import 'package:quant_rd/domain/indicators/indicators.dart';

Candle c(int i, double o, double h, double l, double cl, [double v = 100]) => Candle(
      time: DateTime.utc(2020, 1, 1).add(Duration(days: i)),
      open: o,
      high: h,
      low: l,
      close: cl,
      volume: v,
    );

void main() {
  group('SMA', () {
    test('computes the rolling mean with a null warm-up', () {
      final s = Indicators.sma([1, 2, 3, 4, 5], 3);
      expect(s[0], isNull);
      expect(s[1], isNull);
      expect(s[2], closeTo(2, 1e-9));
      expect(s[3], closeTo(3, 1e-9));
      expect(s[4], closeTo(4, 1e-9));
    });

    test('handles a period longer than the series', () {
      final s = Indicators.sma([1, 2], 5);
      expect(s.every((e) => e == null), isTrue);
    });
  });

  group('EMA', () {
    test('seeds with the SMA and then smooths', () {
      final s = Indicators.ema([1, 2, 3, 4, 5], 3);
      expect(s[0], isNull);
      expect(s[1], isNull);
      expect(s[2], closeTo(2, 1e-9)); // seed = (1+2+3)/3
      expect(s[3], closeTo(3, 1e-9)); // 4*0.5 + 2*0.5
      expect(s[4], closeTo(4, 1e-9)); // 5*0.5 + 3*0.5
    });
  });

  group('RSI (Wilder)', () {
    test('is 100 for a strictly rising series', () {
      final prices = List<double>.generate(20, (i) => (i + 1).toDouble());
      final r = Indicators.rsi(prices, 14);
      expect(r[13], isNull);
      expect(r[14], closeTo(100, 1e-6));
    });

    test('is 0 for a strictly falling series', () {
      final prices = List<double>.generate(20, (i) => (20 - i).toDouble());
      final r = Indicators.rsi(prices, 14);
      expect(r[14], closeTo(0, 1e-6));
    });
  });

  group('ROC', () {
    test('returns percent change over the period', () {
      final r = Indicators.roc([100, 110, 121], 1);
      expect(r[0], isNull);
      expect(r[1], closeTo(10, 1e-9));
      expect(r[2], closeTo(10, 1e-9));
    });
  });

  group('Bollinger', () {
    test('upper/lower sit multiplier standard deviations from the mean', () {
      final (upper, middle, lower) = Indicators.bollinger([1, 2, 3, 4, 5], 3, 2);
      expect(middle[2], closeTo(2, 1e-9));
      final sd = 0.816496580927726;
      expect(upper[2], closeTo(2 + 2 * sd, 1e-6));
      expect(lower[2], closeTo(2 - 2 * sd, 1e-6));
    });
  });

  group('ATR', () {
    test('equals the constant true range', () {
      final candles = List.generate(10, (i) => c(i, 100, 101, 99, 100));
      final a = Indicators.atr(candles, 3);
      expect(a[2], closeTo(2, 1e-9));
      expect(a[9], closeTo(2, 1e-9));
    });

    test('accounts for gaps via true range', () {
      final candles = [
        c(0, 100, 101, 99, 100),
        c(1, 100, 106, 100, 105), // gap up: TR = max(6, |106-100|, |100-100|) = 6
      ];
      final a = Indicators.atr(candles, 1);
      expect(a[0], closeTo(2, 1e-9));
      expect(a[1], closeTo(6, 1e-9));
    });
  });

  group('MACD', () {
    test('histogram equals line minus signal wherever both are defined', () {
      final prices = List<double>.generate(80, (i) => 100 + 10 * math.sin(i / 20) + i * 0.1);
      final (line, signal, hist) = Indicators.macd(prices, 12, 26, 9);
      var checked = 0;
      for (var i = 0; i < prices.length; i++) {
        if (line[i] != null && signal[i] != null && hist[i] != null) {
          expect(hist[i], closeTo(line[i]! - signal[i]!, 1e-9));
          checked++;
        }
      }
      expect(checked, greaterThan(10));
    });
  });

  group('computeSeries', () {
    test('maps a SeriesRef to an aligned series', () {
      final candles = List.generate(30, (i) => c(i, 100, 101, 99, 100 + i.toDouble()));
      final series = Indicators.computeSeries(const SeriesRef(IndicatorType.sma, period: 5), candles);
      expect(series.length, 30);
      expect(series[3], isNull);
      expect(series[4], isNotNull);
    });
  });
}
