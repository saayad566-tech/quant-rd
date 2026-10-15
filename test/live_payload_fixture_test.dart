import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/data/parsers/json_candle_parser.dart';

/// Parses a **real, captured** Yahoo Finance response so the free keyless
/// data path is covered against the actual API shape, not just a hand-written
/// sample. The fixture is a live `chart` payload for AAPL (5 daily bars).
void main() {
  test('the real Yahoo Finance payload parses into sane candles', () {
    final raw = File('test/fixtures/yahoo_chart_aapl.json').readAsStringSync();
    final report = JsonCandleParser.parse(raw);

    expect(report.candles, isNotEmpty);
    expect(report.candles.length, greaterThanOrEqualTo(4));

    // Every bar must be internally consistent and time-ordered.
    for (var i = 0; i < report.candles.length; i++) {
      final c = report.candles[i];
      expect(c.low, lessThanOrEqualTo(c.open));
      expect(c.low, lessThanOrEqualTo(c.close));
      expect(c.high, greaterThanOrEqualTo(c.open));
      expect(c.high, greaterThanOrEqualTo(c.close));
      expect(c.volume, greaterThanOrEqualTo(0));
      expect(c.time.isUtc, isTrue);
      if (i > 0) {
        expect(c.time.isAfter(report.candles[i - 1].time), isTrue);
      }
    }

    // AAPL trades well above a dollar — a sanity check that we read the right
    // fields rather than, say, a timestamp column.
    expect(report.candles.last.close, greaterThan(1));
    expect(report.candles.last.close, lessThan(100000));
  });
}
