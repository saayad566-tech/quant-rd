import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/data/models/fundamentals.dart';
import 'package:quant_rd/data/remote/edgar_client.dart';
import 'package:quant_rd/domain/fundamentals/fundamental_scorer.dart';
import 'package:quant_rd/domain/knowledge/book_catalogue.dart';
import 'package:quant_rd/domain/knowledge/book_framework.dart';

/// Builds a company-facts document shaped like the real EDGAR response.
Map<String, dynamic> companyFacts({
  double? netIncome = 100,
  double? revenue = 1000,
  double? equity = 500,
  double? assets = 2000,
  double? currentAssets = 600,
  double? currentLiabilities = 300,
  double? longTermDebt = 200,
  double? operatingIncome = 150,
  double? cash = 0,
  List<double> annualEps = const [1, 1.5, 2, 2.5],
  List<double> quarterlyEps = const [0.5, 0.5, 0.5, 0.5, 0.7],
  double? shares = 100,
}) {
  Map<String, dynamic> fact(double? value, {String unit = 'USD', bool annual = true}) {
    if (value == null) return {};
    final entries = <Map<String, dynamic>>[];
    if (annual) {
      entries.add({'start': '2023-01-01', 'end': '2023-12-31', 'val': value, 'fy': 2023, 'fp': 'FY', 'form': '10-K', 'filed': '2024-02-01'});
    } else {
      entries.add({'start': '2023-07-01', 'end': '2023-09-30', 'val': value, 'fy': 2023, 'fp': 'Q3', 'form': '10-Q', 'filed': '2023-10-20'});
    }
    return {'units': {unit: entries}};
  }

  /// An EPS-style series. Real filings carry the annual 10-K entries and the
  /// quarterly 10-Q entries under the **same** tag, which is exactly what the
  /// parser has to separate — so the fixture does the same.
  Map<String, dynamic> series(
    List<double> annual, {
    String unit = 'USD/shares',
    List<double> quarterly = const [],
  }) {
    final entries = <Map<String, dynamic>>[];
    for (var i = 0; i < annual.length; i++) {
      final year = 2020 + i;
      entries.add({
        'start': '$year-01-01',
        'end': '$year-12-31',
        'val': annual[i],
        'fy': year,
        'fp': 'FY',
        'form': '10-K',
        'filed': '${year + 1}-02-01',
      });
    }
    // Quarters run about 90 days, which is what the parser filters on.
    const spans = [('01-01', '03-31'), ('04-01', '06-30'), ('07-01', '09-30'), ('10-01', '12-31')];
    for (var i = 0; i < quarterly.length; i++) {
      final year = 2022 + (i ~/ 4);
      final q = i % 4;
      entries.add({
        'start': '$year-${spans[q].$1}',
        'end': '$year-${spans[q].$2}',
        'val': quarterly[i],
        'fy': year,
        'fp': 'Q${q + 1}',
        'form': '10-Q',
        'filed': '$year-05-01',
      });
    }
    return {'units': {unit: entries}};
  }

  return {
    'cik': 320193,
    'entityName': 'Test Corp',
    'facts': {
      'us-gaap': {
        if (netIncome != null) 'NetIncomeLoss': fact(netIncome),
        if (revenue != null) 'Revenues': fact(revenue),
        if (equity != null) 'StockholdersEquity': fact(equity),
        if (assets != null) 'Assets': fact(assets),
        if (currentAssets != null) 'AssetsCurrent': fact(currentAssets),
        if (currentLiabilities != null) 'LiabilitiesCurrent': fact(currentLiabilities),
        if (longTermDebt != null) 'LongTermDebtNoncurrent': fact(longTermDebt),
        if (operatingIncome != null) 'OperatingIncomeLoss': fact(operatingIncome),
        if (cash != null) 'CashAndCashEquivalentsAtCarryingValue': fact(cash),
        'EarningsPerShareDiluted': series(annualEps, quarterly: quarterlyEps),
      },
      'dei': {
        if (shares != null) 'EntityCommonStockSharesOutstanding': fact(shares, unit: 'shares'),
      },
    },
  };
}

void main() {
  group('EDGAR parsing', () {
    test('parses the reported line items and series', () {
      final s = EdgarParser.parseCompanyFacts(symbol: 'TEST', cik: '0000320193', json: companyFacts());
      expect(s.symbol, 'TEST');
      expect(s.entityName, 'Test Corp');
      expect(s['netIncome'], closeTo(100, 1e-9));
      expect(s['revenue'], closeTo(1000, 1e-9));
      expect(s['stockholdersEquity'], closeTo(500, 1e-9));
      expect(s['ebit'], closeTo(150, 1e-9));
      expect(s['sharesOutstanding'], closeTo(100, 1e-9));
      expect(s.annualEps, [1, 1.5, 2, 2.5]);
      expect(s.quarterlyEps.length, 5);
    });

    test('a missing tag becomes a reported gap, never a guess', () {
      final s = EdgarParser.parseCompanyFacts(
        symbol: 'TEST',
        cik: '0000320193',
        json: companyFacts(netIncome: null, currentAssets: null),
      );
      expect(s['netIncome'], isNull);
      expect(s.gaps.any((g) => g.contains('Net income')), isTrue);
      expect(s.gaps.any((g) => g.contains('Current assets')), isTrue);
      expect(s.isComplete, isFalse);
    });

    test('the quarterly series only keeps three-month durations', () {
      final s = EdgarParser.parseCompanyFacts(symbol: 'TEST', cik: '0000320193', json: companyFacts());
      // The annual entries are ~365 days and must not leak into the quarterly list.
      expect(s.quarterlyEps.length, 5);
      expect(s.annualEps.length, 4);
    });

    test('a document with no facts yields gaps and no crash', () {
      final s = EdgarParser.parseCompanyFacts(symbol: 'X', cik: '1', json: {'entityName': 'Empty'});
      expect(s.reported, isEmpty);
      expect(s.gaps, isNotEmpty);
    });

    test('a snapshot round-trips through its map form', () {
      final s = EdgarParser.parseCompanyFacts(symbol: 'TEST', cik: '0000320193', json: companyFacts());
      final back = FundamentalSnapshot.fromMap(jsonDecode(jsonEncode(s.toMap())) as Map<String, dynamic>);
      expect(back.symbol, s.symbol);
      expect(back['netIncome'], closeTo(100, 1e-9));
      expect(back.annualEps.length, s.annualEps.length);
      expect(back.quarterlyEps.length, s.quarterlyEps.length);
    });
  });

  group('fundamental scoring', () {
    FundamentalScore score({double? price = 20}) {
      final s = EdgarParser.parseCompanyFacts(symbol: 'TEST', cik: '0000320193', json: companyFacts());
      return FundamentalScorer.score(s, price: price);
    }

    test('profitability ratios match their formulas', () {
      final f = score();
      expect(f.value('netMarginPct')!, closeTo(10, 1e-6)); // 100/1000
      expect(f.value('roePct')!, closeTo(20, 1e-6)); // 100/500
      expect(f.value('roaPct')!, closeTo(5, 1e-6)); // 100/2000
      // ROIC = EBIT / (assets - current liabilities) = 150 / 1700
      expect(f.value('roicPct')!, closeTo(150 / 1700 * 100, 1e-6));
    });

    test('leverage and liquidity match their formulas', () {
      final f = score();
      expect(f.value('debtToEquity')!, closeTo(0.4, 1e-9)); // 200/500
      expect(f.value('currentRatio')!, closeTo(2.0, 1e-9)); // 600/300
    });

    test('growth metrics match their formulas', () {
      final f = score();
      expect(f.value('epsGrowthPct')!, closeTo(25, 1e-6)); // 2.5/2
      // 3-year CAGR of EPS: (2.5/1)^(1/3) - 1
      expect(f.value('epsGrowth3yPct')!, closeTo(35.72, 0.05));
      expect(f.value('quarterlyEpsGrowthPct')!, closeTo(40, 1e-6)); // 0.7/0.5
      expect(f.value('positiveEarningsYears')!, closeTo(4, 1e-9));
    });

    test('valuation metrics use a real price and are absent without one', () {
      final withPrice = score(price: 20);
      expect(withPrice.value('marketCapUsd')!, closeTo(2000, 1e-6)); // 20 x 100
      // Earnings yield = EBIT / (market cap + debt - cash) = 150 / 2200
      expect(withPrice.value('earningsYieldPct')!, closeTo(150 / 2200 * 100, 1e-6));
      expect(withPrice.value('priceToBook')!, closeTo(4.0, 1e-6));

      final noPrice = score(price: null);
      expect(noPrice.value('marketCapUsd'), isNull);
      expect(noPrice.metric('marketCapUsd')!.unavailableReason, isNotNull);
      expect(noPrice.missing.map((m) => m.key), contains('earningsYieldPct'));
    });

    test('every metric carries its formula', () {
      for (final m in score().metrics) {
        expect(m.formula, isNotEmpty, reason: '${m.key} has no stated formula');
      }
    });
  });

  group('criteria become evaluated, not passive', () {
    test('CAN SLIM fundamental criteria pass on strong filings', () {
      final f = FundamentalScorer.score(
        EdgarParser.parseCompanyFacts(symbol: 'T', cik: '1', json: companyFacts()),
        price: 20,
      );
      final canSlim = frameworkById('canslim')!;
      final c = canSlim.criteria.firstWhere((x) => x.name == 'C — current quarterly earnings');
      final a = canSlim.criteria.firstWhere((x) => x.name == 'A — annual earnings');
      expect(f.evaluate(c).state, CriterionState.met);
      expect(f.evaluate(a).state, CriterionState.met);
    });

    test('the Magic Formula return-on-capital test correctly fails at 8.8%', () {
      final f = FundamentalScorer.score(
        EdgarParser.parseCompanyFacts(symbol: 'T', cik: '1', json: companyFacts()),
        price: 20,
      );
      final mf = frameworkById('magic-formula')!;
      final roc = mf.criteria.firstWhere((x) => x.name == 'Return on capital');
      final r = f.evaluate(roc);
      expect(r.state, CriterionState.unmet);
      expect(r.detail, contains('8.8'));
    });

    test('Graham strength and Lynch balance-sheet tests evaluate', () {
      final f = FundamentalScorer.score(
        EdgarParser.parseCompanyFacts(symbol: 'T', cik: '1', json: companyFacts()),
        price: 20,
      );
      final graham = frameworkById('graham-defensive')!;
      final strength = graham.criteria.firstWhere((x) => x.name == 'Strong financial condition');
      expect(f.evaluate(strength).state, CriterionState.met); // current ratio 2.0

      final lynch = frameworkById('lynch-peg')!;
      final de = lynch.criteria.firstWhere((x) => x.name == 'Balance-sheet strength');
      expect(f.evaluate(de).state, CriterionState.met); // debt/equity 0.4
    });

    test('a criterion needing absent data stays needsData, never met', () {
      final thin = EdgarParser.parseCompanyFacts(
        symbol: 'T',
        cik: '1',
        json: companyFacts(netIncome: null, equity: null, operatingIncome: null),
      );
      final f = FundamentalScorer.score(thin, price: 20);
      final mf = frameworkById('magic-formula')!;
      final roc = mf.criteria.firstWhere((x) => x.name == 'Return on capital');
      final r = f.evaluate(roc);
      expect(r.state, CriterionState.needsData);
      expect(r.detail, isNotEmpty);
    });
  });

  group('fundamental screener integration', () {
    test('a filing flips the Magic Formula criteria from passive to genuinely evaluated', () {
      final f = FundamentalScorer.score(
        EdgarParser.parseCompanyFacts(symbol: 'T', cik: '1', json: companyFacts()),
        price: 20,
      );
      final mf = frameworkById('magic-formula')!;

      // Earnings yield = 6.82% > 0, so this one genuinely passes.
      final ey = mf.criteria.firstWhere((x) => x.name == 'Earnings yield');
      expect(f.evaluate(ey).state, CriterionState.met);

      // Return on capital is 8.8%, below the framework's bar, so it genuinely fails.
      final roc = mf.criteria.firstWhere((x) => x.name == 'Return on capital');
      expect(f.evaluate(roc).state, CriterionState.unmet);

      // The composite rank has no automated check, so it stays needsData.
      final rank = mf.criteria.firstWhere((x) => x.name == 'Composite rank');
      expect(f.evaluate(rank).state, CriterionState.needsData);

      // At least one criterion moved out of needsData, which is the whole point.
      final states = mf.criteria.map((c) => f.evaluate(c).state).toList();
      expect(states.where((s) => s != CriterionState.needsData), isNotEmpty);
    });
  });
}
