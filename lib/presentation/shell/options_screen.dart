/// Options chain and dealer-gamma dashboard.
///
/// The chain comes from one of two sources, and the screen always says which:
///  * **A simulated feed** — a deterministic chain generated around a spot price
///    with a volatility smile. It is labelled "SIMULATED" wherever it is shown,
///    because the numbers are modelled, not observed.
///  * **Your own chain** — paste strikes, open interest and implied volatilities
///    from a real chain you have.
///
/// The maths is the tested [QuantOptions] / [QuantGex] library. Nothing here
/// fabricates a live feed.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/quant/quant_options.dart';
import '../widgets/common.dart';
import 'book_intelligence_screen.dart';

/// Where a displayed chain came from.
enum ChainSource { simulated, userSupplied }

class ChainResult {
  final ChainSource source;
  final double spot;
  final double timeToExpiryYears;
  final double rate;
  final List<OptionQuote> chain;
  final GexResult gex;

  const ChainResult({
    required this.source,
    required this.spot,
    required this.timeToExpiryYears,
    required this.rate,
    required this.chain,
    required this.gex,
  });
}

/// Deterministic simulated chain with a volatility smile. Clearly modelled.
class SimulatedOptionFeed {
  const SimulatedOptionFeed._();

  static List<OptionQuote> generate({
    required double spot,
    double baseVolatility = 0.25,
    int strikesEachSide = 8,
    double strikeStepPct = 1.5,
  }) {
    final chain = <OptionQuote>[];
    for (var k = -strikesEachSide; k <= strikesEachSide; k++) {
      final strike = (spot * (1 + k * strikeStepPct / 100)).roundToDouble();
      // A smile: implied volatility rises away from the money.
      final moneyness = (strike / spot - 1).abs();
      final iv = baseVolatility + moneyness * 1.6;
      // Open interest peaks near the money and thins in the wings.
      final oi = (4000 * math.exp(-math.pow(k / 3.2, 2))).roundToDouble();
      chain.add(OptionQuote(strike: strike, openInterest: oi, impliedVolatility: iv, isCall: true, dealerLong: true));
      chain.add(OptionQuote(strike: strike, openInterest: oi * 0.8, impliedVolatility: iv, isCall: false, dealerLong: false));
    }
    return chain;
  }
}

/// Parses a pasted chain: `strike, openInterest, impliedVolatility, C|P` per line.
class ChainCsvParser {
  const ChainCsvParser._();

  static (List<OptionQuote>?, String?) parse(String text) {
    final out = <OptionQuote>[];
    final lines = text.split(RegExp(r'[\r\n]+'));
    var lineNo = 0;
    for (final raw in lines) {
      lineNo++;
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (lineNo == 1 && line.toLowerCase().contains('strike')) continue; // header
      final parts = line.split(RegExp(r'[,\t]+')).map((s) => s.trim()).toList();
      if (parts.length < 3) return (null, 'Line $lineNo: expected at least "strike, openInterest, impliedVolatility".');
      final strike = double.tryParse(parts[0]);
      final oi = double.tryParse(parts[1]);
      var iv = double.tryParse(parts[2]);
      if (strike == null || oi == null || iv == null) return (null, 'Line $lineNo: one of the numbers could not be parsed.');
      if (iv > 3) iv = iv / 100; // accept "25" as 25%
      final isCall = parts.length < 4 || !parts[3].toLowerCase().startsWith('p');
      out.add(OptionQuote(strike: strike, openInterest: oi, impliedVolatility: iv, isCall: isCall, dealerLong: isCall));
    }
    if (out.isEmpty) return (null, 'No rows were found.');
    return (out, null);
  }
}

class OptionsScreen extends ConsumerStatefulWidget {
  const OptionsScreen({super.key});

  @override
  ConsumerState<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends ConsumerState<OptionsScreen> {
  final _spot = TextEditingController(text: '100');
  final _days = TextEditingController(text: '30');
  final _rate = TextEditingController(text: '4');
  final _vol = TextEditingController(text: '25');
  final _manual = TextEditingController();

  ChainSource _source = ChainSource.simulated;
  ChainResult? _result;
  String? _error;

  @override
  void dispose() {
    _spot.dispose();
    _days.dispose();
    _rate.dispose();
    _vol.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _compute() {
    final spot = double.tryParse(_spot.text.trim());
    final days = double.tryParse(_days.text.trim());
    final ratePct = double.tryParse(_rate.text.trim());
    final volPct = double.tryParse(_vol.text.trim());
    if (spot == null || spot <= 0 || days == null || days <= 0) {
      setState(() => _error = 'Spot and days to expiry must be positive numbers.');
      return;
    }
    final rate = (ratePct ?? 4) / 100;
    final t = days / 365;

    List<OptionQuote> chain;
    if (_source == ChainSource.simulated) {
      chain = SimulatedOptionFeed.generate(spot: spot, baseVolatility: (volPct ?? 25) / 100);
    } else {
      final (parsed, err) = ChainCsvParser.parse(_manual.text);
      if (parsed == null) {
        setState(() => _error = err ?? 'The chain could not be parsed.');
        return;
      }
      chain = parsed;
    }

    setState(() {
      _error = null;
      _result = ChainResult(
        source: _source,
        spot: spot,
        timeToExpiryYears: t,
        rate: rate,
        chain: chain,
        gex: QuantGex.compute(spot: spot, chain: chain, timeToExpiry: t, rate: rate),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = _result;
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        const SectionHeader(
          title: 'Options & Dealer Gamma',
          subtitle: 'Black-Scholes pricing, the Greeks, and net dealer gamma exposure across strikes.',
        ),
        const SizedBox(height: Spacing.sm),
        const ComplianceBanner(compact: true),
        const SizedBox(height: Spacing.md),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Chain source', subtitle: 'Pick where the option data comes from'),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  _sourceChip('Simulated (modelled)', ChainSource.simulated, c),
                  const SizedBox(width: Spacing.xs),
                  _sourceChip('My own chain', ChainSource.userSupplied, c),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  SizedBox(width: 110, child: TextField(controller: _spot, decoration: const InputDecoration(labelText: 'Spot', isDense: true))),
                  const SizedBox(width: Spacing.xs),
                  SizedBox(width: 110, child: TextField(controller: _days, decoration: const InputDecoration(labelText: 'Days', isDense: true))),
                  const SizedBox(width: Spacing.xs),
                  SizedBox(width: 110, child: TextField(controller: _rate, decoration: const InputDecoration(labelText: 'Rate %', isDense: true))),
                  const SizedBox(width: Spacing.xs),
                  SizedBox(width: 130, child: TextField(controller: _vol, decoration: const InputDecoration(labelText: 'Base vol %', isDense: true))),
                  const Spacer(),
                  FilledButton.icon(onPressed: _compute, icon: const Icon(Icons.insights_rounded, size: 18), label: const Text('Compute')),
                ],
              ),
              if (_source == ChainSource.userSupplied) ...[
                const SizedBox(height: Spacing.sm),
                TextField(
                  controller: _manual,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'strike, openInterest, impliedVolatility, C|P\n100, 4000, 0.25, C\n105, 3200, 0.26, C',
                    isDense: true,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: Spacing.xs),
                Text(_error!, style: TextStyle(color: c.danger, fontSize: 12)),
              ],
            ],
          ),
        ),
        if (r != null) ...[
          const SizedBox(height: Spacing.md),
          if (r.source == ChainSource.simulated)
            GlassCard(
              tint: c.warning.withValues(alpha: 0.08),
              border: Border.all(color: c.warning.withValues(alpha: 0.35)),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: c.warning),
                  const SizedBox(width: Spacing.xs),
                  Expanded(
                    child: Text(
                      'SIMULATED CHAIN: these strikes, open interests and volatilities are modelled around the spot price you '
                      'entered, not observed in a market. The maths is exact; the inputs are not real. Paste a real chain to use actual figures.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.warning, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Spacing.md),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Dealer gamma exposure',
                  subtitle: r.source == ChainSource.simulated ? 'Modelled chain' : 'Your supplied chain',
                ),
                const SizedBox(height: Spacing.sm),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: [
                    MetricTile(label: 'Net GEX', value: _compact(r.gex.totalGex), accent: r.gex.isPositiveGamma ? c.success : c.danger),
                    MetricTile(label: 'Gamma wall', value: r.gex.gammaWall?.toStringAsFixed(2) ?? '—'),
                    MetricTile(label: 'Gamma flip', value: r.gex.gammaFlipLevel?.toStringAsFixed(2) ?? '—'),
                    MetricTile(label: 'Strikes', value: '${r.gex.gexByStrike.length}'),
                  ],
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  r.gex.isPositiveGamma
                      ? 'Positive net gamma: dealer hedging dampens moves and price tends to pin toward the wall.'
                      : 'Negative net gamma: dealer hedging can amplify moves away from the wall.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
          _GexHeatmap(gex: r.gex, spot: r.spot),
          const SizedBox(height: Spacing.md),
          _SmileChart(chain: r.chain, spot: r.spot),
        ],
      ],
    );
  }

  Widget _sourceChip(String label, ChainSource s, dynamic c) {
    final selected = _source == s;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() {
        _source = s;
        _result = null;
      }),
    );
  }

  static String _compact(double v) {
    final a = v.abs();
    if (a >= 1e9) return '${(v / 1e9).toStringAsFixed(2)}B';
    if (a >= 1e6) return '${(v / 1e6).toStringAsFixed(2)}M';
    if (a >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}k';
    return v.toStringAsFixed(1);
  }
}

/// A bar heatmap of net gamma by strike, coloured by sign.
class _GexHeatmap extends StatelessWidget {
  final GexResult gex;
  final double spot;

  const _GexHeatmap({required this.gex, required this.spot});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final entries = gex.gexByStrike.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) {
      return GlassCard(child: Text('No strikes to display.', style: Theme.of(context).textTheme.bodySmall));
    }
    final maxAbs = entries.map((e) => e.value.abs()).reduce(math.max);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Net gamma by strike', subtitle: 'Bar height is magnitude; colour is sign'),
          const SizedBox(height: Spacing.sm),
          SizedBox(
            height: 170,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final e in entries)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: maxAbs == 0 ? 0.02 : (e.value.abs() / maxAbs).clamp(0.02, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: (e.value >= 0 ? c.success : c.danger).withValues(alpha: 0.75),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xxs),
          Row(
            children: [
              for (final e in entries)
                Expanded(
                  child: Text(
                    e.key.toStringAsFixed(0),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 8.5, color: e.key == gex.gammaWall ? c.accent : c.textMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text('Spot ${spot.toStringAsFixed(2)} · strikes are ordered low to high; the highlighted label is the gamma wall.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5)),
        ],
      ),
    );
  }
}

/// Implied volatility against strike — the smile.
class _SmileChart extends StatelessWidget {
  final List<OptionQuote> chain;
  final double spot;

  const _SmileChart({required this.chain, required this.spot});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Average the call and put implied vol at each strike.
    final byStrike = <double, List<double>>{};
    for (final q in chain) {
      byStrike.putIfAbsent(q.strike, () => []).add(q.impliedVolatility);
    }
    final points = byStrike.entries.map((e) => MapEntry(e.key, e.value.reduce((a, b) => a + b) / e.value.length)).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (points.length < 2) {
      return GlassCard(child: Text('Not enough strikes to draw a smile.', style: Theme.of(context).textTheme.bodySmall));
    }

    final minIv = points.map((p) => p.value).reduce(math.min);
    final maxIv = points.map((p) => p.value).reduce(math.max);
    final span = (maxIv - minIv) == 0 ? 1.0 : (maxIv - minIv);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Volatility smile', subtitle: 'Implied volatility against strike'),
          const SizedBox(height: Spacing.sm),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in points)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text((p.value * 100).toStringAsFixed(0), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 8)),
                          const SizedBox(height: 2),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: ((p.value - minIv) / span).clamp(0.05, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: c.accentAlt.withValues(alpha: 0.7),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xxs),
          Row(
            children: [
              for (final p in points)
                Expanded(
                  child: Text(
                    p.key.toStringAsFixed(0),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 8.5, color: c.textMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text('Implied volatility rises away from the money — the classic smile shape.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5)),
        ],
      ),
    );
  }
}
