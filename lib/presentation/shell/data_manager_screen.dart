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
                onPressed: _busy ? null : _importCsv,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Import CSV'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _fetchFromProvider,
                icon: const Icon(Icons.cloud_download_rounded, size: 18),
                label: const Text('Fetch from provider'),
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
                      message: 'Import a CSV of OHLCV data, fetch from a provider using your own key, or load a bundled sample to get started.',
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

  Future<void> _importCsv() async {
    setState(() => _busy = true);
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['csv', 'txt']);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes, allowMalformed: true);
      final report = CsvCandleParser.parse(content);
      if (!mounted) return;
      if (report.candles.isEmpty) {
        _snack('No valid OHLCV rows found in the file.', error: true);
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
          );
      if (!mounted) return;
      if (error != null) {
        _snack(error, error: true);
      } else {
        _snack('Imported ${Fmt.integer(report.candles.length)} candles for ${meta.symbol.toUpperCase()}.');
      }
    } catch (e) {
      if (mounted) _snack('Import failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fetchFromProvider() async {
    final keys = await ref.read(apiKeysProvider.future);
    if (!mounted) return;
    final params = await showDialog<_FetchParams>(
      context: context,
      builder: (ctx) => _FetchDialog(keys: keys),
    );
    if (params == null) return;
    setState(() => _busy = true);
    try {
      final candles = await ref.read(marketDataClientProvider).fetch(
            provider: params.provider,
            apiKey: params.apiKey,
            symbol: params.symbol,
            interval: params.interval,
            customUrl: params.provider == ApiProvider.custom ? params.apiKey : null,
          );
      final error = await ref.read(dataActionsProvider).saveCandles(
            workspaceId: _wsId(),
            symbol: params.symbol,
            interval: params.interval,
            candles: candles,
            source: _sourceFor(params.provider),
          );
      if (!mounted) return;
      if (error != null) {
        _snack(error, error: true);
      } else {
        _snack('Fetched ${Fmt.integer(candles.length)} candles for ${params.symbol.toUpperCase()}.');
      }
    } catch (e) {
      if (mounted) _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

  DataSource _sourceFor(ApiProvider p) {
    switch (p) {
      case ApiProvider.alphaVantage:
        return DataSource.alphaVantage;
      case ApiProvider.twelveData:
        return DataSource.twelveData;
      case ApiProvider.polygon:
        return DataSource.polygon;
      case ApiProvider.finnhub:
        return DataSource.finnhub;
      case ApiProvider.custom:
        return DataSource.custom;
    }
  }

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
      return GlassCard(
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
  final ApiProvider provider;
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
  ApiProvider _provider = ApiProvider.alphaVantage;
  BarInterval _interval = BarInterval.d1;
  final _symbol = TextEditingController(text: 'AAPL');
  final _key = TextEditingController();

  @override
  void initState() {
    super.initState();
    _key.text = widget.keys[_provider] ?? '';
  }

  @override
  void dispose() {
    _symbol.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasStored = widget.keys.containsKey(_provider);
    return AlertDialog(
      title: const Text('Fetch from provider'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FieldLabel(
              label: 'Provider',
              child: DropdownButtonFormField<ApiProvider>(
                initialValue: _provider,
                items: ApiProvider.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(),
                onChanged: (v) {
                  setState(() {
                    _provider = v ?? ApiProvider.alphaVantage;
                    _key.text = widget.keys[_provider] ?? '';
                  });
                },
              ),
            ),
            const SizedBox(height: Spacing.sm),
            FieldLabel(
              label: 'Symbol',
              hint: 'e.g. AAPL, RELIANCE.NS, BTC-USD',
              child: TextField(controller: _symbol),
            ),
            const SizedBox(height: Spacing.sm),
            FieldLabel(
              label: _provider == ApiProvider.custom ? 'Endpoint URL' : 'API key',
              hint: hasStored ? 'Using your saved key' : 'Enter a key (saved in the API Keys tab)',
              child: TextField(
                controller: _key,
                obscureText: _provider != ApiProvider.custom,
                decoration: InputDecoration(
                  hintText: hasStored ? Fmt.maskKey(widget.keys[_provider]!) : 'Paste key',
                ),
              ),
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
            const SizedBox(height: Spacing.xs),
            Text(
              'Provider free tiers have request limits; results are cached locally for offline use.',
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
