import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/data/parsers/csv_candle_parser.dart';

void main() {
  test('parses a comma file with a header, sorted and UTC', () {
    const csv = 'date,open,high,low,close,volume\n'
        '2020-01-02,10,11,9,10.5,1000\n'
        '2020-01-03,10.5,12,10,11,1200';
    final r = CsvCandleParser.parse(csv);
    expect(r.candles.length, 2);
    expect(r.skippedRows, 0);
    expect(r.candles.first.time, DateTime.utc(2020, 1, 2));
    expect(r.candles.first.close, closeTo(10.5, 1e-9));
    expect(r.candles.first.volume, closeTo(1000, 1e-9));
    expect(r.candles.last.close, closeTo(11, 1e-9));
  });

  test('detects a semicolon delimiter', () {
    const csv = 'date;open;high;low;close\n2020-01-02;10;11;9;10.5';
    final r = CsvCandleParser.parse(csv);
    expect(r.candles.length, 1);
    expect(r.candles.first.high, closeTo(11, 1e-9));
  });

  test('parses a headerless positional file', () {
    const csv = '2020-01-02,10,11,9,10.5,1000';
    final r = CsvCandleParser.parse(csv);
    expect(r.candles.length, 1);
    expect(r.candles.first.open, closeTo(10, 1e-9));
    expect(r.candles.first.volume, closeTo(1000, 1e-9));
  });

  test('parses epoch-second timestamps', () {
    const csv = '1577923200,10,11,9,10.5,100';
    final r = CsvCandleParser.parse(csv);
    expect(r.candles.length, 1);
    expect(r.candles.first.time, DateTime.fromMillisecondsSinceEpoch(1577923200 * 1000, isUtc: true));
  });

  test('skips malformed rows and reports the count', () {
    const csv = 'date,open,high,low,close\n'
        '2020-01-02,10,11,9,10.5\n'
        'not-a-date,1,2,3,4\n'
        '2020-01-04,x,2,3,4\n'
        '2020-01-05,10,11,9,10.5';
    final r = CsvCandleParser.parse(csv);
    expect(r.candles.length, 2);
    expect(r.skippedRows, 2);
    expect(r.warnings.any((w) => w.contains('skipped')), isTrue);
  });

  test('sorts by time and de-duplicates keeping the last value', () {
    const csv = 'date,open,high,low,close\n'
        '2020-01-03,3,3,3,3\n'
        '2020-01-01,1,1,1,1\n'
        '2020-01-01,9,9,9,9\n'
        '2020-01-02,2,2,2,2';
    final r = CsvCandleParser.parse(csv);
    expect(r.candles.length, 3);
    expect(r.candles[0].time, DateTime.utc(2020, 1, 1));
    expect(r.candles[0].close, closeTo(9, 1e-9)); // last duplicate wins
    expect(r.candles[1].time, DateTime.utc(2020, 1, 2));
    expect(r.candles[2].time, DateTime.utc(2020, 1, 3));
  });

  test('an empty file is reported, not thrown', () {
    final r = CsvCandleParser.parse('');
    expect(r.candles, isEmpty);
    expect(r.warnings, isNotEmpty);
  });
}
