/// Remote market-data client. Fetches OHLCV history from a user-selected
/// provider using the user's own API key.
///
/// Offline-first: this is entirely optional. The app is fully usable with
/// imported CSV data or bundled samples; network fetching only adds convenience.
library;

import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../core/constants.dart';
import '../../core/result.dart';
import '../models/api_provider.dart';
import '../models/candle.dart';
import '../models/dataset.dart';

class MarketDataException implements Exception {
  final ErrorKind kind;
  final String message;
  final Object? cause;
  MarketDataException(this.kind, this.message, [this.cause]);
  @override
  String toString() => message;
}

class MarketDataClient {
  final Dio _dio;

  MarketDataClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: AppLimits.networkTimeout,
              receiveTimeout: AppLimits.networkTimeout,
              sendTimeout: AppLimits.networkTimeout,
              responseType: ResponseType.json,
            ));

  /// Fetches candles for [symbol] at [interval] using [provider] + [apiKey].
  /// [customUrl] is required only when [provider] is [ApiProvider.custom].
  Future<List<Candle>> fetch({
    required ApiProvider provider,
    required String apiKey,
    required String symbol,
    required BarInterval interval,
    int outputSize = 5000,
    String? customUrl,
  }) async {
    final cleanSymbol = symbol.trim().toUpperCase();
    if (provider != ApiProvider.custom && apiKey.trim().isEmpty) {
      throw MarketDataException(ErrorKind.auth, 'Add your ${provider.label} API key first.');
    }
    if (cleanSymbol.isEmpty) {
      throw MarketDataException(ErrorKind.validation, 'Enter a symbol to fetch.');
    }

    switch (provider) {
      case ApiProvider.alphaVantage:
        return _fetchAlphaVantage(cleanSymbol, interval, apiKey, outputSize);
      case ApiProvider.twelveData:
        return _fetchTwelveData(cleanSymbol, interval, apiKey, outputSize);
      case ApiProvider.polygon:
        return _fetchPolygon(cleanSymbol, interval, apiKey);
      case ApiProvider.finnhub:
        return _fetchFinnhub(cleanSymbol, interval, apiKey);
      case ApiProvider.custom:
        return _fetchCustom(customUrl ?? apiKey, cleanSymbol, interval);
    }
  }

  // --- Providers ----------------------------------------------------------

  Future<List<Candle>> _fetchAlphaVantage(String symbol, BarInterval interval, String key, int size) async {
    String function;
    final query = <String, dynamic>{'symbol': symbol, 'apikey': key, 'outputsize': size > 100 ? 'full' : 'compact'};
    switch (interval) {
      case BarInterval.d1:
        function = 'TIME_SERIES_DAILY';
      case BarInterval.w1:
        function = 'TIME_SERIES_WEEKLY';
      default:
        function = 'TIME_SERIES_INTRADAY';
        query['interval'] = _avIntraday(interval);
    }
    query['function'] = function;
    final res = await _get('${ApiProvider.alphaVantage.baseUrl}/query', query: query);
    final data = res.data;
    if (data is! Map) throw MarketDataException(ErrorKind.parse, 'Unexpected Alpha Vantage response.');
    final map = data.cast<String, dynamic>();
    if (map.containsKey('Note')) {
      throw MarketDataException(ErrorKind.rateLimit, 'Alpha Vantage rate limit reached. Try later.');
    }
    if (map.containsKey('Information')) {
      throw MarketDataException(ErrorKind.auth, 'Alpha Vantage: ${map['Information']}');
    }
    if (map.containsKey('Error Message')) {
      throw MarketDataException(ErrorKind.validation, 'Alpha Vantage: ${map['Error Message']}');
    }
    final seriesKey = map.keys.firstWhere((k) => k.toLowerCase().contains('time series'), orElse: () => '');
    if (seriesKey.isEmpty || map[seriesKey] is! Map) {
      throw MarketDataException(ErrorKind.parse, 'No time series returned for $symbol.');
    }
    final series = (map[seriesKey] as Map).cast<String, dynamic>();
    final candles = <Candle>[];
    series.forEach((date, v) {
      final row = (v as Map).cast<String, dynamic>();
      final t = DateTime.tryParse(date);
      final open = _d(row['1. open']);
      final high = _d(row['2. high']);
      final low = _d(row['3. low']);
      final close = _d(row['4. close']);
      final vol = _d(row['5. volume']) ?? 0;
      if (t != null && open != null && high != null && low != null && close != null) {
        candles.add(Candle(time: t.toUtc(), open: open, high: high, low: low, close: close, volume: vol));
      }
    });
    return _finalise(candles, symbol);
  }

  String _avIntraday(BarInterval interval) {
    switch (interval) {
      case BarInterval.m1:
        return '1min';
      case BarInterval.m5:
        return '5min';
      case BarInterval.m15:
        return '15min';
      case BarInterval.m30:
        return '30min';
      case BarInterval.h1:
      case BarInterval.h4:
        return '60min';
      default:
        return '60min';
    }
  }

  Future<List<Candle>> _fetchTwelveData(String symbol, BarInterval interval, String key, int size) async {
    final res = await _get('${ApiProvider.twelveData.baseUrl}/time_series', query: {
      'symbol': symbol,
      'interval': _twelveInterval(interval),
      'outputsize': size,
      'apikey': key,
    });
    final data = res.data;
    if (data is! Map) throw MarketDataException(ErrorKind.parse, 'Unexpected Twelve Data response.');
    final map = data.cast<String, dynamic>();
    if (map['status'] == 'error') {
      final code = map['code'];
      throw MarketDataException(code == 429 ? ErrorKind.rateLimit : ErrorKind.auth, 'Twelve Data: ${map['message'] ?? 'error'}');
    }
    final values = map['values'];
    if (values is! List) throw MarketDataException(ErrorKind.parse, 'No values returned for $symbol.');
    final candles = <Candle>[];
    for (final v in values) {
      final row = (v as Map).cast<String, dynamic>();
      final t = DateTime.tryParse(row['datetime']?.toString() ?? '');
      final open = _d(row['open']);
      final high = _d(row['high']);
      final low = _d(row['low']);
      final close = _d(row['close']);
      final vol = _d(row['volume']) ?? 0;
      if (t != null && open != null && high != null && low != null && close != null) {
        candles.add(Candle(time: t.toUtc(), open: open, high: high, low: low, close: close, volume: vol));
      }
    }
    return _finalise(candles, symbol);
  }

  String _twelveInterval(BarInterval interval) {
    switch (interval) {
      case BarInterval.m1:
        return '1min';
      case BarInterval.m5:
        return '5min';
      case BarInterval.m15:
        return '15min';
      case BarInterval.m30:
        return '30min';
      case BarInterval.h1:
        return '1h';
      case BarInterval.h4:
        return '4h';
      case BarInterval.d1:
        return '1day';
      case BarInterval.w1:
        return '1week';
    }
  }

  Future<List<Candle>> _fetchPolygon(String symbol, BarInterval interval, String key) async {
    final (mult, span) = _polygonRange(interval);
    final to = DateTime.now().toUtc();
    final from = to.subtract(_lookback(interval, 5000));
    final url = '${ApiProvider.polygon.baseUrl}/v2/aggs/ticker/$symbol/range/$mult/$span/${_isoDate(from)}/${_isoDate(to)}';
    final res = await _get(url, query: {'adjusted': 'true', 'sort': 'asc', 'limit': 50000, 'apiKey': key});
    final data = res.data;
    if (data is! Map) throw MarketDataException(ErrorKind.parse, 'Unexpected Polygon response.');
    final map = data.cast<String, dynamic>();
    if (map['status'] == 'ERROR' || map['error'] != null) {
      throw MarketDataException(ErrorKind.validation, 'Polygon: ${map['error'] ?? 'request failed'}');
    }
    final results = map['results'];
    if (results is! List || results.isEmpty) {
      throw MarketDataException(ErrorKind.notFound, 'No data returned for $symbol.');
    }
    final candles = <Candle>[];
    for (final r in results) {
      final row = (r as Map).cast<String, dynamic>();
      final t = _d(row['t']);
      final open = _d(row['o']);
      final high = _d(row['h']);
      final low = _d(row['l']);
      final close = _d(row['c']);
      final vol = _d(row['v']) ?? 0;
      if (t != null && open != null && high != null && low != null && close != null) {
        candles.add(Candle(
          time: DateTime.fromMillisecondsSinceEpoch(t.toInt(), isUtc: true),
          open: open,
          high: high,
          low: low,
          close: close,
          volume: vol,
        ));
      }
    }
    return _finalise(candles, symbol);
  }

  (int, String) _polygonRange(BarInterval interval) {
    switch (interval) {
      case BarInterval.m1:
        return (1, 'minute');
      case BarInterval.m5:
        return (5, 'minute');
      case BarInterval.m15:
        return (15, 'minute');
      case BarInterval.m30:
        return (30, 'minute');
      case BarInterval.h1:
        return (1, 'hour');
      case BarInterval.h4:
        return (4, 'hour');
      case BarInterval.d1:
        return (1, 'day');
      case BarInterval.w1:
        return (1, 'week');
    }
  }

  Future<List<Candle>> _fetchFinnhub(String symbol, BarInterval interval, String key) async {
    final now = DateTime.now().toUtc();
    final from = now.subtract(_lookback(interval, 5000));
    final res = await _get('${ApiProvider.finnhub.baseUrl}/api/v1/stock/candle', query: {
      'symbol': symbol,
      'resolution': _finnhubResolution(interval),
      'from': from.millisecondsSinceEpoch ~/ 1000,
      'to': now.millisecondsSinceEpoch ~/ 1000,
      'token': key,
    });
    final data = res.data;
    if (data is! Map) throw MarketDataException(ErrorKind.parse, 'Unexpected Finnhub response.');
    final map = data.cast<String, dynamic>();
    if (map['s'] != 'ok') {
      throw MarketDataException(ErrorKind.auth, 'Finnhub returned no data (free plans may not include stock candles).');
    }
    final closes = (map['c'] as List?) ?? const [];
    final opens = (map['o'] as List?) ?? const [];
    final highs = (map['h'] as List?) ?? const [];
    final lows = (map['l'] as List?) ?? const [];
    final vols = (map['v'] as List?) ?? const [];
    final times = (map['t'] as List?) ?? const [];
    final candles = <Candle>[];
    for (var i = 0; i < times.length; i++) {
      candles.add(Candle(
        time: DateTime.fromMillisecondsSinceEpoch((times[i] as num).toInt() * 1000, isUtc: true),
        open: _d(opens[i]) ?? 0,
        high: _d(highs[i]) ?? 0,
        low: _d(lows[i]) ?? 0,
        close: _d(closes[i]) ?? 0,
        volume: _d(i < vols.length ? vols[i] : 0) ?? 0,
      ));
    }
    return _finalise(candles, symbol);
  }

  String _finnhubResolution(BarInterval interval) {
    switch (interval) {
      case BarInterval.m1:
        return '1';
      case BarInterval.m5:
        return '5';
      case BarInterval.m15:
        return '15';
      case BarInterval.m30:
        return '30';
      case BarInterval.h1:
      case BarInterval.h4:
        return '60';
      case BarInterval.d1:
        return 'D';
      case BarInterval.w1:
        return 'W';
    }
  }

  Future<List<Candle>> _fetchCustom(String url, String symbol, BarInterval interval) async {
    if (url.trim().isEmpty || !url.startsWith('http')) {
      throw MarketDataException(ErrorKind.validation, 'Enter a valid custom endpoint URL.');
    }
    final res = await _get(url, query: {'symbol': symbol, 'interval': interval.code});
    final data = res.data;
    final List<dynamic> rows;
    if (data is List) {
      rows = data;
    } else if (data is Map && data['data'] is List) {
      rows = data['data'] as List;
    } else {
      throw MarketDataException(ErrorKind.parse, 'Custom endpoint must return a JSON array of OHLCV objects.');
    }
    final candles = <Candle>[];
    for (final r in rows) {
      if (r is! Map) continue;
      final row = r.cast<String, dynamic>();
      final timeRaw = row['time'] ?? row['date'] ?? row['timestamp'] ?? row['t'];
      final t = _parseTime(timeRaw);
      final open = _d(row['open'] ?? row['o']);
      final high = _d(row['high'] ?? row['h']);
      final low = _d(row['low'] ?? row['l']);
      final close = _d(row['close'] ?? row['c']);
      final vol = _d(row['volume'] ?? row['v']) ?? 0;
      if (t != null && open != null && high != null && low != null && close != null) {
        candles.add(Candle(time: t, open: open, high: high, low: low, close: close, volume: vol));
      }
    }
    return _finalise(candles, symbol);
  }

  // --- Helpers ------------------------------------------------------------

  Future<Response<dynamic>> _get(String url, {Map<String, dynamic>? query}) async {
    Object? lastError;
    for (var attempt = 0; attempt <= AppLimits.maxNetworkRetries; attempt++) {
      try {
        return await _dio.get<dynamic>(url, queryParameters: query);
      } on DioException catch (e) {
        lastError = e;
        if (!_retryable(e) || attempt == AppLimits.maxNetworkRetries) break;
        final backoff = AppLimits.retryBaseDelay * math.pow(2, attempt) +
            Duration(milliseconds: math.Random().nextInt(250));
        await Future<void>.delayed(backoff);
      }
    }
    throw _translate(lastError);
  }

  bool _retryable(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        return code == 429 || code >= 500;
      default:
        return false;
    }
  }

  MarketDataException _translate(Object? error) {
    if (error is! DioException) {
      return MarketDataException(ErrorKind.unknown, 'Request failed.', error);
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return MarketDataException(ErrorKind.timeout, ErrorKind.timeout.message, error);
      case DioExceptionType.connectionError:
        return MarketDataException(ErrorKind.network, ErrorKind.network.message, error);
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode ?? 0;
        if (code == 401 || code == 403) return MarketDataException(ErrorKind.auth, ErrorKind.auth.message, error);
        if (code == 429) return MarketDataException(ErrorKind.rateLimit, ErrorKind.rateLimit.message, error);
        if (code == 404) return MarketDataException(ErrorKind.notFound, ErrorKind.notFound.message, error);
        return MarketDataException(ErrorKind.network, 'Server error ($code).', error);
      default:
        return MarketDataException(ErrorKind.unknown, ErrorKind.unknown.message, error);
    }
  }

  Duration _lookback(BarInterval interval, int bars) => interval.duration * bars;

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<Candle> _finalise(List<Candle> candles, String symbol) {
    if (candles.isEmpty) {
      throw MarketDataException(ErrorKind.notFound, 'No candles returned for $symbol.');
    }
    candles.sort((a, b) => a.time.compareTo(b.time));
    final deduped = <Candle>[];
    for (final c in candles) {
      if (deduped.isNotEmpty && deduped.last.time == c.time) {
        deduped[deduped.length - 1] = c;
      } else {
        deduped.add(c);
      }
    }
    return deduped;
  }

  DateTime? _parseTime(Object? v) {
    if (v == null) return null;
    if (v is num) {
      final n = v.toInt();
      return DateTime.fromMillisecondsSinceEpoch(n > 1e12 ? n : n * 1000, isUtc: true);
    }
    final s = v.toString();
    final n = int.tryParse(s);
    if (n != null) return DateTime.fromMillisecondsSinceEpoch(n > 1e12 ? n : n * 1000, isUtc: true);
    return DateTime.tryParse(s)?.toUtc();
  }

  double? _d(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
