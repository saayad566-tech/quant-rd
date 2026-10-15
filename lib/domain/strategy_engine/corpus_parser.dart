/// Public-domain corpus extraction.
///
/// Turns open-source or user-supplied text into candidate framework rules.
///
/// The honest position, stated up front: a rule stated in prose is a **draft**
/// until it maps cleanly onto the executable schema — a known indicator, a known
/// operator, and a numeric or series target. Anything that does not map is
/// **rejected with a reason**, never guessed at and never registered. So the
/// engine scales from real text without inventing mathematics, and every
/// registered rule carries its source title, author, year and the exact sentence
/// it came from.
///
/// Only public-domain, open-source or user-supplied text belongs here. The
/// extractor makes no network calls.
library;

import 'dart:convert';

import 'framework_ingestion.dart';

/// One sentence that looked like a rule, with what could be made of it.
class DraftRule {
  final String sentence;
  final RuleSpec? rule;

  /// 0..1 — how completely the sentence mapped onto the schema.
  final double confidence;

  /// Set when the sentence could not be turned into an executable rule.
  final String? rejection;

  const DraftRule({required this.sentence, required this.rule, required this.confidence, this.rejection});

  bool get accepted => rule != null;
}

class CorpusExtraction {
  final String title;
  final String author;
  final int? year;
  final List<DraftRule> drafts;

  const CorpusExtraction({
    required this.title,
    required this.author,
    this.year,
    required this.drafts,
  });

  List<DraftRule> get accepted => drafts.where((d) => d.accepted).toList(growable: false);
  List<DraftRule> get rejected => drafts.where((d) => !d.accepted).toList(growable: false);

  String get summary =>
      '${drafts.length} candidate sentences · ${accepted.length} mapped to the schema · ${rejected.length} rejected';

  /// Builds a framework document from the accepted drafts, ready for the
  /// ingestion pipeline. Returns null when nothing mapped.
  FrameworkSpec? toFramework({required String id, required String name}) {
    final rules = accepted.map((d) => d.rule!).toList(growable: false);
    if (rules.isEmpty) return null;
    return FrameworkSpec(
      id: id,
      name: name,
      description: 'Extracted from "$title" by $author. ${rules.length} rule(s) mapped from the source text.',
      sourceTitle: title,
      sourceAuthor: author,
      sourceYear: year,
      rule: 'Rules extracted from the source text',
      entry: rules,
      exit: const [],
      notes: {
        'provenance': 'Every rule was extracted from a specific sentence of the source and validated against the schema.',
        'extraction': summary,
      },
    );
  }

  String toJson() => jsonEncode({
        'title': title,
        'author': author,
        if (year != null) 'year': year,
        'summary': summary,
        'accepted': [
          for (final d in accepted)
            {
              'sentence': d.sentence,
              'confidence': d.confidence,
              'rule': {
                'indicator': d.rule!.left.indicator,
                'period': d.rule!.left.period,
                'op': d.rule!.op.id,
                if (d.rule!.value != null) 'value': d.rule!.value,
              },
            }
        ],
        'rejected': [
          for (final d in rejected) {'sentence': d.sentence, 'reason': d.rejection}
        ],
      });
}

class CorpusExtractor {
  const CorpusExtractor._();

  /// Indicators the extractor recognises, mapped to their schema name and a
  /// default period.
  static const Map<String, (String, int)> _indicators = {
    'rsi': ('rsi', 14),
    'relative strength index': ('rsi', 14),
    'macd': ('macdline', 12),
    'moving average': ('sma', 50),
    'moving average line': ('sma', 50),
    'simple moving average': ('sma', 50),
    'exponential moving average': ('ema', 20),
    'average': ('sma', 50),
    'bollinger upper': ('bollupper', 20),
    'upper band': ('bollupper', 20),
    'bollinger lower': ('bolllower', 20),
    'lower band': ('bolllower', 20),
    'average true range': ('atr', 14),
    'volume': ('volume', 1),
    'closing price': ('close', 1),
    'price': ('close', 1),
    'close': ('close', 1),
  };

  /// Comparators, longest first so "crosses above" wins over "above".
  static const List<(String, RuleOp)> _operators = [
    ('crosses above', RuleOp.crossesAbove),
    ('crosses over', RuleOp.crossesAbove),
    ('crosses below', RuleOp.crossesBelow),
    ('crosses under', RuleOp.crossesBelow),
    ('greater than or equal to', RuleOp.greaterOrEqual),
    ('less than or equal to', RuleOp.lessOrEqual),
    ('is greater than', RuleOp.greaterThan),
    ('is less than', RuleOp.lessThan),
    ('above', RuleOp.greaterThan),
    ('exceeds', RuleOp.greaterThan),
    ('over', RuleOp.greaterThan),
    ('below', RuleOp.lessThan),
    ('under', RuleOp.lessThan),
  ];

  /// Splits text into candidate sentences and maps each one.
  static CorpusExtraction extract(String text, {required String title, required String author, int? year}) {
    final sentences = _sentences(text);
    final drafts = <DraftRule>[];
    for (final s in sentences) {
      final draft = _mapSentence(s);
      if (draft != null) drafts.add(draft);
    }
    return CorpusExtraction(title: title, author: author, year: year, drafts: drafts);
  }

  static List<String> _sentences(String text) {
    // Strip Gutenberg boilerplate markers and normalise whitespace.
    final cleaned = text
        .replaceAll(RegExp(r'\r\n?'), '\n')
        .replaceAll(RegExp(r'\*\*\*\s*START OF[^\n]*\*\*\*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\*\*\*\s*END OF[^\n]*\*\*\*', caseSensitive: false), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ');
    final parts = cleaned.split(RegExp(r'(?<=[.!?])\s+|\n{2,}'));
    return parts.map((p) => p.trim()).where((p) => p.length >= 20 && p.length <= 400).toList(growable: false);
  }

  static DraftRule? _mapSentence(String sentence) {
    final lower = sentence.toLowerCase();
    final operatorHit = _findOperator(lower);
    final hasIndicator = _indicators.keys.any((k) => lower.contains(k));
    if (operatorHit == null && !hasIndicator) return null;

    if (operatorHit == null) {
      return DraftRule(sentence: sentence, rule: null, confidence: 0, rejection: 'No comparison operator was found in the sentence.');
    }
    if (!hasIndicator) {
      return DraftRule(sentence: sentence, rule: null, confidence: 0, rejection: 'No recognised indicator was found in the sentence.');
    }

    final op = operatorHit.$1;

    // The left series: the first recognised indicator, with a period if stated.
    final leftHit = _resolveSeries(lower);
    if (leftHit == null) {
      return DraftRule(sentence: sentence, rule: null, confidence: 0, rejection: 'The indicator could not be resolved to a series.');
    }
    final left = leftHit.$1;

    // The target: a second indicator after the first, or a bare number.
    final right = _resolveRight(lower, left, leftHit.$2);
    if (right != null) {
      return DraftRule(sentence: sentence, rule: RuleSpec(left: left, op: op, right: right), confidence: 0.9);
    }

    final number = _firstNumber(lower);
    if (number == null) {
      return DraftRule(sentence: sentence, rule: null, confidence: 0, rejection: 'No numeric threshold or second series was found.');
    }

    // A bare number on an RSI or a price is meaningful; on a moving average it
    // usually is not, so those are rejected rather than guessed.
    if (left.indicator == 'sma' || left.indicator == 'ema') {
      return DraftRule(
        sentence: sentence,
        rule: null,
        confidence: 0,
        rejection: 'A moving average compared to a bare number is ambiguous — the second series is not stated.',
      );
    }

    final confidence = op == RuleOp.crossesAbove || op == RuleOp.crossesBelow ? 0.75 : 0.85;
    return DraftRule(sentence: sentence, rule: RuleSpec(left: left, op: op, value: number), confidence: confidence);
  }

  /// Finds the operator that appears **earliest** in the sentence, matching on
  /// word boundaries so "oversold" never reads as the operator "over".
  static (RuleOp, int)? _findOperator(String lower) {
    (RuleOp, int, int)? best; // op, position, phrase length
    for (final (phrase, op) in _operators) {
      final m = RegExp(r'\b' + RegExp.escape(phrase) + r'\b').firstMatch(lower);
      if (m == null) continue;
      final better = best == null ||
          m.start < best.$2 ||
          (m.start == best.$2 && phrase.length > best.$3);
      if (better) best = (op, m.start, phrase.length);
    }
    return best == null ? null : (best.$1, best.$2);
  }

  /// The first indicator phrase in the sentence, with its position.
  static (SeriesSpec, int)? _resolveSeries(String lower) {
    // Prefer the longest indicator phrase so "bollinger upper" beats "upper".
    final keys = _indicators.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    (SeriesSpec, int)? best;
    for (final key in keys) {
      final at = lower.indexOf(key);
      if (at < 0) continue;
      final (indicator, defaultPeriod) = _indicators[key]!;
      final period = _periodNear(lower, at, key.length) ?? defaultPeriod;
      final spec = SeriesSpec(indicator: indicator, period: period);
      if (best == null || at < best.$2) best = (spec, at);
    }
    return best;
  }

  /// A **second** indicator appearing after the first, e.g. the 200-day average
  /// in "the 50-day average crosses above the 200-day average".
  static SeriesSpec? _resolveRight(String lower, SeriesSpec left, int leftAt) {
    final keys = _indicators.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    (int, SeriesSpec)? best;
    for (final key in keys) {
      var from = 0;
      while (true) {
        final at = lower.indexOf(key, from);
        if (at < 0) break;
        from = at + 1;
        if (at <= leftAt) continue;
        final (indicator, defaultPeriod) = _indicators[key]!;
        final period = _periodNear(lower, at, key.length) ?? defaultPeriod;
        final candidate = SeriesSpec(indicator: indicator, period: period);
        if (candidate.indicator == left.indicator && candidate.period == left.period) continue;
        if (best == null || at < best.$1) best = (at, candidate);
        break;
      }
    }
    return best?.$2;
  }

  /// Looks for a period near an indicator mention, e.g. "the 50-day average".
  static int? _periodNear(String lower, int at, int keyLength) {
    final window = lower.substring(at >= 30 ? at - 30 : 0, (at + keyLength + 20).clamp(0, lower.length));
    final m = RegExp(r'(\d{1,3})\s*[- ]?\s*(day|week|period|bar|month)').firstMatch(window);
    if (m != null) {
      final n = int.tryParse(m.group(1)!);
      if (n != null && n > 1 && n <= 400) {
        return m.group(2) == 'week' ? n * 5 : n;
      }
    }
    return null;
  }

  static double? _firstNumber(String lower) {
    final m = RegExp(r'(-?\d{1,6}(?:\.\d+)?)\s*(%|percent|per cent)?').firstMatch(lower);
    if (m == null) return null;
    final v = double.tryParse(m.group(1)!);
    if (v == null) return null;
    // A trailing percent sign makes the threshold a percentage value.
    return v;
  }
}
