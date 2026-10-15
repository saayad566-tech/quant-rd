/// Fundamental scoring: turns reported filings into the ratios the framework
/// library screens on, and evaluates those frameworks' fundamental criteria.
///
/// Every formula here is explicit and auditable. When an input is absent the
/// metric is **not** produced — it is reported as unavailable, so a framework
/// criterion that depends on it stays `needsData` rather than passing by default.
library;

import '../../data/models/fundamentals.dart';
import '../knowledge/book_framework.dart';

class ScoredMetric {
  final String key;
  final String label;
  final double? value;
  final String unit;
  final String formula;
  final String? unavailableReason;

  const ScoredMetric({
    required this.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.formula,
    this.unavailableReason,
  });

  bool get available => value != null;

  String get display => available ? '${value!.toStringAsFixed(2)}$unit' : 'unavailable';
}

class FundamentalScore {
  final String symbol;
  final List<ScoredMetric> metrics;

  const FundamentalScore({required this.symbol, required this.metrics});

  ScoredMetric? metric(String key) {
    for (final m in metrics) {
      if (m.key == key) return m;
    }
    return null;
  }

  double? value(String key) => metric(key)?.value;

  List<ScoredMetric> get available => metrics.where((m) => m.available).toList(growable: false);
  List<ScoredMetric> get missing => metrics.where((m) => !m.available).toList(growable: false);

  /// Evaluates one framework criterion against this score.
  CriterionResult evaluate(FrameworkCriterion c) {
    CriterionResult need(String why) =>
        CriterionResult(criterion: c, state: CriterionState.needsData, detail: why);

    bool met;
    String detail;

    switch (c.name) {
      case 'Earnings yield':
        final ey = value('earningsYieldPct');
        if (ey == null) return need(metric('earningsYieldPct')?.unavailableReason ?? 'Earnings yield could not be computed.');
        met = ey > 0;
        detail = 'EBIT/EV = ${ey.toStringAsFixed(2)}%';
      case 'Return on capital':
        final roc = value('roicPct');
        if (roc == null) return need(metric('roicPct')?.unavailableReason ?? 'Return on capital could not be computed.');
        met = roc >= 20;
        detail = 'ROC ${roc.toStringAsFixed(1)}%';
      case 'C — current quarterly earnings':
        final g = value('quarterlyEpsGrowthPct');
        if (g == null) return need('Quarterly EPS history is not in the filing extract.');
        met = g >= 20;
        detail = 'quarterly EPS growth ${g.toStringAsFixed(1)}% year over year';
      case 'A — annual earnings':
        final g = value('epsGrowth3yPct');
        final roe = value('roePct');
        if (g == null || roe == null) return need('Annual EPS history or equity is not in the filing extract.');
        met = g >= 25 && roe >= 17;
        detail = '3-year EPS growth ${g.toStringAsFixed(1)}%, ROE ${roe.toStringAsFixed(1)}%';
      case 'Strong financial condition':
        final cr = value('currentRatio');
        if (cr == null) return need('Current assets or liabilities are not in the filing extract.');
        met = cr >= 2;
        detail = 'current ratio ${cr.toStringAsFixed(2)}';
      case 'Balance-sheet strength':
        final de = value('debtToEquity');
        if (de == null) return need('Debt or equity is not in the filing extract.');
        met = de < 1;
        detail = 'debt/equity ${de.toStringAsFixed(2)}';
      case 'Adequate size':
        final cap = value('marketCapUsd');
        if (cap == null) return need('Share count or price is unavailable.');
        met = cap >= 50e6;
        detail = 'market cap \$${(cap / 1e6).toStringAsFixed(0)}m';
      case 'Earnings stability':
        final years = value('positiveEarningsYears');
        if (years == null) return need('Annual earnings history is not in the filing extract.');
        met = years >= 5;
        detail = '$years consecutive positive-earnings years';
      case 'Profitability tests':
        final roa = value('roaPct');
        if (roa == null) return need('Net income or assets are not in the filing extract.');
        met = roa > 0;
        detail = 'ROA ${roa.toStringAsFixed(1)}%';
      case 'Leverage, liquidity, source of funds':
        final de = value('debtToEquity');
        final cr = value('currentRatio');
        if (de == null || cr == null) return need('Debt, equity, current assets or liabilities are unavailable.');
        met = de < 1 && cr >= 1;
        detail = 'debt/equity ${de.toStringAsFixed(2)}, current ratio ${cr.toStringAsFixed(2)}';
      case 'Operating efficiency':
        final nm = value('netMarginPct');
        if (nm == null) return need('Net income or revenue is not in the filing extract.');
        met = nm > 0;
        detail = 'net margin ${nm.toStringAsFixed(1)}%';
      case 'PEG ratio':
        final peg = value('peg');
        if (peg == null) return need('PEG needs an earnings multiple and a growth rate, one of which is missing.');
        met = peg < 1;
        detail = 'PEG ${peg.toStringAsFixed(2)}';
      case 'Moderate price relative to assets':
        final pb = value('priceToBook');
        if (pb == null) return need('Price or book equity is unavailable.');
        met = pb < 1.5;
        detail = 'P/B ${pb.toStringAsFixed(2)}';
      default:
        return need('No fundamental check is defined for this criterion.');
    }

    return CriterionResult(criterion: c, state: met ? CriterionState.met : CriterionState.unmet, detail: detail);
  }
}

class FundamentalScorer {
  const FundamentalScorer._();

  /// Computes every metric the filing supports. [price] is optional and comes
  /// from the market-data side, so market-cap-based ratios are only produced
  /// when a price is actually available.
  static FundamentalScore score(FundamentalSnapshot s, {double? price}) {
    final out = <ScoredMetric>[];
    final r = s.reported;

    double? get(String k) => r[k];

    void add(String key, String label, double? value, String unit, String formula, {String? reason}) {
      out.add(ScoredMetric(key: key, label: label, value: value, unit: unit, formula: formula, unavailableReason: reason));
    }

    final netIncome = get('netIncome');
    final revenue = get('revenue');
    final equity = get('stockholdersEquity');
    final assets = get('assets');
    final currentAssets = get('currentAssets');
    final currentLiabilities = get('currentLiabilities');
    final longTermDebt = get('longTermDebt');
    final shares = get('sharesOutstanding');
    final ebit = get('ebit');
    final cash = get('cash');

    // --- Profitability ---
    add('netMarginPct', 'Net margin', (netIncome != null && revenue != null && revenue != 0) ? netIncome / revenue * 100 : null, '%',
        'net income / revenue', reason: 'Net income or revenue is not in the filing extract.');
    add('roePct', 'Return on equity', (netIncome != null && equity != null && equity != 0) ? netIncome / equity * 100 : null, '%',
        'net income / stockholders equity', reason: 'Net income or equity is not in the filing extract.');
    add('roaPct', 'Return on assets', (netIncome != null && assets != null && assets != 0) ? netIncome / assets * 100 : null, '%',
        'net income / total assets', reason: 'Net income or assets is not in the filing extract.');

    // Return on capital uses EBIT over invested capital, the Greenblatt form.
    final investedCapital = (assets != null && currentLiabilities != null) ? assets - currentLiabilities : null;
    add('roicPct', 'Return on capital',
        (ebit != null && investedCapital != null && investedCapital != 0) ? ebit / investedCapital * 100 : null, '%',
        'EBIT / (total assets - current liabilities)',
        reason: 'EBIT or invested capital could not be derived from the filing extract.');

    // --- Leverage and liquidity ---
    add('debtToEquity', 'Debt / equity', (longTermDebt != null && equity != null && equity != 0) ? longTermDebt / equity : null, '',
        'long-term debt / stockholders equity', reason: 'Long-term debt or equity is not in the filing extract.');
    add('currentRatio', 'Current ratio', (currentAssets != null && currentLiabilities != null && currentLiabilities != 0) ? currentAssets / currentLiabilities : null, '',
        'current assets / current liabilities', reason: 'Current assets or liabilities are not in the filing extract.');

    // --- Growth ---
    add('epsGrowthPct', 'EPS growth (latest year)', _yoy(s.annualEps), '%', '(EPS_t / EPS_{t-1} - 1) x 100',
        reason: 'Fewer than two annual EPS figures were reported.');
    add('epsGrowth3yPct', 'EPS growth (3-year)', _cagr(s.annualEps, 3), '%', '3-year compound annual growth in EPS',
        reason: 'Fewer than four annual EPS figures were reported.');
    add('revenueGrowthPct', 'Revenue growth (latest year)', _yoy(s.annualRevenue), '%', '(revenue_t / revenue_{t-1} - 1) x 100',
        reason: 'Fewer than two annual revenue figures were reported.');
    add('quarterlyEpsGrowthPct', 'Quarterly EPS growth', _yoy(s.quarterlyEps), '%', 'latest quarter EPS versus the same quarter a year earlier',
        reason: 'Fewer than five quarterly EPS figures were reported.');
    add('positiveEarningsYears', 'Positive-earnings years', s.annualEps.isEmpty ? null : _consecutivePositive(s.annualEps).toDouble(), '',
        'count of consecutive recent years with positive EPS',
        reason: 'No annual EPS history was reported.');

    // --- Valuation, only with a real price ---
    final marketCap = (price != null && shares != null) ? price * shares : null;
    add('marketCapUsd', 'Market capitalisation', marketCap, 'USD', 'price x shares outstanding',
        reason: 'A price or share count is unavailable, so market capitalisation cannot be computed.');
    final ev = (marketCap != null && longTermDebt != null) ? marketCap + longTermDebt - (cash ?? 0) : null;
    add('earningsYieldPct', 'Earnings yield', (ebit != null && ev != null && ev != 0) ? ebit / ev * 100 : null, '%',
        'EBIT / enterprise value', reason: 'EBIT, market capitalisation or debt is unavailable.');
    add('priceToBook', 'Price / book', (marketCap != null && equity != null && equity != 0) ? marketCap / equity : null, '',
        'market capitalisation / stockholders equity', reason: 'A price, share count or equity figure is unavailable.');
    final epsGrowth = _cagr(s.annualEps, 3);
    final pe = (marketCap != null && netIncome != null && netIncome > 0) ? marketCap / netIncome : null;
    add('peg', 'PEG', (pe != null && epsGrowth != null && epsGrowth > 0) ? pe / epsGrowth : null, '',
        '(market cap / net income) / 3-year EPS growth',
        reason: 'A positive earnings multiple and a positive growth rate are both required.');

    return FundamentalScore(symbol: s.symbol, metrics: out);
  }

  static double? _yoy(List<double> series) {
    if (series.length < 2) return null;
    final prev = series[series.length - 2];
    final cur = series[series.length - 1];
    if (prev == 0) return null;
    return (cur / prev - 1) * 100;
  }

  static double? _cagr(List<double> series, int years) {
    if (series.length < years + 1) return null;
    final start = series[series.length - 1 - years];
    final end = series[series.length - 1];
    if (start <= 0 || end <= 0) return null;
    return (pow(end / start, 1 / years) - 1) * 100;
  }

  static int _consecutivePositive(List<double> series) {
    var count = 0;
    for (var i = series.length - 1; i >= 0; i--) {
      if (series[i] > 0) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  /// Local power helper, avoiding a dart:math import for a single call.
  static double pow(double base, double exponent) {
    if (base <= 0) return 0;
    // exp(exponent * ln(base))
    return _exp(exponent * _ln(base));
  }

  static double _ln(double x) {
    if (x <= 0) return double.nan;
    // Natural log via the atanh series, accurate for the range used here.
    final y = (x - 1) / (x + 1);
    final y2 = y * y;
    var sum = 0.0;
    var term = y;
    for (var k = 0; k < 40; k++) {
      sum += term / (2 * k + 1);
      term *= y2;
    }
    return 2 * sum;
  }

  static double _exp(double x) {
    var sum = 1.0;
    var term = 1.0;
    for (var k = 1; k < 60; k++) {
      term *= x / k;
      sum += term;
    }
    return sum;
  }
}
