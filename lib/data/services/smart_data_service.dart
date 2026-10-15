/// Smart data ingestion.
///
/// When a user types a symbol, this service does not simply fail if data is
/// missing. It works down a chain of increasingly specific sources and reports
/// exactly what it did in plain English:
///
///   1. **Local cache** — an identical symbol/interval already stored, so repeat
///      backtests are instant and fully offline.
///   2. **Free keyless sources** — Yahoo Finance, then Binance. No key, no
///      sign-up, zero cost.
///   3. **Keyed providers** — any provider the user has saved a key for.
///
/// Whatever it fetches is saved locally, so the next run is a cache hit.
library;

import '../../core/result.dart';
import '../models/api_provider.dart';
import '../models/candle.dart';
import '../models/dataset.dart';
import '../remote/market_data_client.dart';
import '../storage/repositories.dart';
import '../storage/secret_store.dart';

class DataResolution {
  final Dataset dataset;
  final List<Candle> candles;
  final bool fromCache;
  final List<String> notes;

  const DataResolution({
    required this.dataset,
    required this.candles,
    required this.fromCache,
    required this.notes,
  });
}

class SmartDataService {
  final DatasetRepository datasets;
  final SecretStore secrets;
  final MarketDataClient client;

  SmartDataService({required this.datasets, required this.secrets, required this.client});

  Future<DataResolution> resolve({
    required String workspaceId,
    required String symbol,
    required BarInterval interval,
    int outputSize = 5000,
    ApiProvider? preferProvider,
  }) async {
    final notes = <String>[];
    final sym = symbol.trim().toUpperCase();
    if (sym.isEmpty) {
      throw MarketDataException(ErrorKind.validation, 'Enter a symbol to fetch.');
    }

    // 1. Local cache — instant and offline.
    final existing = await datasets.all(workspaceId);
    for (final d in existing) {
      if (d.symbol.toUpperCase() == sym && d.interval == interval) {
        final candles = await datasets.candles(d.id);
        if (candles.isNotEmpty) {
          notes.add('Using local cache: ${candles.length} candles for $sym (${interval.label}) are already stored — no network needed.');
          return DataResolution(dataset: d, candles: candles, fromCache: true, notes: notes);
        }
      }
    }

    final failures = <String>[];

    // If the caller asked for a specific provider, try that first.
    if (preferProvider != null) {
      final res = await _tryProvider(preferProvider, sym, interval, workspaceId, outputSize, notes, failures);
      if (res != null) return res;
    }

    // 2. Free keyless sources (no key required).
    for (final p in ApiProvider.keyless) {
      if (p == preferProvider) continue;
      final res = await _tryProvider(p, sym, interval, workspaceId, outputSize, notes, failures);
      if (res != null) return res;
    }

    // 3. Keyed providers the user has configured.
    for (final p in ApiProvider.keyed) {
      if (p == preferProvider) continue;
      final key = await secrets.read('apikey.${p.id}');
      if (key == null || key.isEmpty) continue;
      final res = await _tryProvider(p, sym, interval, workspaceId, outputSize, notes, failures, apiKey: key);
      if (res != null) return res;
    }

    final detail = failures.isEmpty ? '' : ' Details — ${failures.join(' | ')}';
    throw MarketDataException(
      ErrorKind.notFound,
      'Could not fetch “$sym”.$detail\n'
      'You can still import a CSV or JSON file in Market Data, or add an API key in the API Keys tab.',
    );
  }

  Future<DataResolution?> _tryProvider(
    ApiProvider provider,
    String sym,
    BarInterval interval,
    String workspaceId,
    int outputSize,
    List<String> notes,
    List<String> failures, {
    String apiKey = '',
  }) async {
    try {
      final candles = await client.fetch(
        provider: provider,
        apiKey: apiKey,
        symbol: sym,
        interval: interval,
        outputSize: outputSize,
        customUrl: provider == ApiProvider.custom ? apiKey : null,
      );
      final saved = await datasets.save(
        workspaceId: workspaceId,
        symbol: sym,
        interval: interval,
        source: _sourceFor(provider),
        candles: candles,
        note: 'Auto-fetched from ${provider.label}',
      );
      final dataset = saved.valueOrNull;
      if (dataset == null) return null;
      final free = !provider.requiresKey;
      notes.add(
        'Fetched ${candles.length} candles from ${provider.label}${free ? ' (free, no key needed)' : ' using your saved API key'} '
        'and cached them locally for offline use.',
      );
      return DataResolution(dataset: dataset, candles: candles, fromCache: false, notes: notes);
    } catch (e) {
      failures.add('${provider.label}: ${_short(e)}');
      return null;
    }
  }

  static DataSource _sourceFor(ApiProvider p) {
    switch (p) {
      case ApiProvider.yahoo:
        return DataSource.yahooFinance;
      case ApiProvider.binance:
        return DataSource.binance;
      case ApiProvider.alphaVantage:
        return DataSource.alphaVantage;
      case ApiProvider.twelveData:
        return DataSource.twelveData;
      case ApiProvider.polygon:
        return DataSource.polygon;
      case ApiProvider.finnhub:
        return DataSource.finnhub;
      case ApiProvider.custom:
        return DataSource.custom;
    }
  }

  static String _short(Object e) {
    final s = e.toString().replaceAll('\n', ' ').trim();
    return s.length > 110 ? '${s.substring(0, 110)}\u2026' : s;
  }
}
