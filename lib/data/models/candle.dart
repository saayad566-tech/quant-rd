/// A single OHLCV price bar.
library;

class Candle {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume = 0,
  });

  Map<String, dynamic> toMap() => {
        't': time.millisecondsSinceEpoch,
        'o': open,
        'h': high,
        'l': low,
        'c': close,
        'v': volume,
      };

  factory Candle.fromMap(Map<String, dynamic> m) => Candle(
        time: DateTime.fromMillisecondsSinceEpoch((m['t'] as num).toInt(), isUtc: true),
        open: (m['o'] as num).toDouble(),
        high: (m['h'] as num).toDouble(),
        low: (m['l'] as num).toDouble(),
        close: (m['c'] as num).toDouble(),
        volume: (m['v'] as num?)?.toDouble() ?? 0,
      );

  /// Compact CSV-friendly representation.
  Map<String, dynamic> toCsvRow() => {
        'timestamp': time.toIso8601String(),
        'open': open,
        'high': high,
        'low': low,
        'close': close,
        'volume': volume,
      };

  @override
  String toString() => 'Candle(${time.toIso8601String()}, O=$open H=$high L=$low C=$close V=$volume)';
}
