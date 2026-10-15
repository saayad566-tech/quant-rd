/// Market regions and strict cross-market isolation.
///
/// When the active region is India, the app evaluates and lists Indian
/// instruments only. When it is the United States, only US instruments. Crypto
/// pairs are region-neutral and are allowed everywhere (they are not a national
/// equity listing), which is stated rather than hidden.
library;

enum MarketRegion {
  india(
    label: 'India',
    exchanges: 'NSE / BSE',
    currency: '\u20b9',
    benchmark: '^NSEI',
    sampleSymbols: [
      'RELIANCE.NS', 'TCS.NS', 'HDFCBANK.NS', 'INFY.NS', 'ICICIBANK.NS',
      'SBIN.NS', 'BHARTIARTL.NS', 'ITC.NS', 'LT.NS', 'HINDUNILVR.NS',
      'AXISBANK.NS', 'KOTAKBANK.NS', 'MARUTI.NS', 'TITAN.NS', 'SUNPHARMA.NS',
      '^NSEI', '^BSESN',
    ],
  ),
  unitedStates(
    label: 'United States',
    exchanges: 'NASDAQ / NYSE',
    currency: r'$',
    benchmark: '^GSPC',
    sampleSymbols: [
      'AAPL', 'MSFT', 'NVDA', 'AMZN', 'GOOGL',
      'META', 'TSLA', 'AVGO', 'JPM', 'XOM',
      'UNH', 'V', 'COST', 'LLY', 'AMD',
      '^GSPC', '^IXIC',
    ],
  ),
  global(
    label: 'Global',
    exchanges: 'Multiple',
    currency: r'$',
    benchmark: '^GSPC',
    sampleSymbols: [],
  );

  const MarketRegion({
    required this.label,
    required this.exchanges,
    required this.currency,
    required this.benchmark,
    required this.sampleSymbols,
  });

  final String label;
  final String exchanges;
  final String currency;
  final String benchmark;
  final List<String> sampleSymbols;

  /// True when [symbol] belongs to this region. Crypto is region-neutral.
  bool allows(String symbol) {
    final s = symbol.trim().toUpperCase();
    if (s.isEmpty) return false;
    if (isRegionNeutral(s)) return true;
    switch (this) {
      case MarketRegion.india:
        return s.endsWith('.NS') || s.endsWith('.BO') || s.startsWith('^NSE') || s.startsWith('^BSE');
      case MarketRegion.unitedStates:
        return !s.endsWith('.NS') &&
            !s.endsWith('.BO') &&
            !s.startsWith('^NSE') &&
            !s.startsWith('^BSE') &&
            !s.endsWith('.L') &&
            !s.endsWith('.TO') &&
            !s.endsWith('.HK');
      case MarketRegion.global:
        return true;
    }
  }

  /// Crypto pairs and other non-national instruments.
  static bool isRegionNeutral(String symbol) {
    final s = symbol.toUpperCase();
    return s.contains('-USD') || s.endsWith('USDT') || s.endsWith('-EUR') || s.endsWith('-INR');
  }

  /// Filters a symbol list to this region. This is the single funnel every
  /// listing in the app passes through, so cross-market leakage cannot occur.
  List<String> filter(Iterable<String> symbols) =>
      symbols.where(allows).toList(growable: false);

  static MarketRegion fromId(String? id) =>
      MarketRegion.values.firstWhere((r) => r.name == id, orElse: () => MarketRegion.india);
}
