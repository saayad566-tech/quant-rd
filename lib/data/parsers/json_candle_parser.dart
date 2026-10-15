/// Robust JSON candle parser.
///
/// Accepts the shapes people actually have on hand:
///  * an array of objects — `[{"date":..., "open":..., "high":..., "low":..., "close":..., "volume":...}]`
///  * an array of arrays — `[[time, open, high, low, close, volume], ...]`
///  * an object wrapping any of the above under `data` / `values` / `candles` / `result` / `rows` / `klines`
///  * a raw **Yahoo Finance** chart response (paste it straight in)
///  * a raw **Binance** klines array
library;

import 'dart:convert';

import '../models/candle.dart';
import 'csv_candle_parser.dart';
import 'parse_report.dart';

class JsonCandleParser {
  const JsonCandleParser._();

  static const List<String> _wrapperKeys = ['data', 'values', 'candles', 'result', 'rows', 'klines', 'ohlcv', 'bars'];

  static CandleParseReport parse(String content) {
    final warnings = <String>[];
    dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (e) {
      return CandleParseReport(
        candles: const [],
        totalRows: 0,
        skippedRows: 0,
        warnings: ['This does not look like valid JSON.'],
        detectedColumns: const [],
      );
    }

    // Yahoo Finance chart response.
    if (decoded is Map && decoded['chart'] is Map) {
      return _parseYahoo(decoded['chart'] as Map, warnings);
    }

    final rows = _extractRows(decoded, warnings);
    if (rows == null || rows.isEmpty) {
      return CandleParseReport(
        candles: const [],
        totalRows: 0,
        skippedRows: 0,
        warnings: [...warnings, 'No candle array was found in the JSON.'],
        detectedColumns: const [],
      );
    }

    final candles = <Candle>[];
    var skipped = 0;
    for (final row in rows) {
      final candle = _rowToCandle(row);
      if (candle == null) {
        skipped++;
      } else {
        candles.add(candle);
      }
    }

    final (deduped, dedupeWarnings) = _finalise(candles);
    warnings.addAll(dedupeWarnings);
    if (skipped > 0) warnings.add('$skipped row(s) skipped as malformed.');

    return CandleParseReport(
      candles: deduped,
      totalRows: rows.length,
      skippedRows: skipped,
      warnings: warnings,
      detectedColumns: const ['time', 'open', 'high', 'low', 'close', 'volume'],
      sourceLabel: 'JSON',
    );
  }

  static List<dynamic>? _extractRows(dynamic decoded, List<String> warnings) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      for (final key in _wrapperKeys) {
        final v = decoded[key];
        if (v is List) return v;
        if (v is Map) {
          final nested = _extractRows(v, warnings);
          if (nested != null) return nested;
        }
      }
    }
    return null;
  }

  static CandleParseReport _parseYahoo(Map chart, List<String> warnings) {
    final err = chart['error'];
    if (err != null) {
      final msg = err is Map ? (err['description'] ?? 'unknown error') : err.toString();
      return CandleParseReport(
        candles: const [],
        totalRows: 0,
        skippedRows: 0,
        warnings: ['Yahoo Finance error: $msg'],
        detectedColumns: const [],
      );
    }
    final results = chart['result'];
    if (results is! List || results.isEmpty) {
      return CandleParseReport(
        candles: const [],
        totalRows: 0,
        skippedRows: 0,
        warnings: ['Yahoo Finance response contained no results.'],
        detectedColumns: const [],
      );
    }
    final r0 = results.first;
    if (r0 is! Map) {
      return CandleParseReport(
        candles: const [],
        totalRows: 0,
        skippedRows: 0,
        warnings: ['Unexpected Yahoo Finance structure.'],
        detectedColumns: const [],
      );
    }
    final timestamps = (r0['timestamp'] as List?) ?? const [];
    final indicators = r0['indicators'];
    if (indicators is! Map) {
      return CandleParseReport(
        candles: const [],
        totalRows: 0,
        skippedRows: 0,
        warnings: ['Yahoo Finance response had no indicators.'],
        detectedColumns: const [],
      );
    }
    final quotes = indicators['quote'];
    if (quotes is! List || quotes.isEmpty) {
      return CandleParseReport(
        candles: const [],
        totalRows: 0,
        skippedRows: 0,
        warnings: ['Yahoo Finance response had no quotes.'],
        detectedColumns: const [],
      );
    }
    final quote = quotes.first;
    if (quote is! Map) {
      return CandleParseReport(
        candles: const [],
        totalRows: 0,
        skippedRows: 0,
        warnings: ['Unexpected Yahoo Finance quote structure.'],
        detectedColumns: const [],
      );
    }
    final opens = quote['open'] as List?;
    final highs = quote['high'] as List?;
    final lows = quote['low'] as List?;
    final closes = quote['close'] as List?;
    final volumes = quote['volume'] as List?;

    final candles = <Candle>[];
    for (var i = 0; i < timestamps.length; i++) {
      final t = timestamps[i];
      final time = t is num ? DateTime.fromMillisecondsSinceEpoch(t.toInt() * 1000, isUtc: true) : null;
      if (time == null) continue;
      final o = _num(opens, i);
      final h = _num(highs, i);
      final l = _num(lows, i);
      final c = _num(closes, i);
      if (o == null || h == null || l == null || c == null) continue;
      candles.add(Candle(time: time, open: o, high: h, low: l, close: c, volume: _num(volumes, i) ?? 0));
    }
    final (deduped, dedupeWarnings) = _finalise(candles);
    warnings.addAll(dedupeWarnings);
    return CandleParseReport(
      candles: deduped,
      totalRows: timestamps.length,
      skippedRows: timestamps.length - candles.length,
      warnings: warnings,
      detectedColumns: const ['time', 'open', 'high', 'low', 'close', 'volume'],
      sourceLabel: 'Yahoo Finance JSON',
    );
  }

  static double? _num(List? list, int i) {
    if (list == null || i >= list.length) return null;
    final v = list[i];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return double.tryParse(s);
  }

  static Candle? _rowToCandle(dynamic row) {
    if (row is List) {
      if (row.length < 5) return null;
      final time = _time(row[0]);
      final o = _d(row[1]);
      final h = _d(row[2]);
      final l = _d(row[3]);
      final c = _d(row[4]);
      final v = row.length > 5 ? _d(row[5]) ?? 0 : 0.0;
      if (time == null || o == null || h == null || l == null || c == null) return null;
      return Candle(time: time, open: o, high: h, low: l, close: c, volume: v);
    }
    if (row is Map) {
      final m = row.cast<String, dynamic>();
      final time = _time(m['time'] ?? m['date'] ?? m['datetime'] ?? m['timestamp'] ?? m['t'] ?? m['openTime'] ?? m['open_time']);
      final o = _d(m['open'] ?? m['o']);
      final h = _d(m['high'] ?? m['h']);
      final l = _d(m['low'] ?? m['l']);
      final c = _d(m['close'] ?? m['c']);
      final v = _d(m['volume'] ?? m['v']) ?? 0;
      if (time == null || o == null || h == null || l == null || c == null) return null;
      return Candle(time: time, open: o, high: h, low: l, close: c, volume: v);
    }
    return null;
  }

  static DateTime? _time(dynamic v) {
    if (v == null) return null;
    if (v is num) {
      final n = v.toInt();
      return DateTime.fromMillisecondsSinceEpoch(n > 1e12 ? n : n * 1000, isUtc: true);
    }
    final s = v.toString().trim();
    final n = int.tryParse(s);
    if (n != null) return DateTime.fromMillisecondsSinceEpoch(n > 1e12 ? n : n * 1000, isUtc: true);
    return CsvCandleParser.parseTimestamp(s);
  }

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return double.tryParse(s);
  }

  static (List<Candle>, List<String>) _finalise(List<Candle> candles) {
    final warnings = <String>[];
    candles.sort((a, b) => a.time.compareTo(b.time));
    final deduped = <Candle>[];
    for (final c in candles) {
      if (deduped.isNotEmpty && deduped.last.time == c.time) {
        deduped[deduped.length - 1] = c;
      } else {
        deduped.add(c);
      }
    }
    return (deduped, warnings);
  }
}
