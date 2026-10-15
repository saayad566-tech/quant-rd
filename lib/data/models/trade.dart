/// A completed round-trip trade produced by the backtester.
library;

enum ExitReason {
  signal('Signal'),
  stopLoss('Stop-loss'),
  takeProfit('Take-profit'),
  endOfData('End of data');

  const ExitReason(this.label);
  final String label;
}

class Trade {
  final int id;
  final bool isLong;
  final DateTime entryTime;
  final DateTime exitTime;
  final double entryPrice;
  final double exitPrice;
  final double quantity;
  final double pnl;
  final double pnlPct;
  final double fees;
  final double equityAfter;
  final ExitReason exitReason;

  const Trade({
    required this.id,
    required this.isLong,
    required this.entryTime,
    required this.exitTime,
    required this.entryPrice,
    required this.exitPrice,
    required this.quantity,
    required this.pnl,
    required this.pnlPct,
    required this.fees,
    required this.equityAfter,
    required this.exitReason,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'is_long': isLong ? 1 : 0,
        'entry_time': entryTime.millisecondsSinceEpoch,
        'exit_time': exitTime.millisecondsSinceEpoch,
        'entry_price': entryPrice,
        'exit_price': exitPrice,
        'quantity': quantity,
        'pnl': pnl,
        'pnl_pct': pnlPct,
        'fees': fees,
        'equity_after': equityAfter,
        'exit_reason': exitReason.name,
      };

  factory Trade.fromMap(Map<String, dynamic> m) => Trade(
        id: (m['id'] as num).toInt(),
        isLong: ((m['is_long'] as num).toInt()) == 1,
        entryTime: DateTime.fromMillisecondsSinceEpoch((m['entry_time'] as num).toInt(), isUtc: true),
        exitTime: DateTime.fromMillisecondsSinceEpoch((m['exit_time'] as num).toInt(), isUtc: true),
        entryPrice: (m['entry_price'] as num).toDouble(),
        exitPrice: (m['exit_price'] as num).toDouble(),
        quantity: (m['quantity'] as num).toDouble(),
        pnl: (m['pnl'] as num).toDouble(),
        pnlPct: (m['pnl_pct'] as num).toDouble(),
        fees: (m['fees'] as num).toDouble(),
        equityAfter: (m['equity_after'] as num).toDouble(),
        exitReason: ExitReason.values.firstWhere((e) => e.name == m['exit_reason'], orElse: () => ExitReason.signal),
      );
}
