/// CSV / text builders for exporting results and data. Pure functions, no I/O,
/// so they are trivially unit-testable and work on every platform.
library;

import '../models/backtest_result.dart';
import '../models/candle.dart';

class ExportService {
  const ExportService._();

  /// Escapes a field for CSV: wraps in quotes when it contains a comma, quote,
  /// or newline, and doubles any embedded quotes.
  static String _esc(Object? value) {
    final s = value?.toString() ?? '';
    if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static String _row(List<Object?> cells) => cells.map(_esc).join(',');

  /// One row per completed trade.
  static String tradesToCsv(BacktestResult result) {
    final b = StringBuffer();
    b.writeln(_row(['id', 'side', 'entry_time', 'exit_time', 'entry_price', 'exit_price', 'quantity', 'pnl', 'pnl_pct', 'fees', 'exit_reason']));
    for (final t in result.trades) {
      b.writeln(_row([
        t.id,
        t.isLong ? 'long' : 'short',
        t.entryTime.toIso8601String(),
        t.exitTime.toIso8601String(),
        t.entryPrice,
        t.exitPrice,
        t.quantity,
        t.pnl,
        t.pnlPct,
        t.fees,
        t.exitReason.label,
      ]));
    }
    return b.toString();
  }

  /// Key/value metrics summary as CSV.
  static String metricsToCsv(BacktestResult result) {
    final m = result.metrics;
    final b = StringBuffer();
    b.writeln(_row(['metric', 'value']));
    final rows = <List<Object?>>[
      ['strategy', result.strategyName],
      ['symbol', result.symbol],
      ['run_at', result.runAt.toIso8601String()],
      ['bars', result.barCount],
      ['initial_capital', m.initialCapital],
      ['final_equity', m.finalEquity],
      ['net_profit', m.netProfit],
      ['total_return_pct', m.totalReturnPct],
      ['cagr_pct', m.cagrPct],
      ['volatility_pct', m.volatilityPct],
      ['sharpe', m.sharpe],
      ['sortino', m.sortino],
      ['max_drawdown_pct', m.maxDrawdownPct],
      ['calmar', m.calmar],
      ['trade_count', m.tradeCount],
      ['win_rate_pct', m.winRatePct],
      ['profit_factor', m.profitFactor],
      ['expectancy', m.expectancy],
      ['avg_win', m.avgWin],
      ['avg_loss', m.avgLoss],
      ['exposure_pct', m.exposurePct],
      ['total_fees', m.totalFees],
      ['buy_hold_return_pct', m.buyHoldReturnPct],
    ];
    for (final r in rows) {
      b.writeln(_row(r));
    }
    return b.toString();
  }

  /// One row per candle.
  static String candlesToCsv(List<Candle> candles) {
    final b = StringBuffer();
    b.writeln(_row(['timestamp', 'open', 'high', 'low', 'close', 'volume']));
    for (final c in candles) {
      b.writeln(_row([c.time.toIso8601String(), c.open, c.high, c.low, c.close, c.volume]));
    }
    return b.toString();
  }

  /// Equity curve as CSV (time, equity, drawdown %).
  static String equityToCsv(BacktestResult result) {
    final b = StringBuffer();
    b.writeln(_row(['timestamp', 'equity', 'drawdown_pct']));
    for (final p in result.equityCurve) {
      b.writeln(_row([p.time.toIso8601String(), p.equity, p.drawdownPct]));
    }
    return b.toString();
  }

  /// A safe file name stem from a symbol / strategy name.
  static String safeName(String input) =>
      input.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_').replaceAll(RegExp(r'_+'), '_');
}
