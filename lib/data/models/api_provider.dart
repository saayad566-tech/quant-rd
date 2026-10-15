/// Supported market-data providers.
///
/// Two of them — Yahoo Finance and Binance — are **keyless**: they are free
/// public endpoints that need no sign-up, so the app can fetch real historical
/// data the moment a user types a symbol. The rest use the user's own API key.
library;

enum ApiProvider {
  yahoo(
    id: 'yahoo',
    label: 'Yahoo Finance (free)',
    baseUrl: 'https://query1.finance.yahoo.com',
    keyHelp: 'No key needed. Free public endpoint — stocks, ETFs, indices, FX and crypto.',
    signupUrl: '',
    requiresKey: false,
    blurb: 'Stocks, ETFs, indices, FX, crypto',
  ),
  binance(
    id: 'binance',
    label: 'Binance (free)',
    baseUrl: 'https://api.binance.com',
    keyHelp: 'No key needed. Free public crypto OHLCV.',
    signupUrl: '',
    requiresKey: false,
    blurb: 'Crypto pairs (BTCUSDT, ETHUSDT…)',
  ),
  alphaVantage(
    id: 'alphavantage',
    label: 'Alpha Vantage',
    baseUrl: 'https://www.alphavantage.co',
    keyHelp: 'Free key, 25 requests/day on the free tier.',
    signupUrl: 'https://www.alphavantage.co/support/#api-key',
    requiresKey: true,
    blurb: 'Stocks, FX, crypto',
  ),
  twelveData(
    id: 'twelvedata',
    label: 'Twelve Data',
    baseUrl: 'https://api.twelvedata.com',
    keyHelp: 'Free key, 8 requests/minute and 800/day.',
    signupUrl: 'https://twelvedata.com/pricing',
    requiresKey: true,
    blurb: 'Stocks, FX, crypto',
  ),
  polygon(
    id: 'polygon',
    label: 'Polygon.io',
    baseUrl: 'https://api.polygon.io',
    keyHelp: 'Free key, 5 requests/minute, end-of-day data.',
    signupUrl: 'https://polygon.io/dashboard/signup',
    requiresKey: true,
    blurb: 'US stocks',
  ),
  finnhub(
    id: 'finnhub',
    label: 'Finnhub',
    baseUrl: 'https://finnhub.io',
    keyHelp: 'Free key, 60 requests/minute. Stock candles may require a paid plan.',
    signupUrl: 'https://finnhub.io/register',
    requiresKey: true,
    blurb: 'Stocks, FX, crypto',
  ),
  custom(
    id: 'custom',
    label: 'Custom endpoint',
    baseUrl: '',
    keyHelp: 'A GET endpoint returning a JSON array of OHLCV objects.',
    signupUrl: '',
    requiresKey: false,
    blurb: 'Your own URL',
  );

  const ApiProvider({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.keyHelp,
    required this.signupUrl,
    required this.requiresKey,
    required this.blurb,
  });

  final String id;
  final String label;
  final String baseUrl;
  final String keyHelp;
  final String signupUrl;

  /// True when the provider needs the user to supply an API key.
  final bool requiresKey;

  /// Short description of what this provider covers.
  final String blurb;

  /// Providers that need a key (used by the API-keys screen).
  static List<ApiProvider> get keyed => ApiProvider.values.where((p) => p.requiresKey).toList();

  /// Free, keyless providers, tried automatically when fetching a symbol.
  static List<ApiProvider> get keyless => ApiProvider.values.where((p) => !p.requiresKey && p != ApiProvider.custom).toList();

  static ApiProvider fromId(String id) =>
      ApiProvider.values.firstWhere((e) => e.id == id, orElse: () => ApiProvider.yahoo);
}
