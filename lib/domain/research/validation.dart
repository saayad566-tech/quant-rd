/// The mandatory validation gate.
///
/// A strategy is never "published" on the strength of an assertion. Every claim
/// about a strategy must come from a real backtest over real bars, and it must
/// clear an explicit, inspectable policy. The numbers here are computed by the
/// engine — nothing in this file can invent a metric.
library;

import 'dart:convert';

import '../../data/models/backtest_result.dart';
import '../engine/metrics.dart';

class ValidationPolicy {
  final int minTrades;
  final double minProfitFactor;
  final double maxDrawdownPct;
  final bool requirePositiveExpectancy;

  const ValidationPolicy({
    this.minTrades = 5,
    this.minProfitFactor = 1.0,
    this.maxDrawdownPct = 50,
    this.requirePositiveExpectancy = true,
  });

  Map<String, dynamic> toMap() => {
        'min_trades': minTrades,
        'min_profit_factor': minProfitFactor,
        'max_drawdown_pct': maxDrawdownPct,
        'require_positive_expectancy': requirePositiveExpectancy,
      };

  factory ValidationPolicy.fromMap(Map<String, dynamic> m) => ValidationPolicy(
        minTrades: (m['min_trades'] as num?)?.toInt() ?? 5,
        minProfitFactor: (m['min_profit_factor'] as num?)?.toDouble() ?? 1.0,
        maxDrawdownPct: (m['max_drawdown_pct'] as num?)?.toDouble() ?? 50,
        requirePositiveExpectancy: (m['require_positive_expectancy'] as bool?) ?? true,
      );
}

class ValidationCheck {
  final String label;
  final bool passed;
  final String detail;

  const ValidationCheck({required this.label, required this.passed, required this.detail});

  String toLine() => '${passed ? 'PASS' : 'FAIL'} — $label ($detail)';
}

class ValidationOutcome {
  final bool passed;
  final List<ValidationCheck> checks;

  const ValidationOutcome({required this.passed, required this.checks});

  List<String> get failures => checks.where((c) => !c.passed).map((c) => '${c.label}: ${c.detail}').toList();
  List<String> get lines => checks.map((c) => c.toLine()).toList();

  static ValidationOutcome evaluate(Metrics m, ValidationPolicy policy) {
    final checks = <ValidationCheck>[
      ValidationCheck(
        label: 'Enough trades',
        passed: m.tradeCount >= policy.minTrades,
        detail: '${m.tradeCount} trades (need \u2265 ${policy.minTrades})',
      ),
      ValidationCheck(
        label: 'Profit factor above threshold',
        passed: m.profitFactor >= policy.minProfitFactor,
        detail: '${m.profitFactor.toStringAsFixed(2)} (need \u2265 ${policy.minProfitFactor.toStringAsFixed(2)})',
      ),
      ValidationCheck(
        label: 'Drawdown within limit',
        passed: m.maxDrawdownPct <= policy.maxDrawdownPct,
        detail: '${m.maxDrawdownPct.toStringAsFixed(1)}% (limit ${policy.maxDrawdownPct.toStringAsFixed(0)}%)',
      ),
      ValidationCheck(
        label: 'Positive expectancy',
        passed: !policy.requirePositiveExpectancy || m.expectancy > 0,
        detail: m.expectancy.toStringAsFixed(2),
      ),
    ];
    return ValidationOutcome(passed: checks.every((c) => c.passed), checks: checks);
  }
}

/// A durable record proving a strategy was validated against a specific dataset.
class StrategyValidation {
  final String id;
  final String workspaceId;
  final String strategyId;
  final String datasetId;
  final String symbol;
  final Metrics metrics;
  final bool passed;
  final List<String> checks;
  final ValidationPolicy policy;
  final DateTime runAt;

  const StrategyValidation({
    required this.id,
    required this.workspaceId,
    required this.strategyId,
    required this.datasetId,
    required this.symbol,
    required this.metrics,
    required this.passed,
    required this.checks,
    required this.policy,
    required this.runAt,
  });

  factory StrategyValidation.fromRun({
    required String id,
    required String workspaceId,
    required BacktestResult result,
    required ValidationPolicy policy,
  }) =>
      StrategyValidation.fromMetrics(
        id: id,
        workspaceId: workspaceId,
        strategyId: result.strategyId,
        datasetId: result.datasetId,
        symbol: result.symbol,
        metrics: result.metrics,
        policy: policy,
      );

  /// Builds a record directly from engine metrics (used by the research
  /// pipeline, which has metrics without a stored BacktestResult).
  factory StrategyValidation.fromMetrics({
    required String id,
    required String workspaceId,
    required String strategyId,
    required String datasetId,
    required String symbol,
    required Metrics metrics,
    required ValidationPolicy policy,
  }) {
    final outcome = ValidationOutcome.evaluate(metrics, policy);
    return StrategyValidation(
      id: id,
      workspaceId: workspaceId,
      strategyId: strategyId,
      datasetId: datasetId,
      symbol: symbol,
      metrics: metrics,
      passed: outcome.passed,
      checks: outcome.lines,
      policy: policy,
      runAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'workspace_id': workspaceId,
        'strategy_id': strategyId,
        'dataset_id': datasetId,
        'symbol': symbol,
        'metrics': jsonEncode(metrics.toMap()),
        'passed': passed ? 1 : 0,
        'checks': jsonEncode(checks),
        'policy': jsonEncode(policy.toMap()),
        'run_at': runAt.millisecondsSinceEpoch,
      };

  factory StrategyValidation.fromMap(Map<String, dynamic> m) => StrategyValidation(
        id: m['id'] as String,
        workspaceId: (m['workspace_id'] as String?) ?? '',
        strategyId: m['strategy_id'] as String,
        datasetId: m['dataset_id'] as String,
        symbol: (m['symbol'] as String?) ?? '',
        metrics: Metrics.fromMap(jsonDecode(m['metrics'] as String) as Map<String, dynamic>),
        passed: ((m['passed'] as num?)?.toInt() ?? 0) == 1,
        checks: (jsonDecode(m['checks'] as String) as List).map((e) => e.toString()).toList(),
        policy: ValidationPolicy.fromMap(jsonDecode(m['policy'] as String) as Map<String, dynamic>),
        runAt: DateTime.fromMillisecondsSinceEpoch((m['run_at'] as num).toInt()),
      );
}
