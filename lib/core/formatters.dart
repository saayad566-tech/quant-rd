/// Locale-aware, human-friendly formatting helpers.
library;

import 'package:intl/intl.dart';

class Fmt {
  const Fmt._();

  static final NumberFormat _compact = NumberFormat.compact();
  static final NumberFormat _int = NumberFormat('#,##0');
  static final NumberFormat _dec2 = NumberFormat('#,##0.00');
  static final DateFormat _date = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, HH:mm');

  /// Formats a currency amount with the given symbol (defaults to \u20b9 INR).
  static String money(double value, {String symbol = '\u20b9', int decimals = 2}) {
    final f = NumberFormat.currency(symbol: symbol, decimalDigits: decimals);
    return f.format(value);
  }

  static String moneyCompact(double value, {String symbol = '\u20b9'}) {
    final sign = value < 0 ? '-' : '';
    return '$sign$symbol${_compact.format(value.abs())}';
  }

  static String integer(num value) => _int.format(value);

  static String decimal(double value, [int places = 2]) {
    if (places == 2) return _dec2.format(value);
    return NumberFormat('#,##0.${'#' * places}').format(value);
  }

  static String percent(double value, {int places = 2, bool withSign = false}) {
    final s = '${value.toStringAsFixed(places)}%';
    return withSign && value > 0 ? '+$s' : s;
  }

  static String date(DateTime d) => _date.format(d.toLocal());
  static String dateTime(DateTime d) => _dateTime.format(d.toLocal());

  static String compact(num value) => _compact.format(value);

  static String bytes(int value) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double v = value.toDouble();
    int i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
  }

  /// Masks an API key for display: shows the first 3 and last 3 characters.
  static String maskKey(String key) {
    if (key.isEmpty) return '';
    if (key.length <= 8) return '\u2022' * key.length;
    return '${key.substring(0, 3)}${'\u2022' * 6}${key.substring(key.length - 3)}';
  }
}
