/// Risk & performance metrics computed from an equity curve and trade log.
///
/// All formulas are standard and documented inline. Returns are computed on the
/// per-bar equity series; annualisation uses the configured [barsPerYear].
library;

import 'dart:math' as math;

import '../../data/models/backtest_config.dart';
import '../../data/models/trade.dart';

class Metrics {
  final double initialCapital;
  final double finalEquity;
  final double netProfit;
  final double totalReturnPct;
  final double cagrPct;
  final double volatilityPct;
  final double sharpe;
  final double sortino;
  final double maxDrawdownPct;
  final int maxDrawdownBars;
  final double calmar;
  final int tradeCount;
  final double winRatePct;
  final double profitFactor;
  final double expectancy;
  final double avgWin;
  final double avgLoss;
  final double exposurePct;
  final double bestTradePct;
  final double worstTradePct;
  final double totalFees;
  final double buyHoldReturnPct;

  const Metrics({
    required this.initialCapital,
    required this.finalEquity,
    required this.netProfit,
    required this.totalReturnPct,
    required this.cagrPct,
    required this.volatilityPct,
    required this.sharpe,
    required this.sortino,
    required this.maxDrawdownPct,
    required this.maxDrawdownBars,
    required this.calmar,
    required this.tradeCount,
    required this.winRatePct,
    required this.profitFactor,
    required this.expectancy,
    required this.avgWin,
    required this.avgLoss,
    required this.exposurePct,
    required this.bestTradePct,
    required this.worstTradePct,
    required this.totalFees,
    required this.buyHoldReturnPct,
  });

  static const Metrics empty = Metrics(
    initialCapital: 0,
    finalEquity: 0,
    netProfit: 0,
    totalReturnPct: 0,
    cagrPct: 0,
    volatilityPct: 0,
    sharpe: 0,
    sortino: 0,
    maxDrawdownPct: 0,
    maxDrawdownBars: 0,
    calmar: 0,
    tradeCount: 0,
    winRatePct: 0,
    profitFactor: 0,
    expectancy: 0,
    avgWin: 0,
    avgLoss: 0,
    exposurePct: 0,
    bestTradePct: 0,
    worstTradePct: 0,
    totalFees: 0,
    buyHoldReturnPct: 0,
  );

  Map<String, dynamic> toMap() => {
        'initial_capital': initialCapital,
        'final_equity': finalEquity,
        'net_profit': netProfit,
        'total_return_pct': totalReturnPct,
        'cagr_pct': cagrPct,
        'volatility_pct': volatilityPct,
        'sharpe': sharpe,
        'sortino': sortino,
        'max_dd_pct': maxDrawdownPct,
        'max_dd_bars': maxDrawdownBars,
        'calmar': calmar,
        'trade_count': tradeCount,
        'win_rate_pct': winRatePct,
        'profit_factor': profitFactor,
        'expectancy': expectancy,
        'avg_win': avgWin,
        'avg_loss': avgLoss,
        'exposure_pct': exposurePct,
        'best_trade_pct': bestTradePct,
        'worst_trade_pct': worstTradePct,
        'total_fees': totalFees,
        'buy_hold_return_pct': buyHoldReturnPct,
      };

  factory Metrics.fromMap(Map<String, dynamic> m) => Metrics(
        initialCapital: (m['initial_capital'] as num).toDouble(),
        finalEquity: (m['final_equity'] as num).toDouble(),
        netProfit: (m['net_profit'] as num).toDouble(),
        totalReturnPct: (m['total_return_pct'] as num).toDouble(),
        cagrPct: (m['cagr_pct'] as num).toDouble(),
        volatilityPct: (m['volatility_pct'] as num).toDouble(),
        sharpe: (m['sharpe'] as num).toDouble(),
        sortino: (m['sortino'] as num).toDouble(),
        maxDrawdownPct: (m['max_dd_pct'] as num).toDouble(),
        maxDrawdownBars: (m['max_dd_bars'] as num).toInt(),
        calmar: (m['calmar'] as num).toDouble(),
        tradeCount: (m['trade_count'] as num).toInt(),
        winRatePct: (m['win_rate_pct'] as num).toDouble(),
        profitFactor: (m['profit_factor'] as num).toDouble(),
        expectancy: (m['expectancy'] as num).toDouble(),
        avgWin: (m['avg_win'] as num).toDouble(),
        avgLoss: (m['avg_loss'] as num).toDouble(),
        exposurePct: (m['exposure_pct'] as num).toDouble(),
        bestTradePct: (m['best_trade_pct'] as num).toDouble(),
        worstTradePct: (m['worst_trade_pct'] as num).toDouble(),
        totalFees: (m['total_fees'] as num).toDouble(),
        buyHoldReturnPct: (m['buy_hold_return_pct'] as num).toDouble(),
      );

  /// Computes all metrics. [equity] must be the mark-to-market equity at each
  /// bar close; [exposedBars] counts bars holding a position; [buyHold] is the
  /// buy-and-hold return percentage over the same window for comparison.
  static Metrics compute({
    required BacktestConfig config,
    required List<double> equity,
    required List<DateTime> times,
    required List<Trade> trades,
    required int exposedBars,
    required double buyHoldReturnPct,
  }) {
    final initial = config.initialCapital;
    if (equity.isEmpty) {
      return Metrics.empty;
    }
    final finalEquity = equity.last;
    final netProfit = finalEquity - initial;
    final totalReturnPct = initial == 0 ? 0.0 : (finalEquity / initial - 1) * 100;

    // Per-bar simple returns.
    final returns = <double>[];
    for (var i = 1; i < equity.length; i++) {
      final prev = equity[i - 1];
      if (prev == 0) {
        returns.add(0);
      } else {
        returns.add(equity[i] / prev - 1);
      }
    }

    final barsPerYear = config.barsPerYear;
    final nBars = equity.length;

    // CAGR using elapsed calendar time when available, else bar count.
    double cagr = 0;
    if (nBars > 1 && initial > 0 && finalEquity > 0) {
      final years = _yearsBetween(times.first, times.last, nBars, barsPerYear);
      if (years > 0) {
        cagr = (math.pow(finalEquity / initial, 1 / years) - 1) * 100;
      }
    }

    final meanRet = returns.isEmpty ? 0.0 : returns.reduce((a, b) => a + b) / returns.length;
    final variance = returns.isEmpty
        ? 0.0
        : returns.map((r) => (r - meanRet) * (r - meanRet)).reduce((a, b) => a + b) / returns.length;
    final stdRet = math.sqrt(variance);
    final volatilityPct = stdRet * math.sqrt(barsPerYear) * 100;

    final rfPerBar = config.riskFreeRatePct / 100 / barsPerYear;
    final excess = returns.map((r) => r - rfPerBar).toList();
    final meanExcess = excess.isEmpty ? 0.0 : excess.reduce((a, b) => a + b) / excess.length;
    final sharpe = stdRet == 0 ? 0.0 : (meanExcess / stdRet) * math.sqrt(barsPerYear);

    // Sortino: downside deviation only.
    final downside = excess.where((r) => r < 0).toList();
    final downsideVar = downside.isEmpty
        ? 0.0
        : downside.map((r) => r * r).reduce((a, b) => a + b) / downside.length;
    final downsideStd = math.sqrt(downsideVar);
    final sortino = downsideStd == 0 ? 0.0 : (meanExcess / downsideStd) * math.sqrt(barsPerYear);

    // Max drawdown and its duration.
    double peak = equity.first;
    double maxDd = 0;
    int ddStart = 0;
    int maxDdBars = 0;
    for (var i = 0; i < equity.length; i++) {
      if (equity[i] > peak) {
        peak = equity[i];
        ddStart = i;
      }
      final dd = peak == 0 ? 0.0 : (peak - equity[i]) / peak;
      if (dd > maxDd) {
        maxDd = dd;
        maxDdBars = i - ddStart;
      }
    }
    final maxDrawdownPct = maxDd * 100;
    final calmar = maxDrawdownPct == 0 ? 0.0 : cagr / maxDrawdownPct;

    // Trade statistics.
    final wins = trades.where((t) => t.pnl > 0).toList();
    final losses = trades.where((t) => t.pnl <= 0).toList();
    final grossProfit = wins.fold<double>(0, (a, t) => a + t.pnl);
    final grossLoss = losses.fold<double>(0, (a, t) => a + t.pnl.abs());
    final winRate = trades.isEmpty ? 0.0 : wins.length / trades.length * 100;
    final profitFactor = grossLoss == 0 ? (grossProfit > 0 ? double.infinity : 0.0) : grossProfit / grossLoss;
    final avgWin = wins.isEmpty ? 0.0 : grossProfit / wins.length;
    final avgLoss = losses.isEmpty ? 0.0 : -grossLoss / losses.length;
    final expectancy = trades.isEmpty
        ? 0.0
        : trades.fold<double>(0, (a, t) => a + t.pnl) / trades.length;
    final bestTradePct = trades.isEmpty ? 0.0 : trades.map((t) => t.pnlPct).reduce(math.max);
    final worstTradePct = trades.isEmpty ? 0.0 : trades.map((t) => t.pnlPct).reduce(math.min);
    final totalFees = trades.fold<double>(0, (a, t) => a + t.fees);
    final exposure = nBars == 0 ? 0.0 : exposedBars / nBars * 100;

    return Metrics(
      initialCapital: initial,
      finalEquity: finalEquity,
      netProfit: netProfit,
      totalReturnPct: totalReturnPct,
      cagrPct: cagr,
      volatilityPct: volatilityPct,
      sharpe: sharpe.isFinite ? sharpe : 0,
      sortino: sortino.isFinite ? sortino : 0,
      maxDrawdownPct: maxDrawdownPct,
      maxDrawdownBars: maxDdBars,
      calmar: calmar.isFinite ? calmar : 0,
      tradeCount: trades.length,
      winRatePct: winRate,
      profitFactor: profitFactor.isFinite ? profitFactor : 0,
      expectancy: expectancy,
      avgWin: avgWin,
      avgLoss: avgLoss,
      exposurePct: exposure,
      bestTradePct: bestTradePct,
      worstTradePct: worstTradePct,
      totalFees: totalFees,
      buyHoldReturnPct: buyHoldReturnPct,
    );
  }

  static double _yearsBetween(DateTime a, DateTime b, int nBars, int barsPerYear) {
    final days = b.difference(a).inSeconds / 86400;
    if (days > 30) return days / 365.25;
    return nBars / barsPerYear;
  }
}
