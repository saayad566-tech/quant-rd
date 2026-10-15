import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/data/parsers/csv_candle_parser.dart';
import 'package:quant_rd/data/parsers/json_candle_parser.dart';

void main() {
  group('array of objects', () {
    test('parses time/open/high/low/close/volume', () {
      const json = '['
          '{"date":"2020-01-02","open":10,"high":11,"low":9,"close":10.5,"volume":1000},'
          '{"date":"2020-01-03","open":10.5,"high":12,"low":10,"close":11,"volume":1200}'
          ']';
      final r = JsonCandleParser.parse(json);
      expect(r.candles.length, 2);
      expect(r.candles.first.time, DateTime.utc(2020, 1, 2));
      expect(r.candles.first.close, closeTo(10.5, 1e-9));
      expect(r.candles.last.volume, closeTo(1200, 1e-9));
    });

    test('accepts short keys (t/o/h/l/c/v)', () {
      const json = '[{"t":1577923200,"o":1,"h":2,"l":0.5,"c":1.5,"v":10}]';
      final r = JsonCandleParser.parse(json);
      expect(r.candles.single.close, closeTo(1.5, 1e-9));
      expect(r.candles.single.time, DateTime.fromMillisecondsSinceEpoch(1577923200 * 1000, isUtc: true));
    });
  });

  group('array of arrays', () {
    test('parses [time, o, h, l, c, v]', () {
      const json = '[[1577923200,1,2,0.5,1.5,10],[1578009600,1.5,3,1,2.5,20]]';
      final r = JsonCandleParser.parse(json);
      expect(r.candles.length, 2);
      expect(r.candles.last.close, closeTo(2.5, 1e-9));
    });
  });

  group('wrapped payloads', () {
    test('unwraps a data array', () {
      const json = '{"data":[{"date":"2020-01-02","open":1,"high":2,"low":0.5,"close":1.5,"volume":10}]}';
      final r = JsonCandleParser.parse(json);
      expect(r.candles.length, 1);
    });

    test('unwraps a nested result object', () {
      const json = '{"result":{"candles":[{"time":1577923200,"open":1,"high":2,"low":0.5,"close":1.5}]}}';
      final r = JsonCandleParser.parse(json);
      expect(r.candles.length, 1);
    });
  });

  group('Yahoo Finance response', () {
    test('parses the chart structure and skips null bars', () {
      const json = '{"chart":{"error":null,"result":[{"timestamp":[1577923200,1578009600,1578096000],'
          '"indicators":{"quote":[{"open":[1,2,null],"high":[2,3,null],"low":[0.5,1,null],"close":[1.5,2.5,null],"volume":[10,20,null]}]}}]}}';
      final r = JsonCandleParser.parse(json);
      expect(r.candles.length, 2);
      expect(r.candles.first.close, closeTo(1.5, 1e-9));
      expect(r.candles.first.time, DateTime.fromMillisecondsSinceEpoch(1577923200 * 1000, isUtc: true));
    });

    test('surfaces a Yahoo error message', () {
      const json = '{"chart":{"error":{"description":"No data found, symbol may be delisted"}}}';
      final r = JsonCandleParser.parse(json);
      expect(r.candles, isEmpty);
      expect(r.warnings.join(' '), contains('delisted'));
    });
  });

  group('Binance klines response', () {
    test('parses the array-of-arrays payload', () {
      const json = '[[1577923200000,"1.0","2.0","0.5","1.5","10",1578009599999,"15",100,5,"7.5","0"]]';
      final r = JsonCandleParser.parse(json);
      expect(r.candles.length, 1);
      expect(r.candles.single.open, closeTo(1.0, 1e-9));
      expect(r.candles.single.close, closeTo(1.5, 1e-9));
      expect(r.candles.single.volume, closeTo(10, 1e-9));
    });
  });

  group('robustness', () {
    test('invalid JSON is reported, not thrown', () {
      final r = JsonCandleParser.parse('{not json');
      expect(r.candles, isEmpty);
      expect(r.warnings, isNotEmpty);
    });

    test('sorts and de-duplicates by timestamp', () {
      const json = '[{"t":1578009600,"o":2,"h":2,"l":2,"c":2,"v":1},'
          '{"t":1577923200,"o":1,"h":1,"l":1,"c":1,"v":1},'
          '{"t":1577923200,"o":9,"h":9,"l":9,"c":9,"v":1}]';
      final r = JsonCandleParser.parse(json);
      expect(r.candles.length, 2);
      expect(r.candles.first.close, closeTo(9, 1e-9)); // last duplicate wins
    });
  });

  group('shared timestamp parsing', () {
    test('CSV and JSON agree on the same date', () {
      final a = CsvCandleParser.parseTimestamp('2020-01-02');
      final b = JsonCandleParser.parse('[{"date":"2020-01-02","open":1,"high":1,"low":1,"close":1}]').candles.single.time;
      expect(a, b);
      expect(a, DateTime.utc(2020, 1, 2));
    });
  });
}
