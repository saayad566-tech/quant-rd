/// Framework ingestion: the honest, working version of "learn from the books".
///
/// A framework is described in a small declarative schema — indicators,
/// comparison operators, hard thresholds, and risk rules — and this pipeline
/// turns that description into a live [BaseStrategy] in the factory. Nothing is
/// hardcoded by book name: the rules are data, the engine executes them.
///
/// Where the corpus comes from is deliberately explicit:
///  * frameworks bundled with the app (the catalogue in `book_catalogue.dart`),
///  * **public-domain texts** fetched from Project Gutenberg and parsed, and
///  * any framework document **you** supply, which is parsed locally.
///
/// This engine does not, and will not, download in-copyright books.
library;

import 'dart:convert';

import '../../data/models/candle.dart';
import '../indicators/indicators.dart';
import 'strategy_engine.dart';

// ---------------------------------------------------------------------------
// Schema
// ---------------------------------------------------------------------------

enum RuleOp {
  crossesAbove('crossesAbove'),
  crossesBelow('crossesBelow'),
  greaterThan('greaterThan'),
  lessThan('lessThan'),
  greaterOrEqual('greaterOrEqual'),
  lessOrEqual('lessOrEqual');

  const RuleOp(this.id);
  final String id;

  static RuleOp? byId(String? id) {
    for (final o in RuleOp.values) {
      if (o.id.toLowerCase() == (id ?? '').toLowerCase()) return o;
    }
    return null;
  }
}

/// The indicator series a rule compares. `period` is used by the averaging and
/// oscillator series; `period2` is the slow leg for MACD and the deviation
/// multiple for Bollinger.
class SeriesSpec {
  final String indicator;
  final int period;
  final int period2;
  final double multiple;

  const SeriesSpec({required this.indicator, this.period = 14, this.period2 = 0, this.multiple = 2});

  static SeriesSpec fromJson(Map<String, dynamic> m) => SeriesSpec(
        indicator: (m['indicator'] as String? ?? 'close').toLowerCase(),
        period: (m['period'] as num?)?.toInt() ?? 14,
        period2: (m['period2'] as num?)?.toInt() ?? 0,
        multiple: (m['multiple'] as num?)?.toDouble() ?? 2,
      );
}

class RuleSpec {
  final SeriesSpec left;
  final RuleOp op;

  /// Either a constant threshold or another series to compare against.
  final double? value;
  final SeriesSpec? right;

  const RuleSpec({required this.left, required this.op, this.value, this.right});

  static RuleSpec? fromJson(Map<String, dynamic> m) {
    final left = m['left'] is Map ? SeriesSpec.fromJson((m['left'] as Map).cast<String, dynamic>()) : SeriesSpec.fromJson(m);
    final op = RuleOp.byId(m['op'] as String?);
    if (op == null) return null;
    final right = m['right'] is Map ? SeriesSpec.fromJson((m['right'] as Map).cast<String, dynamic>()) : null;
    final value = (m['value'] as num?)?.toDouble();
    if (right == null && value == null) return null;
    return RuleSpec(left: left, op: op, value: value, right: right);
  }
}

class FrameworkSpec {
  final String id;
  final String name;
  final String description;
  final String sourceTitle;
  final String sourceAuthor;
  final int? sourceYear;
  final String rule;
  final List<RuleSpec> entry;
  final List<RuleSpec> exit;
  final double stopPct;
  final double targetPct;
  final Map<String, String> notes;

  const FrameworkSpec({
    required this.id,
    required this.name,
    required this.description,
    required this.sourceTitle,
    required this.sourceAuthor,
    required this.rule,
    required this.entry,
    required this.exit,
    this.sourceYear,
    this.stopPct = 8,
    this.targetPct = 0,
    this.notes = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'source': {'title': sourceTitle, 'author': sourceAuthor, if (sourceYear != null) 'year': sourceYear},
        'rule': rule,
        'entry': [for (final r in entry) _ruleToJson(r)],
        'exit': [for (final r in exit) _ruleToJson(r)],
        'risk': {'stopPct': stopPct, 'targetPct': targetPct},
        if (notes.isNotEmpty) 'notes': notes,
      };

  static Map<String, dynamic> _ruleToJson(RuleSpec r) => {
        'left': {'indicator': r.left.indicator, 'period': r.left.period, if (r.left.period2 != 0) 'period2': r.left.period2},
        'op': r.op.id,
        if (r.value != null) 'value': r.value,
        if (r.right != null) 'right': {'indicator': r.right!.indicator, 'period': r.right!.period, if (r.right!.period2 != 0) 'period2': r.right!.period2},
      };
}

// ---------------------------------------------------------------------------
// Parser
// ---------------------------------------------------------------------------

class FrameworkParseError implements Exception {
  final String message;
  const FrameworkParseError(this.message);
  @override
  String toString() => 'FrameworkParseError: $message';
}

class FrameworkParser {
  const FrameworkParser._();

  /// Parses one framework document. Throws [FrameworkParseError] with a
  /// descriptive message rather than returning a half-built strategy.
  static FrameworkSpec parse(Map<String, dynamic> m) {
    final id = (m['id'] as String?)?.trim();
    if (id == null || id.isEmpty) throw const FrameworkParseError('A framework needs a non-empty "id".');
    final name = (m['name'] as String?)?.trim();
    if (name == null || name.isEmpty) throw FrameworkParseError('Framework "$id" needs a "name".');

    final source = (m['source'] as Map?)?.cast<String, dynamic>() ?? const {};
    final title = (source['title'] as String?)?.trim() ?? '';
    final author = (source['author'] as String?)?.trim() ?? '';
    if (title.isEmpty) throw FrameworkParseError('Framework "$id" must cite a source title — provenance is mandatory.');

    final entryRaw = (m['entry'] as List?) ?? const [];
    final exitRaw = (m['exit'] as List?) ?? const [];
    final entry = <RuleSpec>[];
    for (final e in entryRaw) {
      if (e is! Map) continue;
      final r = RuleSpec.fromJson(e.cast<String, dynamic>());
      if (r == null) throw FrameworkParseError('Framework "$id" has an entry rule with an unknown operator or no target.');
      entry.add(r);
    }
    if (entry.isEmpty) throw FrameworkParseError('Framework "$id" has no usable entry rules.');

    final exit = <RuleSpec>[];
    for (final e in exitRaw) {
      if (e is! Map) continue;
      final r = RuleSpec.fromJson(e.cast<String, dynamic>());
      if (r != null) exit.add(r);
    }

    final risk = (m['risk'] as Map?)?.cast<String, dynamic>() ?? const {};
    final notes = <String, String>{};
    final notesRaw = (m['notes'] as Map?)?.cast<String, dynamic>();
    if (notesRaw != null) {
      for (final e in notesRaw.entries) {
        notes[e.key] = '${e.value}';
      }
    }

    return FrameworkSpec(
      id: id,
      name: name,
      description: (m['description'] as String?) ?? '',
      sourceTitle: title,
      sourceAuthor: author,
      sourceYear: (source['year'] as num?)?.toInt(),
      rule: (m['rule'] as String?) ?? 'Declared rule set',
      entry: entry,
      exit: exit,
      stopPct: (risk['stopPct'] as num?)?.toDouble() ?? 8,
      targetPct: (risk['targetPct'] as num?)?.toDouble() ?? 0,
      notes: notes,
    );
  }

  /// Parses a document that is either a single framework object or an object
  /// with a "frameworks" array.
  static List<FrameworkSpec> parseDocument(String jsonText) {
    final dynamic decoded = jsonDecode(jsonText);
    if (decoded is List) {
      return [for (final e in decoded) parse((e as Map).cast<String, dynamic>())];
    }
    if (decoded is Map) {
      final map = decoded.cast<String, dynamic>();
      final list = map['frameworks'];
      if (list is List) {
        return [for (final e in list) parse((e as Map).cast<String, dynamic>())];
      }
      return [parse(map)];
    }
    throw const FrameworkParseError('The document must be a framework object, an array, or an object with a "frameworks" array.');
  }
}

// ---------------------------------------------------------------------------
// The executable strategy produced from a spec
// ---------------------------------------------------------------------------

/// Resolves a [SeriesSpec] to a numeric series over the bars.
class _SeriesResolver {
  static List<double?> resolve(SeriesSpec spec, List<Candle> candles) {
    final closes = candles.map((c) => c.close).toList(growable: false);
    switch (spec.indicator) {
      case 'close':
        return closes.map((c) => c).toList(growable: false);
      case 'open':
        return candles.map((c) => c.open).toList(growable: false);
      case 'high':
        return candles.map((c) => c.high).toList(growable: false);
      case 'low':
        return candles.map((c) => c.low).toList(growable: false);
      case 'volume':
        return candles.map((c) => c.volume).toList(growable: false);
      case 'sma':
        return Indicators.sma(closes, spec.period);
      case 'ema':
        return Indicators.ema(closes, spec.period);
      case 'rsi':
        return Indicators.rsi(closes, spec.period);
      case 'atr':
        return Indicators.atr(candles, spec.period);
      case 'roc':
        return Indicators.roc(closes, spec.period);
      case 'macdline':
        return Indicators.macd(closes, spec.period == 14 ? 12 : spec.period, spec.period2 == 0 ? 26 : spec.period2, 9).$1;
      case 'macdsignal':
        return Indicators.macd(closes, spec.period == 14 ? 12 : spec.period, spec.period2 == 0 ? 26 : spec.period2, 9).$2;
      case 'macdhist':
        return Indicators.macd(closes, spec.period == 14 ? 12 : spec.period, spec.period2 == 0 ? 26 : spec.period2, 9).$3;
      case 'bollupper':
        return Indicators.bollinger(closes, spec.period, spec.multiple).$1;
      case 'bollmiddle':
        return Indicators.bollinger(closes, spec.period, spec.multiple).$2;
      case 'bolllower':
        return Indicators.bollinger(closes, spec.period, spec.multiple).$3;
      default:
        throw FrameworkParseError('Unknown indicator "${spec.indicator}".');
    }
  }
}

/// A strategy defined entirely by data. Stateless and reproducible.
class DeclarativeStrategy extends BaseStrategy {
  final FrameworkSpec spec;

  DeclarativeStrategy(this.spec);

  @override
  String get id => spec.id;
  @override
  String get name => spec.name;
  @override
  String get description => spec.description.isEmpty ? spec.rule : spec.description;
  @override
  StrategyProvenance get provenance => StrategyProvenance(
        frameworkId: spec.id,
        frameworkName: spec.name,
        source: '${spec.sourceAuthor}, "${spec.sourceTitle}"${spec.sourceYear == null ? '' : ' (${spec.sourceYear})'}',
        rule: spec.rule,
        notes: spec.notes,
      );

  @override
  List<StrategyParameter> get parameters => [
        StrategyParameter(key: 'stopPct', label: 'Stop-loss (%)', value: spec.stopPct, min: 0.5, max: 50, description: 'Initial stop distance below entry.'),
        StrategyParameter(key: 'targetPct', label: 'Target (%)', value: spec.targetPct, min: 0, max: 200, description: 'Optional profit target; 0 disables it.'),
      ];

  @override
  BaseStrategy configure(Map<String, double> values) {
    final stop = values['stopPct'] ?? spec.stopPct;
    final target = values['targetPct'] ?? spec.targetPct;
    return DeclarativeStrategy(FrameworkSpec(
      id: spec.id,
      name: spec.name,
      description: spec.description,
      sourceTitle: spec.sourceTitle,
      sourceAuthor: spec.sourceAuthor,
      sourceYear: spec.sourceYear,
      rule: spec.rule,
      entry: spec.entry,
      exit: spec.exit,
      stopPct: stop.clamp(0.5, 50),
      targetPct: target.clamp(0, 200),
      notes: spec.notes,
    ));
  }

  @override
  List<Signal> generateSignals(String symbol, List<Candle> candles) {
    final out = <Signal>[];
    if (candles.length < 3) return out;

    // Resolve each distinct series once.
    final cache = <String, List<double?>>{};
    List<double?> series(SeriesSpec s) =>
        cache.putIfAbsent('${s.indicator}:${s.period}:${s.period2}:${s.multiple}', () => _SeriesResolver.resolve(s, candles));

    bool evalRule(RuleSpec r, int i) {
      final left = series(r.left);
      if (i < 0 || i >= left.length) return false;
      final l = left[i];
      if (l == null) return false;

      final right = r.right == null ? null : series(r.right!);
      final rv = right == null ? r.value : (i < right.length ? right[i] : null);
      if (rv == null) return false;

      switch (r.op) {
        case RuleOp.greaterThan:
          return l > rv;
        case RuleOp.lessThan:
          return l < rv;
        case RuleOp.greaterOrEqual:
          return l >= rv;
        case RuleOp.lessOrEqual:
          return l <= rv;
        case RuleOp.crossesAbove:
          if (i == 0) return false;
          final pl = left[i - 1];
          final pr = right == null ? r.value : (i - 1 < right.length ? right[i - 1] : null);
          if (pl == null || pr == null) return false;
          return pl <= pr && l > rv;
        case RuleOp.crossesBelow:
          if (i == 0) return false;
          final pl = left[i - 1];
          final pr = right == null ? r.value : (i - 1 < right.length ? right[i - 1] : null);
          if (pl == null || pr == null) return false;
          return pl >= pr && l < rv;
      }
    }

    var inPosition = false;
    for (var i = 1; i < candles.length; i++) {
      final entryHit = spec.entry.every((r) => evalRule(r, i));
      final exitHit = spec.exit.isNotEmpty && spec.exit.any((r) => evalRule(r, i));

      if (!inPosition && entryHit) {
        inPosition = true;
        final price = candles[i].close;
        out.add(Signal(
          symbol: symbol,
          time: candles[i].time,
          index: i,
          side: SignalSide.long,
          price: price,
          stop: spec.stopPct > 0 ? price * (1 - spec.stopPct / 100) : null,
          target: spec.targetPct > 0 ? price * (1 + spec.targetPct / 100) : null,
          rationale: 'Entry rules satisfied (${spec.entry.length} condition${spec.entry.length == 1 ? '' : 's'})',
          provenance: provenance,
        ));
      } else if (inPosition && exitHit) {
        inPosition = false;
        out.add(Signal(
          symbol: symbol,
          time: candles[i].time,
          index: i,
          side: SignalSide.exit,
          price: candles[i].close,
          rationale: 'Exit rule satisfied',
          provenance: provenance,
        ));
      }
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// Ingestion
// ---------------------------------------------------------------------------

class IngestResult {
  final List<String> registered;
  final List<String> failed;

  const IngestResult({required this.registered, required this.failed});

  int get count => registered.length;
}

class FrameworkIngestor {
  const FrameworkIngestor._();

  /// Parses a document and registers every framework it contains. A malformed
  /// framework is reported, never silently dropped.
  static IngestResult ingestDocument(String jsonText) {
    final registered = <String>[];
    final failed = <String>[];
    List<FrameworkSpec> specs;
    try {
      specs = FrameworkParser.parseDocument(jsonText);
    } catch (e) {
      return IngestResult(registered: const [], failed: ['$e']);
    }
    for (final s in specs) {
      try {
        StrategyFactory.register(DeclarativeStrategy(s));
        registered.add(s.id);
      } catch (e) {
        failed.add('${s.id}: $e');
      }
    }
    return IngestResult(registered: registered, failed: failed);
  }

  /// Serialises the bundled catalogue's frameworks into the schema, so the
  /// shipped set is itself ingested through the same pipeline rather than
  /// special-cased.
  static List<FrameworkSpec> fromCatalogue(List<Map<String, dynamic>> catalogueJson) {
    final out = <FrameworkSpec>[];
    for (final m in catalogueJson) {
      try {
        out.add(FrameworkParser.parse(m));
      } catch (_) {
        // A catalogue entry that does not fit the schema is skipped here and
        // remains available through the framework knowledge base.
      }
    }
    return out;
  }
}
