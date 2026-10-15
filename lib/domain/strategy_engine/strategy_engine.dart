/// The Strategy Plugin Engine.
///
/// Every book-derived strategy is a stateless, self-describing [BaseStrategy]:
/// it declares its provenance (which book and which rule), its tunable
/// parameters with bounds, and a pure `generateSignals` function over standard
/// price bars. Nothing here knows about the UI, and no strategy is hardcoded
/// into a screen or handler.
library;

import '../../data/models/candle.dart';

enum SignalSide { long, exit }

/// Where a strategy came from. Provenance is mandatory — a signal that cannot
/// cite its rule is not allowed out of the engine.
class StrategyProvenance {
  final String frameworkId;
  final String frameworkName;
  final String source;
  final String rule;
  final Map<String, String> notes;

  const StrategyProvenance({
    required this.frameworkId,
    required this.frameworkName,
    required this.source,
    required this.rule,
    this.notes = const {},
  });

  String get citation => '$source — $rule';
}

/// A declared, bounded parameter. Bounds are enforced on configuration so a
/// strategy cannot be driven into a nonsensical state.
class StrategyParameter {
  final String key;
  final String label;
  final double value;
  final double min;
  final double max;
  final String description;

  const StrategyParameter({
    required this.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.description,
  });

  StrategyParameter withValue(double v) => StrategyParameter(
        key: key,
        label: label,
        value: v.clamp(min, max),
        min: min,
        max: max,
        description: description,
      );
}

class Signal {
  final String symbol;
  final DateTime time;
  final int index;
  final SignalSide side;
  final double price;
  final double? stop;
  final double? target;
  final String rationale;
  final StrategyProvenance provenance;
  final Map<String, double> parameters;

  const Signal({
    required this.symbol,
    required this.time,
    required this.index,
    required this.side,
    required this.price,
    required this.rationale,
    required this.provenance,
    this.stop,
    this.target,
    this.parameters = const {},
  });

  bool get isEntry => side == SignalSide.long;

  /// The compliance marker appended to every strategy output.
  static const String complianceMarker =
      'NOT INVESTMENT ADVICE: an algorithmic output from a financial-literature framework, for research and education only.';

  String describe() =>
      '${isEntry ? 'ENTER' : 'EXIT'} $symbol at ${price.toStringAsFixed(2)}'
      '${stop != null ? ' · stop ${stop!.toStringAsFixed(2)}' : ''}'
      '${target != null ? ' · target ${target!.toStringAsFixed(2)}' : ''}'
      ' — $rationale [${provenance.citation}]';
}

/// The plugin contract.
abstract class BaseStrategy {
  String get id;
  String get name;
  String get description;
  StrategyProvenance get provenance;

  /// The parameters this strategy exposes. Read them through [param].
  List<StrategyParameter> get parameters;

  /// A configured copy. Implementations must validate through [StrategyParameter.withValue].
  BaseStrategy configure(Map<String, double> values);

  /// Pure signal generation over the supplied bars. Stateless: calling this twice
  /// with the same input returns the same output.
  List<Signal> generateSignals(String symbol, List<Candle> candles);

  double param(String key) {
    for (final p in parameters) {
      if (p.key == key) return p.value;
    }
    throw ArgumentError('Unknown parameter "$key" for strategy "$id"');
  }

  /// The most recent signal, or null when the last bar produced none.
  Signal? latestSignal(String symbol, List<Candle> candles) {
    final signals = generateSignals(symbol, candles);
    return signals.isEmpty ? null : signals.last;
  }
}

/// The registry. Strategies are looked up by id; nothing is instantiated by
/// name-matching in the UI.
class StrategyFactory {
  StrategyFactory._();

  static final Map<String, BaseStrategy> _registry = {};

  static void register(BaseStrategy strategy) {
    _registry[strategy.id] = strategy;
  }

  static void registerAll(Iterable<BaseStrategy> strategies) {
    for (final s in strategies) {
      register(s);
    }
  }

  static BaseStrategy? create(String id) => _registry[id];

  static List<BaseStrategy> all() => _registry.values.toList(growable: false);

  static List<String> get ids => _registry.keys.toList(growable: false);

  static bool get isEmpty => _registry.isEmpty;
}
