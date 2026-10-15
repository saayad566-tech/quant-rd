/// The complete output of a backtest run.
library;

import 'dart:convert';

import '../../domain/engine/metrics.dart';
import 'backtest_config.dart';
import 'trade.dart';

class EquityPoint {
  final DateTime time;
  final double equity;
  final double drawdownPct;

  const EquityPoint({required this.time, required this.equity, required this.drawdownPct});

  Map<String, dynamic> toMap() => {
        't': time.millisecondsSinceEpoch,
        'e': equity,
        'd': drawdownPct,
      };

  factory EquityPoint.fromMap(Map<String, dynamic> m) => EquityPoint(
        time: DateTime.fromMillisecondsSinceEpoch((m['t'] as num).toInt(), isUtc: true),
        equity: (m['e'] as num).toDouble(),
        drawdownPct: (m['d'] as num).toDouble(),
      );
}

class BacktestResult {
  final String id;
  final String workspaceId;
  final String strategyId;
  final String strategyName;
  final String datasetId;
  final String symbol;
  final BacktestConfig config;
  final List<EquityPoint> equityCurve;
  final List<Trade> trades;
  final Metrics metrics;
  final int barCount;
  final DateTime runAt;

  const BacktestResult({
    required this.id,
    this.workspaceId = '',
    required this.strategyId,
    required this.strategyName,
    required this.datasetId,
    required this.symbol,
    required this.config,
    required this.equityCurve,
    required this.trades,
    required this.metrics,
    required this.barCount,
    required this.runAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'workspace_id': workspaceId,
        'strategy_id': strategyId,
        'strategy_name': strategyName,
        'dataset_id': datasetId,
        'symbol': symbol,
        'config': jsonEncode(config.toMap()),
        'equity': jsonEncode(equityCurve.map((e) => e.toMap()).toList()),
        'trades': jsonEncode(trades.map((t) => t.toMap()).toList()),
        'metrics': jsonEncode(metrics.toMap()),
        'bar_count': barCount,
        'run_at': runAt.millisecondsSinceEpoch,
      };

  factory BacktestResult.fromMap(Map<String, dynamic> m) => BacktestResult(
        id: m['id'] as String,
        workspaceId: (m['workspace_id'] as String?) ?? '',
        strategyId: m['strategy_id'] as String,
        strategyName: m['strategy_name'] as String,
        datasetId: m['dataset_id'] as String,
        symbol: m['symbol'] as String,
        config: BacktestConfig.fromMap(jsonDecode(m['config'] as String) as Map<String, dynamic>),
        equityCurve: (jsonDecode(m['equity'] as String) as List)
            .map((e) => EquityPoint.fromMap(e as Map<String, dynamic>))
            .toList(),
        trades: (jsonDecode(m['trades'] as String) as List)
            .map((e) => Trade.fromMap(e as Map<String, dynamic>))
            .toList(),
        metrics: Metrics.fromMap(jsonDecode(m['metrics'] as String) as Map<String, dynamic>),
        barCount: (m['bar_count'] as num).toInt(),
        runAt: DateTime.fromMillisecondsSinceEpoch((m['run_at'] as num).toInt()),
      );

  /// A lightweight summary for list views (avoids decoding the full curve).
  Map<String, dynamic> toSummaryMap() => {
        'id': id,
        'strategy_id': strategyId,
        'strategy_name': strategyName,
        'dataset_id': datasetId,
        'symbol': symbol,
        'metrics': jsonEncode(metrics.toMap()),
        'config': jsonEncode(config.toMap()),
        'bar_count': barCount,
        'run_at': runAt.millisecondsSinceEpoch,
      };
}

class BacktestSummary {
  final String id;
  final String strategyId;
  final String strategyName;
  final String datasetId;
  final String symbol;
  final Metrics metrics;
  final int barCount;
  final DateTime runAt;

  const BacktestSummary({
    required this.id,
    required this.strategyId,
    required this.strategyName,
    required this.datasetId,
    required this.symbol,
    required this.metrics,
    required this.barCount,
    required this.runAt,
  });

  factory BacktestSummary.fromMap(Map<String, dynamic> m) => BacktestSummary(
        id: m['id'] as String,
        strategyId: m['strategy_id'] as String,
        strategyName: m['strategy_name'] as String,
        datasetId: m['dataset_id'] as String,
        symbol: m['symbol'] as String,
        metrics: Metrics.fromMap(jsonDecode(m['metrics'] as String) as Map<String, dynamic>),
        barCount: (m['bar_count'] as num).toInt(),
        runAt: DateTime.fromMillisecondsSinceEpoch((m['run_at'] as num).toInt()),
      );
}
