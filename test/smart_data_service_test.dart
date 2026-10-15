import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/core/result.dart';
import 'package:quant_rd/data/models/api_provider.dart';
import 'package:quant_rd/data/models/candle.dart';
import 'package:quant_rd/data/models/dataset.dart';
import 'package:quant_rd/data/remote/market_data_client.dart';
import 'package:quant_rd/data/services/smart_data_service.dart';
import 'package:quant_rd/data/storage/app_database_web.dart';
import 'package:quant_rd/data/storage/repositories.dart';
import 'package:quant_rd/data/storage/secret_store.dart';

Candle candle(int i) => Candle(
      time: DateTime.utc(2020, 1, 1).add(Duration(days: i)),
      open: 1,
      high: 2,
      low: 0.5,
      close: 1.5,
      volume: 10,
    );

/// A stand-in client that succeeds only for the providers in [working].
class FakeClient extends MarketDataClient {
  final Set<ApiProvider> working;
  final List<ApiProvider> attempted = [];

  FakeClient(this.working) : super();

  @override
  Future<List<Candle>> fetch({
    required ApiProvider provider,
    required String apiKey,
    required String symbol,
    required BarInterval interval,
    int outputSize = 5000,
    String? customUrl,
  }) async {
    attempted.add(provider);
    if (!working.contains(provider)) {
      throw MarketDataException(ErrorKind.network, 'simulated failure for ${provider.label}');
    }
    return [candle(0), candle(1)];
  }
}

void main() {
  const ws = 'ws-test';
  late WebAppDatabase db;
  late DatasetRepository datasets;
  late InMemorySecretStore secrets;

  setUp(() async {
    db = WebAppDatabase();
    await db.open();
    datasets = DatasetRepository(db);
    secrets = InMemorySecretStore();
  });

  SmartDataService svc(FakeClient client) =>
      SmartDataService(datasets: datasets, secrets: secrets, client: client);

  test('uses the local cache when the symbol is already stored', () async {
    await datasets.save(
      workspaceId: ws,
      symbol: 'AAPL',
      interval: BarInterval.d1,
      source: DataSource.yahooFinance,
      candles: [candle(0), candle(1), candle(2)],
    );
    final client = FakeClient({ApiProvider.yahoo});
    final res = await svc(client).resolve(workspaceId: ws, symbol: 'aapl', interval: BarInterval.d1);
    expect(res.fromCache, isTrue);
    expect(res.candles.length, 3);
    expect(client.attempted, isEmpty, reason: 'a cache hit must not touch the network');
    expect(res.notes.join(' ').toLowerCase(), contains('local cache'));
  });

  test('falls through to the first working free source', () async {
    final client = FakeClient({ApiProvider.yahoo, ApiProvider.binance});
    final res = await svc(client).resolve(workspaceId: ws, symbol: 'MSFT', interval: BarInterval.d1);
    expect(res.fromCache, isFalse);
    expect(client.attempted.first, ApiProvider.yahoo);
    expect(res.notes.join(' ').toLowerCase(), contains('free'));
  });

  test('falls back to the next source when the first fails', () async {
    final client = FakeClient({ApiProvider.binance}); // yahoo will throw
    final res = await svc(client).resolve(workspaceId: ws, symbol: 'BTC-USD', interval: BarInterval.d1);
    expect(client.attempted, [ApiProvider.yahoo, ApiProvider.binance]);
    expect(res.dataset.source, DataSource.binance);
  });

  test('uses a keyed provider when the free sources fail', () async {
    await secrets.write('apikey.alphavantage', 'demo-key');
    final client = FakeClient({ApiProvider.alphaVantage});
    final res = await svc(client).resolve(workspaceId: ws, symbol: 'TSLA', interval: BarInterval.d1);
    expect(res.dataset.source, DataSource.alphaVantage);
    expect(res.notes.join(' ').toLowerCase(), contains('api key'));
  });

  test('fetched data is cached, so the next call needs no network', () async {
    final client = FakeClient({ApiProvider.yahoo});
    await svc(client).resolve(workspaceId: ws, symbol: 'NVDA', interval: BarInterval.d1);
    final callsAfterFirst = client.attempted.length;
    final second = await svc(client).resolve(workspaceId: ws, symbol: 'NVDA', interval: BarInterval.d1);
    expect(second.fromCache, isTrue);
    expect(client.attempted.length, callsAfterFirst);
  });

  test('throws a helpful error when nothing works', () async {
    final client = FakeClient({});
    await expectLater(
      svc(client).resolve(workspaceId: ws, symbol: 'NOPE', interval: BarInterval.d1),
      throwsA(isA<MarketDataException>()),
    );
  });

  test('an empty symbol is rejected', () async {
    final client = FakeClient({ApiProvider.yahoo});
    await expectLater(
      svc(client).resolve(workspaceId: ws, symbol: '   ', interval: BarInterval.d1),
      throwsA(isA<MarketDataException>()),
    );
    expect(client.attempted, isEmpty);
  });

  test('workspaces stay isolated for cached data', () async {
    final client = FakeClient({ApiProvider.yahoo});
    await svc(client).resolve(workspaceId: ws, symbol: 'AMD', interval: BarInterval.d1);
    // A different workspace must not see that cache.
    final other = await svc(client).resolve(workspaceId: 'ws-other', symbol: 'AMD', interval: BarInterval.d1);
    expect(other.fromCache, isFalse);
  });
}
