/// Market Data screen: import CSV, fetch from a provider, load samples, and
/// manage saved datasets. Fully functional offline.
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/api_provider.dart';
import '../../data/models/dataset.dart';
import '../../data/export/export_service.dart';
import '../../data/parsers/csv_candle_parser.dart';
import '../../data/parsers/json_candle_parser.dart';
import '../../data/sample/sample_data.dart';
import '../../domain/providers/core_providers.dart';
import '../../domain/providers/feature_providers.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/export_helper.dart';

class DataManagerScreen extends ConsumerStatefulWidget {
  const DataManagerScreen({super.key});

  @override
  ConsumerState<DataManagerScreen> createState() => _DataManagerScreenState();
}

class _DataManagerScreenState extends ConsumerState<DataManagerScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final datasets = ref.watch(datasetsProvider);
    final selectedId = ref.watch(selectedDatasetIdProvider);
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Market Data',
            subtitle: 'Import OHLCV CSV files, fetch from a provider, or load bundled samples.',
            trailing: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                : null,
          ),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _fetchData,
                icon: const Icon(Icons.cloud_download_rounded, size: 18),
                label: const Text('Fetch data (auto)'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _importFile,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Import CSV / JSON'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _loadSample,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('Load sample data'),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          Expanded(
            child: datasets.when(
              loading: () => const LoadingView(label: 'Loading datasets\u2026'),
              error: (e, _) => ErrorView(message: 'Could not load datasets: $e', onRetry: () => ref.invalidate(datasetsProvider)),
              data: (list) {
                if (list.isEmpty) {
                  return GlassCard(
                    child: EmptyState(
                      icon: Icons.storage_rounded,
                      title: 'No datasets yet',
                      message: 'Type a symbol and press “Fetch data” — Quant RD tries free keyless sources first, then any provider you have a key for. You can also import a CSV/JSON file or load a bundled sample.',
                      action: FilledButton.icon(
                        onPressed: _loadSample,
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text('Load sample data'),
                      ),
                    ),
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final d = list[i];
                          final selected = d.id == selectedId;
                          return GlassCard(
                            margin: const EdgeInsets.only(bottom: Spacing.sm),
                            onTap: () => ref.read(selectedDatasetIdProvider.notifier).select(d.id),
                            border: selected ? Border.all(color: c.accent, width: 1.4) : null,
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.12), borderRadius: Radii.rXs),
                                  child: Icon(Icons.candlestick_chart_rounded, color: c.accent, size: 20),
                                ),
                                const SizedBox(width: Spacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(d.symbol, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                                      Text(
                                        '${d.source.label} \u00b7 ${d.interval.label} \u00b7 ${Fmt.integer(d.barCount)} bars',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      Text(
                                        '${Fmt.date(d.start)} \u2192 ${Fmt.date(d.end)}',
                                        style: Theme.of(context).textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Delete dataset',
                                  icon: Icon(Icons.delete_outline_rounded, size: 18, color: c.textMuted),
                                  onPressed: () => _confirmDelete(d),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      flex: 2,
                      child: _DatasetPreview(datasetId: selectedId),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Dataset d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete dataset?'),
        content: Text('“${d.symbol}” and its ${Fmt.integer(d.barCount)} candles will be removed. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(dataActionsProvider).deleteDataset(d.id);
      if (ref.read(selectedDatasetIdProvider) == d.id) {
        ref.read(selectedDatasetIdProvider.notifier).clear();
      }
    }
  }

  Future<void> _importFile() async {
    setState(() => _busy = true);
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['csv', 'txt', 'json']);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes, allowMalformed: true);
      final trimmed = content.trimLeft();
      final looksJson = file.name.toLowerCase().endsWith('.json') || trimmed.startsWith('{') || trimmed.startsWith('[');
      final report = looksJson ? JsonCandleParser.parse(content) : CsvCandleParser.parse(content);
      if (!mounted) return;
      if (report.candles.isEmpty) {
        final why = report.warnings.isEmpty ? 'No valid OHLCV rows were found.' : report.warnings.join(' ');
        _snack('Could not read that file. $why', error: true);
        return;
      }
      final meta = await _promptDatasetMeta(
        defaultSymbol: file.name.split('.').first,
        detectedColumns: report.detectedColumns,
        rowCount: report.candles.length,
        warnings: report.warnings,
      );
      if (meta == null) return;
      final error = await ref.read(dataActionsProvider).importCsv(
            workspaceId: _wsId(),
            symbol: meta.symbol,
            interval: meta.interval,
            report: report,
            source: looksJson ? DataSource.jsonImport : DataSource.csvImport,
          );
      if (!mounted) return;
      if (error != null) {
        _snack(error, error: true);
      } else {
        _snack('Imported ${Fmt.integer(report.candles.length)} candles for ${meta.symbol.toUpperCase()} from ${looksJson ? 'JSON' : 'CSV'}.');
      }
    } catch (e) {
      if (mounted) _snack('Import failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Smart fetch: local cache first, then free keyless sources, then any keyed
  /// provider the user has configured. Reports what it did in plain English.
  Future<void> _fetchData() async {
    final keys = await ref.read(apiKeysProvider.future);
    if (!mounted) return;
    final params = await showDialog<_FetchParams>(
      context: context,
      builder: (ctx) => _FetchDialog(keys: keys),
    );
    if (params == null) return;
    setState(() => _busy = true);
    try {
      final result = await ref.read(dataActionsProvider).smartFetch(
            workspaceId: _wsId(),
            symbol: params.symbol,
            interval: params.interval,
            preferProvider: params.provider,
          );
      if (!mounted) return;
      if (result.error != null) {
        _snack(result.error!, error: true);
      } else {
        _showNotes(result.notes);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showNotes(List<String> notes) {
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: notes
            .map((n) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(n)))
            .toList(),
      ),
      backgroundColor: c.surfaceAlt,
      duration: const Duration(seconds: 7),
    ));
  }

  Future<void> _loadSample() async {
    final sample = await showDialog<SampleSeries>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Load sample data'),
        children: SampleData.bundled()
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, s),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_awesome_rounded),
                    title: Text(s.symbol),
                    subtitle: Text('${s.interval.label} \u00b7 ${Fmt.integer(s.candles.length)} bars \u00b7 synthetic'),
                  ),
                ))
            .toList(),
      ),
    );
    if (sample == null) return;
    setState(() => _busy = true);
    try {
      final error = await ref.read(dataActionsProvider).saveCandles(
            workspaceId: _wsId(),
            symbol: sample.symbol,
            interval: sample.interval,
            candles: sample.candles,
            source: DataSource.custom,
            note: 'Synthetic sample data (not real market data).',
          );
      if (!mounted) return;
      if (error != null) {
        _snack(error, error: true);
      } else {
        _snack('Loaded ${sample.symbol}.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _wsId() => ref.read(activeWorkspaceIdProvider).value ?? StorageKeys.defaultWorkspaceId;

  Future<_DatasetMeta?> _promptDatasetMeta({
    required String defaultSymbol,
    required List<String> detectedColumns,
    required int rowCount,
    required List<String> warnings,
  }) {
    return showDialog<_DatasetMeta>(
      context: context,
      builder: (ctx) => _DatasetMetaDialog(
        defaultSymbol: defaultSymbol,
        detectedColumns: detectedColumns,
        rowCount: rowCount,
        warnings: warnings,
      ),
    );
  }

  void _snack(String message, {bool error = false}) {
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? c.danger.withValues(alpha: 0.9) : c.surfaceAlt,
    ));
  }
}

class _DatasetPreview extends ConsumerWidget {
  final String? datasetId;
  const _DatasetPreview({this.datasetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    if (datasetId == null) {
      return const GlassCard(
        child: SizedBox(
          height: 260,
          child: EmptyState(
            icon: Icons.insights_rounded,
            title: 'No dataset selected',
            message: 'Select a dataset to preview its price series.',
          ),
        ),
      );
    }
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Preview', style: Theme.of(context).textTheme.titleMedium)),
              Consumer(builder: (context, ref, _) {
                return TextButton.icon(
                  onPressed: () async {
                    final candles = await ref.read(datasetCandlesProvider(datasetId!).future);
                    if (candles.isEmpty || !context.mounted) return;
                    await exportText(
                      context,
                      fileName: 'dataset_${datasetId}_${candles.length}_bars.csv',
                      content: ExportService.candlesToCsv(candles),
                      log: ref.read(activityLogProvider),
                    );
                  },
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('CSV'),
                );
              }),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Consumer(builder: (context, ref, _) {
            final async = ref.watch(datasetCandlesProvider(datasetId!));
            return async.when(
              loading: () => const SizedBox(height: 220, child: LoadingView()),
              error: (e, _) => SizedBox(height: 220, child: ErrorView(message: '$e')),
              data: (candles) => candles.isEmpty
                  ? SizedBox(height: 220, child: Center(child: Text('No candles', style: TextStyle(color: c.textMuted))))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RepaintBoundary(child: PriceChart(candles: candles)),
                        const SizedBox(height: Spacing.sm),
                        Text(
                          '${Fmt.integer(candles.length)} candles \u00b7 ${Fmt.date(candles.first.time)} \u2192 ${Fmt.date(candles.last.time)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
            );
          }),
        ],
      ),
    );
  }
}

class _DatasetMeta {
  final String symbol;
  final BarInterval interval;
  const _DatasetMeta(this.symbol, this.interval);
}

class _DatasetMetaDialog extends StatefulWidget {
  final String defaultSymbol;
  final List<String> detectedColumns;
  final int rowCount;
  final List<String> warnings;

  const _DatasetMetaDialog({
    required this.defaultSymbol,
    required this.detectedColumns,
    required this.rowCount,
    required this.warnings,
  });

  @override
  State<_DatasetMetaDialog> createState() => _DatasetMetaDialogState();
}

class _DatasetMetaDialogState extends State<_DatasetMetaDialog> {
  late final TextEditingController _symbol;
  BarInterval _interval = BarInterval.d1;

  @override
  void initState() {
    super.initState();
    _symbol = TextEditingController(text: widget.defaultSymbol.toUpperCase());
  }

  @override
  void dispose() {
    _symbol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      title: const Text('Confirm dataset'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${Fmt.integer(widget.rowCount)} rows detected.', style: Theme.of(context).textTheme.bodyMedium),
            if (widget.warnings.isNotEmpty) ...[
              const SizedBox(height: Spacing.xs),
              ...widget.warnings.map((w) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: c.warning),
                      const SizedBox(width: 6),
                      Expanded(child: Text(w, style: Theme.of(context).textTheme.bodySmall)),
                    ],
                  )),
            ],
            const SizedBox(height: Spacing.md),
            FieldLabel(
              label: 'Symbol / name',
              child: TextField(controller: _symbol),
            ),
            const SizedBox(height: Spacing.sm),
            FieldLabel(
              label: 'Bar interval',
              child: DropdownButtonFormField<BarInterval>(
                initialValue: _interval,
                items: BarInterval.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(),
                onChanged: (v) => setState(() => _interval = v ?? BarInterval.d1),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _DatasetMeta(_symbol.text.trim(), _interval)),
          child: const Text('Import'),
        ),
      ],
    );
  }
}

class _FetchParams {
  /// null means "Auto" — try the local cache, then free keyless sources, then
  /// any provider the user has a key for.
  final ApiProvider? provider;
  final String apiKey;
  final String symbol;
  final BarInterval interval;
  const _FetchParams(this.provider, this.apiKey, this.symbol, this.interval);
}

class _FetchDialog extends StatefulWidget {
  final Map<ApiProvider, String> keys;
  const _FetchDialog({required this.keys});

  @override
  State<_FetchDialog> createState() => _FetchDialogState();
}

class _FetchDialogState extends State<_FetchDialog> {
  ApiProvider? _provider; // null = Auto
  BarInterval _interval = BarInterval.d1;
  final _symbol = TextEditingController(text: 'AAPL');
  final _key = TextEditingController();

  @override
  void dispose() {
    _symbol.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = _provider;
    final hasStored = p != null && widget.keys.containsKey(p);
    final isCustom = p == ApiProvider.custom;
    final isKeyless = p != null && !p.requiresKey && !isCustom;

    return AlertDialog(
      title: const Text('Fetch market data'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.08),
                borderRadius: Radii.rSm,
                border: Border.all(color: c.accent.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 16, color: c.accent),
                  const SizedBox(width: Spacing.xs),
                  Expanded(
                    child: Text(
                      'Auto checks your local cache first, then free keyless sources (Yahoo Finance, Binance), then any provider you have a key for.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),
            FieldLabel(
              label: 'Symbol',
              hint: 'e.g. AAPL, RELIANCE.NS, BTC-USD, NIFTY50',
              child: TextField(controller: _symbol),
            ),
            const SizedBox(height: Spacing.sm),
            FieldLabel(
              label: 'Bar interval',
              child: DropdownButtonFormField<BarInterval>(
                initialValue: _interval,
                items: BarInterval.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(),
                onChanged: (v) => setState(() => _interval = v ?? BarInterval.d1),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            FieldLabel(
              label: 'Source',
              child: DropdownButtonFormField<ApiProvider?>(
                initialValue: _provider,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<ApiProvider?>(value: null, child: Text('Auto — free sources first (recommended)')),
                  ...ApiProvider.values.map(
                    (e) => DropdownMenuItem<ApiProvider?>(
                      value: e,
                      child: Text(e.requiresKey ? e.label : '${e.label} — no key needed', overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() {
                  _provider = v;
                  _key.text = (v != null && widget.keys.containsKey(v)) ? widget.keys[v]! : '';
                }),
              ),
            ),
            if (p != null && p.requiresKey) ...[
              const SizedBox(height: Spacing.sm),
              FieldLabel(
                label: 'API key',
                hint: hasStored ? 'Using your saved key' : 'Enter a key (save it in the API Keys tab)',
                child: TextField(
                  controller: _key,
                  obscureText: true,
                  decoration: InputDecoration(hintText: hasStored ? Fmt.maskKey(widget.keys[p]!) : 'Paste key'),
                ),
              ),
            ],
            if (isCustom) ...[
              const SizedBox(height: Spacing.sm),
              FieldLabel(
                label: 'Endpoint URL',
                child: TextField(controller: _key, decoration: const InputDecoration(hintText: 'https://example.com/ohlcv')),
              ),
            ],
            if (isKeyless) ...[
              const SizedBox(height: Spacing.xs),
              Text('No API key needed for this source.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.success)),
            ],
            const SizedBox(height: Spacing.xs),
            Text(
              'Whatever is fetched is cached locally, so repeat backtests run instantly offline.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.textMuted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _FetchParams(_provider, _key.text.trim(), _symbol.text.trim(), _interval)),
          child: const Text('Fetch'),
        ),
      ],
    );
  }
}
