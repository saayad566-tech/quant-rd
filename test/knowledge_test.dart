import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/data/models/candle.dart';
import 'package:quant_rd/data/models/strategy_spec.dart';
import 'package:quant_rd/domain/knowledge/book_catalogue.dart';
import 'package:quant_rd/domain/knowledge/book_framework.dart';
import 'package:quant_rd/domain/knowledge/framework_screener.dart';
import 'package:quant_rd/domain/knowledge/market_region.dart';
import 'package:quant_rd/domain/knowledge/supply_chain.dart';
import 'package:quant_rd/domain/engine/builtin_strategies.dart';

/// A steady uptrend: price rises 1 unit per bar from [start].
List<Candle> uptrend(int bars, {double start = 100}) => List.generate(bars, (i) {
      final p = start + i;
      return Candle(
        time: DateTime.utc(2020, 1, 1).add(Duration(days: i)),
        open: p,
        high: p + 0.5,
        low: p - 0.5,
        close: p,
        volume: 1000 + i.toDouble(),
      );
    });

/// A steady downtrend.
List<Candle> downtrend(int bars, {double start = 400}) => List.generate(bars, (i) {
      final p = start - i;
      return Candle(
        time: DateTime.utc(2020, 1, 1).add(Duration(days: i)),
        open: p,
        high: p + 0.5,
        low: p - 0.5,
        close: p,
        volume: 1000 + i.toDouble(),
      );
    });

void main() {
  group('catalogue integrity', () {
    test('framework ids are unique and non-empty', () {
      final ids = kFrameworks.map((f) => f.id).toList();
      expect(ids.length, kFrameworks.length);
      expect(ids.toSet().length, ids.length, reason: 'framework ids must be unique');
      expect(ids.every((id) => id.isNotEmpty), isTrue);
    });

    test('every framework cites a real book and has criteria', () {
      for (final f in kFrameworks) {
        expect(f.book.title, isNotEmpty, reason: '${f.id} has no book title');
        expect(f.book.author, isNotEmpty, reason: '${f.id} has no author');
        expect(f.criteria, isNotEmpty, reason: '${f.id} has no criteria');
        expect(f.philosophy.length, greaterThan(40));
      }
    });

    test('the technical frameworks expose criteria computable from candles', () {
      for (final id in ['minervini-trend-template', 'canslim', 'weinstein-stage', 'momentum-factor']) {
        final f = frameworkById(id)!;
        expect(f.computable, isNotEmpty, reason: '$id should have computable criteria');
      }
    });

    test('the reading list is populated and public-domain entries carry a Gutenberg id', () {
      expect(kBookCatalogue.length, greaterThan(50));
      final pd = publicDomainBooks();
      expect(pd, isNotEmpty);
      expect(pd.every((b) => b.gutenbergId != null), isTrue);
      expect(pd.every((b) => b.isPublicDomain), isTrue);
    });

    test('frameworkById returns null for an unknown id', () {
      expect(frameworkById('does-not-exist'), isNull);
    });
  });

  group('market region isolation', () {
    test('India accepts NSE/BSE listings and rejects US tickers', () {
      expect(MarketRegion.india.allows('RELIANCE.NS'), isTrue);
      expect(MarketRegion.india.allows('TCS.BO'), isTrue);
      expect(MarketRegion.india.allows('^NSEI'), isTrue);
      expect(MarketRegion.india.allows('AAPL'), isFalse);
      expect(MarketRegion.india.allows('MSFT'), isFalse);
    });

    test('the US accepts plain tickers and rejects Indian listings', () {
      expect(MarketRegion.unitedStates.allows('AAPL'), isTrue);
      expect(MarketRegion.unitedStates.allows('^GSPC'), isTrue);
      expect(MarketRegion.unitedStates.allows('RELIANCE.NS'), isFalse);
      expect(MarketRegion.unitedStates.allows('TCS.BO'), isFalse);
    });

    test('crypto is region-neutral and allowed everywhere', () {
      expect(MarketRegion.isRegionNeutral('BTC-USD'), isTrue);
      expect(MarketRegion.india.allows('BTC-USD'), isTrue);
      expect(MarketRegion.unitedStates.allows('BTC-USD'), isTrue);
      expect(MarketRegion.india.allows('BTCUSDT'), isTrue);
    });

    test('filter drops everything outside the region — no cross-market leakage', () {
      final mixed = ['RELIANCE.NS', 'AAPL', 'TCS.NS', 'MSFT', 'BTC-USD'];
      expect(MarketRegion.india.filter(mixed), ['RELIANCE.NS', 'TCS.NS', 'BTC-USD']);
      expect(MarketRegion.unitedStates.filter(mixed), ['AAPL', 'MSFT', 'BTC-USD']);
      expect(MarketRegion.global.filter(mixed).length, 5);
    });

    test('an empty symbol is rejected everywhere', () {
      for (final r in MarketRegion.values) {
        expect(r.allows('   '), isFalse);
      }
    });
  });

  group('framework screener', () {
    const screener = FrameworkScreener();

    test('a steady uptrend satisfies the moving-average stack of the trend template', () {
      final f = frameworkById('minervini-trend-template')!;
      final report = screener.screen(f, {'STRONG.NS': uptrend(300)});
      expect(report.universeSize, 1);
      final v = report.hits.single.verdict;

      final byName = {for (final r in v.results) r.criterion.name: r};
      expect(byName['Price above the long averages']!.state, CriterionState.met);
      expect(byName['150 above 200']!.state, CriterionState.met);
      expect(byName['200-day rising']!.state, CriterionState.met);
      expect(byName['50 above both']!.state, CriterionState.met);
      expect(byName['Price above 50']!.state, CriterionState.met);
      expect(byName['Well off the low']!.state, CriterionState.met);
    });

    test('a downtrend fails the stack', () {
      final f = frameworkById('minervini-trend-template')!;
      final report = screener.screen(f, {'WEAK.NS': downtrend(300)});
      final v = report.hits.single.verdict;
      final byName = {for (final r in v.results) r.criterion.name: r};
      expect(byName['Price above the long averages']!.state, CriterionState.unmet);
      expect(v.passed, isFalse);
    });

    test('criteria that need fundamentals are reported as N/A, never as passes', () {
      final f = frameworkById('canslim')!;
      final report = screener.screen(f, {'A.NS': uptrend(300)});
      final v = report.hits.single.verdict;
      expect(v.unknown, greaterThan(0));
      // The fundamental criteria must never appear as met.
      final fundamental = v.results.where((r) => !r.criterion.computableFromCandles);
      expect(fundamental.every((r) => r.state == CriterionState.needsData), isTrue);
      // And the score is computed only over the evaluable criteria.
      expect(v.evaluated, v.results.length - v.unknown);
    });

    test('relative strength is genuinely cross-sectional', () {
      final f = frameworkById('minervini-trend-template')!;
      final report = screener.screen(f, {
        'UP.NS': uptrend(300),
        'DOWN.NS': downtrend(300),
      });
      final up = report.hits.firstWhere((h) => h.symbol == 'UP.NS');
      final down = report.hits.firstWhere((h) => h.symbol == 'DOWN.NS');
      final upRs = up.verdict.results.firstWhere((r) => r.criterion.name == 'Relative strength');
      final downRs = down.verdict.results.firstWhere((r) => r.criterion.name == 'Relative strength');
      expect(upRs.state, CriterionState.met);
      expect(downRs.state, CriterionState.unmet);
    });

    test('results are ranked by score, best first', () {
      final f = frameworkById('weinstein-stage')!;
      final report = screener.screen(f, {
        'UP.NS': uptrend(300),
        'DOWN.NS': downtrend(300),
      });
      expect(report.hits.length, 2);
      expect(report.hits.first.verdict.score, greaterThanOrEqualTo(report.hits.last.verdict.score));
    });

    test('instruments with too little history are skipped, not scored', () {
      final f = frameworkById('weinstein-stage')!;
      final report = screener.screen(f, {'SHORT.NS': uptrend(50), 'LONG.NS': uptrend(300)});
      expect(report.universeSize, 1);
      expect(report.hits.single.symbol, 'LONG.NS');
    });
  });

  group('supply chain', () {
    test('every theme has front-line names and upstream choke-points', () {
      expect(kSupplyChainThemes, isNotEmpty);
      for (final t in kSupplyChainThemes) {
        expect(t.frontLine, isNotEmpty, reason: '${t.id} has no front-line names');
        expect(t.upstream, isNotEmpty, reason: '${t.id} has no upstream layers');
        for (final l in t.upstream) {
          expect(l.whyItMatters.length, greaterThan(20), reason: '${t.id}/${l.layer} needs a rationale');
        }
      }
    });

    test('the AI infrastructure theme names the thermal and grid constraints', () {
      final t = supplyChainThemeById('ai-infrastructure')!;
      final layers = t.upstream.map((l) => l.layer.toLowerCase()).join(' ');
      expect(layers, contains('thermal'));
      expect(layers, contains('grid'));
    });
  });

  group('strategy framework tagging', () {
    test('every built-in strategy that cites a framework cites a real one', () {
      for (final s in BuiltInStrategies.all()) {
        if (s.frameworkId == null) continue;
        expect(frameworkById(s.frameworkId!), isNotNull, reason: '${s.id} cites unknown framework ${s.frameworkId}');
      }
    });

    test('the tagged built-ins point at the frameworks the directive names', () {
      final sma = BuiltInStrategies.smaCrossover();
      expect(sma.frameworkId, 'weinstein-stage');
      final rsi = BuiltInStrategies.rsiReversion();
      expect(rsi.frameworkId, 'wilder-rsi-atr');
    });

    test('a framework tag round-trips through the strategy map', () {
      final s = BuiltInStrategies.macdTrend();
      final restored = StrategySpec.fromMap(s.toMap());
      expect(restored.frameworkId, s.frameworkId);
    });
  });
}
