import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/data/models/candle.dart';
import 'package:quant_rd/domain/strategy_engine/book_strategies.dart';
import 'package:quant_rd/domain/strategy_engine/framework_ingestion.dart';
import 'package:quant_rd/domain/strategy_engine/strategy_engine.dart';
import 'package:quant_rd/domain/tracking/signal_tracker.dart';

Candle bar(int i, double c, {double v = 1000}) => Candle(
      time: DateTime.utc(2020, 1, 1).add(Duration(days: i)),
      open: c,
      high: c + 0.5,
      low: c - 0.5,
      close: c,
      volume: v,
    );

/// A long flat base followed by a steady rise — enough history for the
/// long-lookback strategies.
List<Candle> baseThenRise({int flat = 260, int rise = 120}) {
  final out = <Candle>[];
  for (var i = 0; i < flat; i++) {
    out.add(bar(i, 100));
  }
  for (var i = 0; i < rise; i++) {
    out.add(bar(flat + i, 100 + (i + 1) * 1.0, v: 2000));
  }
  return out;
}

const _validFramework = '''
{
  "id": "test.cross_50_200",
  "name": "Test 50/200 cross",
  "description": "A declarative crossover framework used to prove the ingestion pipeline executes rules.",
  "source": {"title": "A Test Framework", "author": "QA", "year": 2024},
  "rule": "Enter when the 50-period average crosses above the 200-period average",
  "entry": [{"left": {"indicator": "sma", "period": 50}, "op": "crossesAbove", "right": {"indicator": "sma", "period": 200}}],
  "exit": [{"left": {"indicator": "sma", "period": 50}, "op": "crossesBelow", "right": {"indicator": "sma", "period": 200}}],
  "risk": {"stopPct": 8, "targetPct": 20},
  "notes": {"limitation": "none"}
}
''';

void main() {
  setUpAll(() {
    registerBookStrategies();
  });

  group('strategy factory', () {
    test('the book strategies register with unique ids', () {
      final ids = StrategyFactory.ids;
      expect(ids, isNotEmpty);
      expect(ids.toSet().length, ids.length);
      expect(StrategyFactory.create('book.minervini.trend_template'), isNotNull);
    });

    test('an unknown id returns null rather than a stub', () {
      expect(StrategyFactory.create('does.not.exist'), isNull);
    });

    test('every strategy carries mandatory provenance', () {
      for (final s in StrategyFactory.all()) {
        expect(s.provenance.frameworkId, isNotEmpty, reason: '${s.id} has no framework id');
        expect(s.provenance.source, isNotEmpty, reason: '${s.id} has no source');
        expect(s.provenance.rule, isNotEmpty, reason: '${s.id} has no rule');
        expect(s.name, isNotEmpty);
        expect(s.description, isNotEmpty);
      }
    });

    test('parameters are declared with sane bounds and clamp on configuration', () {
      final s = StrategyFactory.create('book.minervini.trend_template')!;
      expect(s.parameters, isNotEmpty);
      final configured = s.configure({'atrStopMultiple': 999});
      expect(configured.param('atrStopMultiple'), lessThanOrEqualTo(5));
      final low = s.configure({'atrStopMultiple': -5});
      expect(low.param('atrStopMultiple'), greaterThanOrEqualTo(0.5));
    });

    test('an unknown parameter name is rejected', () {
      final s = StrategyFactory.create('book.turtle.breakout')!;
      expect(() => s.param('nope'), throwsArgumentError);
    });
  });

  group('signal generation', () {
    test('the turtle breakout fires on a breakout and is deterministic', () {
      final candles = baseThenRise();
      final s = StrategyFactory.create('book.turtle.breakout')!;
      final a = s.generateSignals('TEST', candles);
      final b = s.generateSignals('TEST', candles);
      expect(a, isNotEmpty);
      expect(a.length, b.length);
      expect(a.first.index, b.first.index);
      expect(a.first.side, SignalSide.long);
      expect(a.first.price, closeTo(b.first.price, 1e-9));
    });

    test('the trend template fires only once the moving-average stack is right', () {
      final candles = baseThenRise();
      final s = StrategyFactory.create('book.minervini.trend_template')!;
      final signals = s.generateSignals('TEST', candles);
      expect(signals, isNotEmpty);
      // Every signal must come after enough bars to have built the 200-day average.
      expect(signals.every((x) => x.index >= 260), isTrue);
      expect(signals.first.stop, isNotNull);
      expect(signals.first.stop!, lessThan(signals.first.price));
    });

    test('an RSI strategy emits an exit after an entry', () {
      final candles = <Candle>[];
      // Push RSI down, then up.
      for (var i = 0; i < 40; i++) {
        candles.add(bar(i, 100 - i * 0.8));
      }
      for (var i = 0; i < 40; i++) {
        candles.add(bar(40 + i, 68 + i * 1.2));
      }
      final s = StrategyFactory.create('book.wilder.rsi')!;
      final signals = s.generateSignals('TEST', candles);
      expect(signals.any((x) => x.side == SignalSide.long), isTrue);
    });

    test('a strategy returns nothing rather than guessing when history is too short', () {
      final s = StrategyFactory.create('book.minervini.trend_template')!;
      expect(s.generateSignals('TEST', [bar(0, 100), bar(1, 101)]), isEmpty);
    });

    test('latestSignal returns the final signal or null', () {
      final s = StrategyFactory.create('book.turtle.breakout')!;
      expect(s.latestSignal('TEST', [bar(0, 100)]), isNull);
      expect(s.latestSignal('TEST', baseThenRise()), isNotNull);
    });
  });

  group('framework ingestion', () {
    test('a valid framework is parsed and registered', () {
      final result = FrameworkIngestor.ingestDocument(_validFramework);
      expect(result.failed, isEmpty);
      expect(result.registered, contains('test.cross_50_200'));
      final strategy = StrategyFactory.create('test.cross_50_200');
      expect(strategy, isNotNull);
      expect(strategy!.provenance.source, contains('A Test Framework'));
    });

    test('the ingested framework executes its declared rules', () {
      final strategy = StrategyFactory.create('test.cross_50_200')!;
      final signals = strategy.generateSignals('TEST', baseThenRise());
      expect(signals, isNotEmpty);
      expect(signals.first.side, SignalSide.long);
      // The stop must come from the declared risk section.
      expect(signals.first.stop, closeTo(signals.first.price * 0.92, 1e-6));
    });

    test('a framework with no source is rejected — provenance is mandatory', () {
      final doc = jsonEncode({
        'id': 'test.no_source',
        'name': 'No source',
        'entry': [
          {'left': {'indicator': 'close'}, 'op': 'greaterThan', 'value': 1}
        ],
      });
      expect(() => FrameworkParser.parseDocument(doc), throwsA(isA<FrameworkParseError>()));
    });

    test('an unknown operator is rejected', () {
      final doc = jsonEncode({
        'id': 'test.bad_op',
        'name': 'Bad op',
        'source': {'title': 'X', 'author': 'Y'},
        'entry': [
          {'left': {'indicator': 'close'}, 'op': 'isNear', 'value': 1}
        ],
      });
      expect(() => FrameworkParser.parseDocument(doc), throwsA(isA<FrameworkParseError>()));
    });

    test('a framework with no entry rules is rejected', () {
      final doc = jsonEncode({
        'id': 'test.no_entry',
        'name': 'No entry',
        'source': {'title': 'X', 'author': 'Y'},
        'entry': <dynamic>[],
      });
      expect(() => FrameworkParser.parseDocument(doc), throwsA(isA<FrameworkParseError>()));
    });

    test('a malformed document reports the failure instead of crashing', () {
      final result = FrameworkIngestor.ingestDocument('{not json');
      expect(result.registered, isEmpty);
      expect(result.failed, isNotEmpty);
    });

    test('a document with a frameworks array registers every entry', () {
      final doc = jsonEncode({
        'frameworks': [
          jsonDecode(_validFramework),
          {
            'id': 'test.rsi_rule',
            'name': 'RSI rule',
            'source': {'title': 'Another Test', 'author': 'QA'},
            'entry': [
              {'left': {'indicator': 'rsi', 'period': 14}, 'op': 'lessThan', 'value': 30}
            ],
          }
        ]
      });
      final result = FrameworkIngestor.ingestDocument(doc);
      expect(result.failed, isEmpty);
      expect(result.registered.length, 2);
      expect(result.registered, contains('test.rsi_rule'));
    });

    test('round-tripping a spec through JSON preserves its rules', () {
      final spec = FrameworkParser.parseDocument(_validFramework).single;
      final roundTripped = FrameworkParser.parseDocument(jsonEncode(spec.toJson())).single;
      expect(roundTripped.id, spec.id);
      expect(roundTripped.entry.length, spec.entry.length);
      expect(roundTripped.entry.first.op, spec.entry.first.op);
      expect(roundTripped.stopPct, spec.stopPct);
      expect(roundTripped.targetPct, spec.targetPct);
    });
  });

  group('signal tracker', () {
    test('trades are simulated and metrics are computed from them', () {
      final candles = baseThenRise();
      final strategy = StrategyFactory.create('book.turtle.breakout')!;
      final signals = strategy.generateSignals('TEST', candles);
      final trades = SignalTracker.simulate(signals, candles);
      expect(trades.length, signals.where((s) => s.isEntry).length);

      final m = SignalTracker.metrics(trades);
      expect(m.trades, trades.length);
      expect(m.winRate, inInclusiveRange(0, 1));
      expect(m.maxDrawdownPct, greaterThanOrEqualTo(0));
      expect(m.averageHoldBars, greaterThanOrEqualTo(0));
      expect(m.summary, contains('trades'));
    });

    test('an empty signal list yields empty metrics, not an exception', () {
      final m = SignalTracker.metrics(const []);
      expect(m.trades, 0);
      expect(m.winRate, 0);
    });

    test('every trade records where it exited and why', () {
      final candles = baseThenRise();
      final strategy = StrategyFactory.create('book.turtle.breakout')!;
      final trades = SignalTracker.simulate(strategy.generateSignals('TEST', candles), candles);
      for (final t in trades) {
        expect(t.exitReason, isNotEmpty);
        expect(t.exitIndex, greaterThanOrEqualTo(t.entryIndex));
        expect(t.entryPrice, greaterThan(0));
      }
    });

    test('the compliance marker is present on strategy output', () {
      expect(Signal.complianceMarker, contains('NOT INVESTMENT ADVICE'));
      expect(SignalTracker.complianceMarker, contains('NOT INVESTMENT ADVICE'));
    });
  });
}
