import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/data/models/backtest_config.dart';
import 'package:quant_rd/data/models/candle.dart';
import 'package:quant_rd/data/models/dataset.dart';
import 'package:quant_rd/data/sample/sample_data.dart';
import 'package:quant_rd/domain/research/research_pipeline.dart';
import 'package:quant_rd/domain/research/validation.dart';

Candle rising(int i) => Candle(
      time: DateTime.utc(2020, 1, 1).add(Duration(days: i)),
      open: 100 + i.toDouble(),
      high: 101 + i.toDouble(),
      low: 99 + i.toDouble(),
      close: 100 + i.toDouble(),
    );

void main() {
  const config = BacktestConfig(initialCapital: 100000, feeBps: 5, slippageBps: 2);

  group('Data Analyst profile', () {
    test('detects an uptrend on a monotonically rising series', () {
      final candles = List.generate(200, rising);
      final p = ResearchPipeline.profile(candles, config);
      expect(p.bars, 200);
      expect(p.totalReturnPct, greaterThan(0));
      expect(p.trendSlopePctPerBar, greaterThan(0));
      expect(p.upBarRatio, closeTo(1.0, 1e-9));
      expect(p.regime, 'Uptrend');
    });

    test('an empty series yields the empty profile', () {
      expect(ResearchPipeline.profile(const [], config).bars, 0);
    });
  });

  group('Strategy Builder', () {
    test('is deterministic — the same dataset yields the same candidates', () {
      final a = ResearchPipeline.generate(DatasetProfile.empty, limit: 20).map((s) => s.id).toList();
      final b = ResearchPipeline.generate(DatasetProfile.empty, limit: 20).map((s) => s.id).toList();
      expect(a, b);
      expect(a.length, 20);
      expect(a.toSet().length, 20, reason: 'candidate ids must be unique');
    });

    test('respects the candidate limit', () {
      expect(ResearchPipeline.generate(DatasetProfile.empty, limit: 5).length, 5);
    });
  });

  group('pipeline run', () {
    test('evaluates every candidate and returns a bounded, sorted leaderboard', () async {
      final candles = SampleData.generate(symbol: 'TEST', bars: 400, interval: BarInterval.d1);
      const pipeline = ResearchPipeline();
      final report = await pipeline.run(
        candles: candles,
        datasetId: 'd1',
        symbol: 'TEST',
        workspaceId: 'ws',
        config: config,
        maxCandidates: 12,
        batchSize: 4,
        keepTop: 5,
      );

      expect(report.evaluated, 12);
      expect(report.leaderboard.length, lessThanOrEqualTo(5));
      expect(report.log.first, contains('Data Analyst'));

      // Sorted by score, descending.
      for (var i = 1; i < report.leaderboard.length; i++) {
        expect(report.leaderboard[i - 1].score, greaterThanOrEqualTo(report.leaderboard[i].score));
      }
      // Metrics come from the engine, never invented.
      final best = report.leaderboard.first;
      expect(best.metrics.tradeCount, greaterThanOrEqualTo(0));
      expect(best.metrics.finalEquity, greaterThan(0));
    });

    test('reports progress across batches', () async {
      final candles = SampleData.generate(symbol: 'TEST', bars: 300, interval: BarInterval.d1);
      final seen = <double>[];
      await const ResearchPipeline().run(
        candles: candles,
        datasetId: 'd1',
        symbol: 'TEST',
        workspaceId: 'ws',
        config: config,
        maxCandidates: 8,
        batchSize: 2,
        onProgress: (p, _) => seen.add(p),
      );
      expect(seen, isNotEmpty);
      expect(seen.last, closeTo(1.0, 1e-9));
    });

    test('the validation gate can reject every candidate', () async {
      final candles = SampleData.generate(symbol: 'TEST', bars: 300, interval: BarInterval.d1);
      final report = await const ResearchPipeline(policy: ValidationPolicy(minTrades: 100000)).run(
        candles: candles,
        datasetId: 'd1',
        symbol: 'TEST',
        workspaceId: 'ws',
        config: config,
        maxCandidates: 6,
        batchSize: 3,
      );
      expect(report.evaluated, 6);
      expect(report.rejected, 6);
      expect(report.leaderboard.every((c) => !c.validation.passed), isTrue);
    });

    test('too little data is reported, not crashed on', () async {
      final report = await const ResearchPipeline().run(
        candles: [rising(0), rising(1), rising(2)],
        datasetId: 'd1',
        symbol: 'TEST',
        workspaceId: 'ws',
        config: config,
      );
      expect(report.evaluated, 0);
      expect(report.log.join(' '), contains('Not enough bars'));
    });
  });

  group('score', () {
    test('is the documented composite of real engine metrics', () async {
      final candles = SampleData.generate(symbol: 'TEST', bars: 250, interval: BarInterval.d1);
      final report = await const ResearchPipeline().run(
        candles: candles,
        datasetId: 'd1',
        symbol: 'TEST',
        workspaceId: 'ws',
        config: config,
        maxCandidates: 3,
        batchSize: 3,
      );
      final best = report.leaderboard.first;
      final m = best.metrics;
      final pf = m.profitFactor.isFinite ? m.profitFactor.clamp(0.0, 5.0) : 5.0;
      final sharpe = m.sharpe.isFinite ? m.sharpe : 0.0;
      final expected = sharpe + 0.3 * pf - 0.5 * (m.maxDrawdownPct / 100.0);
      expect(best.score, closeTo(expected, 1e-9));
    });
  });
}
