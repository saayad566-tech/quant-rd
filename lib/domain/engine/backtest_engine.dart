/// Event-driven backtest engine.
///
/// Design guarantees (no look-ahead bias):
///  * Indicator values at bar `i` use only bars `0..i`.
///  * A signal generated from the close of bar `i` is executed at the **open of
///    bar `i+1`**.
///  * Stop-loss / take-profit are evaluated intra-bar against the bar's high/low
///    and filled at the trigger price, adjusted for slippage.
///  * Fees and slippage are charged on both entry and exit.
///
/// Long/short semantics: when [StrategySpec.allowShort] is true the rule set is
/// interpreted symmetrically — an entry signal opens a long, an exit signal
/// opens a short, and the opposite signal closes the position.
library;

import '../../data/models/backtest_config.dart';
import '../../data/models/backtest_result.dart';
import '../../data/models/candle.dart';
import '../../data/models/strategy_spec.dart';
import '../../data/models/trade.dart';
import 'metrics.dart';
import 'strategy_engine.dart';

class BacktestEngine {
  const BacktestEngine._();

  static BacktestResult run({
    required String resultId,
    required List<Candle> candles,
    required StrategySpec strategy,
    required BacktestConfig config,
    required String datasetId,
    required String symbol,
    String workspaceId = '',
  }) {
    if (candles.length < 2) {
      return _emptyResult(resultId, strategy, config, datasetId, symbol, candles, workspaceId);
    }

    final refs = strategy.requiredSeries;
    final series = StrategyEngine.computeSeries(refs, candles);
    final warmup = StrategyEngine.warmupBars(strategy);
    final start = warmup.clamp(0, candles.length - 1);

    final feeRate = config.feeBps / 10000;
    final slipRate = config.slippageBps / 10000;

    var cash = config.initialCapital;
    _Position? position;
    var pendingEntry = 0; // 1 = enter long, -1 = enter short
    var pendingExit = false;

    final trades = <Trade>[];
    final equityCurve = <EquityPoint>[];
    final equityValues = <double>[];
    final times = <DateTime>[];
    var exposedBars = 0;
    var tradeId = 0;

    for (var i = start; i < candles.length; i++) {
      final bar = candles[i];

      // --- A. Execute queued orders at this bar's OPEN ---------------------
      if (position == null && pendingEntry != 0) {
        position = _open(
          isLong: pendingEntry > 0,
          price: _applySlip(bar.open, pendingEntry, slipRate),
          time: bar.time,
          equity: cash,
          strategy: strategy,
          feeRate: feeRate,
        );
        cash = _openCash(cash, position);
      } else if (position != null && pendingExit) {
        final t = _close(
          position: position,
          exitPrice: _applySlip(bar.open, position.isLong ? -1 : 1, slipRate),
          exitTime: bar.time,
          feeRate: feeRate,
          reason: ExitReason.signal,
          id: ++tradeId,
          cash: cash,
        );
        cash = t.cash;
        trades.add(t.trade);
        position = null;
      }
      pendingEntry = 0;
      pendingExit = false;

      // --- B. Intra-bar stop-loss / take-profit ---------------------------
      if (position != null && (strategy.stopLossPct > 0 || strategy.takeProfitPct > 0)) {
        final trigger = _slTpTrigger(position, strategy, bar);
        if (trigger != null) {
          final t = _close(
            position: position,
            exitPrice: _applySlip(trigger.price, position.isLong ? -1 : 1, slipRate),
            exitTime: bar.time,
            feeRate: feeRate,
            reason: trigger.reason,
            id: ++tradeId,
            cash: cash,
          );
          cash = t.cash;
          trades.add(t.trade);
          position = null;
        }
      }

      // --- C. Mark to market at close and record the equity point ---------
      if (position != null) exposedBars++;
      final equityNow = _equity(cash, position, bar.close);
      equityValues.add(equityNow);
      times.add(bar.time);

      // --- D. Evaluate signals at close → queue for the next bar's open ----
      if (position != null) {
        final closeSignal = position.isLong
            ? StrategyEngine.exitSignal(strategy, i, series)
            : StrategyEngine.entrySignal(strategy, i, series);
        if (closeSignal) pendingExit = true;
      } else {
        if (StrategyEngine.entrySignal(strategy, i, series)) {
          pendingEntry = 1;
        } else if (strategy.allowShort && StrategyEngine.exitSignal(strategy, i, series)) {
          pendingEntry = -1;
        }
      }
    }

    // Close any open position at the final close.
    if (position != null) {
      final last = candles.last;
      final t = _close(
        position: position,
        exitPrice: _applySlip(last.close, position.isLong ? -1 : 1, slipRate),
        exitTime: last.time,
        feeRate: feeRate,
        reason: ExitReason.endOfData,
        id: ++tradeId,
        cash: cash,
      );
      cash = t.cash;
      trades.add(t.trade);
      position = null;
      if (equityValues.isNotEmpty) equityValues[equityValues.length - 1] = cash;
    }

    // Drawdown series.
    double peak = equityValues.isEmpty ? config.initialCapital : equityValues.first;
    for (var i = 0; i < equityValues.length; i++) {
      if (equityValues[i] > peak) peak = equityValues[i];
      final dd = peak == 0 ? 0.0 : (peak - equityValues[i]) / peak * 100;
      equityCurve.add(EquityPoint(time: times[i], equity: equityValues[i], drawdownPct: dd));
    }

    final firstClose = candles[start].close;
    final lastClose = candles.last.close;
    final buyHold = firstClose == 0 ? 0.0 : (lastClose / firstClose - 1) * 100;

    final metrics = Metrics.compute(
      config: config,
      equity: equityValues,
      times: times,
      trades: trades,
      exposedBars: exposedBars,
      buyHoldReturnPct: buyHold,
    );

    return BacktestResult(
      id: resultId,
      workspaceId: workspaceId,
      strategyId: strategy.id,
      strategyName: strategy.name,
      datasetId: datasetId,
      symbol: symbol,
      config: config,
      equityCurve: equityCurve,
      trades: trades,
      metrics: metrics,
      barCount: candles.length - start,
      runAt: DateTime.now(),
    );
  }

  // --- Helpers ------------------------------------------------------------

  static _Position _open({
    required bool isLong,
    required double price,
    required DateTime time,
    required double equity,
    required StrategySpec strategy,
    required double feeRate,
  }) {
    final notional = _notional(strategy, equity);
    final qty = price <= 0 ? 0.0 : notional / price;
    final fee = notional * feeRate;
    return _Position(
      isLong: isLong,
      entryPrice: price,
      quantity: qty,
      entryTime: time,
      entryFee: fee,
    );
  }

  static double _openCash(double cash, _Position pos) {
    final notional = pos.entryPrice * pos.quantity;
    return pos.isLong ? cash - notional - pos.entryFee : cash + notional - pos.entryFee;
  }

  static double _applySlip(double price, int direction, double slipRate) =>
      price * (1 + direction * slipRate);

  static double _notional(StrategySpec strategy, double equity) {
    switch (strategy.sizing) {
      case PositionSizing.allIn:
        return equity;
      case PositionSizing.fixedAmount:
        return strategy.sizingValue.clamp(0, equity);
      case PositionSizing.percentOfEquity:
        final pct = strategy.sizingValue.clamp(0, 100) / 100;
        return equity * pct;
    }
  }

  static double _equity(double cash, _Position? position, double markPrice) {
    if (position == null) return cash;
    return position.isLong
        ? cash + position.quantity * markPrice
        : cash - position.quantity * markPrice;
  }

  static _Trigger? _slTpTrigger(_Position p, StrategySpec strategy, Candle bar) {
    if (p.isLong) {
      if (strategy.stopLossPct > 0) {
        final sl = p.entryPrice * (1 - strategy.stopLossPct / 100);
        if (bar.low <= sl) return _Trigger(sl, ExitReason.stopLoss);
      }
      if (strategy.takeProfitPct > 0) {
        final tp = p.entryPrice * (1 + strategy.takeProfitPct / 100);
        if (bar.high >= tp) return _Trigger(tp, ExitReason.takeProfit);
      }
    } else {
      if (strategy.stopLossPct > 0) {
        final sl = p.entryPrice * (1 + strategy.stopLossPct / 100);
        if (bar.high >= sl) return _Trigger(sl, ExitReason.stopLoss);
      }
      if (strategy.takeProfitPct > 0) {
        final tp = p.entryPrice * (1 - strategy.takeProfitPct / 100);
        if (bar.low <= tp) return _Trigger(tp, ExitReason.takeProfit);
      }
    }
    return null;
  }

  static _CloseResult _close({
    required _Position position,
    required double exitPrice,
    required DateTime exitTime,
    required double feeRate,
    required ExitReason reason,
    required int id,
    required double cash,
  }) {
    final notional = position.quantity * exitPrice;
    final fee = notional * feeRate;
    final newCash = position.isLong ? cash + notional - fee : cash - notional - fee;
    final grossPnl = position.isLong
        ? (exitPrice - position.entryPrice) * position.quantity
        : (position.entryPrice - exitPrice) * position.quantity;
    final totalFees = position.entryFee + fee;
    final pnl = grossPnl - totalFees;
    final entryNotional = position.entryPrice * position.quantity;
    final pnlPct = entryNotional == 0 ? 0.0 : pnl / entryNotional * 100;
    return _CloseResult(
      cash: newCash,
      trade: Trade(
        id: id,
        isLong: position.isLong,
        entryTime: position.entryTime,
        exitTime: exitTime,
        entryPrice: position.entryPrice,
        exitPrice: exitPrice,
        quantity: position.quantity,
        pnl: pnl,
        pnlPct: pnlPct,
        fees: totalFees,
        equityAfter: newCash,
        exitReason: reason,
      ),
    );
  }

  static BacktestResult _emptyResult(
    String id,
    StrategySpec strategy,
    BacktestConfig config,
    String datasetId,
    String symbol,
    List<Candle> candles,
    String workspaceId,
  ) =>
      BacktestResult(
        id: id,
        workspaceId: workspaceId,
        strategyId: strategy.id,
        strategyName: strategy.name,
        datasetId: datasetId,
        symbol: symbol,
        config: config,
        equityCurve: const [],
        trades: const [],
        metrics: Metrics.empty,
        barCount: candles.length,
        runAt: DateTime.now(),
      );
}

class _Position {
  final bool isLong;
  final double entryPrice;
  final double quantity;
  final DateTime entryTime;
  final double entryFee;
  _Position({
    required this.isLong,
    required this.entryPrice,
    required this.quantity,
    required this.entryTime,
    required this.entryFee,
  });
}

class _Trigger {
  final double price;
  final ExitReason reason;
  _Trigger(this.price, this.reason);
}

class _CloseResult {
  final double cash;
  final Trade trade;
  _CloseResult({required this.cash, required this.trade});
}
