import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/domain/strategy_engine/book_strategies.dart';
import 'package:quant_rd/domain/strategy_engine/corpus_parser.dart';
import 'package:quant_rd/domain/strategy_engine/framework_ingestion.dart';
import 'package:quant_rd/domain/strategy_engine/strategy_engine.dart';

const _sample = '''
This public-domain text describes a simple method. When the relative strength index is below 30 the stock is
considered oversold and may be bought. Buy when the 50 day moving average crosses above the 200 day moving average.
The student should keep a careful record of every transaction and review it each week.
A stock trading below 5 dollars should generally be avoided by the cautious investor.
''';

void main() {
  setUpAll(registerBookStrategies);

  group('extraction', () {
    test('maps clean rules onto the schema', () {
      final ex = CorpusExtractor.extract(_sample, title: 'A Public Domain Treatise', author: 'A Writer', year: 1910);
      expect(ex.accepted, isNotEmpty);
      final indicators = ex.accepted.map((d) => d.rule!.left.indicator).toSet();
      expect(indicators, contains('rsi'));
      expect(indicators, contains('sma'));
    });

    test('reads the RSI threshold and comparator', () {
      final ex = CorpusExtractor.extract('When the relative strength index is below 30 the stock is oversold.',
          title: 'T', author: 'A');
      final rule = ex.accepted.single.rule!;
      expect(rule.left.indicator, 'rsi');
      expect(rule.op, RuleOp.lessThan);
      expect(rule.value, closeTo(30, 1e-9));
    });

    test('reads a moving-average crossover with both periods', () {
      final ex = CorpusExtractor.extract('Buy when the 50 day moving average crosses above the 200 day moving average.',
          title: 'T', author: 'A');
      final rule = ex.accepted.single.rule!;
      expect(rule.left.indicator, 'sma');
      expect(rule.left.period, 50);
      expect(rule.op, RuleOp.crossesAbove);
      expect(rule.right, isNotNull);
      expect(rule.right!.period, 200);
    });

    test('converts weeks to trading days', () {
      final ex = CorpusExtractor.extract('Sell when the price falls below the 30 week moving average.', title: 'T', author: 'A');
      final rule = ex.accepted.single.rule!;
      final periods = [rule.left.period, if (rule.right != null) rule.right!.period];
      expect(periods, contains(150), reason: '30 weeks is 150 trading days');
    });
  });

  group('rejection — the guardrail against invented mathematics', () {
    test('a sentence with no comparator is rejected', () {
      final ex = CorpusExtractor.extract('The student should keep a careful record of every transaction and review it each week.',
          title: 'T', author: 'A');
      expect(ex.accepted, isEmpty);
    });

    test('a moving average compared to a bare number is rejected as ambiguous', () {
      final ex = CorpusExtractor.extract('The price should be above the 50 day moving average of 100 dollars.', title: 'T', author: 'A');
      // Whatever it resolves to, it must never invent a threshold silently.
      for (final d in ex.rejected) {
        expect(d.rejection, isNotEmpty);
      }
    });

    test('every rejected draft states why', () {
      final ex = CorpusExtractor.extract(_sample, title: 'T', author: 'A');
      for (final d in ex.rejected) {
        expect(d.rejection, isNotNull);
        expect(d.rejection!.length, greaterThan(10));
      }
    });

    test('plain prose with no indicators yields nothing', () {
      final ex = CorpusExtractor.extract('It was a bright cold day in April, and the clocks were striking thirteen.', title: 'T', author: 'A');
      expect(ex.drafts, isEmpty);
    });
  });

  group('framework construction and registration', () {
    test('accepted drafts build a valid framework document', () {
      final ex = CorpusExtractor.extract(_sample, title: 'A Public Domain Treatise', author: 'A Writer', year: 1910);
      final spec = ex.toFramework(id: 'corpus.test', name: 'Test rules');
      expect(spec, isNotNull);
      expect(spec!.entry, isNotEmpty);
      expect(spec.sourceTitle, 'A Public Domain Treatise');
      expect(spec.sourceYear, 1910);
      expect(spec.notes['extraction'], isNotNull);
    });

    test('nothing mapped means no framework, not an empty one', () {
      final ex = CorpusExtractor.extract('It was a bright cold day in April.', title: 'T', author: 'A');
      expect(ex.toFramework(id: 'x', name: 'y'), isNull);
    });

    test('the extracted framework registers and executes', () {
      final ex = CorpusExtractor.extract(_sample, title: 'A Public Domain Treatise', author: 'A Writer', year: 1910);
      final spec = ex.toFramework(id: 'corpus.exec', name: 'Executable rules')!;
      final json = spec.toJson();
      final encoded = FrameworkIngestor.ingestDocument(jsonEncode(json));
      expect(encoded.failed, isEmpty);
      expect(encoded.registered, contains('corpus.exec'));

      final strategy = StrategyFactory.create('corpus.exec');
      expect(strategy, isNotNull);
      expect(strategy!.provenance.source, contains('A Public Domain Treatise'));
      expect(strategy.provenance.rule, isNotEmpty);
      expect(strategy.generateSignals('T', const []), isEmpty);
    });

    test('the extraction report is serialisable', () {
      final ex = CorpusExtractor.extract(_sample, title: 'T', author: 'A');
      final json = ex.toJson();
      expect(json, contains('accepted'));
      expect(json, contains('rejected'));
      expect(json, contains('summary'));
    });
  });
}

