import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/core/buffers/rolling_buffer.dart';
import 'package:quant_rd/data/models/candle.dart';

Candle c(int i, double close) => Candle(
      time: DateTime.utc(2020, 1, 1).add(Duration(days: i)),
      open: close,
      high: close + 1,
      low: close - 1,
      close: close,
    );

void main() {
  group('RollingBuffer', () {
    test('evicts the oldest once the cap is reached', () {
      final b = RollingBuffer<int>(capacity: 3);
      b.addAll([1, 2, 3, 4, 5]);
      expect(b.items, [3, 4, 5]);
      expect(b.length, 3);
      expect(b.isFull, isTrue);
      expect(b.first, 3);
      expect(b.last, 5);
    });

    test('memory stays flat no matter how long the feed runs', () {
      final b = RollingBuffer<int>(capacity: 100);
      for (var i = 0; i < 100000; i++) {
        b.add(i);
      }
      expect(b.length, 100);
      expect(b.last, 99999);
      expect(b.first, 99900);
    });

    test('rejects a non-positive capacity', () {
      expect(() => RollingBuffer<int>(capacity: 0), throwsArgumentError);
    });

    test('snapshot is a defensive copy', () {
      final b = RollingBuffer<int>(capacity: 2)..addAll([1, 2]);
      final snap = b.snapshot();
      b.add(3);
      expect(snap, [1, 2]);
      expect(b.items, [2, 3]);
    });
  });

  group('RollingCandleBuffer', () {
    test('caps a long candle history and keeps the newest bars', () {
      final buf = RollingCandleBuffer(capacity: 5000);
      for (var i = 0; i < 12000; i++) {
        buf.add(c(i, 100 + i.toDouble()));
      }
      expect(buf.length, 5000);
      expect(buf.isFull, isTrue);
      expect(buf.last!.close, closeTo(12000 + 99, 1e-9));
      expect(buf.first!.close, closeTo(100 + 7000, 1e-9));
    });

    test('reports the buffered high/low range', () {
      final buf = RollingCandleBuffer(capacity: 10)
        ..addAll([c(0, 10), c(1, 50), c(2, 20)]);
      final r = buf.range!;
      expect(r.$1, closeTo(51, 1e-9)); // highest high
      expect(r.$2, closeTo(9, 1e-9)); // lowest low
    });

    test('range is null when empty', () {
      expect(RollingCandleBuffer(capacity: 5).range, isNull);
    });
  });
}
