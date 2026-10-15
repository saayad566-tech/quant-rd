import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/data/models/backtest_config.dart';
import 'package:quant_rd/data/models/candle.dart';
import 'package:quant_rd/data/models/strategy_spec.dart';
import 'package:quant_rd/domain/engine/backtest_engine.dart';

Candle c(int i, double o, double h, double l, double cl) => Candle(
      time: DateTime.utc(2020, 1, 1).add(Duration(days: i)),
      open: o,
      high: h,
      low: l,
      close: cl,
      volume: 100,
    );

StrategySpec alwaysEnter() => StrategySpec(
      id: 't',
      name: 'always',
      entry: [
        const Condition(
          left: Operand.series(SeriesRef(IndicatorType.close)),
          op: ComparisonOp.greaterThan,
          right: Operand.constant(0),
        ),
      ],
      sizing: PositionSizing.allIn,
      updatedAt: DateTime.utc(2024),
    );

void main() {
  final candles = [
    c(0, 100, 100, 100, 100),
    c(1, 100, 100, 100, 100),
    c(2, 100, 150, 100, 150),
    c(3, 150, 150, 150, 150),
  ];

  test('slippage worsens both the entry and the exit fill', () {
    final r = BacktestEngine.run(
      resultId: 'slip',
      candles: candles,
      strategy: alwaysEnter(),
      config: const BacktestConfig(initialCapital: 100000, feeBps: 0, slippageBps: 100),
      datasetId: 'd',
      symbol: 'T',
    );
    // Entry at 100 * 1.01 = 101, exit at 150 * 0.99 = 148.5.
    // qty = 100000/101 = 990.099; final = 990.099 * 148.5 = 147029.70
    expect(r.trades.single.entryPrice, closeTo(101, 1e-9));
    expect(r.trades.single.exitPrice, closeTo(148.5, 1e-9));
    expect(r.metrics.finalEquity, closeTo(147029.70, 0.5));
  });

  test('slippage reduces the return versus a frictionless run', () {
    final clean = BacktestEngine.run(
      resultId: 'a',
      candles: candles,
      strategy: alwaysEnter(),
      config: const BacktestConfig(initialCapital: 100000, feeBps: 0, slippageBps: 0),
      datasetId: 'd',
      symbol: 'T',
    );
    final slipped = BacktestEngine.run(
      resultId: 'b',
      candles: candles,
      strategy: alwaysEnter(),
      config: const BacktestConfig(initialCapital: 100000, feeBps: 0, slippageBps: 50),
      datasetId: 'd',
      symbol: 'T',
    );
    expect(slipped.metrics.totalReturnPct, lessThan(clean.metrics.totalReturnPct));
    expect(clean.metrics.totalReturnPct, closeTo(50, 1e-6));
  });

  test('fees and slippage stack on both sides', () {
    final r = BacktestEngine.run(
      resultId: 'both',
      candles: candles,
      strategy: alwaysEnter(),
      config: const BacktestConfig(initialCapital: 100000, feeBps: 50, slippageBps: 50),
      datasetId: 'd',
      symbol: 'T',
    );
    // Worse than either cost alone.
    final feesOnly = BacktestEngine.run(
      resultId: 'f',
      candles: candles,
      strategy: alwaysEnter(),
      config: const BacktestConfig(initialCapital: 100000, feeBps: 50, slippageBps: 0),
      datasetId: 'd',
      symbol: 'T',
    );
    expect(r.metrics.finalEquity, lessThan(feesOnly.metrics.finalEquity));
  });
}
