import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/data/models/candle.dart';
import 'package:quant_rd/domain/quant/quant_mechanics.dart';
import 'package:quant_rd/domain/quant/quant_options.dart';
import 'package:quant_rd/domain/quant/quant_risk.dart';

/// Deterministic pseudo-random so every statistical test is reproducible.
class Lcg {
  int _s;
  Lcg(this._s);
  double next() {
    _s = (_s * 1103515245 + 12345) & 0x7fffffff;
    return _s / 0x7fffffff;
  }
}

Candle bar(int i, double o, double h, double l, double c, [double v = 1000]) => Candle(
      time: DateTime.utc(2020, 1, 1).add(Duration(days: i)),
      open: o,
      high: h,
      low: l,
      close: c,
      volume: v,
    );

List<Candle> line(int n, double start, double step, {double volume = 1000}) => List.generate(n, (i) {
      final p = start + step * i;
      return bar(i, p, p + 0.5, p - 0.5, p, volume);
    });

void main() {
  group('pivots', () {
    test('finds a clean swing high and low', () {
      final candles = [
        bar(0, 10, 11, 9, 10),
        bar(1, 10, 12, 9.5, 11),
        bar(2, 11, 15, 10.5, 12), // swing high
        bar(3, 12, 13, 11, 12),
        bar(4, 12, 12.5, 11.5, 12),
        bar(5, 12, 12.5, 8, 9), // swing low
        bar(6, 9, 10, 9, 9.5),
        bar(7, 9.5, 10.5, 9.4, 10),
      ];
      final pv = QuantMechanics.pivots(candles, n: 2);
      expect(pv.any((p) => p.isHigh && p.index == 2), isTrue);
      expect(pv.any((p) => !p.isHigh && p.index == 5), isTrue);
    });
  });

  group('trendline', () {
    test('a perfect line has an R-squared of 1', () {
      final candles = line(12, 100, 1);
      final pv = List.generate(10, (i) => Pivot(index: i, price: 100 + i.toDouble(), isHigh: true, time: candles[i].time));
      final t = QuantMechanics.fitTrendline(candles, pv, touchTolerance: 0.001);
      expect(t.slope, closeTo(1.0, 1e-9));
      expect(t.r2, closeTo(1.0, 1e-9));
      expect(t.valueAt(5), closeTo(105, 1e-9));
    });

    test('a line is valid only with enough touches', () {
      final candles = line(12, 100, 1);
      final pv = [Pivot(index: 0, price: 100, isHigh: true, time: candles[0].time)];
      final t = QuantMechanics.fitTrendline(candles, pv);
      expect(t.isValid, isFalse);
    });
  });

  group('fibonacci', () {
    test('retracement levels are exact', () {
      final f = QuantMechanics.fibonacci(100, 200);
      expect(f['23.6%'], closeTo(200 - 100 * 0.236, 1e-9));
      expect(f['61.8%'], closeTo(138.2, 1e-9));
      expect(f['100.0%'], closeTo(100, 1e-9));
      expect(f['161.8%'], closeTo(200 - 100 * 1.618, 1e-9));
    });
  });

  group('vwap', () {
    test('matches a hand-computed two-bar example', () {
      final candles = [
        bar(0, 9, 10, 8, 9, 100), // typical 9
        bar(1, 11, 12, 10, 11, 300), // typical 11
      ];
      final v = QuantMechanics.vwap(candles);
      expect(v[0], closeTo(9.0, 1e-9));
      expect(v[1], closeTo((9 * 100 + 11 * 300) / 400, 1e-9));
    });

    test('anchored vwap restarts at the anchor', () {
      final candles = [
        bar(0, 9, 10, 8, 9, 100),
        bar(1, 11, 12, 10, 11, 300),
        bar(2, 20, 21, 19, 20, 100), // typical 20
      ];
      final a = QuantMechanics.anchoredVwap(candles, 2);
      expect(a[0], isNull);
      expect(a[2], closeTo(20.0, 1e-9));
    });
  });

  group('volume profile', () {
    test('the point of control sits where volume concentrated', () {
      final candles = <Candle>[];
      // 30 bars clustered tightly around 100, then 5 bars up at 120.
      for (var i = 0; i < 30; i++) {
        candles.add(bar(i, 100, 100.5, 99.5, 100, 1000));
      }
      for (var i = 30; i < 35; i++) {
        candles.add(bar(i, 120, 120.5, 119.5, 120, 100));
      }
      final p = QuantMechanics.volumeProfile(candles, bins: 20);
      expect(p.poc, closeTo(100, 1.5));
      expect(p.vah, greaterThanOrEqualTo(p.poc));
      expect(p.val, lessThanOrEqualTo(p.poc));
      expect(p.totalVolume, greaterThan(0));
    });
  });

  group('obv and delta', () {
    test('obv adds on up-closes and subtracts on down-closes', () {
      final candles = [
        bar(0, 10, 11, 9, 10, 100),
        bar(1, 10, 12, 9, 11, 200), // up
        bar(2, 11, 12, 9, 10, 300), // down
      ];
      final o = QuantMechanics.obv(candles);
      expect(o[0], 0);
      expect(o[1], 200);
      expect(o[2], -100);
    });

    test('the delta proxy is bounded by the bar volume and labelled a proxy', () {
      final candles = [bar(0, 10, 11, 9, 11, 100)]; // close at the high => all buying
      final d = QuantMechanics.deltaProxy(candles);
      expect(d[0], closeTo(100, 1e-9));
      final candles2 = [bar(0, 10, 11, 9, 9, 100)]; // close at the low => all selling
      expect(QuantMechanics.deltaProxy(candles2)[0], closeTo(-100, 1e-9));
    });
  });

  group('atr and channels', () {
    test('atr equals the constant true range when there are no gaps', () {
      final candles = line(30, 100, 1).map((c) => bar(c.time.difference(DateTime.utc(2020, 1, 1)).inDays, c.open, c.close + 1, c.close - 1, c.close)).toList();
      final a = QuantMechanics.atr(candles, period: 14);
      expect(a[13], closeTo(2.0, 1e-9));
      expect(a[29], closeTo(2.0, 1e-9));
    });

    test('bollinger bands bracket the middle line', () {
      final candles = line(60, 100, 0.5);
      final b = QuantMechanics.bollinger(candles, period: 20, multiple: 2);
      const i = 40;
      expect(b.upper[i]!, greaterThan(b.middle[i]!));
      expect(b.lower[i]!, lessThan(b.middle[i]!));
    });

    test('an atr channel is symmetric about the middle', () {
      final candles = line(60, 100, 0.5);
      final c = QuantMechanics.atrChannel(candles, period: 20, multiple: 2);
      const i = 40;
      expect(c.upper[i]! - c.middle[i]!, closeTo(c.middle[i]! - c.lower[i]!, 1e-9));
    });
  });

  group('patterns', () {
    test('detects a double bottom', () {
      final candles = <Candle>[
        bar(0, 100, 101, 99, 100),
        bar(1, 100, 101, 90, 95),
        bar(2, 95, 96, 89.5, 90), // low 1
        bar(3, 90, 96, 90, 95),
        bar(4, 95, 100, 94, 99),
        bar(5, 99, 105, 98, 99), // peak between
        bar(6, 99, 99.5, 90, 92),
        bar(7, 92, 93, 89.8, 90), // low 2 (within tolerance)
        bar(8, 90, 95, 90, 94),
        bar(9, 94, 96, 93, 95),
        bar(10, 95, 97, 94, 96),
        bar(11, 96, 98, 95, 97),
      ];
      final p = QuantMechanics.doubleTopsAndBottoms(candles, n: 2, tolerancePct: 3);
      expect(p.any((x) => x.name == 'Double bottom'), isTrue);
    });

    test('classifies a large gap as exhaustion', () {
      final candles = <Candle>[];
      for (var i = 0; i < 30; i++) {
        candles.add(bar(i, 100, 100.5, 99.5, 100));
      }
      candles.add(bar(30, 108, 109, 107, 108)); // gaps well above the prior high
      final g = QuantMechanics.gaps(candles);
      expect(g, isNotEmpty);
      expect(g.last.name, contains('gap'));
    });
  });

  group('regime', () {
    test('a steady rise with steady volatility reads as a bull, low-volatility regime', () {
      final candles = line(200, 100, 0.3);
      final r = QuantMechanics.regime(candles);
      expect(r, isNotNull);
      expect(r!.regime, MarketRegime.bullLowVol);
      expect(r.trendSlopePct, greaterThan(0));
    });

    test('a decline reads as a bear regime', () {
      final candles = line(200, 300, -0.4);
      final r = QuantMechanics.regime(candles);
      expect(r, isNotNull);
      expect(r!.regime, MarketRegime.bearHighVol);
    });
  });

  group('features', () {
    test('fractional differentiation with d=1 is the first difference', () {
      final xs = [1.0, 3.0, 6.0, 10.0, 15.0];
      final f = QuantMechanics.fractionalDifference(xs, 1.0);
      expect(f.length, 4);
      for (var i = 0; i < f.length; i++) {
        expect(f[i], closeTo(xs[i + 1] - xs[i], 1e-9));
      }
    });

    test('log returns are correct', () {
      final r = QuantMechanics.logReturns([100, 110]);
      expect(r.single, closeTo(math.log(1.1), 1e-9));
    });

    test('the triple barrier records the first barrier touched', () {
      final candles = <Candle>[];
      // Flat bars to establish ATR, then a bar that spikes up.
      for (var i = 0; i < 20; i++) {
        candles.add(bar(i, 100, 101, 99, 100));
      }
      candles.add(bar(20, 100, 130, 99, 129)); // big up move, hits take-profit
      final labels = QuantMechanics.tripleBarrier(candles, events: [19], takeProfitMultiple: 2, stopLossMultiple: 1, maxBars: 5);
      expect(labels.length, 1);
      expect(labels.single.label, 1);
    });
  });

  group('trailing stop (Section 5, exact ladder)', () {
    test('the stop ratchets through the specified steps', () {
      final ts = TrailingStop(entryPrice: 100);
      expect(ts.update(100).stopPrice, closeTo(90, 1e-9)); // initial -10% floor
      expect(ts.update(105).stopPrice, closeTo(90, 1e-9)); // below +10%
      expect(ts.update(110).stopPrice, closeTo(100, 1e-9)); // +10% -> break-even
      expect(ts.update(115).stopPrice, closeTo(105, 1e-9)); // +15% -> +5%
      expect(ts.update(120).stopPrice, closeTo(108, 1e-9)); // +20% -> 10% below the peak
      expect(ts.update(130).stopPrice, closeTo(117, 1e-9)); // peak 130 -> 90% of peak
      expect(ts.update(155).stopPrice, closeTo(150, 1e-9)); // +55% peak -> +50% stop
    });

    test('the stop never loosens', () {
      final ts = TrailingStop(entryPrice: 100);
      ts.update(150);
      final high = ts.update(150).stopPrice;
      final after = ts.update(120).stopPrice; // price falls; stop must hold
      expect(after, closeTo(high, 1e-9));
    });

    test('replay exits at the stop when price falls through it', () {
      final ts = TrailingStop(entryPrice: 100);
      final r = ts.replay([105, 110, 112, 95]);
      expect(r.exited, isTrue);
      expect(r.exitPrice, closeTo(100, 1e-9)); // the break-even stop set at +10%
    });

    test('the -10% floor protects an immediate adverse move', () {
      final ts = TrailingStop(entryPrice: 100);
      final r = ts.replay([100, 95, 89]);
      expect(r.exited, isTrue);
      // The stop fills at the stop level (the -10% floor), not at the close.
      expect(r.exitPrice, closeTo(90, 1e-9));
      expect(r.realisedGainPct, closeTo(-10, 1e-9));
    });
  });

  group('risk', () {
    test('kelly is zero without an edge and positive with one', () {
      expect(QuantRisk.kellyFraction(winRate: 0.3, payoffRatio: 1), 0);
      final f = QuantRisk.kellyFraction(winRate: 0.6, payoffRatio: 2);
      expect(f, closeTo((2 * 0.6 - 0.4) / 2, 1e-9));
    });

    test('expected value matches the definition', () {
      final ev = QuantRisk.expectedValue(winRate: 0.5, averageWin: 200, averageLoss: 100);
      expect(ev, closeTo(50, 1e-9));
    });

    test('max drawdown is measured peak to trough', () {
      expect(QuantRisk.maxDrawdownPct([100, 120, 60, 80]), closeTo(50, 1e-9));
    });

    test('position size respects the risk budget', () {
      final size = QuantRisk.positionSize(equity: 100000, riskPerTradePct: 1, entryPrice: 100, stopPrice: 95);
      expect(size, closeTo(200, 1e-9)); // 1000 risk / 5 per unit
    });

    test('position size returns zero rather than dividing by a zero stop', () {
      expect(QuantRisk.positionSize(equity: 100000, riskPerTradePct: 1, entryPrice: 100, stopPrice: 100), 0);
    });
  });

  group('statistics', () {
    test('a cointegrated pair is detected', () {
      final rnd = Lcg(42);
      final x = <double>[];
      var level = 100.0;
      for (var i = 0; i < 300; i++) {
        level += (rnd.next() - 0.5) * 2;
        x.add(level);
      }
      final y = [for (var i = 0; i < x.length; i++) 2 * x[i] + (rnd.next() - 0.5) * 0.5];
      final r = QuantStatistics.engleGranger(y, x);
      expect(r, isNotNull);
      expect(r!.hedgeRatio, closeTo(2.0, 0.2));
      expect(r.isCointegrated, isTrue);
    });

    test('two unrelated random walks are not cointegrated', () {
      final a = Lcg(7), b = Lcg(99);
      var la = 100.0, lb = 50.0;
      final x = <double>[], y = <double>[];
      for (var i = 0; i < 300; i++) {
        la += (a.next() - 0.5) * 2;
        lb += (b.next() - 0.5) * 2;
        x.add(la);
        y.add(lb);
      }
      final r = QuantStatistics.engleGranger(y, x);
      expect(r, isNotNull);
      expect(r!.isCointegrated, isFalse);
    });

    test('the kalman filter smooths a noisy series', () {
      final rnd = Lcg(3);
      final noisy = [for (var i = 0; i < 200; i++) 100 + (rnd.next() - 0.5) * 10];
      final smooth = QuantStatistics.kalman(noisy);
      expect(smooth.length, noisy.length);
      // The filtered series must vary less than the raw one.
      double sd(List<double> xs) {
        final m = xs.reduce((a, b) => a + b) / xs.length;
        return math.sqrt(xs.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / xs.length);
      }
      expect(sd(smooth.sublist(10)), lessThan(sd(noisy.sublist(10))));
    });

    test('the z-score is zero at the mean and signed away from it', () {
      final z = QuantStatistics.zScore([1, 2, 3, 4, 5, 100], window: 5);
      expect(z[5]!, greaterThan(0));
    });
  });

  group('options', () {
    test('black-scholes matches the standard reference value', () {
      final g = QuantOptions.blackScholes(spot: 100, strike: 100, timeToExpiry: 1, volatility: 0.2, rate: 0.05, isCall: true);
      expect(g.price, closeTo(10.45, 0.05));
      expect(g.delta, closeTo(0.6368, 0.01));
      expect(g.gamma, greaterThan(0));
      expect(g.vega, greaterThan(0));
    });

    test('put-call parity holds', () {
      final c = QuantOptions.blackScholes(spot: 100, strike: 100, timeToExpiry: 1, volatility: 0.2, rate: 0.05, isCall: true);
      final p = QuantOptions.blackScholes(spot: 100, strike: 100, timeToExpiry: 1, volatility: 0.2, rate: 0.05, isCall: false);
      final parity = 100 - 100 * math.exp(-0.05);
      expect(c.price - p.price, closeTo(parity, 0.02));
    });

    test('implied volatility inverts the price', () {
      final g = QuantOptions.blackScholes(spot: 100, strike: 105, timeToExpiry: 0.5, volatility: 0.35, rate: 0.04, isCall: true);
      final iv = QuantOptions.impliedVolatility(
        marketPrice: g.price,
        spot: 100,
        strike: 105,
        timeToExpiry: 0.5,
        rate: 0.04,
        isCall: true,
      );
      expect(iv, isNotNull);
      expect(iv!, closeTo(0.35, 0.005));
    });

    test('implied volatility refuses a price outside the no-arbitrage bounds', () {
      final iv = QuantOptions.impliedVolatility(marketPrice: 500, spot: 100, strike: 100, timeToExpiry: 1, rate: 0.05, isCall: true);
      expect(iv, isNull);
    });

    test('at expiry the price is intrinsic value', () {
      final g = QuantOptions.blackScholes(spot: 110, strike: 100, timeToExpiry: 0, volatility: 0.2, rate: 0.05, isCall: true);
      expect(g.price, closeTo(10, 1e-9));
      expect(g.delta, closeTo(1, 1e-9));
    });

    test('gamma exposure is positive for a long-gamma chain', () {
      final chain = [
        const OptionQuote(strike: 100, openInterest: 1000, impliedVolatility: 0.2, isCall: true, dealerLong: true),
        const OptionQuote(strike: 105, openInterest: 500, impliedVolatility: 0.2, isCall: true, dealerLong: true),
      ];
      final g = QuantGex.compute(spot: 100, chain: chain, timeToExpiry: 0.1, rate: 0.05);
      expect(g.totalGex, greaterThan(0));
      expect(g.isPositiveGamma, isTrue);
      expect(g.gammaWall, isNotNull);
    });
  });
}
