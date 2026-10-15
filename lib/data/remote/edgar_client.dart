/// SEC EDGAR client.
///
/// EDGAR is free and needs no API key, but the SEC **requires** a descriptive
/// `User-Agent` identifying the requester. Set it in Configs ("SEC EDGAR
/// User-Agent"); a request without one is refused by the SEC, which is why the
/// client will not send a request until a user agent is configured.
///
/// The parser is a pure function over the JSON, so it is testable without the
/// network, and every figure it cannot read becomes an entry in `gaps` rather
/// than a guessed number.
library;

import 'dart:math' as math;

import '../models/fundamentals.dart';

abstract class EdgarClient {
  /// True when this platform can make HTTP calls at all.
  bool get supported;

  /// Resolves a ticker to a zero-padded ten-digit CIK, or null when unknown.
  Future<String?> resolveCik(String ticker);

  /// Fetches the company-facts document and normalises it.
  ///
  /// Throws [DataFeedUnavailable] only when the feed cannot be reached at all;
  /// missing individual figures are reported in the snapshot's gaps.
  Future<FundamentalSnapshot> fetchFundamentals(String ticker, {required String userAgent});

  /// The default user agent, used when the setting is blank.
  static const String defaultUserAgent = 'Quant RD research tool (contact: set your email in Configs)';
}

/// Pure parsing of an EDGAR company-facts document.
class EdgarParser {
  const EdgarParser._();

  static const List<String> _epsTags = ['EarningsPerShareDiluted', 'EarningsPerShareBasic'];
  static const List<String> _revenueTags = [
    'RevenueFromContractWithCustomerExcludingAssessedTax',
    'Revenues',
    'SalesRevenueNet',
  ];
  static const List<String> _debtTags = ['LongTermDebtNoncurrent', 'LongTermDebt', 'LongTermDebtCurrent'];

  /// Parses `companyfacts` JSON into a snapshot. Never throws on a missing tag.
  static FundamentalSnapshot parseCompanyFacts({
    required String symbol,
    required String cik,
    required Map<String, dynamic> json,
  }) {
    final gaps = <String>[];
    final reported = <String, double>{};

    final facts = (json['facts'] as Map?)?.cast<String, dynamic>() ?? const {};
    final usGaap = (facts['us-gaap'] as Map?)?.cast<String, dynamic>() ?? const {};
    final dei = (facts['dei'] as Map?)?.cast<String, dynamic>() ?? const {};

    final entityName = (json['entityName'] as String?) ?? symbol;

    /// Most recent annual (10-K, FY) value for a tag.
    double? latestAnnual(Map<String, dynamic> source, String tag, {String unit = 'USD'}) {
      final series = _series(source, tag, unit: unit);
      if (series.isEmpty) return null;
      return series.last.value;
    }

    /// Annual series for a tag, oldest first, deduplicated by fiscal year.
    List<_Fact> annualSeries(Map<String, dynamic> source, String tag, {String unit = 'USD'}) {
      final all = _series(source, tag, unit: unit);
      final byYear = <int, _Fact>{};
      for (final f in all) {
        if (f.durationDays < 300 || f.durationDays > 400) continue;
        final key = f.end.year;
        final existing = byYear[key];
        if (existing == null || f.end.isAfter(existing.end)) byYear[key] = f;
      }
      final out = byYear.values.toList()..sort((a, b) => a.end.compareTo(b.end));
      return out;
    }

    double? firstAvailable(List<String> tags, {String unit = 'USD'}) {
      for (final t in tags) {
        final v = latestAnnual(usGaap, t, unit: unit);
        if (v != null) return v;
      }
      return null;
    }

    // --- Line items ---
    final revenue = firstAvailable(_revenueTags);
    if (revenue == null) gaps.add('Revenue: none of the revenue tags were present.');
    final netIncome = firstAvailable(['NetIncomeLoss']);
    if (netIncome == null) gaps.add('Net income: NetIncomeLoss was not present.');
    final equity = firstAvailable(['StockholdersEquity', 'StockholdersEquityIncludingPortionAttributableToNoncontrollingInterest']);
    if (equity == null) gaps.add('Stockholders equity was not present.');
    final assets = firstAvailable(['Assets']);
    if (assets == null) gaps.add('Total assets were not present.');
    final liabilities = firstAvailable(['Liabilities']);
    final currentAssets = firstAvailable(['AssetsCurrent']);
    if (currentAssets == null) gaps.add('Current assets were not present.');
    final currentLiabilities = firstAvailable(['LiabilitiesCurrent']);
    if (currentLiabilities == null) gaps.add('Current liabilities were not present.');
    final longTermDebt = firstAvailable(_debtTags);
    if (longTermDebt == null) gaps.add('Long-term debt was not present.');
    final cash = firstAvailable(['CashAndCashEquivalentsAtCarryingValue', 'CashCashEquivalentsRestrictedCashAndRestrictedCashEquivalents']);
    final operatingIncome = firstAvailable(['OperatingIncomeLoss']);
    if (operatingIncome == null) gaps.add('Operating income (the EBIT proxy) was not present.');

    // Shares outstanding lives in the dei namespace.
    double? shares;
    for (final tag in ['EntityCommonStockSharesOutstanding']) {
      final v = latestAnnual(dei, tag, unit: 'shares');
      if (v != null) {
        shares = v;
        break;
      }
    }
    if (shares == null) gaps.add('Shares outstanding (dei) were not present.');

    if (revenue != null) reported['revenue'] = revenue;
    if (netIncome != null) reported['netIncome'] = netIncome;
    if (equity != null) reported['stockholdersEquity'] = equity;
    if (assets != null) reported['assets'] = assets;
    if (liabilities != null) reported['liabilities'] = liabilities;
    if (currentAssets != null) reported['currentAssets'] = currentAssets;
    if (currentLiabilities != null) reported['currentLiabilities'] = currentLiabilities;
    if (longTermDebt != null) reported['longTermDebt'] = longTermDebt;
    if (cash != null) reported['cash'] = cash;
    if (operatingIncome != null) reported['ebit'] = operatingIncome;
    if (shares != null) reported['sharesOutstanding'] = shares;

    // --- Series for growth ---
    final annualEps = <double>[];
    for (final tag in _epsTags) {
      final series = annualSeries(usGaap, tag, unit: 'USD/shares');
      if (series.isNotEmpty) {
        annualEps.addAll(series.map((f) => f.value));
        break;
      }
    }
    if (annualEps.isEmpty) gaps.add('Annual EPS history was not present.');

    final annualRevenue = <double>[];
    for (final tag in _revenueTags) {
      final series = annualSeries(usGaap, tag);
      if (series.isNotEmpty) {
        annualRevenue.addAll(series.map((f) => f.value));
        break;
      }
    }

    // Quarterly EPS: three-month durations, oldest first.
    final quarterlyEps = <double>[];
    for (final tag in _epsTags) {
      final all = _series(usGaap, tag, unit: 'USD/shares').where((f) => f.durationDays >= 80 && f.durationDays <= 100).toList();
      if (all.isNotEmpty) {
        all.sort((a, b) => a.end.compareTo(b.end));
        quarterlyEps.addAll(all.map((f) => f.value));
        break;
      }
    }
    if (quarterlyEps.length < 5) gaps.add('Fewer than five quarterly EPS figures were available, so the quarterly growth test cannot run.');

    return FundamentalSnapshot(
      symbol: symbol,
      cik: cik,
      entityName: entityName,
      reported: reported,
      annualEps: annualEps,
      annualRevenue: annualRevenue,
      quarterlyEps: quarterlyEps,
      asOf: DateTime.now(),
      gaps: gaps,
    );
  }

  static List<_Fact> _series(Map<String, dynamic> source, String tag, {required String unit}) {
    final tagData = (source[tag] as Map?)?.cast<String, dynamic>();
    if (tagData == null) return const [];
    final units = (tagData['units'] as Map?)?.cast<String, dynamic>();
    if (units == null) return const [];
    final list = (units[unit] as List?) ?? (units.values.isNotEmpty ? units.values.first as List? : null);
    if (list == null) return const [];

    final out = <_Fact>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      final m = raw.cast<String, dynamic>();
      final val = (m['val'] as num?)?.toDouble();
      final endRaw = m['end'] as String?;
      if (val == null || endRaw == null) continue;
      final end = DateTime.tryParse(endRaw);
      if (end == null) continue;
      final start = DateTime.tryParse((m['start'] as String?) ?? '') ?? end;
      out.add(_Fact(value: val, start: start, end: end, form: (m['form'] as String?) ?? '', fiscalPeriod: (m['fp'] as String?) ?? ''));
    }
    return out;
  }
}

class _Fact {
  final double value;
  final DateTime start;
  final DateTime end;
  final String form;
  final String fiscalPeriod;

  const _Fact({required this.value, required this.start, required this.end, required this.form, required this.fiscalPeriod});

  int get durationDays => math.max(0, end.difference(start).inDays);
}
