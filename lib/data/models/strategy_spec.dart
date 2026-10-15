/// Strategy definition: a declarative rule set evaluated bar-by-bar.
///
/// A strategy is a list of entry conditions (ALL must hold to open) and exit
/// conditions (ANY holding closes the position), plus optional stop-loss /
/// take-profit and position sizing. This model is intentionally serialisable so
/// users can save, share and reload strategies.
library;

/// Technical indicators available to the rule builder.
enum IndicatorType {
  close('Close price', 0),
  sma('SMA', 1),
  ema('EMA', 1),
  rsi('RSI', 1),
  macdLine('MACD line', 3),
  macdSignal('MACD signal', 3),
  macdHist('MACD histogram', 3),
  bollUpper('Bollinger upper', 2),
  bollMiddle('Bollinger middle', 2),
  bollLower('Bollinger lower', 2),
  atr('ATR', 1),
  volume('Volume', 0),
  stochK('Stochastic %K', 3),
  stochD('Stochastic %D', 3),
  roc('Rate of change %', 1);

  const IndicatorType(this.label, this.paramCount);
  final String label;

  /// Number of parameters this indicator meaningfully consumes.
  final int paramCount;
}

/// A reference to a computed indicator series with its parameters.
class SeriesRef {
  final IndicatorType type;
  final int period;
  final int period2;
  final int period3;
  final double multiplier;

  const SeriesRef(
    this.type, {
    this.period = 14,
    this.period2 = 26,
    this.period3 = 9,
    this.multiplier = 2.0,
  });

  SeriesRef copyWith({
    IndicatorType? type,
    int? period,
    int? period2,
    int? period3,
    double? multiplier,
  }) =>
      SeriesRef(
        type ?? this.type,
        period: period ?? this.period,
        period2: period2 ?? this.period2,
        period3: period3 ?? this.period3,
        multiplier: multiplier ?? this.multiplier,
      );

  /// A stable identity used to cache computed series (two refs with identical
  /// parameters share one computation).
  String get key => '${type.name}:$period:$period2:$period3:$multiplier';

  /// Human-readable label including parameters.
  String get label {
    switch (type) {
      case IndicatorType.close:
        return 'Close';
      case IndicatorType.volume:
        return 'Volume';
      case IndicatorType.macdLine:
        return 'MACD($period,$period2,$period3)';
      case IndicatorType.macdSignal:
        return 'MACD signal($period,$period2,$period3)';
      case IndicatorType.macdHist:
        return 'MACD hist($period,$period2,$period3)';
      case IndicatorType.bollUpper:
        return 'BB upper($period, ${multiplier}x)';
      case IndicatorType.bollMiddle:
        return 'BB mid($period)';
      case IndicatorType.bollLower:
        return 'BB lower($period, ${multiplier}x)';
      case IndicatorType.stochK:
        return 'Stoch %K($period)';
      case IndicatorType.stochD:
        return 'Stoch %D($period,$period3)';
      default:
        return '${type.label}($period)';
    }
  }

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'p': period,
        'p2': period2,
        'p3': period3,
        'm': multiplier,
      };

  factory SeriesRef.fromMap(Map<String, dynamic> m) => SeriesRef(
        IndicatorType.values.firstWhere((e) => e.name == m['type'], orElse: () => IndicatorType.close),
        period: (m['p'] as num?)?.toInt() ?? 14,
        period2: (m['p2'] as num?)?.toInt() ?? 26,
        period3: (m['p3'] as num?)?.toInt() ?? 9,
        multiplier: (m['m'] as num?)?.toDouble() ?? 2.0,
      );
}

/// Comparison operators used inside a condition.
enum ComparisonOp {
  greaterThan('is above', '>'),
  lessThan('is below', '<'),
  crossesAbove('crosses above', '\u2197'),
  crossesBelow('crosses below', '\u2198');

  const ComparisonOp(this.label, this.glyph);
  final String label;
  final String glyph;
}

/// One side of a comparison: either an indicator series or a constant value.
class Operand {
  final bool isConstant;
  final SeriesRef? ref;
  final double constant;

  const Operand.series(this.ref)
      : isConstant = false,
        constant = 0;

  const Operand.constant(this.constant)
      : isConstant = true,
        ref = null;

  String get label => isConstant ? constant.toString() : ref!.label;

  Map<String, dynamic> toMap() => isConstant
      ? {'c': constant}
      : {'r': ref!.toMap()};

  factory Operand.fromMap(Map<String, dynamic> m) =>
      m.containsKey('c') ? Operand.constant((m['c'] as num).toDouble()) : Operand.series(SeriesRef.fromMap(m['r'] as Map<String, dynamic>));
}

/// A single comparison rule, e.g. `SMA(50) crosses above SMA(200)`.
class Condition {
  final Operand left;
  final ComparisonOp op;
  final Operand right;

  const Condition({required this.left, required this.op, required this.right});

  String get label => '${left.label} ${op.label} ${right.label}';

  /// All series referenced by this condition (for pre-computation).
  List<SeriesRef> get refs => [
        if (!left.isConstant) left.ref!,
        if (!right.isConstant) right.ref!,
      ];

  Map<String, dynamic> toMap() => {'l': left.toMap(), 'op': op.name, 'r': right.toMap()};

  factory Condition.fromMap(Map<String, dynamic> m) => Condition(
        left: Operand.fromMap(m['l'] as Map<String, dynamic>),
        op: ComparisonOp.values.firstWhere((e) => e.name == m['op'], orElse: () => ComparisonOp.greaterThan),
        right: Operand.fromMap(m['r'] as Map<String, dynamic>),
      );
}

enum PositionSizing {
  percentOfEquity('% of equity'),
  fixedAmount('Fixed amount'),
  allIn('All-in');

  const PositionSizing(this.label);
  final String label;
}

class StrategySpec {
  final String id;

  /// Owning workspace id. An empty string marks a global built-in template that
  /// is available in every workspace.
  final String workspaceId;
  final String name;
  final String description;
  final bool isBuiltIn;
  final List<Condition> entry;
  final List<Condition> exit;
  final double stopLossPct;
  final double takeProfitPct;
  final PositionSizing sizing;
  final double sizingValue;
  final bool allowShort;

  /// Whether the strategy is active (enabled) in this workspace.
  final bool enabled;
  final DateTime updatedAt;

  const StrategySpec({
    required this.id,
    this.workspaceId = '',
    required this.name,
    this.description = '',
    this.isBuiltIn = false,
    this.entry = const [],
    this.exit = const [],
    this.stopLossPct = 0,
    this.takeProfitPct = 0,
    this.sizing = PositionSizing.percentOfEquity,
    this.sizingValue = 100,
    this.allowShort = false,
    this.enabled = true,
    required this.updatedAt,
  });

  StrategySpec copyWith({
    String? workspaceId,
    String? name,
    String? description,
    List<Condition>? entry,
    List<Condition>? exit,
    double? stopLossPct,
    double? takeProfitPct,
    PositionSizing? sizing,
    double? sizingValue,
    bool? allowShort,
    bool? enabled,
    DateTime? updatedAt,
  }) =>
      StrategySpec(
        id: id,
        workspaceId: workspaceId ?? this.workspaceId,
        name: name ?? this.name,
        description: description ?? this.description,
        isBuiltIn: isBuiltIn,
        entry: entry ?? this.entry,
        exit: exit ?? this.exit,
        stopLossPct: stopLossPct ?? this.stopLossPct,
        takeProfitPct: takeProfitPct ?? this.takeProfitPct,
        sizing: sizing ?? this.sizing,
        sizingValue: sizingValue ?? this.sizingValue,
        allowShort: allowShort ?? this.allowShort,
        enabled: enabled ?? this.enabled,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Every series this strategy needs computed.
  List<SeriesRef> get requiredSeries {
    final map = <String, SeriesRef>{};
    for (final c in [...entry, ...exit]) {
      for (final r in c.refs) {
        map[r.key] = r;
      }
    }
    return map.values.toList();
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'workspace_id': workspaceId,
        'name': name,
        'description': description,
        'is_built_in': isBuiltIn ? 1 : 0,
        'entry': entry.map((e) => e.toMap()).toList(),
        'exit': exit.map((e) => e.toMap()).toList(),
        'stop_loss_pct': stopLossPct,
        'take_profit_pct': takeProfitPct,
        'sizing': sizing.name,
        'sizing_value': sizingValue,
        'allow_short': allowShort ? 1 : 0,
        'enabled': enabled ? 1 : 0,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory StrategySpec.fromMap(Map<String, dynamic> m) => StrategySpec(
        id: m['id'] as String,
        workspaceId: (m['workspace_id'] as String?) ?? '',
        name: m['name'] as String,
        description: (m['description'] as String?) ?? '',
        isBuiltIn: ((m['is_built_in'] as num?)?.toInt() ?? 0) == 1,
        entry: ((m['entry'] as List?) ?? const []).map((e) => Condition.fromMap(e as Map<String, dynamic>)).toList(),
        exit: ((m['exit'] as List?) ?? const []).map((e) => Condition.fromMap(e as Map<String, dynamic>)).toList(),
        stopLossPct: (m['stop_loss_pct'] as num?)?.toDouble() ?? 0,
        takeProfitPct: (m['take_profit_pct'] as num?)?.toDouble() ?? 0,
        sizing: PositionSizing.values.firstWhere((e) => e.name == m['sizing'], orElse: () => PositionSizing.percentOfEquity),
        sizingValue: (m['sizing_value'] as num?)?.toDouble() ?? 100,
        allowShort: ((m['allow_short'] as num?)?.toInt() ?? 0) == 1,
        enabled: ((m['enabled'] as num?)?.toInt() ?? 1) == 1,
        updatedAt: DateTime.fromMillisecondsSinceEpoch((m['updated_at'] as num?)?.toInt() ?? 0),
      );
}
