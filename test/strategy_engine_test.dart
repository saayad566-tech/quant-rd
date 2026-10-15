import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/data/models/candle.dart';
import 'package:quant_rd/data/models/strategy_spec.dart';
import 'package:quant_rd/domain/engine/strategy_engine.dart';

Candle c(int i, double cl) => Candle(
      time: DateTime.utc(2020, 1, 1).add(Duration(days: i)),
      open: cl,
      high: cl,
      low: cl,
      close: cl,
    );

void main() {
  test('crossesAbove is true only on the bar the line crosses', () {
    final candles = [c(0, 1), c(1, 3), c(2, 2), c(3, 4)];
    final strategy = StrategySpec(
      id: 's',
      name: 's',
      entry: [
        const Condition(
          left: Operand.series(SeriesRef(IndicatorType.close)),
          op: ComparisonOp.crossesAbove,
          right: Operand.constant(2),
        ),
      ],
      updatedAt: DateTime.utc(2024),
    );
    final series = StrategyEngine.computeSeries(strategy.requiredSeries, candles);
    expect(StrategyEngine.entrySignal(strategy, 0, series), isFalse);
    expect(StrategyEngine.entrySignal(strategy, 1, series), isTrue);
    expect(StrategyEngine.entrySignal(strategy, 2, series), isFalse);
    expect(StrategyEngine.entrySignal(strategy, 3, series), isTrue);
  });

  test('crossesBelow is the mirror of crossesAbove', () {
    final candles = [c(0, 4), c(1, 1), c(2, 3), c(3, 0)];
    final strategy = StrategySpec(
      id: 's',
      name: 's',
      exit: [
        const Condition(
          left: Operand.series(SeriesRef(IndicatorType.close)),
          op: ComparisonOp.crossesBelow,
          right: Operand.constant(2),
        ),
      ],
      updatedAt: DateTime.utc(2024),
    );
    final series = StrategyEngine.computeSeries(strategy.requiredSeries, candles);
    expect(StrategyEngine.exitSignal(strategy, 0, series), isFalse);
    expect(StrategyEngine.exitSignal(strategy, 1, series), isTrue);
    expect(StrategyEngine.exitSignal(strategy, 2, series), isFalse);
    expect(StrategyEngine.exitSignal(strategy, 3, series), isTrue);
  });

  test('an entry with an empty rule set never fires', () {
    final strategy = StrategySpec(id: 's', name: 's', updatedAt: DateTime.utc(2024));
    final series = StrategyEngine.computeSeries(strategy.requiredSeries, [c(0, 1), c(1, 2)]);
    expect(StrategyEngine.entrySignal(strategy, 1, series), isFalse);
  });

  test('warm-up counts referenced periods plus one for a cross', () {
    final cross = StrategySpec(
      id: 's',
      name: 's',
      entry: [
        const Condition(
          left: Operand.series(SeriesRef(IndicatorType.sma, period: 50)),
          op: ComparisonOp.crossesAbove,
          right: Operand.series(SeriesRef(IndicatorType.sma, period: 200)),
        ),
      ],
      updatedAt: DateTime.utc(2024),
    );
    expect(StrategyEngine.warmupBars(cross), 201);

    final plain = StrategySpec(
      id: 's',
      name: 's',
      entry: [
        const Condition(
          left: Operand.series(SeriesRef(IndicatorType.close)),
          op: ComparisonOp.greaterThan,
          right: Operand.constant(0),
        ),
      ],
      updatedAt: DateTime.utc(2024),
    );
    expect(StrategyEngine.warmupBars(plain), 0);
  });
}
