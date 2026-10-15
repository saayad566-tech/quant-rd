/// Options mechanics: Black-Scholes pricing, the Greeks, and dealer gamma
/// exposure.
///
/// This is a real calculator. It needs an options chain — strikes, open
/// interest and implied volatilities — which this build has no live feed for,
/// so the app drives it from data you supply rather than pretending to stream a
/// chain it cannot see.
library;

import 'dart:math' as math;

class OptionGreeks {
  final double price;
  final double delta;
  final double gamma;
  final double theta;
  final double vega;
  final double rho;

  const OptionGreeks({
    required this.price,
    required this.delta,
    required this.gamma,
    required this.theta,
    required this.vega,
    required this.rho,
  });
}

class QuantOptions {
  const QuantOptions._();

  /// Standard normal probability density.
  static double _pdf(double x) => math.exp(-0.5 * x * x) / math.sqrt(2 * math.pi);

  /// Standard normal cumulative distribution, via the Abramowitz-Stegun
  /// approximation of the error function (absolute error under 1.5e-7).
  static double _cdf(double x) => 0.5 * (1 + _erf(x / math.sqrt2));

  static double _erf(double x) {
    final sign = x < 0 ? -1.0 : 1.0;
    final ax = x.abs();
    const a1 = 0.254829592;
    const a2 = -0.284496736;
    const a3 = 1.421413741;
    const a4 = -1.453152027;
    const a5 = 1.061405429;
    const p = 0.3275911;
    final t = 1.0 / (1.0 + p * ax);
    final y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * math.exp(-ax * ax);
    return sign * y;
  }

  /// Black-Scholes price and Greeks.
  ///
  /// [timeToExpiry] is in years, [volatility] is annualised (0.2 = 20%),
  /// [rate] is the continuously compounded risk-free rate. At or past expiry the
  /// intrinsic value is returned with degenerate Greeks, which is the correct
  /// limit rather than a division by zero.
  static OptionGreeks blackScholes({
    required double spot,
    required double strike,
    required double timeToExpiry,
    required double volatility,
    required double rate,
    required bool isCall,
  }) {
    if (timeToExpiry <= 0 || volatility <= 0) {
      final intrinsic = isCall ? math.max(0.0, spot - strike) : math.max(0.0, strike - spot);
      final delta = isCall ? (spot > strike ? 1.0 : 0.0) : (spot < strike ? -1.0 : 0.0);
      return OptionGreeks(price: intrinsic, delta: delta, gamma: 0, theta: 0, vega: 0, rho: 0);
    }

    final sqrtT = math.sqrt(timeToExpiry);
    final d1 = (math.log(spot / strike) + (rate + volatility * volatility / 2) * timeToExpiry) / (volatility * sqrtT);
    final d2 = d1 - volatility * sqrtT;
    final discount = math.exp(-rate * timeToExpiry);

    final nd1 = _cdf(d1);
    final nd2 = _cdf(d2);
    final pdfd1 = _pdf(d1);

    final price = isCall ? spot * nd1 - strike * discount * nd2 : strike * discount * _cdf(-d2) - spot * _cdf(-d1);
    final delta = isCall ? nd1 : nd1 - 1;
    final gamma = pdfd1 / (spot * volatility * sqrtT);
    final vega = spot * pdfd1 * sqrtT / 100; // per 1% change in volatility
    final theta = isCall
        ? (-(spot * pdfd1 * volatility) / (2 * sqrtT) - rate * strike * discount * nd2) / 365
        : (-(spot * pdfd1 * volatility) / (2 * sqrtT) + rate * strike * discount * _cdf(-d2)) / 365;
    final rho = isCall ? strike * timeToExpiry * discount * nd2 / 100 : -strike * timeToExpiry * discount * _cdf(-d2) / 100;

    return OptionGreeks(price: price, delta: delta, gamma: gamma, theta: theta, vega: vega, rho: rho);
  }

  /// Implied volatility by bisection on the Black-Scholes price. Returns null
  /// when the market price sits outside the no-arbitrage bounds, rather than
  /// returning a fabricated number.
  static double? impliedVolatility({
    required double marketPrice,
    required double spot,
    required double strike,
    required double timeToExpiry,
    required double rate,
    required bool isCall,
    double tolerance = 1e-6,
    int maxIterations = 100,
  }) {
    if (timeToExpiry <= 0) return null;
    final discount = math.exp(-rate * timeToExpiry);
    final lowerBound = isCall ? math.max(0.0, spot - strike * discount) : math.max(0.0, strike * discount - spot);
    final upperBound = isCall ? spot : strike * discount;
    if (marketPrice < lowerBound || marketPrice > upperBound) return null;

    var lo = 0.0001, hi = 5.0;
    for (var i = 0; i < maxIterations; i++) {
      final mid = (lo + hi) / 2;
      final p = blackScholes(spot: spot, strike: strike, timeToExpiry: timeToExpiry, volatility: mid, rate: rate, isCall: isCall).price;
      if ((p - marketPrice).abs() < tolerance) return mid;
      if (p > marketPrice) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return (lo + hi) / 2;
  }
}

// ---------------------------------------------------------------------------
// Dealer gamma exposure
// ---------------------------------------------------------------------------

class OptionQuote {
  final double strike;
  final double openInterest;
  final double impliedVolatility;
  final bool isCall;

  /// Whether dealers are assumed long this contract. Market makers are
  /// conventionally assumed long calls and short puts; that assumption is passed
  /// in explicitly rather than buried.
  final bool dealerLong;

  const OptionQuote({
    required this.strike,
    required this.openInterest,
    required this.impliedVolatility,
    required this.isCall,
    required this.dealerLong,
  });
}

class GexResult {
  final double totalGex;

  /// Gamma exposure by strike, in currency per 1% move.
  final Map<double, double> gexByStrike;

  /// The strike carrying the largest positive exposure — the level price is
  /// most likely to be pinned toward.
  final double? gammaWall;

  /// The spot level where cumulative dealer gamma crosses zero. Above it,
  /// hedging dampens moves; below it, hedging can amplify them.
  final double? gammaFlipLevel;

  const GexResult({
    required this.totalGex,
    required this.gexByStrike,
    required this.gammaWall,
    required this.gammaFlipLevel,
  });

  bool get isPositiveGamma => totalGex >= 0;
}

class QuantGex {
  const QuantGex._();

  /// Dealer gamma exposure per strike:
  ///   GEX = gamma x openInterest x 100 x spot^2 x 0.01 x sign
  /// summed across the chain. The 0.01 expresses the result per 1% move.
  static GexResult compute({
    required double spot,
    required List<OptionQuote> chain,
    required double timeToExpiry,
    required double rate,
    double contractMultiplier = 100,
  }) {
    final byStrike = <double, double>{};
    var total = 0.0;

    for (final q in chain) {
      final greeks = QuantOptions.blackScholes(
        spot: spot,
        strike: q.strike,
        timeToExpiry: timeToExpiry,
        volatility: q.impliedVolatility,
        rate: rate,
        isCall: q.isCall,
      );
      final sign = q.dealerLong ? 1.0 : -1.0;
      final gex = greeks.gamma * q.openInterest * contractMultiplier * spot * spot * 0.01 * sign;
      byStrike.update(q.strike, (v) => v + gex, ifAbsent: () => gex);
      total += gex;
    }

    double? wall;
    var wallGex = double.negativeInfinity;
    for (final e in byStrike.entries) {
      if (e.value > wallGex) {
        wallGex = e.value;
        wall = e.key;
      }
    }

    // The gamma flip: scan spot levels and find where cumulative exposure
    // changes sign, which is where hedging behaviour inverts.
    double? flip;
    final strikes = byStrike.keys.toList()..sort();
    if (strikes.length >= 2) {
      var prevCum = 0.0;
      for (var i = 0; i < strikes.length; i++) {
        var cum = 0.0;
        for (final s in strikes) {
          final greeks = _totalGammaAt(s, chain, spot, timeToExpiry, rate);
          cum += greeks;
        }
        if (i > 0 && ((prevCum < 0 && cum >= 0) || (prevCum >= 0 && cum < 0))) {
          flip = strikes[i];
          break;
        }
        prevCum = cum;
      }
    }

    return GexResult(totalGex: total, gexByStrike: byStrike, gammaWall: wall, gammaFlipLevel: flip);
  }

  static double _totalGammaAt(double level, List<OptionQuote> chain, double spot, double t, double rate) {
    var sum = 0.0;
    for (final q in chain) {
      final g = QuantOptions.blackScholes(
        spot: level,
        strike: q.strike,
        timeToExpiry: t,
        volatility: q.impliedVolatility,
        rate: rate,
        isCall: q.isCall,
      ).gamma;
      sum += g * q.openInterest * (q.dealerLong ? 1 : -1);
    }
    return sum;
  }
}
