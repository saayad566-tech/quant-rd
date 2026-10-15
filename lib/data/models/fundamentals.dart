/// Fundamental data model.
///
/// A snapshot holds only figures that were actually reported in a filing. Any
/// metric that could not be read is listed in [gaps] and is never filled with a
/// fabricated value — the guardrail is that a missing number stays missing.
library;

class FundamentalSnapshot {
  final String symbol;
  final String cik;
  final String entityName;

  /// Raw reported line items, keyed by canonical name.
  final Map<String, double> reported;

  /// Annual series for growth calculations, oldest first.
  final List<double> annualEps;
  final List<double> annualRevenue;

  /// Quarterly EPS, oldest first, used for the CAN SLIM quarterly test.
  final List<double> quarterlyEps;

  final DateTime asOf;

  /// Which figures could not be read from the filing.
  final List<String> gaps;

  /// Where the data came from, for provenance.
  final String source;

  const FundamentalSnapshot({
    required this.symbol,
    required this.cik,
    required this.entityName,
    required this.reported,
    this.annualEps = const [],
    this.annualRevenue = const [],
    this.quarterlyEps = const [],
    required this.asOf,
    this.gaps = const [],
    this.source = 'SEC EDGAR XBRL company facts',
  });

  bool get isComplete => gaps.isEmpty;

  double? operator [](String key) => reported[key];

  Map<String, dynamic> toMap() => {
        'symbol': symbol,
        'cik': cik,
        'entity': entityName,
        'reported': reported,
        'annual_eps': annualEps,
        'annual_revenue': annualRevenue,
        'quarterly_eps': quarterlyEps,
        'as_of': asOf.millisecondsSinceEpoch,
        'gaps': gaps,
        'source': source,
      };

  factory FundamentalSnapshot.fromMap(Map<String, dynamic> m) => FundamentalSnapshot(
        symbol: (m['symbol'] as String?) ?? '',
        cik: (m['cik'] as String?) ?? '',
        entityName: (m['entity'] as String?) ?? '',
        reported: ((m['reported'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', (v as num).toDouble())),
        annualEps: ((m['annual_eps'] as List?) ?? const []).map((e) => (e as num).toDouble()).toList(),
        annualRevenue: ((m['annual_revenue'] as List?) ?? const []).map((e) => (e as num).toDouble()).toList(),
        quarterlyEps: ((m['quarterly_eps'] as List?) ?? const []).map((e) => (e as num).toDouble()).toList(),
        asOf: DateTime.fromMillisecondsSinceEpoch((m['as_of'] as num?)?.toInt() ?? 0),
        gaps: ((m['gaps'] as List?) ?? const []).map((e) => '$e').toList(),
        source: (m['source'] as String?) ?? 'SEC EDGAR XBRL company facts',
      );
}

/// Raised when a feed cannot be reached at all. Callers show a "Data Feed
/// Unavailable" state rather than substituting numbers.
class DataFeedUnavailable implements Exception {
  final String feed;
  final String reason;
  const DataFeedUnavailable(this.feed, this.reason);
  @override
  String toString() => '$feed unavailable: $reason';
}
