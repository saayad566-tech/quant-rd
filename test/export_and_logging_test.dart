import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/core/errors/error_reporter.dart';
import 'package:quant_rd/core/logging/activity_log.dart';
import 'package:quant_rd/data/export/export_service.dart';
import 'package:quant_rd/data/models/backtest_config.dart';
import 'package:quant_rd/data/models/backtest_result.dart';
import 'package:quant_rd/data/models/candle.dart';
import 'package:quant_rd/data/models/trade.dart';
import 'package:quant_rd/domain/engine/metrics.dart';

BacktestResult sampleResult({String strategyName = 'SMA Cross'}) => BacktestResult(
      id: 'r1',
      strategyId: 's1',
      strategyName: strategyName,
      datasetId: 'd1',
      symbol: 'TEST',
      config: const BacktestConfig(initialCapital: 100000),
      equityCurve: [
        EquityPoint(time: DateTime.utc(2020, 1, 1), equity: 100000, drawdownPct: 0),
        EquityPoint(time: DateTime.utc(2020, 1, 2), equity: 110000, drawdownPct: 0),
      ],
      trades: [
        Trade(
          id: 1,
          isLong: true,
          entryTime: DateTime.utc(2020, 1, 1),
          exitTime: DateTime.utc(2020, 1, 2),
          entryPrice: 100,
          exitPrice: 110,
          quantity: 10,
          pnl: 100,
          pnlPct: 10,
          fees: 5,
          equityAfter: 110000,
          exitReason: ExitReason.signal,
        ),
      ],
      metrics: Metrics.empty,
      barCount: 2,
      runAt: DateTime.utc(2020, 1, 3),
    );

void main() {
  group('ExportService', () {
    test('trades CSV has a header and one row per trade', () {
      final csv = ExportService.tradesToCsv(sampleResult());
      final lines = csv.trim().split('\n');
      expect(lines.length, 2);
      expect(lines.first, contains('entry_price'));
      expect(lines.last, contains('long'));
    });

    test('metrics CSV contains the key metrics', () {
      final csv = ExportService.metricsToCsv(sampleResult());
      expect(csv, contains('sharpe'));
      expect(csv, contains('max_drawdown_pct'));
    });

    test('candles CSV has a header plus one row per candle', () {
      final candles = [
        Candle(time: DateTime.utc(2020, 1, 1), open: 1, high: 2, low: 0.5, close: 1.5, volume: 10),
        Candle(time: DateTime.utc(2020, 1, 2), open: 1.5, high: 2, low: 1, close: 1.8, volume: 12),
      ];
      final csv = ExportService.candlesToCsv(candles);
      expect(csv.trim().split('\n').length, 3);
      expect(csv, contains('timestamp,open,high,low,close,volume'));
    });

    test('fields containing commas are quoted', () {
      final csv = ExportService.metricsToCsv(sampleResult(strategyName: 'A, B'));
      expect(csv, contains('"A, B"'));
    });

    test('safeName strips unsafe characters', () {
      expect(ExportService.safeName('SMA Cross / 50-200'), 'SMA_Cross_50-200');
    });
  });

  group('ErrorReporter.describeError', () {
    test('maps network failures to plain English', () {
      expect(ErrorReporter.describeError(Exception('SocketException: Failed host lookup'), null), contains('internet'));
    });

    test('maps timeouts to plain English', () {
      expect(ErrorReporter.describeError(Exception('TimeoutException after 30s'), null), contains('took too long'));
    });

    test('never leaks an empty message', () {
      final msg = ErrorReporter.describeError(StateError('boom'), null);
      expect(msg, isNotEmpty);
      expect(msg, contains('boom'));
    });
  });

  group('ActivityLog', () {
    test('records entries newest-first and exports oldest-first', () {
      final log = ActivityLog();
      log.info('first');
      log.success('second');
      expect(log.entries.first.message, 'second');
      final text = log.exportText();
      expect(text.indexOf('first'), lessThan(text.indexOf('second')));
    });

    test('round-trips through JSON', () {
      final log = ActivityLog();
      log.warn('careful');
      final restored = ActivityLog()..loadFrom(log.toJson());
      expect(restored.entries.single.message, 'careful');
      expect(restored.entries.single.level, LogLevel.warning);
    });

    test('survives corrupt JSON', () {
      final log = ActivityLog()..loadFrom('{not json');
      expect(log.entries, isEmpty);
    });
  });
}
