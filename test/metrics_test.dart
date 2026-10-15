import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/data/models/backtest_config.dart';
import 'package:quant_rd/data/models/trade.dart';
import 'package:quant_rd/domain/engine/metrics.dart';

Trade t(int id, double pnl, double pnlPct) => Trade(
      id: id,
      isLong: true,
      entryTime: DateTime.utc(2020, 1, 1),
      exitTime: DateTime.utc(2020, 1, 2),
      entryPrice: 100,
      exitPrice: 100 + pnl / 10,
      quantity: 10,
      pnl: pnl,
      pnlPct: pnlPct,
      fees: 0,
      equityAfter: 100 + pnl,
      exitReason: ExitReason.signal,
    );

void main() {
  final times = [
    DateTime.utc(2020, 1, 1),
    DateTime.utc(2020, 1, 2),
    DateTime.utc(2020, 1, 3),
    DateTime.utc(2020, 1, 4),
  ];

  test('total return and max drawdown', () {
    final m = Metrics.compute(
      config: const BacktestConfig(initialCapital: 100, barsPerYear: 252, riskFreeRatePct: 0),
      equity: [100, 120, 90, 110],
      times: times,
      trades: const [],
      exposedBars: 0,
      buyHoldReturnPct: 0,
    );
    expect(m.finalEquity, closeTo(110, 1e-9));
    expect(m.netProfit, closeTo(10, 1e-9));
    expect(m.totalReturnPct, closeTo(10, 1e-9));
    expect(m.maxDrawdownPct, closeTo(25, 1e-9)); // (120-90)/120
  });

  test('win rate, profit factor and expectancy from trades', () {
    final trades = [t(1, 200, 2), t(2, -100, -1), t(3, 300, 3)];
    final m = Metrics.compute(
      config: const BacktestConfig(initialCapital: 1000, barsPerYear: 252, riskFreeRatePct: 0),
      equity: const [1000, 1200, 1100, 1400],
      times: times,
      trades: trades,
      exposedBars: 3,
      buyHoldReturnPct: 5,
    );
    expect(m.tradeCount, 3);
    expect(m.winRatePct, closeTo(66.666, 0.01));
    expect(m.profitFactor, closeTo(5, 1e-9)); // 500 / 100
    expect(m.expectancy, closeTo(400 / 3, 1e-9));
    expect(m.avgWin, closeTo(250, 1e-9));
    expect(m.avgLoss, closeTo(-100, 1e-9));
    expect(m.bestTradePct, closeTo(3, 1e-9));
    expect(m.worstTradePct, closeTo(-1, 1e-9));
    expect(m.buyHoldReturnPct, closeTo(5, 1e-9));
  });

  test('empty equity yields the empty metric set', () {
    final m = Metrics.compute(
      config: const BacktestConfig(),
      equity: const [],
      times: const [],
      trades: const [],
      exposedBars: 0,
      buyHoldReturnPct: 0,
    );
    expect(m.tradeCount, 0);
    expect(m.totalReturnPct, 0);
  });
}
