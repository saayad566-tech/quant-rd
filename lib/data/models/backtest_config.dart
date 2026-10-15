/// Backtest configuration: capital, costs and risk settings.
library;

class BacktestConfig {
  final double initialCapital;
  final double feeBps; // commission + charges per side, in basis points
  final double slippageBps; // adverse fill per side, in basis points
  final double riskFreeRatePct; // annual risk-free rate for Sharpe/Sortino
  final int barsPerYear; // annualisation factor for the dataset interval

  const BacktestConfig({
    this.initialCapital = 100000,
    this.feeBps = 5,
    this.slippageBps = 2,
    this.riskFreeRatePct = 6.0,
    this.barsPerYear = 252,
  });

  BacktestConfig copyWith({
    double? initialCapital,
    double? feeBps,
    double? slippageBps,
    double? riskFreeRatePct,
    int? barsPerYear,
  }) =>
      BacktestConfig(
        initialCapital: initialCapital ?? this.initialCapital,
        feeBps: feeBps ?? this.feeBps,
        slippageBps: slippageBps ?? this.slippageBps,
        riskFreeRatePct: riskFreeRatePct ?? this.riskFreeRatePct,
        barsPerYear: barsPerYear ?? this.barsPerYear,
      );

  Map<String, dynamic> toMap() => {
        'initial_capital': initialCapital,
        'fee_bps': feeBps,
        'slippage_bps': slippageBps,
        'risk_free_pct': riskFreeRatePct,
        'bars_per_year': barsPerYear,
      };

  factory BacktestConfig.fromMap(Map<String, dynamic> m) => BacktestConfig(
        initialCapital: (m['initial_capital'] as num?)?.toDouble() ?? 100000,
        feeBps: (m['fee_bps'] as num?)?.toDouble() ?? 5,
        slippageBps: (m['slippage_bps'] as num?)?.toDouble() ?? 2,
        riskFreeRatePct: (m['risk_free_pct'] as num?)?.toDouble() ?? 6.0,
        barsPerYear: (m['bars_per_year'] as num?)?.toInt() ?? 252,
      );
}
