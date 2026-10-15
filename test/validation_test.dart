import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/data/models/backtest_config.dart';
import 'package:quant_rd/data/models/dataset.dart';
import 'package:quant_rd/data/models/strategy_spec.dart';
import 'package:quant_rd/data/sample/sample_data.dart';
import 'package:quant_rd/domain/engine/backtest_engine.dart';
import 'package:quant_rd/domain/engine/builtin_strategies.dart';
import 'package:quant_rd/domain/research/validation.dart';

void main() {
  test('a lenient policy passes, a demanding one fails — on real metrics', () {
    final candles = SampleData.generate(symbol: 'T', bars: 800, interval: BarInterval.d1);
    final result = BacktestEngine.run(
      resultId: 'v1',
      candles: candles,
      strategy: BuiltInStrategies.buyAndHold(),
      config: const BacktestConfig(),
      datasetId: 'd',
      symbol: 'T',
    );

    final lenient = ValidationOutcome.evaluate(
      result.metrics,
      const ValidationPolicy(minTrades: 1, minProfitFactor: 0, maxDrawdownPct: 100, requirePositiveExpectancy: false),
    );
    expect(lenient.passed, isTrue);

    final strict = ValidationOutcome.evaluate(result.metrics, const ValidationPolicy(minTrades: 100000));
    expect(strict.passed, isFalse);
    expect(strict.failures, isNotEmpty);
  });

  test('every check line is a readable PASS/FAIL with its measured value', () {
    final candles = SampleData.generate(symbol: 'T', bars: 500, interval: BarInterval.d1);
    final result = BacktestEngine.run(
      resultId: 'v3',
      candles: candles,
      strategy: BuiltInStrategies.macdTrend(),
      config: const BacktestConfig(),
      datasetId: 'd',
      symbol: 'T',
    );
    final outcome = ValidationOutcome.evaluate(result.metrics, const ValidationPolicy());
    expect(outcome.lines.length, 4);
    expect(outcome.lines.every((l) => l.startsWith('PASS') || l.startsWith('FAIL')), isTrue);
  });

  test('a validation record round-trips through the strategy map', () {
    final candles = SampleData.generate(symbol: 'T', bars: 500, interval: BarInterval.d1);
    final result = BacktestEngine.run(
      resultId: 'v2',
      candles: candles,
      strategy: BuiltInStrategies.smaCrossover(),
      config: const BacktestConfig(),
      datasetId: 'd',
      symbol: 'T',
    );
    final v = StrategyValidation.fromRun(id: 'val1', workspaceId: 'ws', result: result, policy: const ValidationPolicy());
    final spec = StrategySpec(id: 's1', name: 'x', updatedAt: DateTime.utc(2024), validation: v);

    final restored = StrategySpec.fromMap(spec.toMap());
    expect(restored.validation, isNotNull);
    expect(restored.validation!.passed, v.passed);
    expect(restored.validation!.metrics.tradeCount, v.metrics.tradeCount);
    expect(restored.validation!.checks.length, v.checks.length);
    expect(restored.validation!.symbol, 'T');
  });

  test('a malformed stored validation degrades to "not validated"', () {
    final restored = StrategySpec.fromMap({'id': 's', 'name': 'n', 'updated_at': 0, 'validation': '{not json'});
    expect(restored.validation, isNull);
  });

  test('clearing a validation is explicit', () {
    final v = StrategyValidation.fromMetrics(
      id: 'v',
      workspaceId: 'ws',
      strategyId: 's',
      datasetId: 'd',
      symbol: 'T',
      metrics: BacktestEngine.run(
        resultId: 'x',
        candles: SampleData.generate(symbol: 'T', bars: 300, interval: BarInterval.d1),
        strategy: BuiltInStrategies.buyAndHold(),
        config: const BacktestConfig(),
        datasetId: 'd',
        symbol: 'T',
      ).metrics,
      policy: const ValidationPolicy(),
    );
    final spec = StrategySpec(id: 's', name: 'n', updatedAt: DateTime.utc(2024), validation: v);
    expect(spec.copyWith(clearValidation: true).validation, isNull);
    expect(spec.copyWith(enabled: false).validation, isNotNull);
  });
}
