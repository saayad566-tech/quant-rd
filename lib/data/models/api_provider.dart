/// Supported market-data providers. Each carries the metadata the API-keys
/// screen needs to guide the user, and the request details the client uses.
library;

enum ApiProvider {
  alphaVantage(
    id: 'alphavantage',
    label: 'Alpha Vantage',
    baseUrl: 'https://www.alphavantage.co',
    keyHelp: 'Free key, 25 requests/day on the free tier.',
    signupUrl: 'https://www.alphavantage.co/support/#api-key',
  ),
  twelveData(
    id: 'twelvedata',
    label: 'Twelve Data',
    baseUrl: 'https://api.twelvedata.com',
    keyHelp: 'Free key, 8 requests/minute and 800/day.',
    signupUrl: 'https://twelvedata.com/pricing',
  ),
  polygon(
    id: 'polygon',
    label: 'Polygon.io',
    baseUrl: 'https://api.polygon.io',
    keyHelp: 'Free key, 5 requests/minute, end-of-day data.',
    signupUrl: 'https://polygon.io/dashboard/signup',
  ),
  finnhub(
    id: 'finnhub',
    label: 'Finnhub',
    baseUrl: 'https://finnhub.io',
    keyHelp: 'Free key, 60 requests/minute. Stock candles may require a paid plan.',
    signupUrl: 'https://finnhub.io/register',
  ),
  custom(
    id: 'custom',
    label: 'Custom endpoint',
    baseUrl: '',
    keyHelp: 'A GET endpoint returning a JSON array of OHLCV objects.',
    signupUrl: '',
  );

  const ApiProvider({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.keyHelp,
    required this.signupUrl,
  });

  final String id;
  final String label;
  final String baseUrl;
  final String keyHelp;
  final String signupUrl;

  static ApiProvider fromId(String id) =>
      ApiProvider.values.firstWhere((e) => e.id == id, orElse: () => ApiProvider.alphaVantage);
}
