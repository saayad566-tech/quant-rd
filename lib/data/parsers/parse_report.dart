/// A shared parse report returned by every data parser (CSV, JSON).
library;

import '../models/candle.dart';

class CandleParseReport {
  final List<Candle> candles;
  final int totalRows;
  final int skippedRows;
  final List<String> warnings;
  final List<String> detectedColumns;

  /// A short, human description of what was detected (used in status messages).
  final String sourceLabel;

  const CandleParseReport({
    required this.candles,
    required this.totalRows,
    required this.skippedRows,
    required this.warnings,
    required this.detectedColumns,
    this.sourceLabel = '',
  });

  bool get isEmpty => candles.isEmpty;
}
