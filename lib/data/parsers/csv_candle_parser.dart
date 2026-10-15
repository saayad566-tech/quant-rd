/// Robust OHLCV CSV parser.
///
/// Handles comma / semicolon / tab / pipe delimiters, an optional header row,
/// multiple date formats, quoted fields and malformed rows (which are skipped
/// and reported rather than silently dropped or fatal).
library;

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../models/candle.dart';

class CsvParseReport {
  final List<Candle> candles;
  final int totalRows;
  final int skippedRows;
  final List<String> warnings;
  final List<String> detectedColumns;

  const CsvParseReport({
    required this.candles,
    required this.totalRows,
    required this.skippedRows,
    required this.warnings,
    required this.detectedColumns,
  });

  bool get isEmpty => candles.isEmpty;
}

class CsvCandleParser {
  const CsvCandleParser._();

  static const List<String> _dateAliases = [
    'date', 'datetime', 'time', 'timestamp', 'day', 'open_time', 'opentime', 'period', 'index',
  ];
  static const List<String> _openAliases = ['open', 'o', 'openprice'];
  static const List<String> _highAliases = ['high', 'h', 'highprice'];
  static const List<String> _lowAliases = ['low', 'l', 'lowprice'];
  static const List<String> _closeAliases = ['close', 'c', 'closeprice', 'last', 'adj close', 'adj_close'];
  static const List<String> _volumeAliases = ['volume', 'v', 'vol', 'basevolume', 'quotevolume'];

  static final List<DateFormat> _dateFormats = [
    DateFormat('yyyy-MM-dd HH:mm:ss'),
    DateFormat('yyyy-MM-dd HH:mm'),
    DateFormat('yyyy-MM-dd'),
    DateFormat('yyyy/MM/dd HH:mm:ss'),
    DateFormat('yyyy/MM/dd'),
    DateFormat('dd-MM-yyyy HH:mm'),
    DateFormat('dd-MM-yyyy'),
    DateFormat('dd/MM/yyyy HH:mm'),
    DateFormat('dd/MM/yyyy'),
    DateFormat('MM/dd/yyyy HH:mm'),
    DateFormat('MM/dd/yyyy'),
  ];

  static CsvParseReport parse(String content) {
    final warnings = <String>[];
    if (content.isEmpty) {
      return const CsvParseReport(candles: [], totalRows: 0, skippedRows: 0, warnings: ['File is empty.'], detectedColumns: []);
    }

    final delimiter = _detectDelimiter(content);
    final rows = Csv(fieldDelimiter: delimiter, autoDetect: false, dynamicTyping: false, skipEmptyLines: true)
        .decode(content.replaceAll('\r\n', '\n').replaceAll('\r', '\n'));
    if (rows.isEmpty) {
      return const CsvParseReport(candles: [], totalRows: 0, skippedRows: 0, warnings: ['No rows found.'], detectedColumns: []);
    }

    final firstRow = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    final hasHeader = _looksLikeHeader(firstRow);

    int iDate = 0, iOpen = 1, iHigh = 2, iLow = 3, iClose = 4, iVolume = 5;
    var detected = <String>['date', 'open', 'high', 'low', 'close', 'volume'];
    var dataStart = 0;

    if (hasHeader) {
      dataStart = 1;
      detected = firstRow;
      iDate = _indexOfAny(firstRow, _dateAliases);
      iOpen = _indexOfAny(firstRow, _openAliases);
      iHigh = _indexOfAny(firstRow, _highAliases);
      iLow = _indexOfAny(firstRow, _lowAliases);
      iClose = _indexOfAny(firstRow, _closeAliases);
      iVolume = _indexOfAny(firstRow, _volumeAliases);
      if (iDate < 0 || iOpen < 0 || iHigh < 0 || iLow < 0 || iClose < 0) {
        warnings.add('Could not identify required columns; assuming order date,open,high,low,close,volume.');
        iDate = 0;
        iOpen = 1;
        iHigh = 2;
        iLow = 3;
        iClose = 4;
        iVolume = 5;
      }
    }

    final candles = <Candle>[];
    var skipped = 0;
    for (var r = dataStart; r < rows.length; r++) {
      final row = rows[r];
      if (row.length <= iClose) {
        skipped++;
        continue;
      }
      try {
        final time = _parseDate(row[iDate].toString().trim());
        if (time == null) {
          skipped++;
          continue;
        }
        final open = _num(row[iOpen]);
        final high = _num(row[iHigh]);
        final low = _num(row[iLow]);
        final close = _num(row[iClose]);
        final volume = (iVolume >= 0 && iVolume < row.length) ? (_num(row[iVolume]) ?? 0) : 0.0;
        if (open == null || high == null || low == null || close == null) {
          skipped++;
          continue;
        }
        candles.add(Candle(time: time, open: open, high: high, low: low, close: close, volume: volume));
      } catch (_) {
        skipped++;
      }
    }

    if (candles.isEmpty) {
      warnings.add('No valid OHLCV rows were found.');
    }

    // Sort ascending and de-duplicate timestamps (keep the last occurrence).
    candles.sort((a, b) => a.time.compareTo(b.time));
    final deduped = <Candle>[];
    for (final c in candles) {
      if (deduped.isNotEmpty && deduped.last.time == c.time) {
        deduped[deduped.length - 1] = c;
      } else {
        deduped.add(c);
      }
    }

    if (skipped > 0) {
      warnings.add('$skipped row(s) skipped as malformed.');
    }
    if (deduped.length > AppLimits.maxCandlesPerDataset) {
      warnings.add('Dataset exceeds the ${AppLimits.maxCandlesPerDataset} candle limit and was truncated.');
    }

    final limited = deduped.length > AppLimits.maxCandlesPerDataset
        ? deduped.sublist(deduped.length - AppLimits.maxCandlesPerDataset)
        : deduped;

    return CsvParseReport(
      candles: limited,
      totalRows: rows.length - dataStart,
      skippedRows: skipped,
      warnings: warnings,
      detectedColumns: detected,
    );
  }

  static String _detectDelimiter(String content) {
    final sample = content.split('\n').take(5).join('\n');
    final counts = {
      ',': sample.split(',').length,
      ';': sample.split(';').length,
      '\t': sample.split('\t').length,
      '|': sample.split('|').length,
    };
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static bool _looksLikeHeader(List<String> row) {
    final alpha = row.where((c) => RegExp(r'[a-zA-Z]').hasMatch(c)).length;
    return alpha >= 2 && !row.any((c) => _parseDate(c) != null);
  }

  static int _indexOfAny(List<String> row, List<String> aliases) {
    for (var i = 0; i < row.length; i++) {
      if (aliases.contains(row[i])) return i;
    }
    return -1;
  }

  static double? _num(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim().replaceAll(',', '');
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  static DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    // Epoch seconds / milliseconds.
    final asInt = int.tryParse(s);
    if (asInt != null) {
      if (s.length >= 13) return DateTime.fromMillisecondsSinceEpoch(asInt, isUtc: true);
      if (s.length >= 10) return DateTime.fromMillisecondsSinceEpoch(asInt * 1000, isUtc: true);
    }
    final iso = DateTime.tryParse(s);
    if (iso != null) {
      final hasTimezone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(s);
      if (hasTimezone) return iso.toUtc();
      // Treat timezone-less timestamps as UTC so results are deterministic.
      return DateTime.utc(iso.year, iso.month, iso.day, iso.hour, iso.minute, iso.second);
    }
    for (final f in _dateFormats) {
      try {
        final d = f.parseStrict(s);
        return DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second);
      } catch (_) {
        // try next format
      }
    }
    return null;
  }
}
