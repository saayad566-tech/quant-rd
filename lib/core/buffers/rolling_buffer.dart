/// A bounded, rolling buffer with a hard capacity cap.
///
/// Live data feeds grow without limit; an unbounded list is the classic memory
/// leak in a charting/streaming app. This buffer enforces a maximum size by
/// evicting the oldest items first, so memory use is flat regardless of how long
/// the feed runs.
library;

import '../../data/models/candle.dart';

class RollingBuffer<T> {
  final int capacity;
  final List<T> _items;

  RollingBuffer({this.capacity = 5000}) : _items = <T>[] {
    if (capacity <= 0) {
      throw ArgumentError.value(capacity, 'capacity', 'must be greater than zero');
    }
  }

  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  bool get isFull => _items.length >= capacity;

  /// The oldest item, or null when empty.
  T? get first => _items.isEmpty ? null : _items.first;

  /// The newest item, or null when empty.
  T? get last => _items.isEmpty ? null : _items.last;

  /// A read-only view of the current contents, oldest first.
  List<T> get items => List<T>.unmodifiable(_items);

  /// Appends one item, evicting the oldest if the cap is reached.
  void add(T item) {
    _items.add(item);
    if (_items.length > capacity) {
      _items.removeRange(0, _items.length - capacity);
    }
  }

  /// Appends many items under the same cap.
  void addAll(Iterable<T> values) {
    for (final v in values) {
      add(v);
    }
  }

  void clear() => _items.clear();

  /// A defensive copy for handing to a consumer (e.g. a chart).
  List<T> snapshot() => List<T>.of(_items);
}

/// A rolling buffer specialised for candles, capped at the app-wide limit.
class RollingCandleBuffer {
  final RollingBuffer<Candle> _buffer;

  RollingCandleBuffer({int capacity = 5000}) : _buffer = RollingBuffer<Candle>(capacity: capacity);

  int get capacity => _buffer.capacity;
  int get length => _buffer.length;
  bool get isEmpty => _buffer.isEmpty;
  bool get isFull => _buffer.isFull;
  Candle? get first => _buffer.first;
  Candle? get last => _buffer.last;
  List<Candle> get candles => _buffer.items;

  void add(Candle candle) => _buffer.add(candle);

  /// Appends a batch, keeping only the newest [capacity] candles.
  void addAll(Iterable<Candle> candles) => _buffer.addAll(candles);

  void clear() => _buffer.clear();

  List<Candle> snapshot() => _buffer.snapshot();

  /// The highest high and lowest low currently buffered — handy for scaling a
  /// chart without a second pass over the source data.
  (double, double)? get range {
    if (_buffer.isEmpty) return null;
    var hi = double.negativeInfinity;
    var lo = double.infinity;
    for (final c in _buffer._items) {
      if (c.high > hi) hi = c.high;
      if (c.low < lo) lo = c.low;
    }
    return (hi, lo);
  }
}
