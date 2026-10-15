/// Curated, ready-to-run strategies shipped with the app.
library;

import '../../data/models/strategy_spec.dart';

class BuiltInStrategies {
  const BuiltInStrategies._();

  static DateTime get _stamp => DateTime.utc(2024, 1, 1);

  static List<StrategySpec> all() => [
        buyAndHold(),
        smaCrossover(),
        emaCrossover(),
        rsiReversion(),
        macdTrend(),
        bollingerBreakout(),
      ];

  static StrategySpec buyAndHold() => StrategySpec(
        id: 'builtin.buy_hold',
        name: 'Buy & Hold',
        description: 'Benchmark: buys on the first bar and holds to the end.',
        isBuiltIn: true,
        entry: [
          const Condition(
            left: Operand.series(SeriesRef(IndicatorType.close)),
            op: ComparisonOp.greaterThan,
            right: Operand.constant(0),
          ),
        ],
        exit: const [],
        sizing: PositionSizing.allIn,
        updatedAt: _stamp,
      );

  static StrategySpec smaCrossover() => StrategySpec(
        id: 'builtin.sma_cross',
        frameworkId: 'weinstein-stage',
        name: 'SMA Crossover (50/200)',
        description: 'Classic golden/death cross trend follower.',
        isBuiltIn: true,
        entry: [
          const Condition(
            left: Operand.series(SeriesRef(IndicatorType.sma, period: 50)),
            op: ComparisonOp.crossesAbove,
            right: Operand.series(SeriesRef(IndicatorType.sma, period: 200)),
          ),
        ],
        exit: [
          const Condition(
            left: Operand.series(SeriesRef(IndicatorType.sma, period: 50)),
            op: ComparisonOp.crossesBelow,
            right: Operand.series(SeriesRef(IndicatorType.sma, period: 200)),
          ),
        ],
        sizing: PositionSizing.allIn,
        updatedAt: _stamp,
      );

  static StrategySpec emaCrossover() => StrategySpec(
        id: 'builtin.ema_cross',
        frameworkId: 'weinstein-stage',
        name: 'EMA Crossover (12/26)',
        description: 'Faster moving-average crossover for shorter horizons.',
        isBuiltIn: true,
        entry: [
          const Condition(
            left: Operand.series(SeriesRef(IndicatorType.ema, period: 12)),
            op: ComparisonOp.crossesAbove,
            right: Operand.series(SeriesRef(IndicatorType.ema, period: 26)),
          ),
        ],
        exit: [
          const Condition(
            left: Operand.series(SeriesRef(IndicatorType.ema, period: 12)),
            op: ComparisonOp.crossesBelow,
            right: Operand.series(SeriesRef(IndicatorType.ema, period: 26)),
          ),
        ],
        sizing: PositionSizing.allIn,
        updatedAt: _stamp,
      );

  static StrategySpec rsiReversion() => StrategySpec(
        id: 'builtin.rsi_reversion',
        frameworkId: 'wilder-rsi-atr',
        name: 'RSI Mean Reversion',
        description: 'Buys oversold (RSI < 30), exits overbought (RSI > 70).',
        isBuiltIn: true,
        entry: [
          const Condition(
            left: Operand.series(SeriesRef(IndicatorType.rsi, period: 14)),
            op: ComparisonOp.lessThan,
            right: Operand.constant(30),
          ),
        ],
        exit: [
          const Condition(
            left: Operand.series(SeriesRef(IndicatorType.rsi, period: 14)),
            op: ComparisonOp.greaterThan,
            right: Operand.constant(70),
          ),
        ],
        stopLossPct: 8,
        sizing: PositionSizing.allIn,
        updatedAt: _stamp,
      );

  static StrategySpec macdTrend() => StrategySpec(
        id: 'builtin.macd_trend',
        frameworkId: 'momentum-factor',
        name: 'MACD Trend',
        description: 'MACD line crossing its signal line.',
        isBuiltIn: true,
        entry: [
          const Condition(
            left: Operand.series(SeriesRef(IndicatorType.macdLine, period: 12, period2: 26, period3: 9)),
            op: ComparisonOp.crossesAbove,
            right: Operand.series(SeriesRef(IndicatorType.macdSignal, period: 12, period2: 26, period3: 9)),
          ),
        ],
        exit: [
          const Condition(
            left: Operand.series(SeriesRef(IndicatorType.macdLine, period: 12, period2: 26, period3: 9)),
            op: ComparisonOp.crossesBelow,
            right: Operand.series(SeriesRef(IndicatorType.macdSignal, period: 12, period2: 26, period3: 9)),
          ),
        ],
        sizing: PositionSizing.allIn,
        updatedAt: _stamp,
      );

  static StrategySpec bollingerBreakout() => StrategySpec(
        id: 'builtin.bollinger_breakout',
        frameworkId: 'turtle-trend',
        name: 'Bollinger Breakout',
        description: 'Buys a close above the upper band, exits back to the mean.',
        isBuiltIn: true,
        entry: [
          const Condition(
            left: Operand.series(SeriesRef(IndicatorType.close)),
            op: ComparisonOp.crossesAbove,
            right: Operand.series(SeriesRef(IndicatorType.bollUpper, period: 20, multiplier: 2)),
          ),
        ],
        exit: [
          const Condition(
            left: Operand.series(SeriesRef(IndicatorType.close)),
            op: ComparisonOp.crossesBelow,
            right: Operand.series(SeriesRef(IndicatorType.bollMiddle, period: 20, multiplier: 2)),
          ),
        ],
        takeProfitPct: 12,
        sizing: PositionSizing.allIn,
        updatedAt: _stamp,
      );
}
