import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/data/models/backtest_config.dart';
import 'package:quant_rd/data/models/candle.dart';
import 'package:quant_rd/data/models/strategy_spec.dart';
import 'package:quant_rd/data/models/trade.dart';
import 'package:quant_rd/domain/engine/backtest_engine.dart';

Candle c(int i, double o, double h, double l, double cl, [double v = 100]) => Candle(
      time: DateTime.utc(2020, 1, 1).add(Duration(days: i)),
      open: o,
      high: h,
      low: l,
      close: cl,
      volume: v,
    );

StrategySpec alwaysEnter({double sl = 0, double tp = 0, PositionSizing sizing = PositionSizing.allIn, double sizingValue = 100}) => StrategySpec(
      id: 't',
      name: 'always',
      entry: [
        const Condition(
          left: Operand.series(SeriesRef(IndicatorType.close)),
          op: ComparisonOp.greaterThan,
          right: Operand.constant(0),
        ),
      ],
      exit: const [],
      stopLossPct: sl,
      takeProfitPct: tp,
      sizing: sizing,
      sizingValue: sizingValue,
      updatedAt: DateTime.utc(2024),
    );

StrategySpec crossAbove(double level) => StrategySpec(
      id: 'x',
      name: 'cross',
      entry: [
        Condition(
          left: const Operand.series(SeriesRef(IndicatorType.close)),
          op: ComparisonOp.crossesAbove,
          right: Operand.constant(level),
        ),
      ],
      exit: const [],
      sizing: PositionSizing.allIn,
      updatedAt: DateTime.utc(2024),
    );

void main() {
  final rising = [
    c(0, 100, 100, 100, 100),
    c(1, 100, 100, 100, 100),
    c(2, 100, 150, 100, 150),
    c(3, 150, 150, 150, 150),
  ];

  test('buy & hold with zero costs returns the price change', () {
    final r = BacktestEngine.run(
      resultId: 'r1',
      candles: rising,
      strategy: alwaysEnter(),
      config: const BacktestConfig(initialCapital: 100000, feeBps: 0, slippageBps: 0),
      datasetId: 'd',
      symbol: 'T',
    );
    expect(r.trades.length, 1);
    expect(r.metrics.finalEquity, closeTo(150000, 1e-6));
    expect(r.metrics.totalReturnPct, closeTo(50, 1e-6));
    expect(r.metrics.buyHoldReturnPct, closeTo(50, 1e-6));
  });

  test('fees reduce the realised equity', () {
    final r = BacktestEngine.run(
      resultId: 'r2',
      candles: rising,
      strategy: alwaysEnter(),
      config: const BacktestConfig(initialCapital: 100000, feeBps: 100, slippageBps: 0),
      datasetId: 'd',
      symbol: 'T',
    );
    // entry fee 1000, exit notional 150000 fee 1500 -> 150000 - 2500 = 147500
    expect(r.metrics.finalEquity, closeTo(147500, 1e-6));
    expect(r.metrics.totalReturnPct, closeTo(47.5, 1e-6));
    expect(r.metrics.totalFees, closeTo(2500, 1e-6));
  });

  test('percent-of-equity sizing scales the position', () {
    final r = BacktestEngine.run(
      resultId: 'r3',
      candles: rising,
      strategy: alwaysEnter(sizing: PositionSizing.percentOfEquity, sizingValue: 50),
      config: const BacktestConfig(initialCapital: 100000, feeBps: 0, slippageBps: 0),
      datasetId: 'd',
      symbol: 'T',
    );
    // half the capital grows 100 -> 150: 50000 + 500*150 = 125000
    expect(r.metrics.finalEquity, closeTo(125000, 1e-6));
    expect(r.metrics.totalReturnPct, closeTo(25, 1e-6));
  });

  test('a signal on the final bar does not open a trade (no look-ahead)', () {
    final candles = [
      c(0, 100, 100, 100, 100),
      c(1, 100, 100, 100, 100),
      c(2, 250, 250, 250, 250),
    ];
    final r = BacktestEngine.run(
      resultId: 'r4',
      candles: candles,
      strategy: crossAbove(200),
      config: const BacktestConfig(initialCapital: 100000, feeBps: 0, slippageBps: 0),
      datasetId: 'd',
      symbol: 'T',
    );
    expect(r.trades, isEmpty);
    expect(r.metrics.totalReturnPct, closeTo(0, 1e-9));
  });

  test('stop-loss closes the position at the trigger price', () {
    final candles = [
      c(0, 100, 100, 100, 100),
      c(1, 100, 100, 100, 100),
      c(2, 100, 100, 80, 85), // dips to 80, stop at 90
    ];
    final r = BacktestEngine.run(
      resultId: 'r5',
      candles: candles,
      strategy: alwaysEnter(sl: 10),
      config: const BacktestConfig(initialCapital: 100000, feeBps: 0, slippageBps: 0),
      datasetId: 'd',
      symbol: 'T',
    );
    expect(r.trades.length, 1);
    expect(r.trades.first.exitReason, ExitReason.stopLoss);
    expect(r.trades.first.exitPrice, closeTo(90, 1e-9));
  });

  test('take-profit closes the position at the trigger price', () {
    final candles = [
      c(0, 100, 100, 100, 100),
      c(1, 100, 100, 100, 100),
      c(2, 100, 130, 100, 120), // spikes to 130, TP at 120
    ];
    final r = BacktestEngine.run(
      resultId: 'r6',
      candles: candles,
      strategy: alwaysEnter(tp: 20),
      config: const BacktestConfig(initialCapital: 100000, feeBps: 0, slippageBps: 0),
      datasetId: 'd',
      symbol: 'T',
    );
    expect(r.trades.length, 1);
    expect(r.trades.first.exitReason, ExitReason.takeProfit);
    expect(r.trades.first.exitPrice, closeTo(120, 1e-9));
  });

  test('too few candles yields an empty, safe result', () {
    final r = BacktestEngine.run(
      resultId: 'r7',
      candles: [c(0, 100, 100, 100, 100)],
      strategy: alwaysEnter(),
      config: const BacktestConfig(),
      datasetId: 'd',
      symbol: 'T',
    );
    expect(r.trades, isEmpty);
    expect(r.equityCurve, isEmpty);
  });
}
