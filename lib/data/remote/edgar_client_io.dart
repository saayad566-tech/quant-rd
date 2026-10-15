/// dart:io SEC EDGAR client.
library;

import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/fundamentals.dart';
import 'edgar_client.dart';

class IoEdgarClient implements EdgarClient {
  final Dio _dio;
  IoEdgarClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 60),
            ));

  Map<String, String> _headers(String userAgent) => {
        'User-Agent': userAgent.trim().isEmpty ? EdgarClient.defaultUserAgent : userAgent.trim(),
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip, deflate',
      };

  @override
  bool get supported => true;

  @override
  Future<String?> resolveCik(String ticker) async {
    final t = ticker.trim().toUpperCase();
    if (t.isEmpty) return null;
    try {
      final res = await _dio.get<dynamic>(
        'https://www.sec.gov/files/company_tickers.json',
        options: Options(headers: _headers(EdgarClient.defaultUserAgent)),
      );
      final data = res.data;
      final map = data is String ? jsonDecode(data) : data;
      if (map is! Map) return null;
      for (final v in map.values) {
        if (v is! Map) continue;
        if ('${v['ticker']}'.toUpperCase() == t) {
          final cik = (v['cik_str'] as num?)?.toInt();
          if (cik == null) return null;
          return cik.toString().padLeft(10, '0');
        }
      }
      return null;
    } on DioException {
      return null;
    }
  }

  @override
  Future<FundamentalSnapshot> fetchFundamentals(String ticker, {required String userAgent}) async {
    final cik = await resolveCik(ticker);
    if (cik == null) {
      throw DataFeedUnavailable('SEC EDGAR', 'No CIK is registered for ticker "$ticker".');
    }
    try {
      final res = await _dio.get<dynamic>(
        'https://data.sec.gov/api/xbrl/companyfacts/CIK$cik.json',
        options: Options(headers: _headers(userAgent)),
      );
      final data = res.data;
      final map = data is String ? jsonDecode(data) as Map<String, dynamic> : (data as Map).cast<String, dynamic>();
      return EdgarParser.parseCompanyFacts(symbol: ticker.toUpperCase(), cik: cik, json: map);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 403 || code == 429) {
        throw DataFeedUnavailable('SEC EDGAR', 'The SEC refused the request ($code). Set a descriptive User-Agent in Configs.');
      }
      throw DataFeedUnavailable('SEC EDGAR', e.message ?? 'network error');
    }
  }
}
