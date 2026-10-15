/// Chart widgets (equity curve, drawdown, price) built on fl_chart 1.x.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/backtest_result.dart';
import '../../data/models/candle.dart';

/// Downsamples a list to at most [maxPoints], preserving the endpoints.
List<T> _downsample<T>(List<T> input, int maxPoints) {
  if (input.length <= maxPoints) return input;
  final step = input.length / maxPoints;
  final out = <T>[];
  for (var i = 0; i < maxPoints; i++) {
    out.add(input[(i * step).floor().clamp(0, input.length - 1)]);
  }
  if (out.last != input.last) out.add(input.last);
  return out;
}

class EquityCurveChart extends StatelessWidget {
  final List<EquityPoint> equity;
  final double initialCapital;
  final String currencySymbol;

  const EquityCurveChart({
    super.key,
    required this.equity,
    required this.initialCapital,
    this.currencySymbol = '\u20b9',
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (equity.isEmpty) {
      return const SizedBox(height: 240, child: Center(child: Text('No equity data')));
    }
    final points = _downsample(equity, 600);
    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].equity));
    }
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.08 + 1;
    final up = points.last.equity >= initialCapital;
    final lineColor = up ? c.success : c.danger;

    return SizedBox(
      height: 260,
      child: LineChart(
        LineChartData(
          minY: minY - pad,
          maxY: maxY + pad,
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 4 <= 0 ? 1 : (maxY - minY) / 4,
            getDrawingHorizontalLine: (_) => FlLine(color: c.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 62,
                getTitlesWidget: (value, meta) => Text(
                  _compact(value, currencySymbol),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (spots.length / 5).clamp(1, double.infinity),
                getTitlesWidget: (value, meta) {
                  final idx = value.round();
                  if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                  final d = points[idx].time.toLocal();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(DateFormat('MMM yy').format(d), style: Theme.of(context).textTheme.labelSmall),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => c.surfaceAlt,
              getTooltipItems: (touched) => touched.map((t) {
                final idx = t.x.round();
                final d = idx >= 0 && idx < points.length ? points[idx].time.toLocal() : null;
                return LineTooltipItem(
                  '${d == null ? '' : DateFormat('dd MMM yyyy').format(d)}\n${_money(t.y, currencySymbol)}',
                  TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.2,
              preventCurveOverShooting: true,
              color: lineColor,
              barWidth: 2.4,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [lineColor.withValues(alpha: 0.28), lineColor.withValues(alpha: 0.02)],
                ),
              ),
            ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: initialCapital,
                color: c.textMuted.withValues(alpha: 0.5),
                strokeWidth: 1,
                dashArray: const [5, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: Theme.of(context).textTheme.labelSmall,
                  labelResolver: (_) => 'Initial',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _compact(double v, String symbol) {
    if (v.abs() >= 10000000) return '$symbol${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v.abs() >= 100000) return '$symbol${(v / 100000).toStringAsFixed(1)}L';
    if (v.abs() >= 1000) return '$symbol${(v / 1000).toStringAsFixed(1)}k';
    return '$symbol${v.toStringAsFixed(0)}';
  }

  static String _money(double v, String symbol) {
    final f = NumberFormat.currency(symbol: symbol, decimalDigits: 0);
    return f.format(v);
  }
}

class DrawdownChart extends StatelessWidget {
  final List<EquityPoint> equity;

  const DrawdownChart({super.key, required this.equity});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (equity.isEmpty) {
      return const SizedBox(height: 160, child: Center(child: Text('No drawdown data')));
    }
    final points = _downsample(equity, 600);
    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), -points[i].drawdownPct));
    }
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);

    return SizedBox(
      height: 170,
      child: LineChart(
        LineChartData(
          minY: minY * 1.1,
          maxY: 0,
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: c.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (value, meta) => Text('${value.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.labelSmall),
              ),
            ),
          ),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: c.danger,
              barWidth: 1.8,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [c.danger.withValues(alpha: 0.35), c.danger.withValues(alpha: 0.02)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PriceChart extends StatelessWidget {
  final List<Candle> candles;

  const PriceChart({super.key, required this.candles});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (candles.isEmpty) {
      return const SizedBox(height: 220, child: Center(child: Text('No price data')));
    }
    final points = _downsample(candles, 600);
    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].close));
    }
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.08 + 0.01;

    return SizedBox(
      height: 230,
      child: LineChart(
        LineChartData(
          minY: minY - pad,
          maxY: maxY + pad,
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 4 <= 0 ? 1 : (maxY - minY) / 4,
            getDrawingHorizontalLine: (_) => FlLine(color: c.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (spots.length / 5).clamp(1, double.infinity),
                getTitlesWidget: (value, meta) {
                  final idx = value.round();
                  if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(DateFormat('MMM yy').format(points[idx].time.toLocal()), style: Theme.of(context).textTheme.labelSmall),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(value.abs() >= 100 ? 0 : 2), style: Theme.of(context).textTheme.labelSmall),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => c.surfaceAlt,
              getTooltipItems: (touched) => touched.map((t) {
                final idx = t.x.round();
                final d = idx >= 0 && idx < points.length ? points[idx].time.toLocal() : null;
                return LineTooltipItem(
                  '${d == null ? '' : DateFormat('dd MMM yyyy').format(d)}\n${t.y.toStringAsFixed(2)}',
                  TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.15,
              color: c.accent,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c.accent.withValues(alpha: 0.22), c.accent.withValues(alpha: 0.02)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
